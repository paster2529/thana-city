WITH txn_pay_with_coin AS (
	SELECT COALESCE(member_id_coin, member_id_pos) AS member_id
		, 14 AS bu_sort
		, 1401 AS merchant_sort
	    , 'Super Turtle' AS bu
		, 'Turtle X' AS merchant
		, CASE
            WHEN data_date::DATE = '2026-05-08'::DATE THEN DATEADD('day', 1, data_date)::DATE
            ELSE data_date::DATE
            END AS data_date
		, 1 AS txn_type_sort
		, 'Pay with coin' AS txn_type
	    , transaction_id
	    , coin_payment_portion
	    , paid_amount
	    , paid_amount - paid_coin - paid_coupon_amount AS paid_others
	    , paid_coupon_amount
	    , paid_coin
	    , paid_coin_cash
	    , paid_coin_incentive
	    , NULL::NUMERIC(10,2) AS redeemed_coin
		, NULL::NUMERIC(10,2) AS redeemed_coin_cash
		, NULL::NUMERIC(10,2) AS redeemed_coin_incentive
		, NULL::NUMERIC(10,2) AS redeemed_coupon_value
		, NULL::TEXT AS coupon_status
		, NULL::BOOLEAN AS is_used_at_pos
		, NULL::TEXT AS redeem_type
	FROM refined.fact_sales_txn_turtle
	WHERE is_valid = TRUE
	    AND COALESCE(member_id_coin, member_id_pos) IS NOT NULL
        AND paid_coin > 0
	UNION ALL
	SELECT COALESCE(a.member_id_coin, a.member_id_reward, a.member_id_pos) AS member_id
		, bu_sort
		, merchant_sort
        , bu_report_ref AS bu
		, merchant_report_ref AS merchant
		, CASE
            WHEN a.data_date::DATE = '2026-05-08'::DATE THEN DATEADD('day', 1, a.data_date)::DATE
            ELSE a.data_date::DATE
            END AS data_date
		, 1 AS txn_type_sort
		, 'Pay with coin' AS txn_type
		, transaction_no AS transaction_id
		, coin_payment_portion
        , paid_amount
        , paid_amount - paid_coin - paid_coupon_amount AS paid_others
        , paid_coupon_amount
        , paid_coin
        , paid_coin_cash
        , paid_coin_incentive
        , NULL::NUMERIC(10,2) AS redeemed_coin
		, NULL::NUMERIC(10,2) AS redeemed_coin_cash
		, NULL::NUMERIC(10,2) AS redeemed_coin_incentive
		, NULL::NUMERIC(10,2) AS redeemed_coupon_value
		, NULL::TEXT AS coupon_status
		, NULL::BOOLEAN AS is_used_at_pos
		, NULL::TEXT AS redeem_type
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
        AND paid_coin > 0
)
, txn_coin_redeemed AS (
    SELECT NVL(used_member_id, redeem_member_id) AS member_id
		, b.bu_sort
		, b.merchant_sort
		, redeem_from_bu AS bu
        , redeem_from_merchant AS merchant
		-- , TRUNC(NVL(used_datetime, redeem_datetime)) AS data_date
        , CASE
            WHEN TRUNC(NVL(used_datetime, redeem_datetime)) = '2026-05-08'::DATE THEN TRUNC(DATEADD('day', 1, NVL(used_datetime, redeem_datetime)))
            ELSE TRUNC(NVL(used_datetime, redeem_datetime))
            END AS data_date
		, 2 AS txn_type_sort
		, 'Coin redeemed' AS txn_type
        , transaction_id
        , NULL::TEXT AS coin_payment_portion
        , NULL::NUMERIC(10,2) AS paid_amount
        , NULL::NUMERIC(10,2) AS paid_others
		, NULL::NUMERIC(10,2) AS paid_coupon_amount
        , NULL::NUMERIC(10,2) AS paid_coin
		, NULL::NUMERIC(10,2) AS paid_coin_cash
		, NULL::NUMERIC(10,2) AS paid_coin_incentive
        , total_coin_value AS redeemed_coin
		, total_cash_coin_value AS redeemed_coin_cash
		, total_incentive_coin_value AS redeemed_coin_incentive
		, total_coupon_value AS redeemed_coupon_value
		, coupon_status
		, is_used_at_pos
		, redeem_type
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
	SELECT NVL(used_member_id, redeem_member_id) AS member_id
		, b.bu_sort
		, b.merchant_sort
		, redeem_from_bu AS bu
		, redeem_from_merchant AS merchant
		-- , TRUNC(NVL(used_datetime, redeem_datetime)) AS data_date
        , CASE
            WHEN TRUNC(NVL(used_datetime, redeem_datetime)) = '2026-05-08'::DATE THEN TRUNC(DATEADD('day', 1, NVL(used_datetime, redeem_datetime)))
            ELSE TRUNC(NVL(used_datetime, redeem_datetime))
            END AS data_date
		, 3 AS txn_type_sort
		, 'Coupon used' AS txn_type
		, transaction_id
		, NULL::TEXT AS coin_payment_portion
		, NULL::NUMERIC(10,2) AS paid_amount
		, NULL::NUMERIC(10,2) AS paid_others
		, NULL::NUMERIC(10,2) AS paid_coupon_amount
		, NULL::NUMERIC(10,2) AS paid_coin
		, NULL::NUMERIC(10,2) AS paid_coin_cash
		, NULL::NUMERIC(10,2) AS paid_coin_incentive
		, CASE
			WHEN redeem_type = 'coin' THEN NULL::NUMERIC(10,2)
			ELSE total_coin_value
			END AS redeemed_coin
		, CASE
			WHEN redeem_type = 'coin' THEN NULL::NUMERIC(10,2)
			ELSE total_cash_coin_value
			END AS redeemed_coin_cash
		, CASE
			WHEN redeem_type = 'coin' THEN NULL::NUMERIC(10,2)
			ELSE total_incentive_coin_value
			END AS redeemed_coin_incentive
		, total_coupon_value AS redeemed_coupon_value
		, coupon_status
		, is_used_at_pos
		, redeem_type
	FROM refined.fact_hook_coupon_redeem a
	LEFT JOIN (
			SELECT DISTINCT bu_sort
				, merchant_sort
				, bu_report_ref AS bu
				, merchant_report_ref AS merchant
			FROM "trusted".ggsheets_setup_merchant_bu_mapping
		) b ON a.redeem_from_bu = b.bu AND a.redeem_from_merchant = b.merchant
	WHERE data_date >= '2026-05-09'::DATE
		AND (is_used_at_pos = TRUE OR coupon_status = 'used')
		AND redeem_from_bu <> 'BU Test'
)
, txn_all AS (
    SELECT * FROM txn_pay_with_coin
    UNION ALL
	SELECT * FROM txn_coin_redeemed
	UNION ALL
	SELECT * FROM txn_coupon_used
)
, txn_agg_prep AS (
    	-- ตัว transaction_id เดียวกันสามารถเกิดได้ทั้งใน 'Coin redeemed' และ 'Coupon used'
    	-- (แถวเดียวกันใน fact_hook_coupon_redeem เข้าเงื่อนไขทั้งสอง CTE) ทำให้ COUNT(DISTINCT transaction_id)
    	-- ถูกต้องเฉพาะภายใน txn_type เดียว แต่ถ้ารวมข้าม txn_type จะนับซ้ำ
    	-- ใช้ flag นี้เลือกนับ transaction_id นั้นแค่ครั้งเดียว (ให้ priority กับ txn_type_sort ที่น้อยกว่า)
    SELECT a.*
    	, b.fiscal_year
    	, ROW_NUMBER() OVER (PARTITION BY a.transaction_id ORDER BY a.txn_type_sort) AS txn_dedup_rn
    FROM txn_all a
    LEFT JOIN (
        SELECT DISTINCT(LAST_DAY(full_date)) AS last_date
				, fiscal_year
			FROM refined.dim_date
		) b ON LAST_DAY(a.data_date) = b.last_date
)
--SELECT *
--FROM txn_agg_prep
--ORDER BY transaction_id, txn_type_sort
, txn_agg AS (
	SELECT member_id
		, fiscal_year
		, LAST_DAY(data_date) AS data_month
		, bu_sort
		, merchant_sort
		, bu
		, merchant
		, txn_type_sort
		, txn_type
		, is_used_at_pos
		, CASE
			WHEN coupon_status = 'used' THEN TRUE
			ELSE FALSE
			END AS is_used_at_hook_app
		, COUNT(DISTINCT transaction_id) AS cnt_txn
		, COUNT(DISTINCT CASE WHEN txn_dedup_rn = 1 THEN transaction_id END) AS cnt_txn_unique
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
	FROM txn_agg_prep
	GROUP BY ALL
)
/* =========================================================================
   Branch 1 — "By BU": grain เดิม (member_id x bu_sort x merchant_sort)
   cohort/cycle state คำนวณแยกต่อ BU/merchant ที่ member เคยไป
   ========================================================================= */
