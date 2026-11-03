SELECT full_date
	, day_key
	, weekday_flag
	, week_begin_date
	, fiscal_year
	, fiscal_quarter
	, fiscal_month
	, same_day_year_ago_date
	, same_day_year_ago_day_key
FROM refined.dim_date
WHERE full_date >= '2026-05-08'::DATE 
        AND fiscal_year <= 
            CASE
                WHEN EXTRACT(MONTH FROM SYSDATE) <= 3 THEN EXTRACT(YEAR FROM SYSDATE) - 1 
                ELSE EXTRACT(YEAR FROM SYSDATE)
            END
;