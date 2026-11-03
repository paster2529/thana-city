WITH event_raw AS (
	SELECT profile_identity
		, event_datetime
		, 'App Installed' AS eventname
		-- , 'clevertap_app_installed' AS source_table
		, NULL::VARCHAR AS attribute_name
		, NULL::VARCHAR AS attribute_value
	FROM trusted.clevertap_app_installed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'App Launched' AS eventname
		-- , 'clevertap_app_launched' AS source_table
		, NULL::VARCHAR AS attribute_name
		, NULL::VARCHAR AS attribute_value
	FROM trusted.clevertap_app_launched
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'Charged' AS eventname
		-- , 'clevertap_charged' AS source_table
		, 'eventprops_transaction_type' AS attribute_name
		, eventprops_transaction_type::VARCHAR AS attribute_value
	FROM trusted.clevertap_charged
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'Charged' AS eventname
		-- , 'clevertap_charged' AS source_table
		, 'eventprops_coin_type_spent' AS attribute_name
		, eventprops_coin_type_spent::VARCHAR AS attribute_value
	FROM trusted.clevertap_charged
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'Charged' AS eventname
		-- , 'clevertap_charged' AS source_table
		, 'eventprops_coin_from_topup_spent' AS attribute_name
		, eventprops_coin_from_topup_spent::VARCHAR AS attribute_value
	FROM trusted.clevertap_charged
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'CLICK' AS eventname
		-- , 'clevertap_click' AS source_table
		, 'eventprops_screen_name' AS attribute_name
		, eventprops_screen_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_click
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'CLICK' AS eventname
		-- , 'clevertap_click' AS source_table
		, 'eventprops_app_sub_feature' AS attribute_name
		, eventprops_app_sub_feature::VARCHAR AS attribute_value
	FROM trusted.clevertap_click
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'CLICK' AS eventname
		-- , 'clevertap_click' AS source_table
		, 'eventprops_element_name' AS attribute_name
		, eventprops_element_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_click
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'COIN_TOPUP' AS eventname
		-- , 'clevertap_coin_topup' AS source_table
		, 'eventprops_status' AS attribute_name
		, eventprops_status::VARCHAR AS attribute_value
	FROM trusted.clevertap_coin_topup
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'COIN_TOPUP' AS eventname
		-- , 'clevertap_coin_topup' AS source_table
		, 'eventprops_fail_reason' AS attribute_name
		, eventprops_fail_reason::VARCHAR AS attribute_value
	FROM trusted.clevertap_coin_topup
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'COIN_TOPUP' AS eventname
		-- , 'clevertap_coin_topup' AS source_table
		, 'eventprops_coin_amount' AS attribute_name
		, eventprops_coin_amount::VARCHAR AS attribute_value
	FROM trusted.clevertap_coin_topup
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'COMMON_FEE_PAYMENT' AS eventname
		-- , 'clevertap_common_fee_payment' AS source_table
		, NULL::VARCHAR AS attribute_name
		, NULL::VARCHAR AS attribute_value
	FROM trusted.clevertap_common_fee_payment
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'FITNESS_IN' AS eventname
		-- , 'clevertap_fitness_in' AS source_table
		, 'eventprops_direction' AS attribute_name
		, eventprops_direction::VARCHAR AS attribute_value
	FROM trusted.clevertap_fitness_in
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'FITNESS_IN' AS eventname
		-- , 'clevertap_fitness_in' AS source_table
		, 'eventprops_access_method' AS attribute_name
		, eventprops_access_method::VARCHAR AS attribute_value
	FROM trusted.clevertap_fitness_in
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'FITNESS_IN' AS eventname
		-- , 'clevertap_fitness_in' AS source_table
		, 'eventprops_gate_name' AS attribute_name
		, eventprops_gate_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_fitness_in
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'FITNESS_MEMBER' AS eventname
		-- , 'clevertap_fitness_member' AS source_table
		, NULL::VARCHAR AS attribute_name
		, NULL::VARCHAR AS attribute_value
	FROM trusted.clevertap_fitness_member
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'GATE_IN' AS eventname
		-- , 'clevertap_gate_in' AS source_table
		, 'eventprops_access_method' AS attribute_name
		, eventprops_access_method::VARCHAR AS attribute_value
	FROM trusted.clevertap_gate_in
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'GATE_IN' AS eventname
		-- , 'clevertap_gate_in' AS source_table
		, 'eventprops_direction' AS attribute_name
		, eventprops_direction::VARCHAR AS attribute_value
	FROM trusted.clevertap_gate_in
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'GATE_IN' AS eventname
		-- , 'clevertap_gate_in' AS source_table
		, 'eventprops_gate_name' AS attribute_name
		, eventprops_gate_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_gate_in
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'GATE_OUT' AS eventname
		-- , 'clevertap_gate_out' AS source_table
		, 'eventprops_direction' AS attribute_name
		, eventprops_direction::VARCHAR AS attribute_value
	FROM trusted.clevertap_gate_out
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'GATE_OUT' AS eventname
		-- , 'clevertap_gate_out' AS source_table
		, 'eventprops_gate_name' AS attribute_name
		, eventprops_gate_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_gate_out
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'LOGIN' AS eventname
		-- , 'clevertap_login' AS source_table
		, 'eventprops_status' AS attribute_name
		, eventprops_status::VARCHAR AS attribute_value
	FROM trusted.clevertap_login
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'LOGIN' AS eventname
		-- , 'clevertap_login' AS source_table
		, 'eventprops_channel' AS attribute_name
		, eventprops_channel::VARCHAR AS attribute_value
	FROM trusted.clevertap_login
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'MEMBER_COUPON' AS eventname
		-- , 'clevertap_member_coupon' AS source_table
		, 'eventprops_merchant_name' AS attribute_name
		, eventprops_merchant_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_member_coupon
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'MEMBER_COUPON' AS eventname
		-- , 'clevertap_member_coupon' AS source_table
		, 'eventprops_coupon_status' AS attribute_name
		, eventprops_coupon_status::VARCHAR AS attribute_value
	FROM trusted.clevertap_member_coupon
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'Notification Viewed' AS eventname
		-- , 'clevertap_notification_viewed' AS source_table
		, 'eventprops_campaign_type' AS attribute_name
		, eventprops_campaign_type::VARCHAR AS attribute_value
	FROM trusted.clevertap_notification_viewed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'Notification Viewed' AS eventname
		-- , 'clevertap_notification_viewed' AS source_table
		, 'eventprops_campaign_name' AS attribute_name
		, eventprops_campaign_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_notification_viewed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'REDEEM' AS eventname
		-- , 'clevertap_redeem' AS source_table
		, 'eventprops_merchant_name' AS attribute_name
		, eventprops_merchant_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_redeem
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'REDEEM' AS eventname
		-- , 'clevertap_redeem' AS source_table
		, 'eventprops_rewards_name' AS attribute_name
		, eventprops_rewards_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_redeem
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'REWARDS_VIEWED' AS eventname
		-- , 'clevertap_rewards_viewed' AS source_table
		, 'eventprops_merchant_name' AS attribute_name
		, eventprops_merchant_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_rewards_viewed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'REWARDS_VIEWED' AS eventname
		-- , 'clevertap_rewards_viewed' AS source_table
		, 'eventprops_rewards_name' AS attribute_name
		, eventprops_rewards_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_rewards_viewed
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'SEARCHED' AS eventname
		-- , 'clevertap_searched' AS source_table
		, 'eventprops_keyword' AS attribute_name
		, eventprops_keyword::VARCHAR AS attribute_value
	FROM trusted.clevertap_searched
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'SIGN_UP' AS eventname
		-- , 'clevertap_sign_up' AS source_table
		, 'eventprops_referred_state' AS attribute_name
		, eventprops_referred_state::VARCHAR AS attribute_value
	FROM trusted.clevertap_sign_up
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'SIGN_UP' AS eventname
		-- , 'clevertap_sign_up' AS source_table
		, 'eventprops_referred_id' AS attribute_name
		, eventprops_referred_id::VARCHAR AS attribute_value
	FROM trusted.clevertap_sign_up
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'SIGN_UP' AS eventname
		-- , 'clevertap_sign_up' AS source_table
		, 'eventprops_user_type' AS attribute_name
		, eventprops_user_type::VARCHAR AS attribute_value
	FROM trusted.clevertap_sign_up
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'UTM_ATTRIBUTION' AS eventname
		-- , 'clevertap_utm_attribution' AS source_table
		, 'eventprops_utm_campaign' AS attribute_name
		, eventprops_utm_campaign::VARCHAR AS attribute_value
	FROM trusted.clevertap_utm_attribution
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'UTM_ATTRIBUTION' AS eventname
		-- , 'clevertap_utm_attribution' AS source_table
		, 'eventprops_utm_source' AS attribute_name
		, eventprops_utm_source::VARCHAR AS attribute_value
	FROM trusted.clevertap_utm_attribution
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'UTM_ATTRIBUTION' AS eventname
		-- , 'clevertap_utm_attribution' AS source_table
		, 'eventprops_utm_medium' AS attribute_name
		, eventprops_utm_medium::VARCHAR AS attribute_value
	FROM trusted.clevertap_utm_attribution
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'UTM Visited' AS eventname
		-- , 'clevertap_utm_visited' AS source_table
		, 'sessionprops_utm_campaign' AS attribute_name
		, sessionprops_utm_campaign::VARCHAR AS attribute_value
	FROM trusted.clevertap_utm_visited
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'UTM Visited' AS eventname
		-- , 'clevertap_utm_visited' AS source_table
		, 'sessionprops_utm_source' AS attribute_name
		, sessionprops_utm_source::VARCHAR AS attribute_value
	FROM trusted.clevertap_utm_visited
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'UTM Visited' AS eventname
		-- , 'clevertap_utm_visited' AS source_table
		, 'sessionprops_utm_medium' AS attribute_name
		, sessionprops_utm_medium::VARCHAR AS attribute_value
	FROM trusted.clevertap_utm_visited
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'VIEW' AS eventname
		-- , 'clevertap_view' AS source_table
		, 'eventprops_app_feature' AS attribute_name
		, eventprops_app_feature::VARCHAR AS attribute_value
	FROM trusted.clevertap_view
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'VIEW' AS eventname
		-- , 'clevertap_view' AS source_table
		, 'eventprops_screen_name' AS attribute_name
		, eventprops_screen_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_view
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'VIEW' AS eventname
		-- , 'clevertap_view' AS source_table
		, 'eventprops_language' AS attribute_name
		, eventprops_language::VARCHAR AS attribute_value
	FROM trusted.clevertap_view
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WALLET_ACTIVATION' AS eventname
		-- , 'clevertap_wallet_activation' AS source_table
		, 'eventprops_wallet_activation_channel' AS attribute_name
		, eventprops_wallet_activation_channel::VARCHAR AS attribute_value
	FROM trusted.clevertap_wallet_activation
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WALLET_CONSENT' AS eventname
		-- , 'clevertap_wallet_consent' AS source_table
		, NULL::VARCHAR AS attribute_name
		, NULL::VARCHAR AS attribute_value
	FROM trusted.clevertap_wallet_consent
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WALLET_KYC' AS eventname
		-- , 'clevertap_wallet_kyc' AS source_table
		, 'eventprops_wallet_kyc' AS attribute_name
		, eventprops_wallet_kyc::VARCHAR AS attribute_value
	FROM trusted.clevertap_wallet_kyc
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_COIN_ISSUED' AS eventname
		-- , 'clevertap_webhook_coin_issued' AS source_table
		, 'eventprops_merchant_category' AS attribute_name
		, eventprops_merchant_category::VARCHAR AS attribute_value
	FROM trusted.clevertap_webhook_coin_issued
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_COIN_ISSUED' AS eventname
		-- , 'clevertap_webhook_coin_issued' AS source_table
		, 'eventprops_coin_type' AS attribute_name
		, eventprops_coin_type::VARCHAR AS attribute_value
	FROM trusted.clevertap_webhook_coin_issued
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_COIN_ISSUED' AS eventname
		-- , 'clevertap_webhook_coin_issued' AS source_table
		, 'eventprops_campaign_name' AS attribute_name
		, eventprops_campaign_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_webhook_coin_issued
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_COIN_ISSUED' AS eventname
		-- , 'clevertap_webhook_coin_issued' AS source_table
		, 'eventprops_merchant_name' AS attribute_name
		, eventprops_merchant_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_webhook_coin_issued
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_COIN_ISSUED' AS eventname
		-- , 'clevertap_webhook_coin_issued' AS source_table
		, 'eventprops_status' AS attribute_name
		, eventprops_status::VARCHAR AS attribute_value
	FROM trusted.clevertap_webhook_coin_issued
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_COIN_ISSUED' AS eventname
		-- , 'clevertap_webhook_coin_issued' AS source_table
		, 'eventprops_coin_earned' AS attribute_name
		, eventprops_coin_earned::VARCHAR AS attribute_value
	FROM trusted.clevertap_webhook_coin_issued
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_REWARD_PUSH' AS eventname
		-- , 'clevertap_webhook_reward_push' AS source_table
		, 'eventprops_campaign_id' AS attribute_name
		, eventprops_campaign_id::VARCHAR AS attribute_value
	FROM trusted.clevertap_webhook_reward_push
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_REWARD_PUSH' AS eventname
		-- , 'clevertap_webhook_reward_push' AS source_table
		, 'eventprops_merchant_name' AS attribute_name
		, eventprops_merchant_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_webhook_reward_push
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_REWARD_PUSH' AS eventname
		-- , 'clevertap_webhook_reward_push' AS source_table
		, 'eventprops_rewards_name' AS attribute_name
		, eventprops_rewards_name::VARCHAR AS attribute_value
	FROM trusted.clevertap_webhook_reward_push
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_REWARD_PUSH' AS eventname
		-- , 'clevertap_webhook_reward_push' AS source_table
		, 'eventprops_status' AS attribute_name
		, eventprops_status::VARCHAR AS attribute_value
	FROM trusted.clevertap_webhook_reward_push
	UNION ALL
	SELECT profile_identity
		, event_datetime
		, 'WEBHOOK_REWARD_PUSH' AS eventname
		-- , 'clevertap_webhook_reward_push' AS source_table
		, 'eventprops_fail_reason' AS attribute_name
		, eventprops_fail_reason::VARCHAR AS attribute_value
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
SELECT profile_identity  AS "profile_identity (fact_event_details)"
	, event_datetime AS "event_datetime (fact_event_details)"
	, eventname AS "eventname (fact_event_details)"
	, attribute_name
	, attribute_value
	, profile_identity || '_' || session_seq AS "session_id (fact_event_details)"
FROM session_numbered