, active_month AS (
	SELECT member_id
		, data_month
        , bu_sort
        , bu AS bu_visited
        , merchant_sort
        , merchant AS merchant_visited
    FROM txn_agg
	GROUP BY ALL
)
, cohort AS (
	SELECT member_id
        , bu_sort
        , bu_visited
        , merchant_sort
        , merchant_visited
        , MIN(data_month) AS cohort_month
    FROM active_month
    GROUP BY ALL
)
, month_spine AS (
    SELECT LAST_DAY(full_date) AS data_month
        , MAX(fiscal_year) AS fiscal_year
    FROM refined.dim_date
    WHERE full_date BETWEEN '2026-05-09'::DATE AND CURRENT_DATE
    GROUP BY ALL
)
, grid AS (
	SELECT a.member_id
		, b.fiscal_year
		, a.cohort_month
		, b.data_month
		, a.bu_sort
		, a.merchant_sort
		, a.bu_visited
		, a.merchant_visited
		, CASE
			WHEN c.member_id IS NULL THEN 0
			ELSE 1
			END AS is_active_month
	FROM cohort a
	INNER JOIN month_spine b ON b.data_month >= a.cohort_month
	LEFT JOIN txn_agg c ON a.member_id = c.member_id
		AND a.merchant_visited = c.merchant
		AND b.data_month = c.data_month
	GROUP BY ALL
)
, flagged_prev AS (
	SELECT *
		, NVL(LAG(is_active_month, 1) OVER (PARTITION BY member_id, bu_sort, merchant_sort ORDER BY data_month), 0) AS prev1
        , NVL(LAG(is_active_month, 2) OVER (PARTITION BY member_id, bu_sort, merchant_sort ORDER BY data_month), 0) AS prev2
	FROM grid
)
, flagged_cycle_status AS (
	SELECT f.member_id
		, f.fiscal_year
		, f.cohort_month
		, f.data_month
		, DATEDIFF(month, f.cohort_month, f.data_month) AS month_number
		, f.bu_sort
		, f.merchant_sort
		, f.bu_visited
		, f.merchant_visited
		, f.is_active_month
		, CASE
			WHEN f.is_active_month = 0 THEN -1
			ELSE 1
			END AS state_sign
		, f.prev1
		, f.prev2
		, b.txn_type_sort
		, b.txn_type
		, CASE
	        WHEN f.data_month = f.cohort_month THEN 1
	        WHEN f.is_active_month = 1 AND f.prev1 = 1 THEN 2
	        WHEN f.is_active_month = 1 AND f.prev1 = 0 THEN 3
	        WHEN f.is_active_month = 0 AND f.prev1 = 0 AND f.prev2 = 0 THEN 5
	        WHEN f.is_active_month = 0 THEN 4
	        END AS state_sort
	    , CASE
	        WHEN f.data_month = f.cohort_month THEN 'New'
	        WHEN f.is_active_month = 1 AND f.prev1 = 1 THEN 'Retain'
	        WHEN f.is_active_month = 1 AND f.prev1 = 0 THEN 'Win Back'
	        WHEN f.is_active_month = 0 AND f.prev1 = 0 AND f.prev2 = 0 THEN 'Churn'
	        WHEN f.is_active_month = 0 THEN 'Inactive'
	        END AS member_cycle_state
		, b.is_used_at_pos
		, b.is_used_at_hook_app
		, b.cnt_txn
		, b.cnt_txn_unique
		, b.paid_amount
		, b.paid_others
		, b.paid_coupon_amount
		, b.paid_coin
		, b.paid_coin_cash
		, b.paid_coin_incentive
		, b.redeemed_coin
		, b.redeemed_coin_cash
		, b.redeemed_coin_incentive
		, b.redeemed_coupon_value
	FROM flagged_prev f
	LEFT JOIN txn_agg b ON b.member_id = f.member_id
	    AND b.merchant = f.merchant_visited
	    AND b.data_month = f.data_month
)
/* =========================================================================
   Branch 2 — "All BU": grain รวม (member_id เท่านั้น ไม่แบ่ง bu/merchant)
   ห้าม sum ตัวเลขจาก Branch 1 ข้าม BU เพราะ member ที่ active หลาย BU
   จะถูกนับซ้ำ (และ cycle state ต่อ BU ก็อาจไม่ตรงกันในเดือนเดียวกัน)
   จึงต้องคำนวณ cohort/cycle state ใหม่ทั้งชุดที่ grain member_id ล้วนๆ
   ========================================================================= */
