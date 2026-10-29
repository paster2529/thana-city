SELECT campaign_name
	, a.member_id
	, INITCAP(b.member_type) AS member_type
	, b.referred_staff_id AS referred_member_id
	, c.is_staff AS referred_is_staff
	, c.activated_wallet AS referred_activated_wallet
	, transaction_datetime
	, transaction_id
	, ref_transaction_id
	, ref_transaction_type
	, total_coin_value
	, incentive_from_bu
	, incentive_from_merchant
FROM refined.fact_hook_coin_issue a
LEFT JOIN refined.dim_hook_member b ON a.member_id = b.member_id
LEFT JOIN refined.dim_hook_member c ON b.referred_staff_id = c.member_id
--WHERE date_trunc('month', transaction_datetime) >= '2026-09-01'::DATE 
WHERE transaction_status = 'confirmed'
	AND campaign_name IN ('coinback-5percent-sep-nov26', 'member-get-member-m2', 'power-up-your-wallet')
ORDER BY campaign_name DESC, transaction_datetime;