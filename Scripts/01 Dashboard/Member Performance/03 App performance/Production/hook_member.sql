SELECT is_staff
	, CASE
		WHEN member_status ='active' THEN TRUE
		ELSE FALSE
	END is_status_active
	, INITCAP(member_type) AS member_type
	, last_day(register_datetime) AS registered_month
	, last_day(activated_wallet_datetime) AS activated_wallet_month
	, count(DISTINCT member_id) AS members
FROM refined.dim_hook_member
GROUP BY ALL