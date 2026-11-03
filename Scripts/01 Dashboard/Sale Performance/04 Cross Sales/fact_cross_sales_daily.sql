WITH hook_members AS (
    SELECT member_id
        , register_datetime
        , DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', register_datetime)))::DATE AS register_month
        , member_status
        , member_type
        , CASE
            WHEN member_type = 'visitor' THEN 'Visitor'
            WHEN member_type = 'resident' AND member_house_type = 'Condominium' THEN 'Resident Condominium'
            WHEN member_type = 'resident' AND member_house_type = 'Housing' THEN 'Resident Housing'
            ELSE 'Resident Unidentified'
            END AS member_group
        , activated_wallet
        , activated_wallet_datetime
        , DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', activated_wallet_datetime)))::DATE AS activated_wallet_month
        , registration_source
        , is_staff
        , is_foreigner
        , nationality
        , gender
        , date_of_birth
        , member_house_type
        , member_house_zone
        , register_hook_app
        , first_app_launch_datetime
        , DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', first_app_launch_datetime)))::DATE AS first_app_launch_month
    FROM refined.dim_hook_member
)
, txn_sales AS (
    SELECT a.member_id
        , data_date
        , bu
        , merchant
        , bu_sort::INT
        , merchant_sort::INT
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
        , b.register_datetime
        , b.register_month
        , b.registration_source
        , b.member_status
        , b.member_type
        , CASE
	        WHEN b.member_group IS NULL THEN 'Non-member'
	        ELSE b.member_group
	        END AS member_group
        , b.activated_wallet
        , b.activated_wallet_datetime
        , b.activated_wallet_month
        , b.is_staff
        , b.is_foreigner
        , b.nationality
        , b.gender
        , b.date_of_birth
        , b.member_house_type
        , b.member_house_zone
        , b.register_hook_app
        , b.first_app_launch_datetime
        , b.first_app_launch_month
    FROM refined.v_fact_sales_all_bu a
    LEFT JOIN hook_members b ON a.member_id = b.member_id
    WHERE a.data_date >= '2026-05-09'::DATE
    GROUP BY ALL
)
SELECT member_id AS "Member ID (daily)"
    , register_datetime AS "Register Datatime (daily)"
    , registration_source AS "Registration Source (daily)"
    , member_type AS "Member Type (daily)"
    , member_status AS "Member Status (daily)"
    , member_group AS "Member Group (daily)"
    , member_house_type AS "Member House Type (daily)"
    , member_house_zone AS "Member House Zone (daily)"
    , is_staff AS "Is Staff (daily)"
    , is_foreigner AS "Is Foreigner (daily)"
    , gender AS "Gender (daily)"
    , data_date AS "Data Date (daily)"
    , DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', data_date)))::DATE AS "Data Month (daily)"
    , count(bu) AS "Total BU Usage (daily)"
    , LISTAGG(bu, ', ') WITHIN GROUP (ORDER BY bu_sort) AS "BU list (daily)"
    , SUM(count_paid_txn) AS "Total Paid TXN (daily)" 
    , SUM(count_paid_noncoin) AS "Total Paid TXN Non-coin (daily)"
    , SUM(count_paid_coin_full) AS "Total Paid TXN Full Coin (daily)"
    , SUM(count_paid_coin_partial) AS "Total Paid TXN Partial Coin (daily)"
    , SUM(paid_amount) AS "Total Paid Amount (daily)"
    , SUM(paid_coin) AS "Total Paid Coin (daily)"
    , SUM(paid_coin_cash) AS "Total Paid Cash Coin (daily)"
    , SUM(paid_coin_incentive) AS "Total Paid Incentive Coin (daily)"
    , SUM(paid_coin_amount) AS "Total Paid Amount Coin (daily)"
    , SUM(paid_cash_amount) AS "Total Paid Amount Cash (daily)"
FROM txn_sales
GROUP BY ALL