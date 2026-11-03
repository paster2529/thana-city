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
, joined_dim AS (
	SELECT a.*
		, NVL(b.name, c.name.en::VARCHAR) AS value
	FROM click_raw a
	LEFT JOIN dim_rewards b ON a.element_name_details = b.reward_id
	LEFT JOIN TRUSTED.hook_reward_categories c ON a.element_name_details = c.id
)
SELECT a.profile_identity
	, a.event_datetime
	, a.eventname
	, a.screen_name
	, a.app_sub_feature
	, a.element_name
	, NVL(value, a.element_name_details) AS element_name_details
	, a.element_name_og
	, last_day(event_datetime) AS data_month
	, b.member_type
	, b.is_staff
FROM joined_dim a
LEFT JOIN refined.dim_hook_member b ON a.profile_identity = b.member_id