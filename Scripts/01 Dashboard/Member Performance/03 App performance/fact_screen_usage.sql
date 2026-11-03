SELECT TRUNC(DATE_TRUNC('day', event_datetime)) AS event_date
	, 'VIEW' AS eventname
	, eventprops_screen_name AS screen_name
	, NULL::TEXT AS details
	, COUNT(DISTINCT profile_identity) AS distinct_users
	, COUNT(*) AS event_count
FROM trusted.clevertap_view
GROUP BY DATE_TRUNC('day', event_datetime)
	, eventprops_screen_name
UNION ALL
SELECT TRUNC(DATE_TRUNC('day', event_datetime)) AS event_date
	, 'CLICK' AS eventname
	, eventprops_screen_name AS screen_name
	, eventprops_app_sub_feature||'|'||eventprops_element_name AS details
	, COUNT(DISTINCT profile_identity) AS distinct_users
	, COUNT(*) AS event_count
FROM trusted.clevertap_click
GROUP BY ALL