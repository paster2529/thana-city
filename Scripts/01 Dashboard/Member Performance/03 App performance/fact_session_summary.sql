WITH event_raw AS (
	SELECT profile_identity
		, event_datetime
		, 'App Installed' AS eventname
	FROM trusted.clevertap_app_installed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'App Launched' AS eventname
	FROM trusted.clevertap_app_launched
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'Charged' AS eventname
	FROM trusted.clevertap_charged
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'CLICK' AS eventname
	FROM trusted.clevertap_click
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'COIN_TOPUP' AS eventname
	FROM trusted.clevertap_coin_topup
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'COMMON_FEE_PAYMENT' AS eventname
	FROM trusted.clevertap_common_fee_payment
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'FITNESS_IN' AS eventname
	FROM trusted.clevertap_fitness_in
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'FITNESS_MEMBER' AS eventname
	FROM trusted.clevertap_fitness_member
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'GATE_IN' AS eventname
	FROM trusted.clevertap_gate_in
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'GATE_OUT' AS eventname
	FROM trusted.clevertap_gate_out
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'LOGIN' AS eventname
	FROM trusted.clevertap_login
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'MEMBER_COUPON' AS eventname
	FROM trusted.clevertap_member_coupon
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'Notification Viewed' AS eventname
	FROM trusted.clevertap_notification_viewed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'REDEEM' AS eventname
	FROM trusted.clevertap_redeem
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'REWARDS_VIEWED' AS eventname
	FROM trusted.clevertap_rewards_viewed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'SEARCHED' AS eventname
	FROM trusted.clevertap_searched
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'SIGN_UP' AS eventname
	FROM trusted.clevertap_sign_up
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'UTM_ATTRIBUTION' AS eventname
	FROM trusted.clevertap_utm_attribution
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'UTM Visited' AS eventname
	FROM trusted.clevertap_utm_visited
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'VIEW' AS eventname
	FROM trusted.clevertap_view
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WALLET_ACTIVATION' AS eventname
	FROM trusted.clevertap_wallet_activation
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WALLET_CONSENT' AS eventname
	FROM trusted.clevertap_wallet_consent
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WALLET_KYC' AS eventname
	FROM trusted.clevertap_wallet_kyc
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_COIN_ISSUED' AS eventname
	FROM trusted.clevertap_webhook_coin_issued
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_REWARD_PUSH' AS eventname
	FROM trusted.clevertap_webhook_reward_push
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
			WHEN 'App Installed' THEN 2
			WHEN 'SIGN_UP' THEN 3
			WHEN 'LOGIN' THEN 4
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
        , DATEDIFF(minute, MIN(event_datetime), MAX(event_datetime)) AS session_duration_min
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
		, LISTAGG(DISTINCT eventname, ' > ') WITHIN GROUP (ORDER BY event_datetime, event_priority) AS event_list_dist
	FROM event_sessionized
	GROUP BY session_id
)
SELECT a.session_id
	, a.member_id
	, a.session_start
	, a.session_end
	, a.session_duration_sec
    , a.session_duration_min
	, a.num_events
	, l.last_event_in_session
	, p.event_list_dist
FROM session_agg a
LEFT JOIN last_event l ON a.session_id = l.session_id
LEFT JOIN event_path_list p ON a.session_id = p.session_id