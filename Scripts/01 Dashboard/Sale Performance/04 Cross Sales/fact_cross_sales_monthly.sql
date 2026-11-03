WITH txn_sales AS (
    SELECT member_id
        , DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', data_date)))::DATE AS data_month
        , bu
        --, merchant
        , bu_sort::INT
        --, merchant_sort::INT
        , SUM(count_txn) AS count_paid_txn
        , SUM(CASE WHEN coin_payment_portion = 'no' THEN count_txn END) AS count_paid_noncoin
        , SUM(CASE WHEN coin_payment_portion = 'full' THEN count_txn END) AS count_paid_coin_full
        , SUM(CASE WHEN coin_payment_portion LIKE 'partial%' THEN count_txn END) AS count_paid_coin_partial
        , SUM(paid_amount) AS paid_amount
        , SUM(paid_coin) AS paid_coin
        , SUM(paid_coin_cash) AS paid_coin_cash
        , SUM(paid_coin_incentive) AS paid_coin_incentive
        , SUM(paid_coin_amount) AS paid_coin_amount
        , SUM(paid_noncoin_amount) AS paid_noncoin_amount
        , SUM(paid_cash_amount) AS paid_cash_amount 
    FROM refined.v_fact_sales_all_bu
    WHERE data_date >= '2026-05-09'::DATE
    GROUP BY ALL
)
SELECT member_id AS "Member ID"
    , data_month AS "Data Month"
    , count(bu) AS "Total BU Usage"
    , LISTAGG(bu, ', ') WITHIN GROUP (ORDER BY bu_sort) AS "BU list"
    , SUM(count_paid_txn) AS "Total Paid TXN" 
    , SUM(count_paid_noncoin) AS "Total Paid TXN Non-coin"
    , SUM(count_paid_coin_full) AS "Total Paid TXN Full Coin"
    , SUM(count_paid_coin_partial) AS "Total Paid TXN Partial Coin"
    , SUM(paid_amount) AS "Total Paid Amount"
    , SUM(paid_coin) AS "Total Paid Coin"
    , SUM(paid_coin_cash) AS "Total Paid Cash Coin"
    , SUM(paid_coin_incentive) AS "Total Paid Incentive Coin"
    , SUM(paid_coin_amount) AS "Total Paid Amount Coin"
    , SUM(paid_cash_amount) AS "Total Paid Amount Cash"
FROM txn_sales
GROUP BY ALL