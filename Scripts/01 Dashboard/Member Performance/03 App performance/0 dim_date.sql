SELECT full_date
        , last_day(full_date) AS dim_month
	, weekday_flag
	, fiscal_year
	, fiscal_month
	, last_day_in_month_flag
FROM refined.dim_date
WHERE fiscal_year >= 2026