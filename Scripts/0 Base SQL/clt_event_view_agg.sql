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
		, TRUNC(event_datetime) AS event_date
		, screen_name
		, CASE
			WHEN gap_to_next_sec IS NULL THEN NULL
			WHEN gap_to_next_sec > 1200 THEN NULL
			ELSE gap_to_next_sec
		END AS screen_usage_sec
	FROM flagged
)
SELECT event_date
	, screen_name
	, COUNT(*) AS page_view
	, AVG(screen_usage_sec) / 60.0 AS avg_page_view_duration_min
FROM sessioned
GROUP BY ALL