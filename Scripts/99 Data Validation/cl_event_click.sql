SELECT * FROM refined.dim_hook_member WHERE register_datetime::DATE = '2026-10-29'

SELECT profile_identity
	, profile_push_token
	, event_datetime
	, deviceinfo_appversion
	, eventprops_app_feature
	, eventprops_app_sub_feature
	, eventprops_screen_name
	, eventprops_element_name
	, eventprops_element_display_name
	, eventprops_provider
	, eventprops_link
FROM "trusted".clevertap_click
WHERE event_datetime::DATE = '2026-10-29'
	AND eventprops_app_feature = 'member'
--	AND profile_identity IN ('14207828', '87241527')
--	AND profile_identity IN ('71369484', '85406079', '39167026', '45809466', '68433808', '23142155', '31203886', '43922708', '88266056')
ORDER BY event_datetime

SELECT DISTINCT eventprops_app_feature AS app_feature
	, eventprops_screen_name AS screen_name
	, eventprops_app_sub_feature AS app_sub_feature
	, eventprops_element_name AS element_name
	, eventprops_element_display_name AS display_name
	, min(event_datetime) AS min_date
	, max(event_datetime) AS max_date
	, count(1) AS cnt
	, count(DISTINCT profile_identity) AS cnt_members
FROM "trusted".clevertap_click
GROUP BY ALL 
ORDER BY 1,2,3,4,5


WITH auth_click AS (
	SELECT NVL(profile_objectid, profile_push_token) AS device_id
		, profile_identity
		, event_datetime
		, eventprops_screen_name AS screen_name
		, eventprops_element_name AS element_name
	FROM "trusted".clevertap_click
	WHERE eventprops_app_feature = 'auth'
		AND event_datetime >= '2026-10-29'
		AND NVL(profile_objectid, profile_push_token) IS NOT NULL
)
, device_step AS (
	SELECT device_id
		, MIN(CASE WHEN screen_name = 'onboarding_screen' AND element_name = 'btn_register' THEN event_datetime END) AS s1_register
		, MIN(CASE WHEN screen_name = 'registration_policy_screen' AND element_name = 'btn_policy_confirm' THEN event_datetime END) AS s2_policy
		, MIN(CASE WHEN screen_name = 'registration_step1_screen' AND element_name = 'btn_continue' THEN event_datetime END) AS s3_info
		, MIN(CASE WHEN screen_name = 'login_otp_screen' AND element_name = 'btn_confirm_otp' THEN event_datetime END) AS s4_otp
		, MIN(CASE WHEN screen_name = 'registration_introduction_screen' AND element_name = 'btn_intro_start' THEN event_datetime END) AS s5_intro
		, MAX(profile_identity) AS profile_identity
	FROM auth_click
	GROUP BY 1
)
, device_funnel AS (
	SELECT device_id
		, CASE
			WHEN s1_register IS NOT NULL THEN 1
			ELSE 0
			END AS f1_register
		, CASE
			WHEN s1_register IS NOT NULL AND s2_policy >= s1_register THEN 1
			ELSE 0
			END AS f2_policy
		, CASE
			WHEN s1_register IS NOT NULL AND s2_policy >= s1_register AND s3_info >= s2_policy THEN 1
			ELSE 0
			END AS f3_info
		, CASE
			WHEN s1_register IS NOT NULL AND s2_policy >= s1_register AND s3_info >= s2_policy AND s4_otp >= s3_info THEN 1
			ELSE 0
			END AS f4_otp
		, CASE
			WHEN s1_register IS NOT NULL AND s2_policy >= s1_register AND s3_info >= s2_policy AND s4_otp >= s3_info AND s5_intro >= s4_otp THEN 1
			ELSE 0
			END AS f5_intro
		, CASE
			WHEN s1_register IS NOT NULL AND profile_identity IS NOT NULL THEN 1
			ELSE 0
			END AS f6_member
	FROM device_step
)
SELECT SUM(f1_register) AS step1_register
	, SUM(f2_policy) AS step2_policy
	, SUM(f3_info) AS step3_info
	, SUM(f4_otp) AS step4_otp
	, SUM(f5_intro) AS step5_intro
	, SUM(f6_member) AS step6_member
FROM device_funnel


SELECT COUNT(*) AS cnt_events
	, SUM(CASE WHEN profile_objectid IS NULL THEN 1 ELSE 0 END) AS cnt_null_objectid
	, SUM(CASE WHEN profile_push_token IS NULL THEN 1 ELSE 0 END) AS cnt_null_push_token
	, COUNT(DISTINCT profile_objectid) AS cnt_objectid
	, COUNT(DISTINCT profile_push_token) AS cnt_push_token
FROM "trusted".clevertap_click
WHERE eventprops_app_feature = 'auth'


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
)
--SELECT DISTINCT element_name_raw, element_object, element_uuid
--FROM event_click
--ORDER BY 1,2,3;
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
--SELECT DISTINCT app_feature, screen_name, section, element_name, element_key 
--FROM event_parsed
--ORDER BY 1,2,3,4,5;
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
--SELECT *
--FROM dim_content_items;
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
	WHERE slug <> 'test'
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
		, COALESCE(c.article_title_en, c.article_title_th, f.article_title_en, f.article_title_th, c.action_value_id, d.reward_name_en, d.reward_name_th, e.category_name, t.tag_name, a.element_key) AS content
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
	LEFT JOIN map_tag t ON a.element_key = t.raw_tag AND a.app_sub_feature = 'reward_tags'
)
SELECT profile_identity
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
FROM final_data
ORDER BY TRUNC(event_datetime) DESC, profile_identity, event_datetime
/************************************************************************************/
/************************************ CHECK DATA ************************************/
/************************************************************************************/
--	/*** CHECK 1: row count ต้องเท่ากัน (ไม่มี fan-out) ***/
--	SELECT (SELECT COUNT(*) FROM event_parsed) AS cnt_event_parsed
--		, (SELECT COUNT(*) FROM final_data) AS cnt_final_data;
--	/*** CHECK 2: ปุ่มที่ยังไม่ได้ map section (ควรได้ 0 rows) ***/
--	SELECT app_feature
--		, screen_name
--		, element_name
--		, COUNT(*) AS cnt_events
--		, MIN(event_datetime) AS first_seen
--	FROM final_data
--	WHERE section = 'Other'
--	GROUP BY 1,2,3
--	ORDER BY 4 DESC
--	/*** CHECK 3: UUID ที่ยัง map ไม่เจอ แยกตาม object ***/
--	SELECT element_object
--		, screen_name
--		, element_key
--		, COUNT(*) AS cnt_events
--		, COUNT(DISTINCT profile_identity) AS cnt_members
--		, MIN(event_datetime) AS first_seen
--		, MAX(event_datetime) AS last_seen
--	FROM final_data
--	WHERE is_content_mapped = 0
--	GROUP BY 1,2,3
--	ORDER BY 4 DESC;
--	/*** CHECK 4: สรุป section ต่อ feature เทียบกับ PDF ***/
--	SELECT app_feature
--		, section
--		, element_name
--		, COUNT(*) AS cnt_events
--		, COUNT(DISTINCT profile_identity) AS cnt_members
--		, MIN(app_version) AS min_app_version
--	FROM final_data
--	GROUP BY 1,2,3
--	ORDER BY 1,2,3