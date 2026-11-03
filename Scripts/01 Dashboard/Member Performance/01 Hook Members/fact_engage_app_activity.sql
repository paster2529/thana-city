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
, joined_member AS (
    SELECT a.*
        , b.registration_source
        , CASE
            WHEN member_type = 'visitor' THEN 'Visitor'
            WHEN member_type = 'resident' AND member_house_type = 'Condominium' THEN 'Resident Condominium'
            WHEN member_type = 'resident' AND member_house_type = 'Housing' THEN 'Resident Housing'
            ELSE 'Resident Unidentified'
            END AS member_group
    FROM all_activity a
    INNER JOIN refined.dim_hook_member b ON a.member_id = b.member_id
    WHERE b.member_status = 'active'
)
, dim_date AS (
	SELECT full_date
		, weekday_flag
		, fiscal_year
	FROM refined.dim_date
	WHERE full_date >= '2026-05-08'::DATE
		AND fiscal_year <= CASE WHEN EXTRACT(MONTH FROM SYSDATE) <= 3 THEN EXTRACT(YEAR FROM SYSDATE) - 1  ELSE EXTRACT(YEAR FROM SYSDATE) END
)
, member_group_list AS (
    SELECT 'Visitor' AS member_group
    UNION ALL SELECT 'Resident Condominium'
    UNION ALL SELECT 'Resident Housing'
    UNION ALL SELECT 'Resident Unidentified'
)
, registration_source_list AS (
    SELECT 'APP' AS registration_source
    UNION ALL SELECT 'QR_COMMON'
    UNION ALL SELECT 'QR_DRIVING_RANGE'
    UNION ALL SELECT 'ADMIN'
    UNION ALL SELECT 'WEB'
    UNION ALL SELECT 'QR_EVENT'
    UNION ALL SELECT 'QR_DAS_HAUS'
    UNION ALL SELECT 'QR_TURTLE_SHOP'
    UNION ALL SELECT 'QR_SHARK_BITE'
    UNION ALL SELECT 'QR_GOLF_CLUB'
    UNION ALL SELECT 'QR_SPORT_CLUB'
    UNION ALL SELECT 'QR_EASTIN'
    UNION ALL SELECT 'QR_HOOK EVENT'
    UNION ALL SELECT 'QR_SPLASH'
)
, date_group_scaffold AS (
    SELECT d.full_date
        , d.weekday_flag
        , d.fiscal_year
        , g.member_group
        , r.registration_source
    FROM dim_date d
    CROSS JOIN member_group_list g
    CROSS JOIN registration_source_list r
)
, final_data AS (
	SELECT a.data_date
	    , a.data_month
	    , a.member_id
	    , COALESCE(a.member_group, b.member_group) AS member_group
	    , COALESCE(a.registration_source, b.registration_source) AS registration_source
	    , a.is_launch_app
	    , a.is_login
	    , a.is_click
	    , a.is_view_page
	    , a.is_activated_wallet
	    , a.is_topup
	    , a.is_payment
	    , a.is_redeem_coupon
	    , b.full_date
	    , b.weekday_flag
	    , b.fiscal_year
	FROM joined_member a
	FULL OUTER JOIN date_group_scaffold b
	    ON a.data_date = b.full_date
	    AND a.member_group = b.member_group
	    AND a.registration_source = b.registration_source
)
SELECT data_date AS "data date (02 app active)"
    , data_month AS "data month (02 app active)"
    , member_id AS "member id (02 app active)"
    , member_group AS "member group (02 app active)"
    , registration_source AS "registration source (02 app active)"
    , is_launch_app AS "is launch app (02 app active)"
    , is_login AS "is login (02 app active)"
    , is_click AS "is click (02 app active)"
    , is_view_page AS "is view page (02 app active)"
    , is_activated_wallet AS "is activated wallet (02 app active)"
    , is_topup AS "is topup (02 app active)"
    , is_payment AS "is payment (02 app active)"
    , is_redeem_coupon AS "is redeem coupon (02 app active)"
    , full_date AS "full date (02 app active)"
    , weekday_flag AS "weekday flag (02 app active)"
    , fiscal_year AS "fiscal year (02 app active)"
FROM final_data