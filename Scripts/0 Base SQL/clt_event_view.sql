SELECT eventname, profile_identity, event_datetime
	, eventprops_language AS language
	, eventprops_screen_name AS screen_name
	, eventprops_app_feature AS app_feature
FROM "trusted".clevertap_view ORDER BY event_datetime DESC LIMIT 200;


WITH base AS (
	SELECT profile_identity
		, event_datetime
		, INITCAP(REPLACE(REPLACE(eventprops_screen_name, 'screen', ''), '_', ' ')) AS screen_name
		, LAG(event_datetime) OVER (PARTITION BY profile_identity ORDER BY event_datetime) AS prev_datetime
		, LEAD(event_datetime) OVER (PARTITION BY profile_identity ORDER BY event_datetime) AS next_datetime
	FROM trusted.clevertap_view
)
, flagged AS (
	SELECT profile_identity
		, event_datetime
		, screen_name
		, prev_datetime
		, next_datetime
		, CASE
			WHEN prev_datetime IS NULL THEN 1
			WHEN DATEDIFF(second, prev_datetime, event_datetime) > 1200 THEN 1
			ELSE 0
		END AS is_new_session
		, DATEDIFF(second, event_datetime, next_datetime) AS gap_to_next_sec
	FROM base
)
, sessioned AS (
	SELECT profile_identity
		, event_datetime
		, screen_name
		, prev_datetime
		, next_datetime
		, SUM(is_new_session) OVER (
			PARTITION BY profile_identity
			ORDER BY event_datetime
			ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
		) AS session_no
		, CASE
			WHEN gap_to_next_sec IS NULL THEN NULL
			WHEN gap_to_next_sec > 1200 THEN NULL
			ELSE gap_to_next_sec
		END AS screen_usage_sec
	FROM flagged
)
SELECT profile_identity
	, profile_identity||'_'||session_no AS session_id
	, MIN(event_datetime) AS session_start
	, MAX(event_datetime) AS session_end
	, LISTAGG(DISTINCT screen_name, '+ ') WITHIN GROUP (ORDER BY event_datetime) AS screen_visit_dist
	, sum(screen_usage_sec) AS session_duration_sec
FROM sessioned
GROUP BY ALL