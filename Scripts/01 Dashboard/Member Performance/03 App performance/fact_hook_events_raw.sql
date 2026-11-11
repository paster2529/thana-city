--C:\Users\piriyas\Documents\GitHub\thana-city\Scripts\01 Dashboard\Member Performance\03 App performance\fact_hook_events_raw.sql
SELECT * FROM "trusted".clevertap_app_installed LIMIT 200;
SELECT * FROM "trusted".clevertap_app_launched LIMIT 200;
SELECT * FROM "trusted".clevertap_sign_up LIMIT 200;
SELECT * FROM "trusted".clevertap_view LIMIT 200;
SELECT * FROM "trusted".clevertap_coin_topup LIMIT 200;
SELECT * FROM "trusted".clevertap_charged LIMIT 200;

WITH data_register AS (
	SELECT member_id
		, CASE
	    	WHEN DATE_TRUNC('day', register_datetime) = DATE_TRUNC('day', '2026-05-08'::DATE) THEN DATEADD('day', 1, register_datetime)
	    	ELSE register_datetime
	    	END AS event_datetime
		, 'Register' AS event_name
		, NULL::TEXT AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::INT AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
	FROM refined.dim_hook_member
	ORDER BY register_datetime
) 
, data_wallet_activated AS (
	SELECT member_id
		, activated_wallet_datetime AS event_datetime
		, 'Activate Wallet' AS event_name
		, NULL::TEXT AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::INT AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
	FROM refined.dim_hook_member
	WHERE member_id IS NOT NULL AND activated_wallet = TRUE
)
, data_click AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, INITCAP(eventname) AS event_name
		, eventprops_app_feature AS app_feature
		, eventprops_app_sub_feature AS app_sub_feature
		, eventprops_screen_name AS screen_name
		, eventprops_element_name AS element_name
		, eventprops_element_display_name AS element_display_name
		, NULL::INT AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, CASE WHEN eventprops_element_name LIKE 'btn_coupon_%' THEN SUBSTRING(eventprops_element_name, 12) END AS coupon_txn_id
	FROM "trusted".clevertap_click
	WHERE profile_identity IS NOT NULL
)
, data_view AS (
	SELECT profile_identity AS member_id
		, event_datetime
		, INITCAP(eventname) AS event_name
		, eventprops_app_feature AS app_feature
		, NULL::TEXT AS app_sub_feature
		, eventprops_screen_name AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::INT AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
	FROM "trusted".clevertap_view
	WHERE profile_identity IS NOT NULL
)
, data_topup AS (
	SELECT member_id
		, transaction_datetime AS event_datetime
		, 'Coin Top-up' AS event_name
		, NULL::TEXT AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, campaign_name AS element_name
		, NULL::TEXT AS element_display_name
		, total_coin_value AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, NULL::TEXT AS coupon_txn_id
	FROM refined.fact_hook_coin_issue
	WHERE data_date >= '2026-05-09'::DATE
		AND transaction_type IN ('topup', 'admin_credit')
		AND coin_type = 'cash'
		AND transaction_status = 'confirmed'
	ORDER BY transaction_datetime DESC
)
, data_coupon_issued AS (
	SELECT redeem_member_id AS member_id
		, redeem_datetime AS event_datetime
		, 'Coupon Issued' AS event_name
		, redeem_type AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, campaign_name AS element_name
		, coupon_name_en AS element_display_name
		, total_coin_value AS value
		, redeem_from_bu AS bu
		, redeem_from_merchant AS merchant
		, transaction_id::TEXT AS coupon_txn_id
	FROM refined.fact_hook_coupon_redeem
)
, data_coupon_used AS (
	SELECT redeem_member_id AS member_id
		, used_datetime AS event_datetime
		, 'Coupon Used' AS event_name
		, redeem_type AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, campaign_name AS element_name
		, coupon_name_en AS element_display_name
		, total_coin_value AS value
		, redeem_from_bu AS bu
		, redeem_from_merchant AS merchant
		, transaction_id::TEXT AS coupon_txn_id
	FROM refined.fact_hook_coupon_redeem
	WHERE coupon_status = 'used'
)
, data_sales AS (
	SELECT NVL(member_id_coin, member_id_pos) AS member_id
		, transaction_datetime AS event_datetime
		, 'Sales' AS event_name
		, coin_payment_portion AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, paid_amount AS value
		, 'Super Turtle' AS bu
		, 'Turtle X' AS merchant
		, NULL::TEXT AS coupon_txn_id
	FROM refined.fact_sales_txn_turtle
	WHERE is_valid = TRUE
		AND NVL(member_id_coin, member_id_pos) IS NOT NULL
	UNION ALL
	SELECT NVL(member_id_coin, member_id_pos) AS member_id
		, transaction_datetime AS event_datetime
		, 'Sales' AS event_name
		, coin_payment_portion AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, paid_amount AS value
		, bu
		, merchant
		, NULL::TEXT AS coupon_txn_id
	FROM refined.fact_sales_txn_bss_merchant
	WHERE is_valid = TRUE
		AND NVL(member_id_coin, member_id_pos) IS NOT NULL
	UNION ALL
	SELECT NVL(member_id_coin, member_id_pos) AS member_id
		, transaction_datetime AS event_datetime
		, 'Sales' AS event_name
		, coin_payment_portion AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, paid_amount AS value
		, 'Chef Man' AS bu
		, 'Chef Man' AS merchant
		, NULL::TEXT AS coupon_txn_id
	FROM refined.fact_sales_txn_chefman
	WHERE is_valid = TRUE
		AND NVL(member_id_coin, member_id_pos) IS NOT NULL
)
, union_all AS (
	SELECT * FROM data_register
	UNION ALL
	SELECT * FROM data_wallet_activated
	UNION ALL
	SELECT * FROM data_topup
	UNION ALL
	SELECT * FROM data_click
	UNION ALL
	SELECT * FROM data_view
	UNION ALL
	SELECT * FROM data_coupon_issued
	UNION ALL
	SELECT * FROM data_coupon_used
	UNION ALL
	SELECT * FROM data_sales
)
--SELECT *
--FROM union_all
/******************************************************/
/********************* CHECK DATA *********************/
/******************************************************/
SELECT event_name
	, count(DISTINCT member_id) AS members
FROM union_all
GROUP BY 1
ORDER BY 1