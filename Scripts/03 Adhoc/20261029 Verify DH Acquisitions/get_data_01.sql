SELECT *
FROM refined.dashaus_shopify_order_historical


	SELECT 
		CASE
			WHEN c.email IS NULL THEN FALSE
			ELSE TRUE
			END AS is_ex_dh
		, CASE
			WHEN first_app_launch_datetime IS NULL THEN FALSE
			ELSE TRUE
			END is_install_hook_app
		, register_hook_app
		, CASE
			WHEN a.member_id IS NULL THEN FALSE
			ELSE TRUE
			END is_register
		, activated_wallet
		, a.is_staff
		, NVL(c.email, b.email) AS email
		, a.member_id
		, LAST_DAY(a.register_datetime) AS register_month
		, LAST_DAY(a.activated_wallet_datetime) AS activated_wallet_month
		, referred_staff_id
		, a.registration_source
		, a.member_status
		, a.member_type
		, a.member_house_type
		, a.member_house_zone
		, a.gender
		, CASE
			WHEN a.date_of_birth IS NULL THEN 'Unknown'
			WHEN datediff(year, a.date_of_birth, current_date) < 16 THEN '<16'
			WHEN datediff(year, a.date_of_birth, current_date) BETWEEN 16 AND 25 THEN '16-25'
			WHEN datediff(year, a.date_of_birth, current_date) BETWEEN 26 AND 35 THEN '26-35'
			WHEN datediff(year, a.date_of_birth, current_date) BETWEEN 36 AND 45 THEN '36-45'
			WHEN datediff(year, a.date_of_birth, current_date) BETWEEN 46 AND 55 THEN '46-55'
			WHEN datediff(year, a.date_of_birth, current_date) >= 56 THEN '56+'
			ELSE 'Invalid'
			END AS age_range
	FROM refined.dim_hook_member a
	LEFT JOIN "trusted".hook_master_customers b ON a.member_uuid = b.id
	FULL OUTER JOIN refined.dashaus_shopify_order_historical c ON LOWER(b.email) = LOWER(c.email)