WITH hook_members AS (
    SELECT member_id
        , CASE 
            WHEN register_datetime < '2026-05-09'::DATE THEN DATEADD('day', 1, register_datetime)::DATE
            ELSE register_datetime::DATE
            END AS register_date
        , registration_source
        , member_type
        , member_house_type
        , member_status
        , is_staff
        , NVL(INITCAP(gender), 'Unknown') AS gender
        , is_foreigner AS is_thai
        , date_of_birth
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
    FROM refined.dim_hook_member
    --WHERE member_status = 'active'
)
, sales_turtle AS (
    SELECT data_date
        , transaction_datetime
        , 'Super Turtle'::TEXT AS bu
        , 'Turtle X'::TEXT AS merchant
        , transaction_id
        , transaction_type
        , is_valid
        , COALESCE(member_id_coin, member_id_pos) AS member_id
        , total_gross_amount -- Gross Amount all line items
		, total_discount_item_amount -- Discount Items all line items
		, total_discount_txn_amount -- Total Bill discount (ส่วนลดท้ายบิล)
		, total_discount_amount -- total_discount_item_amount + total_discount_txn_amount
		, total_net_include_tax_amount
        , paid_amount
        , paid_cash_amount
        , paid_qr_amount
        , paid_card_amount
        , paid_coin_amount
        , paid_coupon_amount
        , paid_linepay_amount
        , paid_wechat_amount
        , paid_alipay_amount
        , paid_rabbitcard_amount
        , paid_others_amount
        , paid_coin
        , paid_coin_cash
        , paid_coin_incentive
        , coin_payment_portion
        , items_count
        , items_discount_items_count
        , payments_count
        , is_delivery
        , is_cod
        , NULL::TEXT AS table_type
        , NULL::INT AS num_of_customer
    FROM refined.fact_sales_txn_turtle
    WHERE is_valid = TRUE
)
, sales_merchant_app AS (
    SELECT data_date
        , transaction_datetime
        , bu
        , merchant
        , transaction_no AS transaction_id
        , transaction_type
        , is_valid
        , COALESCE(member_id_coin, member_id_pos, member_id_reward) AS member_id
        , total_gross_amount -- Gross Amount all line items
		, NULL::FLOAT AS total_discount_item_amount -- Discount Items all line items
		, NULL::FLOAT AS total_discount_txn_amount -- Total Bill discount (ส่วนลดท้ายบิล)
		, NULL::FLOAT AS total_discount_amount -- total_discount_item_amount + total_discount_txn_amount
		, NULL::FLOAT AS total_net_include_tax_amount
        , paid_amount
        , paid_cash_amount
        , paid_qr_amount
        , paid_card_amount
        , paid_coin_amount
        , paid_coupon_amount
        , paid_linepay_amount
        , paid_wechat_amount
        , paid_alipay_amount
        , paid_rabbitcard_amount
        , paid_others_amount
        , paid_coin
        , paid_coin_cash
        , paid_coin_incentive
        , coin_payment_portion
        , NULL::INT AS items_count
        , NULL::INT AS items_discount_items_count
        , payments_count
        , NULL::BOOLEAN AS is_delivery
        , NULL::BOOLEAN AS is_cod
        , NULL::TEXT AS table_type
        , NULL::INT AS num_of_customer
    FROM refined.fact_sales_txn_bss_merchant
    WHERE is_valid = TRUE
)
, sales_chefman AS (
    SELECT data_date
        , transaction_datetime
        , 'Chef Man'::TEXT AS bu
        , 'Chef Man'::TEXT AS merchant
        , transaction_no AS transaction_id
        , transaction_type
        , is_valid
        , COALESCE(member_id_coin, member_id_pos, member_id_reward) AS member_id
        , total_gross_amount -- Gross Amount all line items
		, total_discount_item_amount -- Discount Items all line items
		, total_discount_txn_amount -- Total Bill discount (ส่วนลดท้ายบิล)
		, total_discount_amount -- total_discount_item_amount + total_discount_txn_amount
		, total_net_include_tax_amount
        , paid_amount
        , paid_cash_amount
        , paid_qr_amount
        , paid_card_amount
        , paid_coin_amount
        , paid_coupon_amount
        , paid_linepay_amount
        , paid_wechat_amount
        , paid_alipay_amount
        , paid_rabbitcard_amount
        , paid_others_amount
        , paid_coin
        , paid_coin_cash
        , paid_coin_incentive
        , coin_payment_portion
        , items_count
        , items_discount_items_count
        , payments_count
        , NULL::BOOLEAN AS is_delivery
        , NULL::BOOLEAN AS is_cod
        , CASE
        	WHEN table_id LIKE 'Take Home%' THEN 'Take Home'
        	WHEN table_id LIKE 'VIP%' THEN 'VIP'
        	ELSE 'Normal'
        	END AS table_type
        , numofcustomer AS num_of_customer
    FROM refined.fact_sales_txn_chefman
    WHERE is_valid = TRUE
)
, sales_union AS (
    SELECT * FROM sales_turtle
    UNION ALL
    SELECT * FROM sales_merchant_app
    UNION ALL
    SELECT * FROM sales_chefman
)
, joined_member AS (
    SELECT a.*
        , b.register_date
        , b.registration_source
        , b.member_type
        , b.member_house_type
        , b.member_status
        , NVL(b.is_staff, FALSE) AS is_staff
        , b.gender
        , b.is_thai
        , b.age_range
    FROM sales_union a
    LEFT JOIN hook_members b ON a.member_id = b.member_id
)
SELECT data_date AS "data date"
    , LAST_DAY(data_date) AS "data month"
    , transaction_datetime AS "transaction datetime"
    , bu AS "bu"
    , merchant AS "merchant"
    , transaction_id AS "transaction id"
    , transaction_type AS "transaction type"
    , is_valid AS "is valid"
    , member_id AS "member id"
    , paid_amount AS "paid amount"
    , paid_cash_amount AS "paid cash amount"
    , paid_qr_amount AS "paid qr amount"
    , paid_card_amount AS "paid card amount"
    , paid_coin_amount AS "paid coin amount"
    , paid_coupon_amount AS "paid coupon amount"
    , paid_linepay_amount AS "paid linepay amount"
    , paid_wechat_amount AS "paid wechat amount"
    , paid_alipay_amount AS "paid alipay amount"
    , paid_rabbitcard_amount AS "paid rabbitcard amount"
    , paid_others_amount AS "paid others amount"
    , paid_coin AS "paid coin"
    , paid_coin_cash AS "paid coin cash"
    , paid_coin_incentive AS "paid coin incentive"
    , coin_payment_portion AS "coin payment portion"
    , is_delivery AS "is delivery"
    , is_cod AS "is cod"
    , total_gross_amount AS "total gross amount"
    , total_discount_item_amount AS "total discount item amount"
    , total_discount_txn_amount AS "total discount txn amount"
    , total_discount_amount AS "total discount amount"
    , total_net_include_tax_amount AS "total net include tax amount"
    , items_count AS "items count"
    , items_discount_items_count AS "items discount items count"
    , payments_count AS "payments count"
    , table_type AS "table type"
    , num_of_customer AS "num of customer"
    , register_date AS "register date"
    , registration_source AS "registration source"
    , member_type AS "member type"
    , member_house_type AS "member house type"
    , member_status AS "member status"
    , is_staff AS "is staff"
    , gender AS "gender"
    , is_thai AS "is thai"
    , age_range AS "age range"
FROM joined_member
WHERE LOWER(bu) <> 'bu test'