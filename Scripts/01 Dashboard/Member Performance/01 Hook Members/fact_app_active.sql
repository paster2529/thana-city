WITH txn_launch_app AS (
    SELECT COALESCE(member_id, device_id) AS member_id
        , data_date
--        , COUNT(DISTINCT transaction_id) AS count_launch_app
        , TRUE::BOOLEAN AS is_launch_app
    FROM refined.fact_customer_engage_app
    WHERE data_date >= '2026-05-09'::DATE
        AND transaction_type = 'launch app'
    GROUP BY ALL
)
, txn_login AS (
    SELECT COALESCE(member_id, device_id) AS member_id
        , data_date
--        , COUNT(DISTINCT transaction_id) AS count_login
        , TRUE::BOOLEAN AS is_login
    FROM refined.fact_customer_engage_app
    WHERE data_date >= '2026-05-09'::DATE
        AND transaction_type = 'login'
    GROUP BY ALL
)
, txn_click AS (
    SELECT COALESCE(member_id, device_id) AS member_id
        , data_date
--        , COUNT(DISTINCT transaction_id) AS count_click
        , TRUE::BOOLEAN AS is_click
    FROM refined.fact_customer_engage_app
    WHERE data_date >= '2026-05-09'::DATE
        AND transaction_type = 'click'
    GROUP BY ALL
)
, txn_view_page AS (
    SELECT COALESCE(member_id, device_id) AS member_id
        , data_date
--        , COUNT(DISTINCT transaction_id) AS count_view_page
        , TRUE::BOOLEAN AS is_view_page
    FROM refined.fact_customer_engage_app
    WHERE data_date >= '2026-05-09'::DATE
        AND transaction_type = 'view page'
    GROUP BY ALL
)
, txn_activated_wallet AS (
    SELECT COALESCE(member_id, device_id) AS member_id
        , data_date
        , TRUE::BOOLEAN AS is_activated_wallet
    FROM refined.fact_customer_engage_app
    WHERE data_date >= '2026-05-09'::DATE
        AND transaction_type = 'active wallet'
    GROUP BY ALL
)
, txn_topup AS (
    SELECT COALESCE(member_id, device_id) AS member_id
        , data_date
--        , COUNT(DISTINCT transaction_id) AS count_topup
        , TRUE::BOOLEAN AS is_topup
    FROM refined.fact_customer_engage_app
    WHERE data_date >= '2026-05-09'::DATE
        AND transaction_type = 'topup'
    GROUP BY ALL
)
, txn_payment AS (
    SELECT COALESCE(member_id, device_id) AS member_id
        , data_date
--        , COUNT(DISTINCT transaction_id) AS count_payment
        , TRUE::BOOLEAN AS is_payment
    FROM refined.fact_customer_engage_app
    WHERE data_date >= '2026-05-09'::DATE
        AND transaction_type = 'payment'
    GROUP BY ALL
)
, txn_redeem_coupon AS (
    SELECT NVL(used_member_id, redeem_member_id) AS member_id
        , data_date
--        , count(distinct transaction_id) AS count_redeem_coupon
        , TRUE::BOOLEAN AS is_redeem_coupon
    FROM refined.fact_hook_coupon_redeem
    WHERE data_date >= '2026-05-09'::DATE
        AND (coupon_status = 'used' OR redeem_type = 'coin')
    GROUP BY ALL
)
, all_keys AS (
    SELECT member_id, data_date FROM txn_launch_app
    UNION
    SELECT member_id, data_date FROM txn_login
    UNION
    SELECT member_id, data_date FROM txn_click
    UNION
    SELECT member_id, data_date FROM txn_view_page
    UNION
    SELECT member_id, data_date FROM txn_activated_wallet
    UNION
    SELECT member_id, data_date FROM txn_topup
    UNION
    SELECT member_id, data_date FROM txn_payment
    UNION
    SELECT member_id, data_date FROM txn_redeem_coupon
)
, all_activity AS (
    SELECT k.data_date
    	, DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', k.data_date)))::DATE AS data_month
        , k.member_id
        , COALESCE(la.is_launch_app, FALSE) AS is_launch_app
        , COALESCE(li.is_login, FALSE) AS is_login
        , COALESCE(cl.is_click, FALSE) AS is_click
        , COALESCE(vp.is_view_page, FALSE) AS is_view_page
        , COALESCE(aw.is_activated_wallet, FALSE) AS is_activated_wallet
        , COALESCE(tu.is_topup, FALSE) AS is_topup
        , COALESCE(pm.is_payment, FALSE) AS is_payment
        , COALESCE(rc.is_redeem_coupon, FALSE) AS is_redeem_coupon
--        , COALESCE(la.count_launch_app, 0) AS count_launch_app
--        , COALESCE(li.count_login, 0) AS count_login
--        , COALESCE(cl.count_click, 0) AS count_click
--        , COALESCE(vp.count_view_page, 0) AS count_view_page
--        , COALESCE(tu.count_topup, 0) AS count_topup
--        , COALESCE(pm.count_payment, 0) AS count_payment
--        , COALESCE(rc.count_redeem_coupon, 0) AS count_redeem_coupon
    FROM all_keys k
    LEFT JOIN txn_launch_app la ON k.member_id = la.member_id AND k.data_date = la.data_date
    LEFT JOIN txn_login li ON k.member_id = li.member_id AND k.data_date = li.data_date
    LEFT JOIN txn_click cl ON k.member_id = cl.member_id AND k.data_date = cl.data_date
    LEFT JOIN txn_view_page vp ON k.member_id = vp.member_id AND k.data_date = vp.data_date
    LEFT JOIN txn_activated_wallet aw ON k.member_id = aw.member_id AND k.data_date = aw.data_date
    LEFT JOIN txn_topup tu ON k.member_id = tu.member_id AND k.data_date = tu.data_date
    LEFT JOIN txn_payment pm ON k.member_id = pm.member_id AND k.data_date = pm.data_date
    LEFT JOIN txn_redeem_coupon rc ON k.member_id = rc.member_id AND k.data_date = rc.data_date
    ORDER BY k.member_id, k.data_date
)
SELECT member_id AS "member id (02 app active 2)"
	, data_date AS "data date (02 app active 2)"
	, data_month AS "data month (02 app active 2)"
	, CASE WHEN 
		is_launch_app = TRUE 
		OR is_login = TRUE 
		OR is_click = TRUE 
		OR is_view_page = TRUE
		OR is_activated_wallet = TRUE 
		OR is_topup = TRUE 
		OR is_payment = TRUE 
		OR is_redeem_coupon THEN TRUE
		ELSE FALSE
		END AS is_app_active
FROM all_activity
WHERE LEN(member_id) = 8
GROUP BY ALL