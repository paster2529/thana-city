WITH event_topup AS (
	SELECT profile_identity
		, last_day(event_datetime) AS event_month
		, count(1) AS cnt_event
	FROM (
		SELECT profile_identity
			, event_datetime
			, eventprops_app_feature
			, eventprops_app_sub_feature
			, eventprops_screen_name
			, eventprops_element_name
		FROM TRUSTED.clevertap_click
		WHERE profile_identity IS NOT NULL
			AND eventprops_app_sub_feature = 'topup'
	)
	GROUP BY ALL
	ORDER BY 1,2
)
, txn_coin_topup AS (
	SELECT member_id
		, last_day(transaction_datetime) AS data_month
		, count(DISTINCT transaction_id) AS cnt_topup
		, sum(total_coin_value) AS total_coin_topup
	FROM (
		SELECT member_id
			, transaction_datetime
			, transaction_id
			, total_coin_value
		FROM refined.fact_hook_coin_issue
		WHERE coin_type = 'cash'
			AND transaction_type = 'topup'
			AND transaction_status = 'confirmed'
	)
	GROUP BY ALL
	ORDER BY 1,2
)
, joined_data AS (
	SELECT NVL(a.profile_identity, b.member_id) AS member_id
		, NVL(a.event_month, b.data_month) AS data_month
		, a.cnt_event AS clicks
		, b.cnt_topup 
		, b.total_coin_topup
	FROM event_topup a
	FULL OUTER JOIN txn_coin_topup b ON a.profile_identity = b.member_id
		AND last_day(a.event_month) = last_day(b.data_month)
)
SELECT a.*
	, b.is_staff
	, b.member_type
	, CASE
		WHEN cnt_topup > 0 THEN TRUE
		ELSE FALSE
		END AS is_topup
FROM joined_data a
LEFT JOIN refined.dim_hook_member b ON a.member_id = b.member_id
ORDER BY member_id, data_month