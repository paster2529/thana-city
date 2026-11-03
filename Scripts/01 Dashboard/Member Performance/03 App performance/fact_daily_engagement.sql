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
, event_lagged AS (
	SELECT *
		, LAG(event_datetime) OVER (
			PARTITION BY profile_identity
			ORDER BY event_datetime, event_priority
		) AS prev_event_datetime
	FROM event_prioritized
)
, session_flagged AS (
	SELECT *
		, CASE
			WHEN prev_event_datetime IS NULL THEN 1
			WHEN DATEDIFF(minute, prev_event_datetime, event_datetime) >= 20 THEN 1
			ELSE 0
		END AS is_new_session
	FROM event_lagged
)
, session_numbered AS (
	SELECT *
		, SUM(is_new_session) OVER (
			PARTITION BY profile_identity
			ORDER BY event_datetime, event_priority
			ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
		) AS session_seq
	FROM session_flagged
)
, event_sessionized AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, eventname
		, is_new_session
		, profile_identity || '_' || session_seq AS session_id
	FROM session_numbered
)
, daily_active AS (
	SELECT DATE_TRUNC('day', event_datetime) AS event_date
		, COUNT(DISTINCT member_id) AS dau
		, COUNT(*) AS total_events
	FROM event_sessionized
	GROUP BY DATE_TRUNC('day', event_datetime)
)
, daily_new_sessions AS (
	SELECT DATE_TRUNC('day', event_datetime) AS event_date
		, COUNT(DISTINCT CASE WHEN is_new_session = 1 THEN session_id END) AS new_sessions
	FROM event_sessionized
	GROUP BY DATE_TRUNC('day', event_datetime)
)
, daily_installs AS (
	SELECT DATE_TRUNC('day', event_datetime) AS event_date
		, COUNT(DISTINCT member_id) AS new_installs
	FROM event_sessionized
	WHERE eventname = 'App Installed'
	GROUP BY DATE_TRUNC('day', event_datetime)
)
, daily_signups AS (
	SELECT DATE_TRUNC('day', event_datetime) AS event_date
		, COUNT(DISTINCT member_id) AS new_signups
	FROM event_sessionized
	WHERE eventname = 'SIGN_UP'
	GROUP BY DATE_TRUNC('day', event_datetime)
)
SELECT TRUNC(a.event_date) AS event_date
	, a.dau
	, a.total_events
	, ROUND(a.total_events::DECIMAL / NULLIF(a.dau, 0), 2) AS avg_events_per_active_user
	, s.new_sessions
	, i.new_installs
	, u.new_signups
FROM daily_active a
LEFT JOIN daily_new_sessions s ON a.event_date = s.event_date
LEFT JOIN daily_installs i ON a.event_date = i.event_date
LEFT JOIN daily_signups u ON a.event_date = u.event_date
ORDER BY 1