, txn_agg_all AS (
    SELECT member_id
        , fiscal_year
        , data_month
        , txn_type_sort
        , txn_type
        , is_used_at_pos
        , is_used_at_hook_app
        , SUM(cnt_txn) AS cnt_txn
        , SUM(cnt_txn_unique) AS cnt_txn_unique
        , SUM(paid_amount) AS paid_amount
        , SUM(paid_others) AS paid_others
        , SUM(paid_coupon_amount) AS paid_coupon_amount
        , SUM(paid_coin) AS paid_coin
        , SUM(paid_coin_cash) AS paid_coin_cash
        , SUM(paid_coin_incentive) AS paid_coin_incentive
        , SUM(redeemed_coin) AS redeemed_coin
        , SUM(redeemed_coin_cash) AS redeemed_coin_cash
        , SUM(redeemed_coin_incentive) AS redeemed_coin_incentive
        , SUM(redeemed_coupon_value) AS redeemed_coupon_value
    FROM txn_agg
    GROUP BY ALL
)
, active_month_all AS (
    SELECT member_id
        , data_month
    FROM txn_agg_all
    GROUP BY ALL
)
, cohort_all AS (
    SELECT member_id
        , MIN(data_month) AS cohort_month
    FROM active_month_all
    GROUP BY ALL
)
, grid_all AS (
    SELECT a.member_id
        , b.fiscal_year
        , a.cohort_month
        , b.data_month
        , CASE
            WHEN c.member_id IS NULL THEN 0
            ELSE 1
            END AS is_active_month
    FROM cohort_all a
    INNER JOIN month_spine b ON b.data_month >= a.cohort_month
    LEFT JOIN active_month_all c ON a.member_id = c.member_id
        AND b.data_month = c.data_month
    GROUP BY ALL
)
, flagged_prev_all AS (
    SELECT *
        , NVL(LAG(is_active_month, 1) OVER (PARTITION BY member_id ORDER BY data_month), 0) AS prev1
        , NVL(LAG(is_active_month, 2) OVER (PARTITION BY member_id ORDER BY data_month), 0) AS prev2
    FROM grid_all
)
, flagged_cycle_status_all AS (
    SELECT f.member_id
        , f.fiscal_year
        , f.cohort_month
        , f.data_month
        , DATEDIFF(month, f.cohort_month, f.data_month) AS month_number
        , 0 AS bu_sort
        , 0 AS merchant_sort
        , 'All' AS bu_visited
        , 'All' AS merchant_visited
        , f.is_active_month
        , CASE
            WHEN f.is_active_month = 0 THEN -1
            ELSE 1
            END AS state_sign
        , f.prev1
        , f.prev2
        , b.txn_type_sort
        , b.txn_type
        , CASE
            WHEN f.data_month = f.cohort_month THEN 1
            WHEN f.is_active_month = 1 AND f.prev1 = 1 THEN 2
            WHEN f.is_active_month = 1 AND f.prev1 = 0 THEN 3
            WHEN f.is_active_month = 0 AND f.prev1 = 0 AND f.prev2 = 0 THEN 5
            WHEN f.is_active_month = 0 THEN 4
            END AS state_sort
        , CASE
            WHEN f.data_month = f.cohort_month THEN 'New'
            WHEN f.is_active_month = 1 AND f.prev1 = 1 THEN 'Retain'
            WHEN f.is_active_month = 1 AND f.prev1 = 0 THEN 'Win Back'
            WHEN f.is_active_month = 0 AND f.prev1 = 0 AND f.prev2 = 0 THEN 'Churn'
            WHEN f.is_active_month = 0 THEN 'Inactive'
            END AS member_cycle_state
        , b.is_used_at_pos
        , b.is_used_at_hook_app
        , b.cnt_txn
        , b.cnt_txn_unique
        , b.paid_amount
        , b.paid_others
        , b.paid_coupon_amount
        , b.paid_coin
        , b.paid_coin_cash
        , b.paid_coin_incentive
        , b.redeemed_coin
        , b.redeemed_coin_cash
        , b.redeemed_coin_incentive
        , b.redeemed_coupon_value
    FROM flagged_prev_all f
    LEFT JOIN txn_agg_all b ON b.member_id = f.member_id
        AND b.data_month = f.data_month
)
/* =========================================================================
   Branch 3 — "By BU, All Merchant": grain กลาง (member_id x bu_sort เท่านั้น)
   ใช้ตอน dashboard filter เลือก BU เจาะจง แต่ merchant ยังเป็น "All"
   ห้ามใช้ Branch 1 (grain member x bu x merchant) ตรงๆ ในเคสนี้ เพราะ member
   ที่ active หลาย merchant ใน BU เดียวกัน จะถูกนับซ้ำ/ได้ state ไม่ตรงกัน
   ========================================================================= */
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
, active_month_bu AS (
    SELECT member_id
        , data_month
        , bu_sort
        , bu AS bu_visited
    FROM txn_agg_bu
    GROUP BY ALL
)
, cohort_bu AS (
    SELECT member_id
        , bu_sort
        , bu_visited
        , MIN(data_month) AS cohort_month
    FROM active_month_bu
    GROUP BY ALL
)
, grid_bu AS (
    SELECT a.member_id
        , b.fiscal_year
        , a.cohort_month
        , b.data_month
        , a.bu_sort
        , a.bu_visited
        , CASE
            WHEN c.member_id IS NULL THEN 0
            ELSE 1
            END AS is_active_month
    FROM cohort_bu a
    INNER JOIN month_spine b ON b.data_month >= a.cohort_month
    LEFT JOIN active_month_bu c ON a.member_id = c.member_id
        AND a.bu_visited = c.bu_visited
        AND b.data_month = c.data_month
    GROUP BY ALL
)
, flagged_prev_bu AS (
    SELECT *
        , NVL(LAG(is_active_month, 1) OVER (PARTITION BY member_id, bu_sort ORDER BY data_month), 0) AS prev1
        , NVL(LAG(is_active_month, 2) OVER (PARTITION BY member_id, bu_sort ORDER BY data_month), 0) AS prev2
    FROM grid_bu
)
, flagged_cycle_status_bu AS (
    SELECT f.member_id
        , f.fiscal_year
        , f.cohort_month
        , f.data_month
        , DATEDIFF(month, f.cohort_month, f.data_month) AS month_number
        , f.bu_sort
        , 0 AS merchant_sort
        , f.bu_visited
        , 'All' AS merchant_visited
        , f.is_active_month
        , CASE
            WHEN f.is_active_month = 0 THEN -1
            ELSE 1
            END AS state_sign
        , f.prev1
        , f.prev2
        , b.txn_type_sort
        , b.txn_type
        , CASE
            WHEN f.data_month = f.cohort_month THEN 1
            WHEN f.is_active_month = 1 AND f.prev1 = 1 THEN 2
            WHEN f.is_active_month = 1 AND f.prev1 = 0 THEN 3
            WHEN f.is_active_month = 0 AND f.prev1 = 0 AND f.prev2 = 0 THEN 5
            WHEN f.is_active_month = 0 THEN 4
            END AS state_sort
        , CASE
            WHEN f.data_month = f.cohort_month THEN 'New'
            WHEN f.is_active_month = 1 AND f.prev1 = 1 THEN 'Retain'
            WHEN f.is_active_month = 1 AND f.prev1 = 0 THEN 'Win Back'
            WHEN f.is_active_month = 0 AND f.prev1 = 0 AND f.prev2 = 0 THEN 'Churn'
            WHEN f.is_active_month = 0 THEN 'Inactive'
            END AS member_cycle_state
        , b.is_used_at_pos
        , b.is_used_at_hook_app
        , b.cnt_txn
        , b.cnt_txn_unique
        , b.paid_amount
        , b.paid_others
        , b.paid_coupon_amount
        , b.paid_coin
        , b.paid_coin_cash
        , b.paid_coin_incentive
        , b.redeemed_coin
        , b.redeemed_coin_cash
        , b.redeemed_coin_incentive
        , b.redeemed_coupon_value
    FROM flagged_prev_bu f
    LEFT JOIN txn_agg_bu b ON b.member_id = f.member_id
        AND b.bu_sort = f.bu_sort
        AND b.data_month = f.data_month
)
SELECT 'All BU' AS bu_scope
	, member_id
	, fiscal_year
	, cohort_month
	, data_month
	, month_number
	, bu_sort
	, merchant_sort
	, bu_visited
	, merchant_visited
	, is_active_month
	, state_sign
	, prev1
	, prev2
	, txn_type_sort
	, txn_type
	, state_sort
	, member_cycle_state
	, is_used_at_pos
	, is_used_at_hook_app
	, cnt_txn
	, cnt_txn_unique
	, paid_amount
	, paid_others
	, paid_coupon_amount
	, paid_coin
	, paid_coin_cash
	, paid_coin_incentive
	, redeemed_coin
	, redeemed_coin_cash
	, redeemed_coin_incentive
	, redeemed_coupon_value
