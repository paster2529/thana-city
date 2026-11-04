SELECT NVL(used_member_id, redeem_member_id) AS member_id
	, TRUNC(NVL(used_datetime, redeem_datetime)) AS redeem_date
	, LAST_DAY(NVL(used_datetime, redeem_datetime)) AS redeem_month
--	, redeem_datetime
--	, used_datetime
	, redeem_type
	, campaign_name
	, coupon_category
	, coupon_status
	, coupon_name_en
	, redeem_from_bu
	, redeem_from_merchant
	, COUNT(DISTINCT transaction_id) AS cnt_txn
	, SUM(total_coupon_value) AS total_coupon_value
	, SUM(total_coin_value) AS total_coin_value
	, SUM(total_cash_coin_value) AS total_cash_coin_value
	, SUM(total_incentive_coin_value) AS total_incentive_coin_value
FROM refined.fact_hook_coupon_redeem
WHERE redeem_from_bu <> 'BU Test'
GROUP BY ALL


SELECT * FROM refined.fact_hook_coupon_redeem LIMIT 200;


SELECT redeem_type
	, campaign_name
	, redeem_from_bu AS bu
	, redeem_from_merchant AS merchant
	, coupon_category
	, coupon_name_en
	, coupon_name_th
	, coupon_status
	, transaction_id
	, redeem_datetime
	, used_datetime
	, NVL(used_member_id, redeem_member_id) AS member_id
	, total_coin_value
	, total_coupon_value
FROM refined.fact_hook_coupon_redeem
	WHERE redeem_from_bu <> 'BU Test'