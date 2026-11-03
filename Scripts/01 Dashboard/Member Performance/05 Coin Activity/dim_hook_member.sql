SELECT member_id
	, register_datetime
	, DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', register_datetime)))::DATE AS register_month
	, member_status
	, member_type
    , CASE
        WHEN member_type = 'visitor' THEN 'Visitor'
        WHEN member_type = 'resident' AND member_house_type = 'Condominium' THEN 'Resident Condominium'
        WHEN member_type = 'resident' AND member_house_type = 'Housing' THEN 'Resident Housing'
        ELSE 'Resident Unidentified'
        END AS member_group
	, activated_wallet
	, activated_wallet_datetime
	, DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', activated_wallet_datetime)))::DATE AS activated_wallet_month
	, registration_source
	, is_staff
	, is_foreigner
	, nationality
	, gender
	, date_of_birth
	, member_house_type
	, register_hook_app
	, first_app_launch_datetime
	, DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', first_app_launch_datetime)))::DATE AS first_app_launch_month
FROM refined.dim_hook_member