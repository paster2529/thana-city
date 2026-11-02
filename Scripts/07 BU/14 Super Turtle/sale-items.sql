SELECT DISTINCT product_code
	, CASE WHEN b.item_status IS NULL THEN FALSE ELSE TRUE END AS is_in_master
	, NVL(b.barcode, c.barcode) AS barcode
	, NVL(b.item_status, c.item_status) AS item_status
	, c.item_status AS item_statuc_c
	, product_name
	, NVL(a.item_name_foreign, b.item_name_foreign, c.item_name_foreign) AS item_name_foreign
	, NVL(a.brand, b.brand, c.brand) AS brans
	, NVL(a.group_name, b.group_name, c.group_name) AS group_name
	, NVL(a.dept_name, b.dept_name, c.dept_name) AS dept_name
	, NVL(a.class_name, b.class_name, c.class_name) AS class_name
	, NVL(a.subclass_name, b.subclass_name, c.subclass_name) AS subclass_name
FROM refined.fact_sales_item_turtle a
LEFT JOIN "trusted".pos_turtle_master_product b ON a.product_code = b.item_no
LEFT JOIN "trusted".pos_turtle_master_product c ON LEFT(a.product_code, 9) = c.item_no
ORDER BY 2,1