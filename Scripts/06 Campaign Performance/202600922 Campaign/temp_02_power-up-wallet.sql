WITH incentive_coin AS (
	SELECT member_id
		, transaction_id
		, transaction_datetime
		, transaction_type
		, coin_type
		, campaign_name
		, total_coin_value
		, transaction_status
		, coin_expires_at
		, ref_transaction_id
	FROM refined.fact_hook_coin_issue
	WHERE campaign_name = 'power-up-your-wallet'
		AND trunc(transaction_datetime) >= '2026-09-01'::DATE
	ORDER BY member_id, transaction_datetime
)
, coin_topup AS (
	SELECT member_id
		, transaction_id
		, transaction_datetime
		, transaction_type
		, coin_type
		, campaign_name
		, total_coin_value
		, transaction_status
		, coin_expires_at
		, ref_transaction_id
	FROM refined.fact_hook_coin_issue
	WHERE transaction_type = 'topup'
		AND coin_type = 'cash'
		AND transaction_status = 'confirmed'
		AND member_id IN (SELECT DISTINCT member_id FROM incentive_coin) 
	ORDER BY member_id, transaction_datetime
)
, coin_union AS (
	SELECT * FROM incentive_coin
	UNION ALL
	SELECT * FROM coin_topup
)
, members AS (
	SELECT member_id
		, NULL::TEXT AS transaction_id
		, activated_wallet_datetime AS transaction_datetime
		, 'activated wallet' AS transaction_type
		, NULL::TEXT coin_type
		, NULL::TEXT campaign_name
		, NULL::INT total_coin_value
		, NULL::TEXT transaction_status
		, NULL coin_expires_at
		, NULL::TEXT ref_transaction_id
	FROM refined.dim_hook_member
	WHERE member_id IN (SELECT DISTINCT member_id FROM incentive_coin) 
)
, final_data AS (
	SELECT * FROM members
	UNION ALL
	SELECT * FROM coin_union
)
SELECT *
FROM final_data
ORDER BY member_id, transaction_datetime