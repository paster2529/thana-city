WITH event_raw AS (
	SELECT profile_identity
		, event_datetime
		, 'App Installed' AS eventname
		-- , 'clevertap_app_installed' AS source_table
	FROM trusted.clevertap_app_installed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'App Launched' AS eventname
		-- , 'clevertap_app_launched' AS source_table
	FROM trusted.clevertap_app_launched
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'Charged' AS eventname
		-- , 'clevertap_charged' AS source_table
	FROM trusted.clevertap_charged
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'CLICK' AS eventname
		-- , 'clevertap_click' AS source_table
	FROM trusted.clevertap_click
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'COIN_TOPUP' AS eventname
		-- , 'clevertap_coin_topup' AS source_table
	FROM trusted.clevertap_coin_topup
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'COMMON_FEE_PAYMENT' AS eventname
		-- , 'clevertap_common_fee_payment' AS source_table
	FROM trusted.clevertap_common_fee_payment
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'FITNESS_IN' AS eventname
		-- , 'clevertap_fitness_in' AS source_table
	FROM trusted.clevertap_fitness_in
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'FITNESS_MEMBER' AS eventname
		-- , 'clevertap_fitness_member' AS source_table
	FROM trusted.clevertap_fitness_member
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'GATE_IN' AS eventname
		-- , 'clevertap_gate_in' AS source_table
	FROM trusted.clevertap_gate_in
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'GATE_OUT' AS eventname
		-- , 'clevertap_gate_out' AS source_table
	FROM trusted.clevertap_gate_out
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'LOGIN' AS eventname
		-- , 'clevertap_login' AS source_table
	FROM trusted.clevertap_login
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'MEMBER_COUPON' AS eventname
		-- , 'clevertap_member_coupon' AS source_table
	FROM trusted.clevertap_member_coupon
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'Notification Viewed' AS eventname
		-- , 'clevertap_notification_viewed' AS source_table
	FROM trusted.clevertap_notification_viewed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'REDEEM' AS eventname
		-- , 'clevertap_redeem' AS source_table
	FROM trusted.clevertap_redeem
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'REWARDS_VIEWED' AS eventname
		-- , 'clevertap_rewards_viewed' AS source_table
	FROM trusted.clevertap_rewards_viewed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'SEARCHED' AS eventname
		-- , 'clevertap_searched' AS source_table
	FROM trusted.clevertap_searched
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'SIGN_UP' AS eventname
		-- , 'clevertap_sign_up' AS source_table
	FROM trusted.clevertap_sign_up
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'UTM_ATTRIBUTION' AS eventname
		-- , 'clevertap_utm_attribution' AS source_table
	FROM trusted.clevertap_utm_attribution
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'UTM Visited' AS eventname
		-- , 'clevertap_utm_visited' AS source_table
	FROM trusted.clevertap_utm_visited
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'VIEW' AS eventname
		-- , 'clevertap_view' AS source_table
	FROM trusted.clevertap_view
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WALLET_ACTIVATION' AS eventname
		-- , 'clevertap_wallet_activation' AS source_table
	FROM trusted.clevertap_wallet_activation
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WALLET_CONSENT' AS eventname
		-- , 'clevertap_wallet_consent' AS source_table
	FROM trusted.clevertap_wallet_consent
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WALLET_KYC' AS eventname
		-- , 'clevertap_wallet_kyc' AS source_table
	FROM trusted.clevertap_wallet_kyc
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_COIN_ISSUED' AS eventname
		-- , 'clevertap_webhook_coin_issued' AS source_table
	FROM trusted.clevertap_webhook_coin_issued
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_REWARD_PUSH' AS eventname
		-- , 'clevertap_webhook_reward_push' AS source_table
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
SELECT profile_identity
	, event_datetime
	, eventname
	, profile_identity || '_' || session_seq AS session_id
FROM session_numbered