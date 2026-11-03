WITH dim_date AS (
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
    SELECT DISTINCT registration_source
    FROM refined.dim_hook_member
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
, hook_member AS (
	SELECT *
		, CASE
			WHEN member_type = 'visitor' THEN 'Visitor'
			WHEN member_type = 'resident' AND member_house_type = 'Condominium' THEN 'Resident Condominium'
			WHEN member_type = 'resident' AND member_house_type = 'Housing' THEN 'Resident Housing'
			ELSE 'Resident Unidentified'
			END AS member_group
	FROM refined.dim_hook_member
)
, final_data AS (
	SELECT a.member_id
		, a.register_datetime
		, LAST_DAY(NVL(a.register_datetime, b.full_date)) AS register_month
		, a.member_status
		, a.member_type
		, COALESCE(COALESCE(a.member_group, b.member_group), c.member_group) AS member_group
		, a.activated_wallet
		, a.activated_wallet_datetime
		, TRUNC(a.activated_wallet_datetime) AS activated_wallet_date
--		, DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', COALESCE(a.activated_wallet_datetime, c.full_date))))::DATE AS activated_wallet_month
		, LAST_DAY(NVL(a.activated_wallet_datetime, c.full_date)) AS activated_wallet_month
		, COALESCE(COALESCE(a.registration_source, b.registration_source), c.registration_source) AS registration_source
		, a.is_staff
		, a.is_foreigner
		, a.nationality
		, a.gender
		, a.date_of_birth
		, a.member_house_type
		, a.register_hook_app
		, a.first_app_launch_datetime
--		, DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', a.first_app_launch_datetime)))::DATE AS first_app_launch_month
		, LAST_DAY(a.first_app_launch_datetime) AS first_app_launch_month
		, b.full_date AS kpi_1_date
		, LAST_DAY(b.full_date) AS kpi_1_month
		, c.full_date AS kpi_2_date
		, LAST_DAY(c.full_date) AS kpi_2_month
		, b.weekday_flag
		, b.fiscal_year
	FROM hook_member a
	FULL OUTER JOIN date_group_scaffold b ON a.register_datetime::DATE = b.full_date
		AND a.member_group = b.member_group
		AND a.registration_source = b.registration_source
	FULL OUTER JOIN date_group_scaffold c ON a.activated_wallet_datetime::DATE = c.full_date
		AND a.member_group = c.member_group
		AND a.registration_source = c.registration_source
)
SELECT *
FROM final_data