WITH event_raw AS (
	SELECT profile_identity, event_datetime, eventname
	FROM trusted.clevertap_app_launched
	WHERE profile_identity IS NOT NULL 
	UNION ALL
	SELECT profile_identity, event_datetime, eventname
	FROM trusted.clevertap_view
	WHERE profile_identity IS NOT NULL 
	UNION ALL
	SELECT profile_identity, event_datetime, eventname
	FROM trusted.clevertap_notification_viewed
	WHERE profile_identity IS NOT NULL 
	UNION ALL
	SELECT profile_identity, event_datetime, eventname
	FROM trusted.clevertap_click
	WHERE profile_identity IS NOT NULL 
	UNION ALL
	SELECT profile_identity, event_datetime, eventname
	FROM trusted.clevertap_gate_in
	WHERE profile_identity IS NOT NULL 
	UNION ALL
	SELECT profile_identity, event_datetime, eventname
	FROM trusted.clevertap_gate_out
	WHERE profile_identity IS NOT NULL 
	UNION ALL
	SELECT profile_identity, event_datetime, eventname
	FROM trusted.clevertap_fitness_in
	WHERE profile_identity IS NOT NULL 
	UNION ALL
	SELECT profile_identity, event_datetime, eventname
	FROM trusted.clevertap_common_fee_payment
	WHERE profile_identity IS NOT NULL
	UNION ALL
	SELECT member_id AS profile_identity, register_datetime AS event_datetime, 'Registered' AS eventname
	FROM refined.dim_hook_member
	where member_status = 'active'
)
, distinct_timestamps AS (
	SELECT DISTINCT profile_identity
		, event_datetime
	FROM event_raw
)
, ts_lagged AS (
	SELECT *
		, LAG(event_datetime) OVER (
			PARTITION BY profile_identity
			ORDER BY event_datetime
		) AS prev_event_datetime
	FROM distinct_timestamps
)
, ts_flagged AS (
	SELECT *
		, CASE
			WHEN prev_event_datetime IS NULL THEN 1
			WHEN DATEDIFF(minute, prev_event_datetime, event_datetime) >= 20 THEN 1
			ELSE 0
		END AS is_new_session
	FROM ts_lagged
)
, ts_numbered AS (
	SELECT *
		, SUM(is_new_session) OVER (
			PARTITION BY profile_identity
			ORDER BY event_datetime
			ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
		) AS session_seq
	FROM ts_flagged
)
, event_prioritized AS (
	SELECT *
		, CASE eventname
			WHEN 'App Launched' THEN 1
			WHEN 'Registered' THEN 2
			ELSE 99
		END AS event_priority
	FROM event_raw
)
, event_sessionized AS (
	SELECT e.profile_identity AS member_id
		, e.event_datetime
		, e.eventname
		, e.event_priority
		, e.profile_identity || '_' || t.session_seq AS session_id
	FROM event_prioritized e
	INNER JOIN ts_numbered t
		ON e.profile_identity = t.profile_identity
		AND e.event_datetime = t.event_datetime
)
, session_agg AS (
	SELECT session_id
		, member_id
		, MIN(event_datetime) AS session_start
		, MAX(event_datetime) AS session_end
		, DATEDIFF(second, MIN(event_datetime), MAX(event_datetime)) AS session_duration_sec
		, COUNT(*) AS num_events
	FROM event_sessionized
	GROUP BY session_id
		, member_id
)
, last_event AS (
	SELECT DISTINCT session_id
		, LAST_VALUE(eventname) OVER (
			PARTITION BY session_id
			ORDER BY event_datetime, event_priority
			ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
		) AS last_event_in_session
	FROM event_sessionized
)
, event_path_list AS (
	SELECT session_id
		, LISTAGG(eventname, ' > ') WITHIN GROUP (ORDER BY event_datetime, event_priority) AS event_list_dist
	FROM event_sessionized
	GROUP BY session_id
)
SELECT a.session_id
	, a.member_id
	, mem.member_type
	, mem.is_staff
	, a.session_start
	, a.session_end
	, a.session_duration_sec
	, a.num_events
	, l.last_event_in_session
	, p.event_list_dist
	, trunc(a.session_start) AS data_date
	, last_day(a.session_start) AS data_month
FROM session_agg a
LEFT JOIN last_event l ON a.session_id = l.session_id
LEFT JOIN event_path_list p ON a.session_id = p.session_id
LEFT JOIN refined.dim_hook_member mem ON a.member_id = mem.member_id
ORDER BY a.member_id , a.session_start;