WITH txn_turtle AS (
	SELECT 'Pay with coin' AS txn_type
	    , COALESCE(member_id_coin, member_id_pos) AS member_id
	    , 14 AS bu_sort
	    , 'Super Turtle' AS bu
	    , data_date
	    , transaction_datetime
	    , transaction_no
	    , transaction_id
	    , total_discount_amount
	    , paid_amount
	    , paid_coin
	    , paid_coin_cash
	    , paid_coin_incentive
	    , paid_coin_refund
	    , paid_coupon_amount
	    , NULL::TEXT AS redeem_type
        , NULL::TEXT AS campaign_name
        , NULL::TEXT AS coupon_name
        , created_at
        , updated_at
	FROM refined.fact_sales_txn_turtle
	WHERE is_valid = TRUE
	    AND COALESCE(member_id_coin, member_id_pos) IS NOT NULL
		AND  paid_coin > 0
)
, txn_bss AS (
    SELECT 'Pay with coin' AS txn_type
        , COALESCE(a.member_id_coin, a.member_id_reward, a.member_id_pos) AS member_id
        , bu_sort
        , bu_report_ref AS bu
        , a.data_date
        , a.transaction_datetime
        , a.transaction_no
        , a.transaction_no AS transaction_id
        , NULL::NUMERIC(10,2) AS total_discount_amount
        , paid_amount
        , paid_coin
        , paid_coin_cash
        , paid_coin_incentive
        , paid_coin_refund
        , paid_coupon_amount
        , NULL::TEXT AS redeem_type
        , NULL::TEXT AS campaign_name
        , NULL::TEXT AS coupon_name
        , a.created_at
        , a.updated_at
    FROM refined.fact_sales_txn_bss_merchant a
    LEFT JOIN (
        SELECT DISTINCT bu_sort
            , bu_report_ref
            , merchant_sort
            , merchant_report_ref
        FROM "trusted".ggsheets_setup_merchant_bu_mapping
    ) b ON a.merchant = b.merchant_report_ref
    WHERE a.is_valid = TRUE
        AND a.bu <> 'BU Test'
        AND COALESCE(a.member_id_coin, a.member_id_reward, a.member_id_pos) IS NOT NULL
        AND a.paid_coin > 0
)
, txn_coin_redeemed AS (
	SELECT 'Coin redeemed' AS txn_type
		, NVL(used_member_id, redeem_member_id) AS member_id
	    , b.bu_sort
	    , redeem_from_bu AS bu
	    , data_date
	    , NVL(used_datetime, redeem_datetime) AS transaction_datetime
	    , coupon_code AS transaction_no
	    , transaction_id
		, NULL::NUMERIC(10,2) AS total_discount_amount
	    , total_coin_value::FLOAT AS paid_amount
		, total_coin_value AS paid_coin
	    , total_cash_coin_value AS paid_coin_cash
	    , total_incentive_coin_value AS paid_coin_incentive
		, NULL::INT AS paid_coin_refund
        , total_coupon_value AS paid_coupon_amount
        , redeem_type
        , campaign_name
        , coupon_name_en AS coupon_name
        , created_at
        , updated_at
	FROM refined.fact_hook_coupon_redeem a
	LEFT JOIN (
	        SELECT DISTINCT bu_sort
	        	, merchant_sort
	            , bu_report_ref AS bu
	            , merchant_report_ref AS merchant
	        FROM "trusted".ggsheets_setup_merchant_bu_mapping
	    ) b ON a.redeem_from_bu = b.bu AND a.redeem_from_merchant = b.merchant
	WHERE data_date >= '2026-05-09'::DATE
	    AND redeem_type = 'coin'
        AND redeem_from_bu <> 'BU Test'
)
, txn_coupon_used AS (
	SELECT 'Coupon used' AS txn_type
		, NVL(used_member_id, redeem_member_id) AS member_id
	    , b.bu_sort
	    , redeem_from_bu AS bu
	    , data_date
	    , NVL(used_datetime, redeem_datetime) AS transaction_datetime
	    , coupon_code AS transaction_no
	    , transaction_id
		, NULL::NUMERIC(10,2) AS total_discount_amount
	    , total_coin_value::FLOAT AS paid_amount
		, total_coin_value AS paid_coin
	    , total_cash_coin_value AS paid_coin_cash
	    , total_incentive_coin_value AS paid_coin_incentive
		, NULL::INT AS paid_coin_refund
        , total_coupon_value AS paid_coupon_amount
        , redeem_type
        , campaign_name
        , coupon_name_en AS coupon_name
        , created_at
        , updated_at
	FROM refined.fact_hook_coupon_redeem a
	LEFT JOIN (
	        SELECT DISTINCT bu_sort
	        	, merchant_sort
	            , bu_report_ref AS bu
	            , merchant_report_ref AS merchant
	        FROM "trusted".ggsheets_setup_merchant_bu_mapping
	    ) b ON a.redeem_from_bu = b.bu AND a.redeem_from_merchant = b.merchant
	WHERE data_date >= '2026-05-09'::DATE
	    AND coupon_status = 'used'
        AND redeem_from_bu <> 'BU Test'
)
, txn_all AS (
	SELECT * FROM txn_turtle
	UNION ALL
	SELECT * FROM txn_bss
	UNION ALL
	SELECT * FROM txn_coin_redeemed
	UNION ALL
	SELECT * FROM txn_coupon_used
)
, txn_agg AS (
	SELECT txn_type
		, member_id
		, bu_sort
		, bu
		, data_date
		, transaction_datetime
		, transaction_no
		, transaction_id
		, redeem_type
		, campaign_name
		, coupon_name
	    , LAST_DAY(data_date) AS data_month
	    , total_discount_amount::NUMERIC(18,4) AS total_discount_amount
	    , paid_amount::NUMERIC(18,4) AS paid_amount
	    , paid_coin::NUMERIC(18,4) AS paid_coin
	    , paid_coin_cash::NUMERIC(18,4) AS paid_coin_cash
	    , paid_coin_incentive::NUMERIC(18,4) AS paid_coin_incentive
	    , paid_coin_refund::NUMERIC(18,4) AS paid_coin_refund
	    , paid_coupon_amount::NUMERIC(18,4) AS paid_coupon_amount
	    , b.fiscal_year
	FROM txn_all a
	LEFT JOIN (
	SELECT DISTINCT(LAST_DAY(full_date)) AS last_date
		, fiscal_year
	FROM refined.dim_date
	) b ON LAST_DAY(a.data_date) = b.last_date
)
, txn_agg_bu AS (
    SELECT member_id
        , fiscal_year
        , data_month
        , bu_sort
        , bu
        , txn_type_sort
        , txn_type
        , is_used_at_pos
        , is_used_at_hook_app
        , sum(cnt_txn) AS cnt_txn
        , sum(cnt_txn_unique) AS cnt_txn_unique
        , sum(paid_amount) AS paid_amount
        , sum(paid_others) AS paid_others
        , sum(paid_coupon_amount) AS paid_coupon_amount
        , sum(paid_coin) AS paid_coin
        , sum(paid_coin_cash) AS paid_coin_cash
        , sum(paid_coin_incentive) AS paid_coin_incentive
        , sum(redeemed_coin) AS redeemed_coin
        , sum(redeemed_coin_cash) AS redeemed_coin_cash
        , sum(redeemed_coin_incentive) AS redeemed_coin_incentive
        , sum(redeemed_coupon_value) AS redeemed_coupon_value
    FROM txn_agg
    GROUP BY ALL
)
, hook_member AS (
    SELECT member_id
        , register_datetime
        , CASE
            WHEN DATE_TRUNC('day', register_datetime) = DATE_TRUNC('day', '2026-05-08'::DATE) THEN DATEADD('day', 1, register_datetime)
            ELSE register_datetime
            END AS register_datetime_fixed
        , LAST_DAY(register_datetime) AS register_month
        , INITCAP(REPLACE(REPLACE(REPLACE(registration_source, 'QR_' , '') ,'_' ,' '), '-', ' ')) AS registration_source
        , activated_wallet
        , activated_wallet_datetime
        , LAST_DAY(activated_wallet_datetime) AS activated_wallet_month
        , is_staff
        , member_status
        , member_type
        , member_house_type
        , member_house_zone
        , NVL(INITCAP(gender), 'Unknown') AS gender
        , CASE
            WHEN date_of_birth IS NULL THEN 'Unknown'
            WHEN datediff(year, date_of_birth, current_date) < 16 THEN '<16'
            WHEN datediff(year, date_of_birth, current_date) BETWEEN 16 AND 25 THEN '16-25'
            WHEN datediff(year, date_of_birth, current_date) BETWEEN 26 AND 35 THEN '26-35'
            WHEN datediff(year, date_of_birth, current_date) BETWEEN 36 AND 45 THEN '36-45'
            WHEN datediff(year, date_of_birth, current_date) BETWEEN 46 AND 55 THEN '46-55'
            WHEN datediff(year, date_of_birth, current_date) >= 56 THEN '56+'
            ELSE 'Invalid'
            END AS age_range
        , register_hook_app
        , first_app_launch_datetime
        , total_remaining_coin
        , total_remaining_cash_coin
        , total_remaining_incentive_coin
        , total_remaining_refund_coin
    FROM refined.dim_hook_member
    ORDER BY register_datetime, activated_wallet_datetime, member_id
)
, date_spine AS (
    SELECT full_date AS data_date
        , LAST_DAY(full_date) AS data_month
        , fiscal_year
    FROM refined.dim_date
    WHERE full_date BETWEEN '2026-05-09'::DATE AND CURRENT_DATE
)
, member_date AS (
    SELECT a.member_id
        , b.data_date
        , b.data_month
        , b.fiscal_year
    FROM hook_member a
    CROSS JOIN date_spine b
    WHERE b.data_date >= DATE_TRUNC('day', a.register_datetime_fixed)::DATE
)
, txn_day AS (
    SELECT member_id
        , txn_type
        , bu_sort
        , bu
        , data_date
        , redeem_type
        , COUNT(transaction_no) AS txn_count
        , COUNT(DISTINCT transaction_no) AS txn_no_distinct
        , MIN(transaction_datetime) AS first_txn_datetime
        , MAX(transaction_datetime) AS last_txn_datetime
        , SUM(total_discount_amount) AS total_discount_amount
        , SUM(paid_amount) AS paid_amount
        , SUM(paid_coin) AS paid_coin
        , SUM(paid_coin_cash) AS paid_coin_cash
        , SUM(paid_coin_incentive) AS paid_coin_incentive
        , SUM(paid_coin_refund) AS paid_coin_refund
        , SUM(paid_coupon_amount) AS paid_coupon_amount
    FROM txn_agg
    WHERE data_date >= '2026-05-09'::DATE
    GROUP BY ALL
)
, txn_final AS (
    SELECT a.member_id
        , a.register_datetime
        , a.register_datetime_fixed
        , a.register_month
        , a.registration_source
        , a.activated_wallet
        , a.activated_wallet_datetime
        , a.activated_wallet_month
        , a.is_staff
        , a.member_status
        , a.member_type
        , a.member_house_type
        , a.member_house_zone
        , a.gender
        , a.age_range
        , a.register_hook_app
        , a.first_app_launch_datetime
        , b.data_date
        , b.data_month
        , b.fiscal_year
        , NVL(c.txn_type, 'No transaction') AS txn_type
        , c.redeem_type
        , NVL(c.bu_sort, 99) AS bu_sort
        , NVL(c.bu, 'No transaction') AS bu
        , CASE
            WHEN c.member_id IS NULL THEN FALSE
            ELSE TRUE
            END AS is_active_day
        , NVL(c.txn_count, 0) AS txn_count
        , NVL(c.txn_no_distinct, 0) AS txn_no_distinct
        , NVL(c.total_discount_amount, 0) AS total_discount_amount
        , NVL(c.paid_amount, 0) AS paid_amount
        , NVL(c.paid_coin, 0) AS paid_coin
        , NVL(c.paid_coin_cash, 0) AS paid_coin_cash
        , NVL(c.paid_coin_incentive, 0) AS paid_coin_incentive
        , NVL(c.paid_coin_refund, 0) AS paid_coin_refund
        , NVL(c.paid_coupon_amount, 0) AS paid_coupon_amount
    FROM member_date b
    INNER JOIN hook_member a ON b.member_id = a.member_id
    LEFT JOIN txn_day c ON b.member_id = c.member_id AND b.data_date = c.data_date
)
SELECT *
FROM txn_final 
ORDER BY member_id, bu_sort, data_date, txn_type DESC