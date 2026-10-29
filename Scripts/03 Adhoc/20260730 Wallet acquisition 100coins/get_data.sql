WITH wallet_acquisition AS (
	SELECT a.data_date
		, a.transaction_datetime
		, a.member_id
		, b.member_uuid
		, campaign_name
		, coin_type
		, total_coin_value
		, a.ref_transaction_id
	FROM refined.fact_hook_coin_issue a
	LEFT JOIN refined.dim_hook_member b ON a.member_id = b.member_id
	WHERE campaign_name = 'wallet-acquisition-100coin'
	ORDER BY transaction_datetime
)
, joined_coin_balance AS (
	SELECT a.*
		, b.src_created_at AS topup_dt
		, b.id
		, b.coin_type
		, b.source_type 
		, b.original_amount
	FROM wallet_acquisition a
	LEFT JOIN (
		SELECT id
			, customer_id
			, coin_type
			, source_type
			, src_created_at
			, original_amount
		FROM trusted.hook_coin_balances
		WHERE coin_type = 'incentive' AND source_type = 'clevertap_credit' AND original_amount = 100
	) b ON a.ref_transaction_id = b.id 
)
, joined_coin_txn AS (
	SELECT a.*
		, b.transaction_type
		, b.reference_type
		, b.reference_id
--		, b.src_created_at AS deduct_dt
		, SUM(b.amount) AS coin_deduct_amount
--		, max(b.balance_before) AS balance_before
--		, max(b.balance_after) AS balance_after
	FROM joined_coin_balance a
	LEFT JOIN "trusted".hook_coin_transactions b ON a.id = b.coin_balance_id
	GROUP BY ALL
)
SELECT member_id
	, member_uuid
	, transaction_datetime AS topup_dt
	, campaign_name
	, total_coin_value AS incentive_coin_issue
	, SUM(CASE WHEN reference_type = 'coupon_redeem' THEN coin_deduct_amount END) AS total_coin_deduct_redeem
	, SUM(CASE WHEN reference_type = 'pos_transaction' THEN coin_deduct_amount END) AS total_coin_deduct_pos
	, SUM(coin_deduct_amount) AS total_coin_deduct
	, total_coin_value - SUM(coin_deduct_amount) AS remaining_incentive_coin
FROM joined_coin_txn
GROUP BY ALL 
ORDER BY member_id, transaction_datetime;