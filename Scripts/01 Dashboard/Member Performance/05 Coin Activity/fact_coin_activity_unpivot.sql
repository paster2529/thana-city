WITH coin_topup AS (
    SELECT data_date
        , member_id
        , 1 AS txn_srt
        , 'topup' AS txn_type
        , count(DISTINCT transaction_id) AS cnt_txn
        , sum(total_coin_value) AS total_coin_spent
    FROM refined.fact_hook_coin_issue
    WHERE transaction_type IN ('topup', 'admin_credit')
        AND coin_type = 'cash'
        AND transaction_status = 'confirmed'
    GROUP BY ALL
    ORDER BY 2,1
)
, paid_coin AS (
    SELECT data_date
        , member_id
        , 2 AS txn_srt
        , 'sales' AS txn_type
        , sum(count_txn) AS cnt_txn
        , sum(paid_coin) AS total_coin_spent
    FROM refined.v_fact_sales_all_bu
    WHERE coin_payment_portion <> 'no'
    GROUP BY ALL
    ORDER BY 2,1
)
, redeem_coin AS (
    SELECT data_date
        , NVL(used_member_id, redeem_member_id) AS member_id
        , 3 AS txn_srt
        , 'redeem' AS txn_type
        , count(DISTINCT transaction_id) AS cnt_txn
        , sum(total_coin_value) AS total_coin_spent
    FROM refined.fact_hook_coupon_redeem
    WHERE redeem_type = 'coin'
    GROUP BY ALL
    ORDER BY 2,1
)
, union_all AS (
    SELECT * FROM coin_topup
    UNION ALL
    SELECT * FROM paid_coin
    UNION ALL
    SELECT * FROM redeem_coin
)
, marked AS (
    SELECT *
        , CASE WHEN txn_srt = 1 THEN data_date END AS topup_marker
    FROM union_all
)
, grouped AS (
    SELECT *
        , LAST_VALUE(topup_marker IGNORE NULLS) OVER (
            PARTITION BY member_id
            ORDER BY data_date, txn_srt
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS last_topup_date
        , SUM(CASE WHEN txn_srt = 1 THEN 1 ELSE 0 END) OVER (
            PARTITION BY member_id
            ORDER BY data_date, txn_srt
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS topup_group
    FROM marked
)
, ranked AS (
    SELECT *
        , ROW_NUMBER() OVER (
            PARTITION BY member_id, topup_group, CASE WHEN txn_srt IN (2, 3) THEN 1 ELSE 0 END
            ORDER BY data_date, txn_srt
        ) AS rn_after_topup
    FROM grouped
)
, final AS (
    SELECT data_date
        , DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', data_date)))::DATE AS data_month
        , member_id
        , txn_srt
        , txn_type
        , cnt_txn AS total_txn
        , total_coin_spent
        , CASE
            WHEN txn_srt IN (2, 3) AND rn_after_topup = 1 AND last_topup_date IS NOT NULL
                THEN DATEDIFF('day', last_topup_date, data_date)
        END AS coin_age_days
    FROM ranked
    ORDER BY member_id, data_date, txn_srt
)
SELECT data_date AS "data date (04 coin age)"
    , data_month AS "data month (04 coin age)"
    , member_id AS "member id (04 coin age)"
    , txn_srt AS "txn srt (04 coin age)"
    , txn_type AS "txn type (04 coin age)"
    , total_txn AS "total txn (04 coin age)"
    , total_coin_spent AS "total coin spent (04 coin age)"
    , coin_age_days AS "coin age days (04 coin age)"
FROM FINAL
ORDER BY 3,1,4