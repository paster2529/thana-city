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
, event_topup AS (
	SELECT ROW_NUMBER() OVER(PARTITION BY profile_identity ORDER BY event_datetime) AS rn
		, profile_identity
		, eventname
		, event_datetime
		, eventprops_transaction_amount
		, eventprops_coin_amount
		, eventprops_topup_channel
		, eventprops_transaction_id
		, eventprops_transaction_datetime
	FROM "trusted".clevertap_coin_topup
	WHERE DATE_TRUNC('month', event_datetime) >= '2026-09-01'::DATE
		AND eventprops_status = 'Complete'
		AND eventprops_transaction_amount > 199
	ORDER BY 2,1
)
, event_initiate AS (
	SELECT a.*
		, b.rn AS topup_seq
		, b.eventname
		, b.event_datetime AS event_datetime_topup
		, b.eventprops_transaction_amount
		, b.eventprops_coin_amount
		, b.eventprops_topup_channel
		, b.eventprops_transaction_id
	--	, b.eventprops_transaction_datetime
	FROM event_wallet_activation a
	LEFT JOIN event_topup b ON a.profile_identity = b.profile_identity
	ORDER BY profile_identity, event_datetime, topup_seq
) 
--SELECT * FROM event_initiate;
, wallet_transaction AS (
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
)
SELECT t1.*,
	t2.src_created_at,
	t2.id,
	t2.reference_type,
	t2.reference_id,
	t2.merchant_id,
	t2.type,
	t2.wallet_type,
	t2.coin_type,
	t2.amount,
	t2.note,
	t2.balance_before,
	t2.balance_after,
	t2.value_thb,
	t2.campaign_id,
	t2.source_type
FROM event_initiate t1
LEFT JOIN wallet_transaction t2 ON t1.member_uuid = t2.customer_id
	AND t1.eventprops_transaction_id = t2.ref_external_id
ORDER BY profile_identity, event_datetime, topup_seq, t2.src_created_at