WITH event_view AS (
	SELECT profile_identity
		, last_day(event_datetime) AS event_month
		, count(1) AS cnt_view_wallet
	FROM "trusted".clevertap_view
	WHERE eventprops_screen_name = 'wallet_dashboard_screen'
	GROUP BY ALL
	ORDER BY 1,2
)
, event_click AS (
	SELECT profile_identity
		, last_day(event_datetime) AS event_month
		, sum(CASE WHEN eventprops_app_sub_feature = 'payment' THEN 1 END) AS cnt_click_payment
	FROM (
		SELECT profile_identity
			, event_datetime
			, eventprops_app_feature
			, eventprops_app_sub_feature
			, eventprops_screen_name
			, eventprops_element_name
		FROM TRUSTED.clevertap_click
		WHERE profile_identity IS NOT NULL
--			AND eventprops_screen_name = 'wallet_dashboard_screen'
			AND eventprops_app_sub_feature = 'payment'
	)
	GROUP BY ALL
	ORDER BY 1,2
)
, joined_event AS (
	SELECT NVL(a.profile_identity, b.profile_identity) AS profile_identity
		, NVL(a.event_month, b.event_month) AS event_month
		, a.cnt_view_wallet
		, b.cnt_click_payment
	FROM event_view a
	FULL OUTER JOIN event_click b ON a.profile_identity = b.profile_identity
		AND a.event_month = b.event_month
)
, txn_sales AS (
	SELECT member_id
		, last_day(data_date) AS data_month
--		, bu
--		, merchant
		, sum(count_txn) AS cnt_txn
		, sum(paid_amount) AS paid_amount
		, sum(paid_coin) AS paid_coin
	FROM refined.v_fact_sales_all_bu
	WHERE coin_payment_portion <> 'no'
		AND member_id IS NOT NULL 
	GROUP BY ALL
	ORDER BY 1,2
)
SELECT NVL(a.profile_identity, b.member_id) AS member_id
	, NVL(a.event_month, b.data_month) AS data_month
	, a.cnt_view_wallet 
	, a.cnt_click_payment
	, b.cnt_txn
	, b.paid_amount
	, b.paid_coin
	, c.is_staff
	, c.member_type
	, CASE
		WHEN a.cnt_click_payment IS NOT NULL THEN 1
		ELSE 0
		END AS is_click
	, CASE
		WHEN b.cnt_txn IS NOT NULL THEN 1
		ELSE 0
		END AS is_payment
FROM joined_event a
LEFT JOIN txn_sales b ON a.profile_identity = b.member_id 
	AND a.event_month = b.data_month
LEFT JOIN refined.dim_hook_member c ON NVL(a.profile_identity, b.member_id) = c.member_id
ORDER BY 1,2