WITH txn_activated_wallet AS (
    SELECT DISTINCT member_id
    --    , activated_wallet_datetime::DATE AS activated_wallet_date
        , CASE
            WHEN activated_wallet_datetime::DATE = '2026-05-08'::DATE THEN DATEADD('day', 1, activated_wallet_datetime)::DATE
            ELSE activated_wallet_datetime::DATE
            END AS activated_wallet_date
        , activated_wallet AS is_activated_wallet
    FROM refined.dim_hook_member
    WHERE activated_wallet = TRUE
        AND member_status = 'active'
)
, txn_cash_coin_issue AS (
    SELECT member_id
        , FALSE::BOOLEAN AS is_activated_wallet
        , TRUE::BOOLEAN AS is_cash_coin_issue
        , NULL::BOOLEAN AS is_coin_sales
        , NULL::BOOLEAN AS is_coin_redeem
        -- , data_date
        , CASE
            WHEN data_date::DATE = '2026-05-08'::DATE THEN DATEADD('day', 1, data_date)::DATE
            ELSE data_date::DATE
            END AS data_date
        , NULL::TEXT AS bu
        , NULL::TEXT AS merchant
        , provider
        , COUNT(DISTINCT transaction_id) AS count_coin_topup
        , SUM(total_coin_value) AS value_coin_topup
        , NULL::BIGINT AS count_txn
        , NULL::FLOAT AS paid_amount
        , NULL::FLOAT AS paid_coin
        , NULL::FLOAT AS paid_coin_cash
        , NULL::FLOAT AS paid_coin_incentive
        , NULL::FLOAT AS paid_coin_amount
        , NULL::FLOAT AS paid_noncoin_amount
        , NULL::BIGINT AS count_txn_coin_redeem
        , NULL::FLOAT AS redeem_coin_value
        , NULL::FLOAT AS redeem_cash_coin_value
        , NULL::FLOAT AS redeem_incentive_coin_value
        , NULL::FLOAT AS redeem_coupon_value
    FROM refined.fact_hook_coin_issue
    WHERE data_date >= '2026-05-09'::DATE
        AND transaction_type IN ('topup', 'admin_credit')
        AND coin_type = 'cash'
        AND transaction_status = 'confirmed'
    GROUP BY ALL
)
, txn_coin_sales AS (
    SELECT member_id
        , FALSE::BOOLEAN AS is_activated_wallet
        , NULL::BOOLEAN AS is_cash_coin_issue
        , TRUE::BOOLEAN AS is_coin_sales
        , NULL::BOOLEAN AS is_coin_redeem
        -- , data_date
        , CASE
            WHEN data_date::DATE = '2026-05-08'::DATE THEN DATEADD('day', 1, data_date)::DATE
            ELSE data_date::DATE
            END AS data_date
        , bu
        , merchant
        , NULL::TEXT AS provider
        , NULL::BIGINT AS count_coin_topup
        , NULL::BIGINT AS value_coin_topup
        , SUM(count_txn) AS count_txn
        , SUM(paid_amount) AS paid_amount
        , SUM(paid_coin) AS paid_coin
        , SUM(paid_coin_cash) AS paid_coin_cash
        , SUM(paid_coin_incentive) AS paid_coin_incentive
        , SUM(paid_coin_amount) AS paid_coin_amount
        , SUM(paid_noncoin_amount) AS paid_noncoin_amount
        , NULL::BIGINT AS count_txn_coin_redeem
        , NULL::FLOAT AS redeem_coin_value
        , NULL::FLOAT AS redeem_cash_coin_value
        , NULL::FLOAT AS redeem_incentive_coin_value
        , NULL::FLOAT AS redeem_coupon_value
    FROM refined.v_fact_sales_all_bu
    WHERE data_date >= '2026-05-09'::DATE
        AND coin_payment_portion <> 'no'
    GROUP BY ALL
)
, txn_coin_redeem AS (
    SELECT NVL(used_member_id, redeem_member_id) AS member_id
        , FALSE::BOOLEAN AS is_activated_wallet
        , NULL::BOOLEAN AS is_cash_coin_issue
        , NULL::BOOLEAN AS is_coin_sales
        , TRUE::BOOLEAN AS is_coin_redeem
        -- , data_date
        , CASE
            WHEN NVL(used_datetime, redeem_datetime)::DATE = '2026-05-08'::DATE THEN DATEADD('day', 1, NVL(used_datetime, redeem_datetime))::DATE
            ELSE NVL(used_datetime, redeem_datetime)::DATE
            END AS data_date
        , redeem_from_bu AS bu
        , redeem_from_merchant AS merchant
        , NULL::TEXT AS provider
        , NULL::BIGINT AS count_coin_topup
        , NULL::BIGINT AS value_coin_topup
        , NULL::BIGINT AS count_txn
        , NULL::FLOAT AS paid_amount
        , NULL::FLOAT AS paid_coin
        , NULL::FLOAT AS paid_coin_cash
        , NULL::FLOAT AS paid_coin_incentive
        , NULL::FLOAT AS paid_coin_amount
        , NULL::FLOAT AS paid_noncoin_amount
        , COUNT(DISTINCT transaction_id) AS count_txn_coin_redeem
        , SUM(total_coin_value) AS redeem_coin_value
        , SUM(total_cash_coin_value) AS redeem_cash_coin_value
        , SUM(total_incentive_coin_value) AS redeem_incentive_coin_value
        , SUM(total_coupon_value) AS redeem_coupon_value
    FROM refined.fact_hook_coupon_redeem
    WHERE data_date >= '2026-05-09'::DATE
        AND redeem_type = 'coin'
    GROUP BY ALL
)
, txn_wallet_activation AS (
    SELECT member_id
        , TRUE::BOOLEAN AS is_activated_wallet
        , NULL::BOOLEAN AS is_cash_coin_issue
        , NULL::BOOLEAN AS is_coin_sales
        , NULL::BOOLEAN AS is_coin_redeem
        , activated_wallet_date AS data_date
        , NULL::TEXT AS bu
        , NULL::TEXT AS merchant
        , NULL::TEXT AS provider
        , NULL::BIGINT AS count_coin_topup
        , NULL::FLOAT AS value_coin_topup
        , NULL::BIGINT AS count_txn
        , NULL::FLOAT AS paid_amount
        , NULL::FLOAT AS paid_coin
        , NULL::FLOAT AS paid_coin_cash
        , NULL::FLOAT AS paid_coin_incentive
        , NULL::FLOAT AS paid_coin_amount
        , NULL::FLOAT AS paid_noncoin_amount
        , NULL::BIGINT AS count_txn_coin_redeem
        , NULL::FLOAT AS redeem_coin_value
        , NULL::FLOAT AS redeem_cash_coin_value
        , NULL::FLOAT AS redeem_incentive_coin_value
        , NULL::FLOAT AS redeem_coupon_value
    FROM txn_activated_wallet
)
, wallet_activity AS (
    SELECT * FROM txn_cash_coin_issue
    UNION ALL
    SELECT * FROM txn_coin_sales
    UNION ALL
    SELECT * FROM txn_coin_redeem
    UNION ALL
    SELECT * FROM txn_wallet_activation
)
, dim_date AS (
	SELECT full_date
	    , fiscal_year
	FROM refined.dim_date
	WHERE full_date BETWEEN '2026-05-09'::DATE AND CURRENT_DATE
--	WHERE full_date >= '2026-05-08'::DATE
--		AND fiscal_year =
--			CASE
--	        	WHEN EXTRACT(MONTH FROM SYSDATE) <= 3 THEN EXTRACT(YEAR FROM SYSDATE) - 1
--	        	ELSE EXTRACT(YEAR FROM SYSDATE)
--	    	END
)
, joined_member AS (
    SELECT a.member_id
        , b.is_activated_wallet
        , b.is_cash_coin_issue
        , b.is_coin_sales
        , b.is_coin_redeem
--        , a.activated_wallet_date
        , NVL(b.data_date, c.full_date) AS data_date
        , DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', NVL(b.data_date, c.full_date))))::DATE AS data_month
        , c.fiscal_year
        , b.bu
        , b.merchant
        , b.provider
        , b.count_coin_topup
        , b.value_coin_topup
        , b.count_txn
        , b.paid_amount
        , b.paid_coin
        , b.paid_coin_cash
        , b.paid_coin_incentive
        , b.paid_coin_amount
        , b.paid_noncoin_amount
        , b.count_txn_coin_redeem
        , b.redeem_coin_value
        , b.redeem_cash_coin_value
        , b.redeem_incentive_coin_value
        , b.redeem_coupon_value
    FROM txn_activated_wallet a
    RIGHT JOIN wallet_activity b ON a.member_id = b.member_id
    --FULL OUTER JOIN dim_date c ON b.data_date = c.full_date
    LEFT JOIN dim_date c ON b.data_date = c.full_date
)
SELECT member_id AS "member id (03 coin activity)"
    , is_activated_wallet AS "is activated wallet (03 coin activity)"
    , is_cash_coin_issue AS "is cash coin issue (03 coin activity)"
    , is_coin_sales AS "is coin sales (03 coin activity)"
    , is_coin_redeem AS "is coin redeem (03 coin activity)"
    , data_date AS "data date (03 coin activity)"
    , data_month AS "data month (03 coin activity)"
    , fiscal_year AS "fiscal year (03 coin activity)"
    , bu AS "bu (03 coin activity)"
    , merchant AS "merchant (03 coin activity)"
    , provider AS "provider (03 coin activity)"
    , count_coin_topup AS "count coin topup (03 coin activity)"
    , value_coin_topup AS "value coin topup (03 coin activity)"
    , count_txn AS "count txn (03 coin activity)"
    , paid_amount AS "paid amount (03 coin activity)"
    , paid_coin AS "paid coin (03 coin activity)"
    , paid_coin_cash AS "paid coin cash (03 coin activity)"
    , paid_coin_incentive AS "paid coin incentive (03 coin activity)"
    , paid_coin_amount AS "paid coin amount (03 coin activity)"
    , paid_noncoin_amount AS "paid noncoin amount (03 coin activity)"
    , count_txn_coin_redeem AS "count txn coin redeem (03 coin activity)"
    , redeem_coin_value AS "redeem coin value (03 coin activity)"
    , redeem_cash_coin_value AS "redeem cash coin value (03 coin activity)"
    , redeem_incentive_coin_value AS "redeem incentive coin value (03 coin activity)"
    , redeem_coupon_value AS "redeem coupon value (03 coin activity)"
FROM joined_member