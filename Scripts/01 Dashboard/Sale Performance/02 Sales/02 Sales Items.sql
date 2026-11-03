WITH items_turtle AS (
	SELECT data_date
		, transaction_datetime
		, store_id
		, store_name
		, transaction_id
		, item_id::INT AS item_id
		, product_code
		, product_name AS product_name_th
		, item_name_foreign AS product_name_en
		, brand
		, INITCAP(group_name) AS product_group
		, INITCAP(dept_name) AS dept_name
		, INITCAP(class_name) AS class_name
		, INITCAP(subclass_name) AS subclass_name
		, quantity
		, unit_price
		, gross_amount
		, tax_amount
		, net_include_tax_amount
		, net_exclude_tax_amount
		, discount_item_amount_total
		, list_discount_item_name
		, list_discount_item_voucher
		, 'Super Turtle'::TEXT AS bu
        , 'Turtle X'::TEXT AS merchant
	FROM refined.fact_sales_item_turtle
	WHERE is_valid = TRUE
	ORDER BY data_date DESC, transaction_id, item_id::INT
)
, items_chefman AS (
	SELECT data_date
		, transaction_datetime
		, store_id
		, store_name
		, transaction_no AS transaction_id
		, item_id::INT AS item_id
		, product_code
		, product_name AS product_name_th
		, product_name_alt AS product_name_en
		, NULL::TEXT AS brand
		, INITCAP(product_category_foodbev) AS product_group
		, INITCAP(product_category_name) AS dept_name
		, NULL::TEXT AS class_name
		, NULL::TEXT AS subclass_name
		, quantity
		, unit_price
		, gross_amount
		, tax_amount
		, net_include_tax_amount
		, net_exclude_tax_amount
		, discount_item_amount_total
		, list_discount_item_name
		, list_discount_item_voucher
		, 'Chef Man'::TEXT AS bu
        , 'Chef Man'::TEXT AS merchant
	FROM refined.fact_sales_item_chefman
	WHERE is_valid = TRUE
)
, sales_items AS (
	SELECT * FROM items_turtle
	UNION ALL
	SELECT * FROM items_chefman
)
SELECT *
FROM sales_items