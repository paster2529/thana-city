WITH event_click AS (
	SELECT profile_identity
		, event_datetime
		, eventprops_language AS language
		, eventprops_screen_name AS screen_name
		, eventprops_app_feature AS app_feature
		, eventprops_app_sub_feature AS app_sub_feature
		, eventprops_element_name AS element_name_raw
		, eventprops_element_display_name AS element_display_name
		, eventprops_link AS link
		, eventprops_provider AS provider
		, CASE
			WHEN eventprops_app_sub_feature IN ('banner', 'category', 'reward_card', 'service_action', 'service_card', 'service_icon') THEN 1
			ELSE 0
			END AS is_parsed_element
	FROM "trusted".clevertap_click
--	WHERE profile_identity IS NOT NULL
--		AND event_datetime >= '2026-05-01'
--		AND event_datetime < '2026-11-01'
	WHERE profile_identity = '95733318'
)
, event_parsed AS (
	SELECT *
		, CASE
			WHEN is_parsed_element = 1 THEN SPLIT_PART(element_name_raw, '_', 1)||'_'||SPLIT_PART(element_name_raw, '_', 2)
			ELSE element_name_raw
			END AS element_name
		, CASE
			WHEN is_parsed_element = 1 THEN NULLIF(REGEXP_SUBSTR(element_name_raw, '^[^_]+_[^_]+_(.*)$', 1, 1, 'e'), '')
			ELSE element_name_raw
			END AS element_key
	FROM event_click
)
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
	)
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
	UNION ALL SELECT 'tag_หมวดหมู่-กอล์ฟ' , 'tag_Category-Golf'
	UNION ALL SELECT 'tag_หมวดหมู่-สปอร์ต', 'tag_Category-Sport'
	UNION ALL SELECT 'tag_เครื่องดื่ม' , 'tag_Drink'
	UNION ALL SELECT 'tag_ไดรฟ์วิ่งเรนจ์', 'tag_Driving Range'
	UNION ALL SELECT 'tag_ฟิตเนส' , 'tag_Fitness'
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
		, a.language AS lang
		, INITCAP(REPLACE(a.app_feature, '_', ' ')) AS app_feature
		, INITCAP(REPLACE(a.screen_name, '_', ' ')) AS screen_name
		, INITCAP(REPLACE(a.app_sub_feature, '_', ' ')) AS sub_feature
		, a.element_display_name AS display_name
		, CASE
			WHEN a.app_sub_feature = 'reward_tags' THEN 'Reward Tags'
			ELSE INITCAP(REPLACE(a.element_name, '_', ' '))
			END AS element_name
		, a.element_key
		, c.path_category
		, INITCAP(c.action_value_type) AS type
		, c.article_slug
		, COALESCE(c.action_value_id, c.article_id, d.reward_id, e.category_id) AS content_id
		, COALESCE(c.article_title_en, c.article_title_th, c.action_value_id, d.reward_name_en, d.reward_name_th, e.category_name, t.tag_name, a.element_key) AS content
		, a.provider
		, a.link
		, c.target_member_types
		, CASE
			WHEN a.app_sub_feature NOT IN ('banner', 'category', 'reward_card') THEN NULL
			WHEN COALESCE(c.content_items_id, d.reward_id, e.category_id) IS NOT NULL THEN 1
			ELSE 0
			END AS is_content_mapped
		, NVL(c.is_test_article, 0) AS is_test_content
	FROM event_parsed a
	LEFT JOIN dim_contents c ON a.element_key = c.content_items_id
	LEFT JOIN dim_rewards d ON a.element_key = d.reward_id
	LEFT JOIN dim_reward_categories e ON a.element_key = e.category_id
	LEFT JOIN map_tag t ON a.element_key = t.raw_tag AND a.app_sub_feature = 'reward_tags'
)
SELECT profile_identity
	, event_datetime
	, app_feature
	, screen_name
	, sub_feature
	, element_name
	, type
	, display_name
	, content
	, provider
	, link
	, article_slug
	, element_key
	, target_member_types
	, is_content_mapped
	, is_test_content
FROM final_data