FROM flagged_cycle_status_all
UNION ALL
SELECT 'By BU' AS bu_scope
	, member_id
	, fiscal_year
	, cohort_month
	, data_month
	, month_number
	, bu_sort
	, merchant_sort
	, bu_visited
	, merchant_visited
	, is_active_month
	, state_sign
	, prev1
	, prev2
	, txn_type_sort
	, txn_type
	, state_sort
	, member_cycle_state
	, is_used_at_pos
	, is_used_at_hook_app
	, cnt_txn
	, cnt_txn_unique
	, paid_amount
	, paid_others
	, paid_coupon_amount
	, paid_coin
	, paid_coin_cash
	, paid_coin_incentive
	, redeemed_coin
	, redeemed_coin_cash
	, redeemed_coin_incentive
	, redeemed_coupon_value
FROM flagged_cycle_status
UNION ALL
SELECT 'By BU - All Merchant' AS bu_scope
    , member_id
    , fiscal_year
    , cohort_month
    , data_month
    , month_number
    , bu_sort
    , merchant_sort
    , bu_visited
    , merchant_visited
    , is_active_month
    , state_sign
    , prev1
    , prev2
    , txn_type_sort
    , txn_type
    , state_sort
    , member_cycle_state
    , is_used_at_pos
    , is_used_at_hook_app
    , cnt_txn
    , cnt_txn_unique
    , paid_amount
    , paid_others
    , paid_coupon_amount
    , paid_coin
    , paid_coin_cash
    , paid_coin_incentive
    , redeemed_coin
    , redeemed_coin_cash
    , redeemed_coin_incentive
    , redeemed_coupon_value
FROM flagged_cycle_status_bu
ORDER BY bu_scope, member_id, cohort_month, merchant_sort, data_month, txn_type_sort, state_sort