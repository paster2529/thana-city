WITH event_click AS (
	SELECT profile_identity
		, event_datetime
		, deviceinfo_appversion AS app_version
		, eventprops_language AS language
		, eventprops_screen_name AS screen_name
		, eventprops_app_feature AS app_feature
		, eventprops_app_sub_feature AS app_sub_feature
		, eventprops_element_name AS element_name_raw
		, eventprops_element_display_name AS element_display_name
		, eventprops_link AS link
		, eventprops_provider AS provider
		, NULLIF(REGEXP_SUBSTR(eventprops_element_name, '^[a-z]+_([a-z_]+)_[0-9a-f]{8}-', 1, 1, 'e'), '') AS element_object
		, NULLIF(REGEXP_SUBSTR(eventprops_element_name, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 1, 1, 'i'), '') AS element_uuid
	FROM "trusted".clevertap_click
	WHERE profile_identity IS NOT NULL
--		AND NVL(eventprops_app_feature, '') <> 'auth'
)
, event_parsed AS (
	SELECT *
		, CASE
			WHEN element_object IS NOT NULL THEN SPLIT_PART(element_name_raw, '_', 1)||'_'||element_object
			WHEN element_name_raw LIKE 'btn\\_service\\_%' THEN 'btn_service'
			ELSE element_name_raw
			END AS element_name
		, CASE
			WHEN element_uuid IS NOT NULL THEN element_uuid
			WHEN element_name_raw LIKE 'btn\\_service\\_%' THEN NULLIF(REGEXP_SUBSTR(element_name_raw, '^btn_service_(.*)$', 1, 1, 'e'), '')
			ELSE element_name_raw
			END AS element_key
		, CASE
			WHEN element_name_raw LIKE 'tab\\_%' THEN 'tab_bar'
			WHEN element_name_raw IN ('btn_back', 'btn_contact_back') THEN 'back'
			WHEN element_name_raw = 'btn_close' THEN 'close'
			WHEN element_name_raw LIKE 'btn\\_%tutorial%' THEN 'tutorial'
			WHEN app_sub_feature IS NOT NULL THEN app_sub_feature
			WHEN element_name_raw IN ('btn_notifications', 'btn_my_profile') THEN 'header'
			WHEN element_object = 'article' OR element_name_raw = 'btn_see_all_articles' THEN 'article'
			WHEN element_name_raw = 'btn_search' OR screen_name = 'search_screen' THEN 'search'
			WHEN screen_name IN ('reward_filter_screen', 'merchant_selection_screen') THEN 'filter'
			WHEN element_name_raw = 'btn_my_coupon' THEN 'my_coupon'
			WHEN element_object = 'similar_reward' THEN 'similar_reward'
			WHEN element_name_raw = 'btn_member_card' THEN 'member_card'
			WHEN element_name_raw LIKE 'btn\\_language\\_%' THEN 'settings'
			WHEN element_name_raw = 'btn_open_wallet' THEN 'open_wallet'
			ELSE 'other'
			END AS section
		, CASE
			WHEN element_name_raw LIKE 'tab\\_%' THEN 1
			WHEN element_name_raw IN ('btn_back', 'btn_close', 'btn_contact_back') THEN 1
			ELSE 0
			END AS is_navigation
	FROM event_click
)
, dim_click_label AS (
	SELECT element_uuid
		, element_display_name AS click_label
	FROM (
		SELECT element_uuid
			, element_display_name
			, ROW_NUMBER() OVER (PARTITION BY element_uuid ORDER BY CASE WHEN language = 'EN' THEN 0 ELSE 1 END, event_datetime DESC) AS rn
		FROM event_parsed
		WHERE element_uuid IS NOT NULL
			AND NULLIF(element_display_name, '') IS NOT NULL
	) x
	WHERE rn = 1
)
--SELECT * FROM dim_click_label ORDER BY 1;
, base_content_items AS (
	SELECT id::VARCHAR AS content_items_id
		, target_member_types[0]::TEXT AS target_member_types
		, NULLIF(REGEXP_REPLACE(action_value, '[[:space:]]', ''), '') AS clean_path
	FROM "trusted".hook_content_items
)
, dim_content_items AS (
	SELECT content_items_id
		, target_member_types
		, clean_path
		, CASE
			WHEN clean_path IS NULL THEN NULL
			WHEN clean_path ILIKE 'http%' THEN 'external_link'
			WHEN content_uuid IS NOT NULL THEN 'content'
			ELSE 'internal_page'
			END AS path_category
		, CASE
			WHEN clean_path IS NULL THEN NULL
			WHEN clean_path ILIKE 'http%' THEN REGEXP_SUBSTR(clean_path, '://([^/]+)', 1, 1, 'e')
			WHEN content_uuid IS NOT NULL THEN REGEXP_SUBSTR(clean_path, '/([a-z0-9_]+)-[0-9a-f]{8}-', 1, 1, 'ie')
			ELSE REGEXP_SUBSTR(clean_path, '^/?([^/]+)', 1, 1, 'e')
			END AS action_value_type
		, CASE
			WHEN clean_path IS NULL THEN NULL
			WHEN content_uuid IS NOT NULL THEN content_uuid
			ELSE REGEXP_SUBSTR(clean_path, '[^/]+$')
			END AS action_value_id
	FROM (
		SELECT *
			, NULLIF(REGEXP_SUBSTR(clean_path, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 1, 1, 'i'), '') AS content_uuid
		FROM base_content_items
	) x
)
, dim_article AS (
	SELECT id::VARCHAR AS article_id
		, slug AS article_slug
		, NULLIF(title.en::TEXT, '') AS article_title_en
		, NULLIF(title.th::TEXT, '') AS article_title_th
		, CASE
			WHEN REGEXP_INSTR(NVL(title.en::TEXT, ''), '(^|[^a-z])test([^a-z]|$)', 1, 1, 0, 'i') > 0 THEN 1
			WHEN REGEXP_INSTR(NVL(slug, ''), '(^|[^a-z])test([^a-z]|$)', 1, 1, 0, 'i') > 0 THEN 1
			ELSE 0
			END AS is_test_article
	FROM "trusted".hook_articles
)
, dim_contents AS (
	SELECT a.content_items_id
		, a.target_member_types
		, a.path_category
		, a.action_value_type
		, a.action_value_id
		, b.article_id
		, b.article_slug
		, b.article_title_en
		, b.article_title_th
		, NVL(b.is_test_article, 0) AS is_test_article
	FROM dim_content_items a
	LEFT JOIN dim_article b ON a.action_value_id = b.article_id
)
, dim_rewards AS (
	SELECT reward_id::VARCHAR AS reward_id
		, MAX(CASE WHEN language_code = 'en' THEN NULLIF(name, '') END) AS reward_name_en
		, MAX(CASE WHEN language_code = 'th' THEN NULLIF(name, '') END) AS reward_name_th
	FROM "trusted".hook_reward_translations
	GROUP BY 1
)
, dim_reward_categories AS (
	SELECT id::VARCHAR AS category_id
		, NVL(NULLIF(name.en::VARCHAR, ''), NULLIF(name.th::VARCHAR, '')) AS category_name
	FROM "trusted".hook_reward_categories
)
, map_tag AS (
	SELECT 'tag_แบตมินตัน'::VARCHAR(200) AS raw_tag, 'tag_Badminton'::VARCHAR(200) AS tag_name
	UNION ALL SELECT 'tag_หมวดหมู่-กอล์ฟ', 'tag_Category-Golf'
	UNION ALL SELECT 'tag_หมวดหมู่-สปอร์ต', 'tag_Category-Sport'
	UNION ALL SELECT 'tag_เครื่องดื่ม', 'tag_Drink'
	UNION ALL SELECT 'tag_ไดรฟ์วิ่งเรนจ์', 'tag_Driving Range'
	UNION ALL SELECT 'tag_ฟิตเนส', 'tag_Fitness'
	UNION ALL SELECT 'tag_อาหาร', 'tag_Food'
	UNION ALL SELECT 'tag_กอล์ฟ', 'tag_Golf'
	UNION ALL SELECT 'tag_golfkiosk', 'tag_Golf Kiosk'
	UNION ALL SELECT 'tag_ชาร์กไบท์', 'tag_Sharkbite'
	UNION ALL SELECT 'tag_สแปลช', 'tag_Splash'
	UNION ALL SELECT 'tag_เทอร์เทิลเอ็กซ์', 'tag_TurtleX'
	UNION ALL SELECT 'tag_บีเคซาลอน', 'tag_BK Salon'
	UNION ALL SELECT 'tag_ฟุตซอล', 'tag_Futsal'
	UNION ALL SELECT 'tag_สปอร์ตคลับ', 'tag_Sport Club'
	UNION ALL SELECT 'tag_เทนนิส', 'tag_Tennis'
)
, final_data AS (
	SELECT a.profile_identity
		, a.event_datetime
		, a.event_datetime::DATE AS event_date
		, a.app_version
		, a.language AS lang
		, INITCAP(REPLACE(a.app_feature, '_', ' ')) AS app_feature
		, INITCAP(REPLACE(a.screen_name, '_', ' ')) AS screen_name
		, INITCAP(REPLACE(a.app_sub_feature, '_', ' ')) AS sub_feature
		, INITCAP(REPLACE(a.section, '_', ' ')) AS section
		, a.is_navigation
		, a.element_display_name AS display_name
		, CASE
			WHEN a.app_sub_feature = 'reward_tags' THEN 'Reward Tags'
			ELSE INITCAP(REPLACE(a.element_name, '_', ' '))
			END AS element_name
		, a.element_object
		, a.element_key
		, c.path_category
		, CASE
			WHEN f.article_id IS NOT NULL THEN 'Article'
			ELSE INITCAP(c.action_value_type)
			END AS type
		, NVL(c.article_slug, f.article_slug) AS article_slug
		, COALESCE(c.action_value_id, c.article_id, f.article_id, d.reward_id, e.category_id) AS content_id
		, COALESCE(c.article_title_en, c.article_title_th, f.article_title_en, f.article_title_th, c.action_value_id, d.reward_name_en, d.reward_name_th, e.category_name, t.tag_name, l.click_label, CASE WHEN a.element_object = 'banner' THEN 'Banner '||a.element_uuid END, a.element_key) AS content
		, a.provider
		, a.link
		, c.target_member_types
		, CASE
			WHEN a.element_object IS NULL THEN NULL
			WHEN COALESCE(c.content_items_id, f.article_id, d.reward_id, e.category_id) IS NOT NULL THEN 1
			ELSE 0
			END AS is_content_mapped
		, CASE
			WHEN NVL(c.is_test_article, 0) = 1 OR NVL(f.is_test_article, 0) = 1 THEN 1
			ELSE 0
			END AS is_test_content
	FROM event_parsed a
	LEFT JOIN dim_contents c ON a.element_uuid = c.content_items_id AND a.element_object = 'banner'
	LEFT JOIN dim_article f ON a.element_uuid = f.article_id AND a.element_object = 'article'
	LEFT JOIN dim_rewards d ON a.element_uuid = d.reward_id AND a.element_object IN ('reward', 'similar_reward')
	LEFT JOIN dim_reward_categories e ON a.element_uuid = e.category_id AND a.element_object = 'category'
	LEFT JOIN dim_click_label l ON a.element_uuid = l.element_uuid
	LEFT JOIN map_tag t ON a.element_key = t.raw_tag AND a.app_sub_feature = 'reward_tags'
)
, view_base AS (
	SELECT profile_identity
		, event_datetime
		, deviceinfo_appversion AS app_version
		, eventprops_app_feature AS app_feature
		, eventprops_screen_name AS screen_name
		, DATEDIFF(second, event_datetime, LEAD(event_datetime) OVER (PARTITION BY profile_identity ORDER BY event_datetime)) AS gap_to_next_sec
	FROM trusted.clevertap_view
	WHERE profile_identity IS NOT NULL
)
, event_view AS (
	SELECT profile_identity
		, event_datetime
		, app_version
		, INITCAP(REPLACE(app_feature, '_', ' ')) AS app_feature
		, INITCAP(REPLACE(screen_name, '_', ' ')) AS screen_name
		, CASE
			WHEN gap_to_next_sec <= 1200 THEN gap_to_next_sec
			ELSE NULL
			END AS screen_usage_sec
	FROM view_base
--	WHERE NVL(app_feature, '') <> 'auth'
)
, union_data AS (
	SELECT 'Click'::VARCHAR(10) AS event_type
		, profile_identity
		, event_datetime
		, app_version
		, app_feature
		, screen_name
		, sub_feature
		, section
		, is_navigation
		, element_name
		, element_object
		, type
		, display_name
		, content_id
		, content
		, provider
		, link
		, article_slug
		, element_key
		, target_member_types
		, is_content_mapped
		, is_test_content
		, NULL::INT AS screen_usage_sec
	FROM final_data
	UNION ALL
	SELECT 'View'::VARCHAR(10) AS event_type
		, profile_identity
		, event_datetime
		, app_version
		, app_feature
		, screen_name
		, NULL AS sub_feature
		, NULL AS section
		, 0 AS is_navigation
		, NULL AS element_name
		, NULL AS element_object
		, NULL AS type
		, NULL AS display_name
		, NULL AS content_id
		, NULL AS content
		, NULL AS provider
		, NULL AS link
		, NULL AS article_slug
		, NULL AS element_key
		, NULL AS target_member_types
		, NULL::INT AS is_content_mapped
		, 0 AS is_test_content
		, screen_usage_sec
	FROM event_view
)
SELECT event_type
	, profile_identity
	, event_datetime
	, app_version
	, app_feature
	, screen_name
	, TRIM(REGEXP_REPLACE(screen_name, ' Screen$', '')) AS screen_label
	, sub_feature
	, section
	, is_navigation
	, element_name
	, element_object
	, type
	, display_name
	, content_id
	, content
	, provider
	, link
	, article_slug
	, element_key
	, target_member_types
	, is_content_mapped
	, is_test_content
	, screen_usage_sec
FROM union_data
ORDER BY TRUNC(event_datetime) DESC, profile_identity, event_datetime