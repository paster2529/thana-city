SELECT * FROM refined.dim_hook_member WHERE member_id = '99430992';
SELECT * FROM refined.dim_hook_member WHERE member_uuid = 'f827c85d-f442-4fe8-9b8f-f9e182822dde';

SELECT * FROM "trusted".hook_coin_balances WHERE customer_id = 'f827c85d-f442-4fe8-9b8f-f9e182822dde' ORDER BY src_created_at;
SELECT * FROM "trusted".hook_coin_transactions WHERE customer_id = 'f827c85d-f442-4fe8-9b8f-f9e182822dde' ORDER BY coin_balance_id;
SELECT * FROM "trusted".hook_wallet_transactions WHERE customer_id = 'f827c85d-f442-4fe8-9b8f-f9e182822dde' ORDER BY src_created_at;

SELECT * FROM refined.fact_hook_coin_issue 
--WHERE member_id = '99430992' 
WHERE transaction_id = 'e2f9eb50-a1d9-4c86-9fb0-49f935a7cf70'
ORDER BY transaction_type DESC, transaction_datetime;

SELECT * FROM "trusted".clevertap_coin_topup WHERE profile_identity = '99430992' ORDER BY event_datetime;


WITH event_wallet_activation AS (
	SELECT a.profile_identity
		, b.member_uuid
		, b.is_staff
		, b.member_type
		, a.eventname
		, a.event_datetime
		, a.eventprops_event_datetime
		, a.eventprops_wallet_activation_channel
	FROM (
		SELECT profile_identity
			, eventname
			, event_datetime
			, eventprops_event_datetime
			, eventprops_wallet_activation_channel
			, ROW_NUMBER() OVER(PARTITION BY profile_identity ORDER BY event_datetime) AS rn
		FROM "trusted".clevertap_wallet_activation
		WHERE DATE_TRUNC('month', event_datetime) >= '2026-09-01'::DATE
	) a
	LEFT JOIN refined.dim_hook_member b ON a.profile_identity = b.member_id
	WHERE rn = 1
	ORDER BY event_datetime, profile_identity, eventprops_event_datetime
)
SELECT customer_id
	, src_created_at
	, id
	, reference_type
	, reference_id
	, coin_balance_id
	, merchant_id
	, TYPE
	, wallet_type
	, coin_type
	, amount_formatted AS amount
	, note
	, split_part(note, ': ', 1) AS note_type
	, split_part(note, ': ', 2) AS ref_external_id
	, balance_before
	, balance_after
	, value_thb
	, campaign_id
	, ref_external_id
	, source_type
FROM "trusted".hook_wallet_transactions a
WHERE date_trunc('month', src_created_at)::DATE >= '2026-09-01'::DATE
	AND status = 'confirmed'
	AND customer_id IN (SELECT DISTINCT member_uuid FROM event_wallet_activation)
ORDER BY 1,2












SELECT *
FROM refined.fact_hook_coin_issue
ORDER BY transaction_datetime DESC
LIMIT 200;

SELECT DISTINCT campaign_name FROM refined.fact_hook_coin_issue ORDER BY 1;


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
WHERE transaction_type = 'activated wallet'
ORDER BY transaction_datetime