WITH data_register AS (
	SELECT member_id
		, register_datetime AS event_datetime
		, 'Register' AS event_name
		, NULL::TEXT AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::INT AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, registration_source
		, is_staff
		, referred_staff_id
		, member_type
		, member_status
		, member_house_type
		, member_house_zone
	FROM refined.dim_hook_member
	WHERE member_id = '84698078'
)
, data_wallet_activated AS (
	SELECT a.member_id
		, a.activated_wallet_datetime AS event_datetime
		, 'Activate Wallet' AS event_name
		, NULL::TEXT AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::INT AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, a.registration_source
		, a.is_staff
		, a.referred_staff_id
		, a.member_type
		, a.member_status
		, a.member_house_type
		, a.member_house_zone
	FROM refined.dim_hook_member a
	LEFT JOIN data_register b ON a.member_id = b.member_id
	WHERE a.member_id IS NOT NULL AND a.activated_wallet = TRUE 
		AND a.member_id = '84698078'
)
, data_click AS (
	SELECT profile_identity AS member_id
		, a.event_datetime
		, INITCAP(eventname) AS event_name
		, eventprops_app_feature AS app_feature
		, eventprops_app_sub_feature AS app_sub_feature
		, eventprops_screen_name AS screen_name
		, eventprops_element_name AS element_name
		, eventprops_element_display_name AS element_display_name
		, NULL::INT AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, registration_source
		, is_staff
		, referred_staff_id
		, member_type
		, member_status
		, member_house_type
		, member_house_zone
	FROM "trusted".clevertap_click a
	LEFT JOIN data_register b ON a.profile_identity = b.member_id
	WHERE profile_identity IS NOT NULL 
		AND profile_identity = '84698078'
)
, data_view AS (
	SELECT profile_identity AS member_id
		, a.event_datetime
		, INITCAP(eventname) AS event_name
		, eventprops_app_feature AS app_feature
		, NULL::TEXT AS app_sub_feature
		, eventprops_screen_name AS screen_name
		, NULL::TEXT AS element_name
		, NULL::TEXT AS element_display_name
		, NULL::INT AS value
		, NULL::TEXT AS bu
		, NULL::TEXT AS merchant
		, registration_source
		, is_staff
		, referred_staff_id
		, member_type
		, member_status
		, member_house_type
		, member_house_zone
	FROM "trusted".clevertap_view a
	LEFT JOIN data_register b ON a.profile_identity = b.member_id
	WHERE profile_identity IS NOT NULL 
		AND profile_identity = '84698078'
)
, data_topup AS (
	SELECT a.member_id
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
		, registration_source
		, is_staff
		, referred_staff_id
		, member_type
		, member_status
		, member_house_type
		, member_house_zone
	FROM refined.fact_hook_coin_issue a
	LEFT JOIN data_register b ON a.member_id = b.member_id
    WHERE data_date >= '2026-05-09'::DATE
        AND transaction_type IN ('topup', 'admin_credit')
        AND coin_type = 'cash'
        AND transaction_status = 'confirmed'
        AND a.member_id = '84698078'
)
, data_coupon_redeemed AS (
	SELECT redeem_member_id AS member_id
		, redeem_datetime AS event_datetime
		, 'Coupon Redeem' AS event_name
		, redeem_type AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, campaign_name AS element_name
		, coupon_name_en AS element_display_name
		, total_coin_value AS value
		, redeem_from_bu AS bu
		, redeem_from_merchant AS merchant
		, registration_source
		, is_staff
		, referred_staff_id
		, member_type
		, member_status
		, member_house_type
		, member_house_zone
	FROM refined.fact_hook_coupon_redeem a
	LEFT JOIN data_register b ON a.redeem_member_id = b.member_id
	WHERE a.redeem_member_id = '84698078'
)
, data_coupon_used AS (
	SELECT redeem_member_id AS member_id
		, redeem_datetime AS event_datetime
		, 'Coupon Used' AS event_name
		, redeem_type AS app_feature
		, NULL::TEXT AS app_sub_feature
		, NULL::TEXT AS screen_name
		, campaign_name AS element_name
		, coupon_name_en AS element_display_name
		, total_coin_value AS value
		, redeem_from_bu AS bu
		, redeem_from_merchant AS merchant
		, registration_source
		, is_staff
		, referred_staff_id
		, member_type
		, member_status
		, member_house_type
		, member_house_zone
	FROM refined.fact_hook_coupon_redeem a
	LEFT JOIN data_register b ON a.redeem_member_id = b.member_id
	WHERE coupon_status = 'used'
		AND a.redeem_member_id = '84698078'
)
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
SELECT * FROM data_coupon_redeemed
UNION ALL
SELECT * FROM data_coupon_used
ORDER BY 1,2 DESC