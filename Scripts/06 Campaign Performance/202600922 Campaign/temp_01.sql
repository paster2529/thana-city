WITH base_coupon_redeem AS (
	SELECT DISTINCT redeem_type 
		, campaign_name
		, redeem_from_bu AS bu
		, redeem_from_merchant AS merchant
		, coupon_name_en
		, total_coin_value
		, total_coupon_value
	FROM refined.fact_hook_coupon_redeem
	WHERE coupon_name_en NOT LIKE '%เทส%' AND lower(coupon_name_en) NOT LIKE '%test%'
	ORDER BY 1,2,3
)
SELECT TRUNC(d.valid_from) AS valid_from
	, TRUNC(d.valid_until) AS valid_to
	, a.*
	, b.campaign_type
	, NVL(b.reward_id, c.reward_id) AS reward_id
	, NVL(b.short_code, d.short_code) AS short_code
FROM base_coupon_redeem a
LEFT JOIN "trusted".ggsheets_mkt_campaign b ON a.coupon_name_en = b.rewards_name_en
LEFT JOIN (
	SELECT id
		, reward_id
		, name
	FROM "trusted".hook_reward_translations
	WHERE language_code = 'en'
) c ON a.coupon_name_en = c.name
LEFT JOIN "trusted".hook_merchant_rewards d ON c.reward_id = d.id
ORDER BY 1,2,3,4,5,6,7;



WITH base_coupon_redeem AS (
	SELECT DISTINCT redeem_type 
		, campaign_name
		, redeem_from_bu AS bu
		, redeem_from_merchant AS merchant
		, coupon_name_en
		, total_coin_value
		, total_coupon_value
	FROM refined.fact_hook_coupon_redeem
	WHERE coupon_name_en NOT LIKE '%เทส%' AND lower(coupon_name_en) NOT LIKE '%test%'
	ORDER BY 1,2,3
)
, coupon_master AS (
    SELECT TRUNC(d.valid_from) AS valid_from
        , TRUNC(d.valid_until) AS valid_to
        , a.*
        , b.campaign_type
        , NVL(b.reward_id, c.reward_id) AS reward_id
        , NVL(b.short_code, d.short_code) AS short_code
    FROM base_coupon_redeem a
    LEFT JOIN "trusted".ggsheets_mkt_campaign b ON a.coupon_name_en = b.rewards_name_en
    LEFT JOIN (
        SELECT id
            , reward_id
            , name
        FROM "trusted".hook_reward_translations
        WHERE language_code = 'en'
    ) c ON a.coupon_name_en = c.name
    LEFT JOIN "trusted".hook_merchant_rewards d ON c.reward_id = d.id
    ORDER BY 1,2,3,4,5,6,7
)
, coupon_member AS (
    SELECT b.redeem_type
        , b.campaign_type
        , b.campaign_name
        , b.coupon_name_en
        , merchant_id
        , coupon_code
        , merchant_reward_id
        , coin_spent
        , status
--        , customer_id
--        , used_by
        , d.member_id AS used_member_id
        , used_at_merchant_id
        , used_at
--        , expires_at
--        , activated_at
--        , activation_expires_at
        , c.member_id
        , c.member_type
        , c.activated_wallet
        , c.is_staff
        , c.member_status
    FROM "trusted".hook_customer_coupons a
    LEFT JOIN coupon_master b ON a.merchant_reward_id = b.reward_id
    LEFT JOIN refined.dim_hook_member c ON a.customer_id = c.member_uuid
    LEFT JOIN refined.dim_hook_member d ON a.used_by = d.member_uuid
    WHERE a.status = 'used'
    ORDER BY c.member_id
        , b.redeem_type
        , b.campaign_type
        , b.coupon_name_en
        , expires_at
        , used_at
)
SELECT a.*
	, NVL(b.transaction_id, c.transaction_no) AS transaction_id
	, NVL(b.transaction_datetime, c.transaction_datetime) AS transaction_datetime
FROM coupon_member a
LEFT JOIN refined.fact_sales_item_turtle b ON a.coupon_code = b.list_discount_item_voucher
LEFT JOIN refined.fact_sales_txn_bss_merchant c ON a.coupon_code = c.list_voucher_id
WHERE merchant_reward_id IN ('d002ca18-74a5-4670-96d0-9463dd81a084', '07593cbd-01af-498f-8253-b172229f6e5b', '2dcb1c24-c0e9-458e-b2ea-a08ebc9029d7', '457da69c-e63d-48ca-942a-99d4aaf0e9b2', '74e5af12-8415-49c3-a0ec-4bf0634ffc53', '392d46b4-f9fa-4908-aa0b-370eeea0f20f', '17840b7f-d74e-495a-9ab2-2840f9ba0cf2', 'fbf4e7ed-ccc7-40a6-bdfe-d28247b793d7')
ORDER BY campaign_name, merchant_reward_id, member_id, used_at;