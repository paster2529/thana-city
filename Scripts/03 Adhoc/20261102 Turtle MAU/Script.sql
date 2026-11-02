SELECT member_type
	, member_house_type
	, member_house_zone
	, count(DISTINCT member_id) 
FROM refined.dim_hook_member 
WHERE register_datetime <= '2026-10-31'
GROUP BY ALL
ORDER BY 1,2,3;

WITH rawdata AS (
	SELECT a.member_id
		, last_day(register_datetime) AS register_month
		, b.is_staff
		, INITCAP(b.member_type) AS member_type
		, b.member_house_type AS house_type
		, b.member_house_zone AS house_zone
		, last_day(data_date) AS data_month
		, CASE
			WHEN bu = 'Super Turtle' THEN 1
			ELSE 0
		END AS is_active_turtle
		, bu
		, bu_sort
		, sum(count_txn) AS cnt_txn
		, sum(paid_amount) AS paid_amount
		, sum(paid_coin) AS paid_coin
	FROM refined.v_fact_sales_all_bu a
	LEFT JOIN refined.dim_hook_member b ON a.member_id = b.member_id
	WHERE a.member_id IS NOT NULL AND data_date <= '2026-10-31'::DATE
	GROUP BY ALL
	ORDER BY a.member_id, data_month, is_active_turtle, bu_sort
)
SELECT count(DISTINCT member_id)
FROM rawdata