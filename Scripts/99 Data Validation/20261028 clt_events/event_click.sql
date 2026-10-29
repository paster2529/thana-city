WITH event_click AS (
	SELECT profile_identity
		, eventname
		, event_datetime
		, eventprops_language
		, eventprops_screen_name
		, eventprops_app_feature
		, eventprops_app_sub_feature
		, eventprops_element_display_name
		, eventprops_element_name
		, eventprops_link
		, eventprops_provider
		, CASE
			WHEN eventprops_app_sub_feature IN ('banner', 'category', 'reward_card', 'service_action', 'service_card', 'service_icon') THEN split_part(eventprops_element_name, '_', 1)||'_'||split_part(eventprops_element_name, '_', 2)
			ELSE eventprops_element_name
			END AS element_name
		, CASE
			WHEN eventprops_app_sub_feature IN ('banner', 'category', 'reward_card', 'service_action', 'service_card', 'service_icon') THEN split_part(eventprops_element_name, '_', 3)
			ELSE eventprops_element_name
			END AS element_name_details
	FROM "trusted".clevertap_click
	WHERE profile_identity IS NOT NULL
--	ORDER BY eventprops_screen_name, eventprops_element_name
) 
--	SELECT DISTINCT eventprops_screen_name, element_name, element_name_details 
--	FROM event_click 
--	ORDER BY 1,2,3; 
, base_content_items AS (
	SELECT id
		, action_value
		, target_member_types
		, clean_path
		, NULLIF(REGEXP_SUBSTR(clean_path, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 1, 1, 'i'), '') AS content_uuid
	FROM (
		SELECT id
			, action_value
			, NULLIF(REGEXP_REPLACE(action_value, '[[:space:]]', ''), '') AS clean_path
			, target_member_types[0]::TEXT AS target_member_types
		FROM "trusted".hook_content_items
	)
)
, dim_content_items AS (
	SELECT id AS content_items_id
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
			ELSE SPLIT_PART(clean_path, '/', 2)
		END AS action_value_type
		, CASE
			WHEN clean_path IS NULL THEN NULL
			WHEN content_uuid IS NOT NULL THEN content_uuid
			ELSE REGEXP_SUBSTR(clean_path, '[^/]+$')
		END AS action_value_id
	FROM base_content_items
) 
--	/***/
--	SELECT * 
--	FROM dim_content_items 
--	WHERE clean_path IS NOT NULL
--	ORDER BY path_category, action_value_type, action_value_id, target_member_types;
--	/***/
, dim_article AS (
	SELECT id AS article_id
		, slug AS article_slug
		, title AS article_title
		, title.en::TEXT AS article_title_en
		, title.th::TEXT AS article_title_th
	FROM "trusted".hook_articles
	WHERE LOWER(title.en::TEXT) NOT LIKE '%test%'
)
, dim_contents AS (
	SELECT b.article_id
		, b.article_slug
		, b.article_title_en
		, b.article_title_th
		, a.content_items_id
		, a.target_member_types
		, a.path_category
		, a.action_value_type
		, a.action_value_id
	FROM dim_content_items a
	FULL OUTER JOIN dim_article b ON a.action_value_id = b.article_id
--	ORDER BY a.action_value_type, b.article_id, a.target_member_types
)
--	/***/
--	SELECT * 
--	FROM dim_contents 
--	ORDER BY action_value_id;
--	/***/
, join_btn_banner AS (
	SELECT DISTINCT element_name
		, element_name_details 
		, path_category
		, action_value_type
		, article_slug
		, target_member_types
		, NVL(action_value_id, article_id) AS content_id
		, NVL(article_title_en, article_title_th, content_id) AS content
	FROM event_click a
	LEFT JOIN dim_contents b ON a.element_name_details = b.content_items_id
--	ORDER BY 1,3,4,5,6
)
--	/***/
--	SELECT * 
--	FROM join_btn_banner;
--	/***/
, dim_rewards AS (
	SELECT reward_id
		, name
	FROM "trusted".hook_reward_translations
	WHERE language_code = 'en'
)
, dim_click AS (
	SELECT a.element_name
		, a.element_name_details
		, a.path_category
		, a.action_value_type
		, a.article_slug
		, a.target_member_types
		, a.content_id
		, NVL(a.content, b.name, c.name.en::VARCHAR, a.element_name_details) AS content
	--	, a.cnt_events
	--	, a.cnt_members
	FROM join_btn_banner a
	LEFT JOIN dim_rewards b ON a.element_name_details = b.reward_id
	LEFT JOIN TRUSTED.hook_reward_categories c ON a.element_name_details = c.id
--	ORDER BY 1,3,4,5,6
)
--	/***/
--	SELECT *
--	FROM dim_click;
--	/***/
, final_data_prep AS (
	SELECT a.* 
		, b.content
		, b.path_category
		, b.action_value_type
		, b.article_slug
		, b.target_member_types
	FROM event_click a 
	LEFT JOIN dim_click b ON a.element_name_details = b.element_name_details
)
, final_data AS (
	SELECT profile_identity
		, event_datetime
		, eventprops_language AS lang
		, INITCAP(REPLACE(eventprops_screen_name, '_', ' ')) AS screen_name
		, INITCAP(REPLACE(eventprops_app_sub_feature, '_', ' ')) AS sub_feature
		, eventprops_element_display_name AS display_name
		, CASE
			WHEN eventprops_app_sub_feature = 'reward_tags' THEN 'Reward Tags'
			ELSE INITCAP(REPLACE(element_name, '_', ' ')) 
			END AS element_name
		, INITCAP(action_value_type) AS type
		, article_slug
	--	, content
		, CASE
			WHEN content IN ('tag_Badminton', 'tag_แบตมินตัน') THEN 'tag_Badminton'
			WHEN content IN ('tag_Category-Golf', 'tag_หมวดหมู่-กอล์ฟ') THEN 'tag_Category-Golf'
			WHEN content IN ('tag_หมวดหมู่-สปอร์ต') THEN 'tag_Category-Sport'
			WHEN content IN ('tag_Drink', 'tag_เครื่องดื่ม') THEN 'tag_Drink'
			WHEN content IN ('tag_Driving Range', 'tag_ไดรฟ์วิ่งเรนจ์') THEN 'tag_Driving Range'
			WHEN content IN ('tag_Fitness', 'tag_ฟิตเนส') THEN 'tag_Fitness'
			WHEN content IN ('tag_Food', 'tag_อาหาร') THEN 'tag_Food'
			WHEN content IN ('tag_Golf', 'tag_กอล์ฟ') THEN 'tag_Golf'
			WHEN content IN ('tag_golfkiosk') THEN 'tag_Golf Kiosk'
			WHEN content IN ('tag_Hot Deals') THEN 'tag_Hot Deals'
			WHEN content IN ('tag_Mulligan') THEN 'tag_Mulligan'
			WHEN content IN ('tag_Sharkbite', 'tag_ชาร์กไบท์') THEN 'tag_Sharkbite'
			WHEN content IN ('tag_Splash', 'tag_สแปลช') THEN 'tag_Splash'
			WHEN content IN ('tag_TurtleX', 'tag_เทอร์เทิลเอ็กซ์') THEN 'tag_TurtleX'
			WHEN content IN ('tag_บีเคซาลอน') THEN 'tag_BK Salon'
			WHEN content IN ('tag_ฟุตซอล') THEN 'tag_Futsal'
			WHEN content IN ('tag_สปอร์ตคลับ') THEN 'tag_Sport Club'
			WHEN content IN ('tag_เทนนิส') THEN 'tag_Tennis'
			WHEN eventprops_provider = 'shopify' THEN content||'-'||eventprops_link
			ELSE content
		END AS content
	FROM final_data_prep
	GROUP BY ALL
--	ORDER BY 1 DESC, 2,3,4,5,6,7
)
SELECT *
FROM final_data
WHERE profile_identity = '95733318'
ORDER BY profile_identity, event_datetime