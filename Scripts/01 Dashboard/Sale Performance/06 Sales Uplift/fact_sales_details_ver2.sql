WITH bu_config AS (              -- BU ที่ v_fact มี txn ครบ (member + non-member) และวันที่เริ่มมีข้อมูลครบ
    SELECT 'Super Turtle' AS bu
        , DATE '2026-05-09' AS full_txn_start
    UNION ALL
    SELECT 'Chef Man' AS bu
        , DATE '2026-08-06' AS full_txn_start
)
, member_detail AS (             -- (1) member: มี profile
    SELECT f.data_date
        , f.bu_sort::INT AS bu_sort
        , f.bu
        , 'Member' AS customer_type
        , f.member_id
        , m.member_status
        , m.activated_wallet::BOOLEAN
        , m.is_staff::BOOLEAN
        , m.is_foreigner::BOOLEAN AS is_thai
        , m.register_hook_app::BOOLEAN
        , NVL(INITCAP(m.gender), 'Unknown') AS gender
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
        , CASE
            WHEN member_type = 'visitor' THEN 'Visitor'
            WHEN member_type = 'resident' AND member_house_type = 'Condominium' THEN 'Resident Condominium'
            WHEN member_type = 'resident' AND member_house_type = 'Housing' THEN 'Resident Housing'
            WHEN member_type = 'resident' AND member_house_type IS NULL THEN 'Resident Unidentified'
            END AS member_group
        , member_type
        , INITCAP(REPLACE(REPLACE(m.registration_source, 'QR_' ,'') ,'_' ,' ')) AS registration_source
        , f.n_transactions
        , f.sales
    FROM (
            SELECT data_date
                , bu_sort::INT AS bu_sort
                , bu
                , member_id
                , SUM(count_txn) AS n_transactions
                , SUM(paid_amount) AS sales
            FROM refined.v_fact_sales_all_bu
            WHERE data_date >= DATE '2026-05-09'
                AND member_id IS NOT NULL
            GROUP BY ALL
    ) f
    LEFT JOIN refined.dim_hook_member m ON f.member_id = m.member_id
)
, nonmember_vfact AS (           -- (2) non-member BU ใน bu_config: มีจริงใน v_fact (นับตั้งแต่ full_txn_start ของแต่ละ BU)
    SELECT f.data_date
        , f.bu_sort::INT AS bu_sort
        , f.bu
        , 'Non-member' AS customer_type
        , NULL::VARCHAR AS member_id
        , NULL::VARCHAR AS member_status
        , NULL::BOOLEAN AS activated_wallet
        , NULL::BOOLEAN AS is_staff
        , NULL::BOOLEAN AS is_thai
        , NULL::BOOLEAN AS register_hook_app
        , NULL::VARCHAR AS gender
        , NULL::VARCHAR AS age_range
        , NULL::VARCHAR AS member_group
        , NULL::VARCHAR AS member_type
        , NULL::VARCHAR AS registration_source
        , SUM(f.count_txn) AS n_transactions
        , SUM(f.paid_amount) AS sales
    FROM refined.v_fact_sales_all_bu f
    JOIN bu_config c ON f.bu = c.bu 
        AND f.data_date >= c.full_txn_start
    WHERE f.member_id IS NULL
    GROUP BY ALL
)
, gg AS (                        -- ยอดรวมจริงต่อ bu-date (normalize ชื่อ bu)
    SELECT data_date
        , b.bu_sort::INT AS bu_sort
        , a.bu_report_ref AS bu
        , SUM(sale) AS gg_total
    FROM (
            SELECT data_date
                , CASE
                    WHEN bu = 'GOLF' OR category IN ('Golf Course', 'Golf Kiosk', 'SHARK BITE', 'Splash') THEN 'Thana City Country Club'
                    WHEN bu = 'SPORT' THEN 'Thana City Sports Club'
                    WHEN bu = 'F5 DRIVING RANGE' THEN 'Thana City Driving Range'
                    WHEN bu = 'Turtle-X' THEN 'Super Turtle'
                    WHEN bu = 'HOTEL' THEN 'Eastin Thana City'
                    WHEN bu = 'CHEFMAN' THEN 'Chef Man'
                    WHEN bu = 'EVENT' THEN 'Non-BU'
                    -- TODO: ถ้าชื่อ bu_C ใน ggsheets ไม่ตรงกับ v_fact ให้เพิ่ม mapping ตรงนี้
                    ELSE bu
                    END AS bu_report_ref
                , sale
            FROM "trusted".ggsheets_sales
    ) a
    LEFT JOIN (SELECT DISTINCT bu_sort, bu_report_ref FROM "trusted".ggsheets_setup_merchant_bu_mapping) b ON a.bu_report_ref = b.bu_report_ref
    WHERE data_date >= DATE '2025-04-01'
    GROUP BY ALL
)
, vf_member_bu AS (              -- member sales ต่อ bu-date (ไว้ลบออกจาก ggsheets)
    SELECT data_date
        , bu_sort
        , bu
        , SUM(paid_amount) AS vf_member
    FROM refined.v_fact_sales_all_bu
    WHERE data_date >= DATE '2026-05-09'
        AND member_id IS NOT NULL
    GROUP BY ALL
)
, nonmember_other AS (           -- (3) non-member BU อื่น: ggsheets - member (รวม BU ใน bu_config ช่วงก่อน full_txn_start)
    SELECT g.data_date
        , g.bu_sort::INT
        , g.bu
        , 'Non-member' AS customer_type
        , NULL::VARCHAR AS member_id
        , NULL::VARCHAR AS member_status
        , NULL::BOOLEAN AS activated_wallet
        , NULL::BOOLEAN AS is_staff
        , NULL::BOOLEAN AS is_thai
        , NULL::BOOLEAN AS register_hook_app
        , NULL::VARCHAR AS gender
        , NULL::VARCHAR AS age_range
        , NULL::VARCHAR AS member_group
        , NULL::VARCHAR AS member_type
        , NULL::VARCHAR AS registration_source
        , NULL::BIGINT AS n_transactions      -- ไม่ทราบจำนวน txn ของ non-member
        , g.gg_total - COALESCE(v.vf_member, 0) AS sales
    FROM gg g
    LEFT JOIN vf_member_bu v ON g.bu = v.bu AND g.data_date = v.data_date
    LEFT JOIN bu_config c ON g.bu = c.bu
    WHERE g.data_date >= DATE '2026-05-09'
        AND (c.bu IS NULL OR g.data_date < c.full_txn_start)
)
, nonmember_early AS (
-- (4) ก่อน 2026-05-09 (ตั้งแต่ 2025-04-01): v_fact ไม่มีข้อมูลเลย ถือว่ายอด ggsheets ทั้งหมดเป็น Non-member (ทุก bu รวม Super Turtle)
    SELECT data_date
        , bu_sort::INT
        , bu
        , 'Non-member' AS customer_type
        , NULL::VARCHAR AS member_id
        , NULL::VARCHAR AS member_status
        , NULL::BOOLEAN AS activated_wallet
        , NULL::BOOLEAN AS is_staff
        , NULL::BOOLEAN AS is_thai
        , NULL::BOOLEAN AS register_hook_app
        , NULL::VARCHAR AS gender
        , NULL::VARCHAR AS age_range
        , NULL::VARCHAR AS member_group
        , NULL::VARCHAR AS member_type
        , NULL::VARCHAR AS registration_source
        , NULL::BIGINT AS n_transactions      -- ไม่ทราบจำนวน txn ของ non-member
        , gg_total AS sales
    FROM gg
    WHERE data_date < DATE '2026-05-09'
)
SELECT * FROM member_detail
UNION ALL
SELECT * FROM nonmember_vfact
UNION ALL
SELECT * FROM nonmember_other
UNION ALL
SELECT * FROM nonmember_early