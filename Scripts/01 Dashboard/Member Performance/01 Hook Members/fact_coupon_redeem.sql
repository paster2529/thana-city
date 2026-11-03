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
, coupons AS (
	SELECT coupon_name_en
		, count(DISTINCT transaction_id) AS redeemed_coupons
		, count(DISTINCT redeem_member_id) AS redeemed_members
		, count(DISTINCT CASE WHEN coupon_status = 'used' THEN transaction_id END) AS used_coupons
		, count(DISTINCT CASE WHEN coupon_status = 'used' THEN NVL(used_member_id, redeem_member_id) END) AS used_members
		, sum(total_coupon_value) AS total_coupon_value
		, sum(total_coin_value) AS redeem_coin
		, sum(total_cash_coin_value) AS redeem_coin_cash
		, sum(total_incentive_coin_value) AS redeem_coin_incentive
		, sum(total_refund_cash_coin_value) AS redeem_coin_cash_refund
		, sum(total_refund_incentive_coin_value) AS redeem_coin_incentive_refund
	FROM refined.fact_hook_coupon_redeem
	GROUP BY ALL
	ORDER BY 1
) 
SELECT TRUNC(d.valid_from) AS valid_from
	, TRUNC(d.valid_until) AS valid_to
	, a.*
	, b.campaign_type
	, NVL(b.reward_id, c.reward_id) AS reward_id
	, NVL(b.short_code, d.short_code) AS short_code
	, e.redeemed_coupons
	, e.redeemed_members
	, e.used_coupons
	, e.used_members
	, e.total_coupon_value
	, e.redeem_coin
	, e.redeem_coin_cash
	, e.redeem_coin_incentive
	, e.redeem_coin_cash_refund
	, e.redeem_coin_incentive_refund
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
LEFT JOIN coupons e ON a.coupon_name_en = e.coupon_name_en
ORDER BY 1,3,4,5,6,7