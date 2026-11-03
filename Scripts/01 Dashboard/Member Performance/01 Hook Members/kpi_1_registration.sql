WITH dim_date AS (
	SELECT full_date
		, DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', full_date)))::DATE AS eo_month
		, weekday_flag
		, fiscal_year
	FROM refined.dim_date
	WHERE full_date >= '2026-05-08'::DATE 
		AND fiscal_year <= CASE WHEN EXTRACT(MONTH FROM SYSDATE) <= 3 THEN EXTRACT(YEAR FROM SYSDATE) - 1  ELSE EXTRACT(YEAR FROM SYSDATE) END
)
, kpi_base AS (
	SELECT *, kpi_no::INT AS kpi_no_int FROM trusted.ggsheets_kpi WHERE kpi_no <= 6
)
, kpi_dim AS (
	SELECT DISTINCT kpi_no_int AS kpi_no
		, kpi_name
		, member_type
		, member_house_type
		, bu
		, merchant
		, unit
	FROM kpi_base
)
, kpi_data AS (
	SELECT a.full_date
		, a.eo_month
		, a.weekday_flag
		, a.fiscal_year
		, b.data_date AS kpi_month
		, d.kpi_no
		, d.kpi_name
		, d.member_type
		, d.member_house_type
		, CASE
	        WHEN d.member_type = 'Visitors' THEN 'Visitor'
	        WHEN d.member_type = 'Resident' AND d.member_house_type = 'Condo' THEN 'Resident Condominium'
	        WHEN d.member_type = 'Resident' AND d.member_house_type = 'Housing' THEN 'Resident Housing'
	        END AS member_group
	    , d.bu
	    , d.merchant
	    , b.target AS kpi_target
	    , d.unit
	FROM dim_date a
	CROSS JOIN kpi_dim d
	LEFT JOIN kpi_base b
		ON a.full_date = b.data_date
		AND d.kpi_no = b.kpi_no_int
		AND d.member_type = b.member_type
		AND COALESCE(d.member_house_type, '') = COALESCE(b.member_house_type, '')
		AND COALESCE(d.bu, '') = COALESCE(b.bu, '')
		AND COALESCE(d.merchant, '') = COALESCE(b.merchant, '')
)
, union_all AS (
	SELECT * FROM kpi_data
	UNION ALL
	SELECT full_date
		, eo_month
		, weekday_flag
		, fiscal_year
		, kpi_month
		, kpi_no
	    , kpi_name
	    , 'Resident' AS member_type
	    , NULL AS member_house_type
	    , 'Resident Unidentified' AS member_group
	    , bu
	    , merchant
	    , 0 AS kpi_target
	    , unit
	FROM kpi_data
	WHERE member_type = 'Resident' AND member_house_type = 'Condo'
)
, kpi_filtered AS (
	SELECT full_date AS "full date (KPI 1 Registered)"
	--    , eo_month AS "eo month (KPI 1 Registered)"
	--    , weekday_flag AS "weekday flag (KPI 1 Registered)"
	    , fiscal_year AS "fiscal year (KPI 1 Registered)"
	--    , kpi_month AS "kpi month (KPI 1 Registered)"
	--    , kpi_no AS "kpi no (KPI 1 Registered)"
	    , kpi_name AS "kpi name (KPI 1 Registered)"
	    , member_type AS "member type (KPI 1 Registered)"
	--    , member_house_type AS "member house type (KPI 1 Registered)"
	    , member_group AS "member group (KPI 1 Registered)"
--	    , bu AS "bu (KPI 1 Registered)"
--	    , merchant AS "merchant (KPI 1 Registered)"
	    , kpi_target AS "kpi target (KPI 1 Registered)"
--	    , unit AS "unit (KPI 1 Registered)"
	    , FALSE AS "is_staff (KPI 1 Registered)"
	FROM union_all
	WHERE kpi_no = 1
)
SELECT *
FROM kpi_filtered