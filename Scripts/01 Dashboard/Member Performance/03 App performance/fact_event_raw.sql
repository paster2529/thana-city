WITH data_register AS (
	SELECT member_id
		, CASE
	    	WHEN DATE_TRUNC('day', register_datetime) = DATE_TRUNC('day', '2026-05-08'::DATE) THEN DATEADD('day', 1, register_datetime)
	    	ELSE register_datetime
	    	END AS event_datetime
		, 'Register' AS event_name
		, 'Membership' AS event_category
		, FALSE AS is_app_event
		, NULL::TEXT AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.dim_hook_member
)
, data_wallet_activated AS (
	SELECT member_id
		, activated_wallet_datetime AS event_datetime
		, 'Activate Wallet' AS event_name
		, 'Wallet' AS event_category
		, FALSE AS is_app_event
		, NULL::TEXT AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.dim_hook_member
	WHERE member_id IS NOT NULL
		AND activated_wallet = TRUE
)
, data_topup AS (
	SELECT member_id
		, transaction_datetime AS event_datetime
		, 'Coin Top-up' AS event_name
		, 'Wallet' AS event_category
		, FALSE AS is_app_event
		, NULL::TEXT AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, campaign_name AS element_name
		, NULL::TEXT AS element_display_name
		, total_coin_value::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.fact_hook_coin_issue
	WHERE data_date >= '2026-05-09'::DATE
		AND transaction_type IN ('topup', 'admin_credit')
		AND coin_type = 'cash'
		AND transaction_status = 'confirmed'
)
, data_coupon_issued AS (
	SELECT redeem_member_id AS member_id
		, redeem_datetime AS event_datetime
		, 'Coupon Issued' AS event_name
		, 'Coupon' AS event_category
		, FALSE AS is_app_event
		, redeem_type AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, campaign_name AS element_name
		, coupon_name_en AS element_display_name
		, total_coin_value::DECIMAL(18,2) AS value
		, redeem_from_bu AS bu
		, redeem_from_merchant AS merchant
		, transaction_id::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.fact_hook_coupon_redeem
	WHERE redeem_from_bu <> 'BU Test'
)
, data_coupon_used AS (
	SELECT redeem_member_id AS member_id
		, used_datetime AS event_datetime
		, 'Coupon Used' AS event_name
		, 'Coupon' AS event_category
		, FALSE AS is_app_event
		, redeem_type AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, campaign_name AS element_name
		, coupon_name_en AS element_display_name
		, total_coin_value::DECIMAL(18,2) AS value
		, redeem_from_bu AS bu
		, redeem_from_merchant AS merchant
		, transaction_id::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.fact_hook_coupon_redeem
	WHERE coupon_status = 'used'
		AND redeem_from_bu <> 'BU Test'
)
, data_sales AS (
	SELECT NVL(member_id_coin, member_id_pos) AS member_id
		, transaction_datetime AS event_datetime
		, 'Sales' AS event_name
		, 'Transaction' AS event_category
		, FALSE AS is_app_event
		, coin_payment_portion AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, paid_amount::DECIMAL(18,2) AS value
		, 'Super Turtle' AS bu
		, 'Turtle X' AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.fact_sales_txn_turtle
	WHERE is_valid = TRUE
		AND NVL(member_id_coin, member_id_pos) IS NOT NULL
	UNION ALL
	SELECT NVL(member_id_coin, member_id_pos, member_id_reward) AS member_id
		, transaction_datetime AS event_datetime
		, 'Sales' AS event_name
		, 'Transaction' AS event_category
		, FALSE AS is_app_event
		, coin_payment_portion AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, paid_amount::DECIMAL(18,2) AS value
		, bu
		, merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.fact_sales_txn_bss_merchant
	WHERE is_valid = TRUE
		AND NVL(member_id_coin, member_id_pos, member_id_reward) IS NOT NULL
		AND bu <> 'BU Test'
	UNION ALL
	SELECT NVL(member_id_coin, member_id_pos, member_id_reward) AS member_id
		, transaction_datetime AS event_datetime
		, 'Sales' AS event_name
		, 'Transaction' AS event_category
		, FALSE AS is_app_event
		, coin_payment_portion AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, paid_amount::DECIMAL(18,2) AS value
		, 'Chef Man' AS bu
		, 'Chef Man' AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.fact_sales_txn_chefman
	WHERE is_valid = TRUE
		AND NVL(member_id_coin, member_id_pos, member_id_reward) IS NOT NULL
)
, data_pay_with_coin AS (
	SELECT NVL(member_id_coin, member_id_pos) AS member_id
		, transaction_datetime AS event_datetime
		, 'Pay with Coin' AS event_name
		, 'Transaction' AS event_category
		, FALSE AS is_app_event
		, coin_payment_portion AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, paid_coin::DECIMAL(18,2) AS value
		, 'Super Turtle' AS bu
		, 'Turtle X' AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.fact_sales_txn_turtle
	WHERE is_valid = TRUE
		AND NVL(member_id_coin, member_id_pos) IS NOT NULL
		AND paid_coin > 0
	UNION ALL
	SELECT NVL(member_id_coin, member_id_pos, member_id_reward) AS member_id
		, transaction_datetime AS event_datetime
		, 'Pay with Coin' AS event_name
		, 'Transaction' AS event_category
		, FALSE AS is_app_event
		, coin_payment_portion AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, paid_coin::DECIMAL(18,2) AS value
		, bu
		, merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.fact_sales_txn_bss_merchant
	WHERE is_valid = TRUE
		AND NVL(member_id_coin, member_id_pos, member_id_reward) IS NOT NULL
		AND paid_coin > 0
		AND bu <> 'BU Test'
	UNION ALL
	SELECT NVL(member_id_coin, member_id_pos, member_id_reward) AS member_id
		, transaction_datetime AS event_datetime
		, 'Pay with Coin' AS event_name
		, 'Transaction' AS event_category
		, FALSE AS is_app_event
		, coin_payment_portion AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, paid_coin::DECIMAL(18,2) AS value
		, 'Chef Man' AS bu
		, 'Chef Man' AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, NULL::TEXT AS app_version
		, NULL::TEXT AS platform
		, NULL::TEXT AS language
	FROM refined.fact_sales_txn_chefman
	WHERE is_valid = TRUE
		AND NVL(member_id_coin, member_id_pos, member_id_reward) IS NOT NULL
		AND paid_coin > 0
)
, ct_app_installed AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'App Installed' AS event_name
		, 'Lifecycle' AS event_category
		, TRUE AS is_app_event
		, NULL::TEXT AS app_feature
		, eventprops_ct_source AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, NULL::TEXT AS language
	FROM "trusted".clevertap_app_installed
	WHERE profile_identity IS NOT NULL
)
, ct_app_launched AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'App Launched' AS event_name
		, 'Lifecycle' AS event_category
		, TRUE AS is_app_event
		, NULL::TEXT AS app_feature
		, eventprops_ct_source AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, NULL::TEXT AS language
	FROM "trusted".clevertap_app_launched
	WHERE profile_identity IS NOT NULL
)
, ct_login AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'Login' AS event_name
		, 'Lifecycle' AS event_category
		, TRUE AS is_app_event
		, eventprops_status AS app_feature
		, eventprops_channel AS app_sub_feature
		, NULL::TEXT AS screen_name
		, eventprops_user_type AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, NULL::TEXT AS language
	FROM "trusted".clevertap_login
	WHERE profile_identity IS NOT NULL
)
, ct_tutorial AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'Tutorial' AS event_name
		, 'Onboarding' AS event_category
		, TRUE AS is_app_event
		, NULL::TEXT AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, eventprops_tutorial AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, NULL::TEXT AS language
	FROM "trusted".clevertap_tutorial
	WHERE profile_identity IS NOT NULL
)
, ct_view AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'View' AS event_name
		, 'App Usage' AS event_category
		, TRUE AS is_app_event
		, eventprops_app_feature AS app_feature
		, NULL::TEXT AS app_sub_feature
		, eventprops_screen_name AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, CASE
			WHEN DATEDIFF(second, event_datetime, LEAD(event_datetime) OVER (PARTITION BY profile_identity ORDER BY event_datetime)) <= 1200 THEN DATEDIFF(second, event_datetime, LEAD(event_datetime) OVER (PARTITION BY profile_identity ORDER BY event_datetime))::DECIMAL(18,2)
		END AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, eventprops_language AS language
	FROM "trusted".clevertap_view
	WHERE profile_identity IS NOT NULL
)
, ct_click AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'Click' AS event_name
		, 'App Usage' AS event_category
		, TRUE AS is_app_event
		, eventprops_app_feature AS app_feature
		, eventprops_app_sub_feature AS app_sub_feature
		, eventprops_screen_name AS screen_name
		, eventprops_element_name AS element_name
		, eventprops_element_display_name AS element_display_name
		, NULL::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, CASE WHEN eventprops_element_name LIKE 'btn_coupon_%' THEN SUBSTRING(eventprops_element_name, 12) END AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, eventprops_language AS language
	FROM "trusted".clevertap_click
	WHERE profile_identity IS NOT NULL
)
, ct_searched AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'Searched' AS event_name
		, 'App Usage' AS event_category
		, TRUE AS is_app_event
		, NULL::TEXT AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, eventprops_keyword AS element_display_name
		, NULL::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, NULL::TEXT AS language
	FROM "trusted".clevertap_searched
	WHERE profile_identity IS NOT NULL
)
, ct_category_viewed AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'Category Viewed' AS event_name
		, 'Rewards' AS event_category
		, TRUE AS is_app_event
		, 'rewards' AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, eventprops_category_name AS element_display_name
		, NULL::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, NULL::TEXT AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, NULL::TEXT AS language
	FROM "trusted".clevertap_category_viewed
	WHERE profile_identity IS NOT NULL
)
, ct_rewards_viewed AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'Reward Viewed' AS event_name
		, 'Rewards' AS event_category
		, TRUE AS is_app_event
		, 'rewards' AS app_feature
		, eventprops_product_category AS app_sub_feature
		, NULL::TEXT AS screen_name
		, eventprops_merchant_name AS element_name
		, eventprops_rewards_name AS element_display_name
		, NULLIF(REGEXP_REPLACE(eventprops_coin_to_redeemed, '[^0-9.]', ''), '')::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, eventprops_merchant_name AS merchant
		, NULL::TEXT AS coupon_txn_id
		, eventprops_rewards_id AS reward_id
		, NULL::TEXT AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, NULL::TEXT AS language
	FROM "trusted".clevertap_rewards_viewed
	WHERE profile_identity IS NOT NULL
)
, ct_notification_viewed AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'Notification Viewed' AS event_name
		, 'Engagement' AS event_category
		, TRUE AS is_app_event
		, eventprops_campaign_type AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, eventprops_campaign_name AS element_name
		, eventprops_campaign_labels AS element_display_name
		, NULL::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, eventprops_campaign_id AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, NULL::TEXT AS language
	FROM "trusted".clevertap_notification_viewed
	WHERE profile_identity IS NOT NULL
)
, ct_rating_submitted AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, 'Rating Submitted' AS event_name
		, 'Feedback' AS event_category
		, TRUE AS is_app_event
		, eventprops_nps_classification AS app_feature
		, eventprops_input_type AS app_sub_feature
		, NULL::TEXT AS screen_name
		, eventprops_label AS element_name
		, eventprops_comment AS element_display_name
		, eventprops_user_rating::DECIMAL(18,2) AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
		, NULL::TEXT AS reward_id
		, eventprops_campaign_id AS campaign_id
		, eventprops_ct_app_version AS app_version
		, profile_platform AS platform
		, NULL::TEXT AS language
	FROM "trusted".clevertap_rating_submitted
	WHERE profile_identity IS NOT NULL
)
, app_events AS (
	SELECT * FROM ct_app_installed
	UNION ALL
	SELECT * FROM ct_app_launched
	UNION ALL
	SELECT * FROM ct_login
	UNION ALL
	SELECT * FROM ct_tutorial
	UNION ALL
	SELECT * FROM ct_view
	UNION ALL
	SELECT * FROM ct_click
	UNION ALL
	SELECT * FROM ct_searched
	UNION ALL
	SELECT * FROM ct_category_viewed
	UNION ALL
	SELECT * FROM ct_rewards_viewed
	UNION ALL
	SELECT * FROM ct_notification_viewed
	UNION ALL
	SELECT * FROM ct_rating_submitted
)
, app_flagged AS (
	SELECT *
		, CASE
			WHEN LAG(event_datetime) OVER (PARTITION BY member_id ORDER BY event_datetime, event_name, screen_name, element_name) IS NULL THEN 1
			WHEN DATEDIFF(second, LAG(event_datetime) OVER (PARTITION BY member_id ORDER BY event_datetime, event_name, screen_name, element_name), event_datetime) > 1200 THEN 1
			ELSE 0
		END AS is_new_session
	FROM app_events
)
, app_numbered AS (
	SELECT *
		, SUM(is_new_session) OVER (PARTITION BY member_id ORDER BY event_datetime, event_name, screen_name, element_name ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS session_no
	FROM app_flagged
)
, app_sessioned AS (
	SELECT member_id
		, event_datetime
		, event_name
		, event_category
		, is_app_event
		, app_feature
		, app_sub_feature
		, screen_name
		, element_name
		, element_display_name
		, value
		, bu
		, merchant
		, coupon_txn_id
		, reward_id
		, campaign_id
		, app_version
		, platform
		, language
		, member_id || '_' || session_no AS session_id
		, is_new_session AS is_session_start
		, CASE
			WHEN is_new_session = 1 THEN DATEDIFF(second, event_datetime, MAX(event_datetime) OVER (PARTITION BY member_id, session_no))
		END AS session_duration_sec
	FROM app_numbered
)
, backend_events AS (
	SELECT * FROM data_register
	UNION ALL
	SELECT * FROM data_wallet_activated
	UNION ALL
	SELECT * FROM data_topup
	UNION ALL
	SELECT * FROM data_coupon_issued
	UNION ALL
	SELECT * FROM data_coupon_used
	UNION ALL
	SELECT * FROM data_sales
	UNION ALL
	SELECT * FROM data_pay_with_coin
)
, union_all AS (
	SELECT * FROM app_sessioned
	UNION ALL
	SELECT *
		, NULL::TEXT AS session_id
		, NULL::INT AS is_session_start
		, NULL::INT AS session_duration_sec
	FROM backend_events
)
SELECT *
FROM union_all
--WHERE event_name = 'Click'
-- ทดสอบ: เปิด 2 บรรทัดล่าง / ก่อนใส่ใน Tableau ให้ลบออก
--WHERE member_id = '84698078'
--ORDER BY event_datetime