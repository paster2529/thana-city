SELECT data_date AS kpi_month
        , kpi_no
        , kpi_name
        , member_type
        , member_house_type
        , target
FROM trusted.ggsheets_kpi
WHERE kpi_no = 3