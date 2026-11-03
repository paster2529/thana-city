WITH dim_rewards AS (
	SELECT reward_id
		, name
	FROM "trusted".hook_reward_translations
	WHERE language_code = 'en'
)
, click_raw AS (
	SELECT profile_identity
		, event_datetime
		, eventname
		, eventprops_screen_name AS screen_name
--		, eventprops_app_feature AS app_feature
		, eventprops_app_sub_feature AS app_sub_feature
		, eventprops_element_name AS element_name_og
		, CASE
			WHEN eventprops_app_sub_feature IN ('banner', 'category', 'reward_card', 'service_action', 'service_card', 'service_icon') THEN split_part(eventprops_element_name, '_', 1)||'_'||split_part(eventprops_element_name, '_', 2)
			ELSE eventprops_element_name
			END AS element_name
		, CASE
			WHEN eventprops_app_sub_feature IN ('banner', 'category', 'reward_card', 'service_action', 'service_card', 'service_icon') THEN split_part(eventprops_element_name, '_', 3)
			ELSE eventprops_element_name
			END AS element_name_details
	FROM TRUSTED.clevertap_click
	WHERE profile_identity IS NOT NULL
)
SELECT a.*
	, NVL(b.name, c.name.en::VARCHAR) AS value
FROM click_raw a
LEFT JOIN dim_rewards b ON a.element_name_details = b.reward_id
LEFT JOIN TRUSTED.hook_reward_categories c ON a.element_name_details = c.id
