SELECT DISTINCT bu_sort
	, merchant_sort
	, bu_report_ref
	, merchant_report_ref
FROM "trusted".ggsheets_setup_merchant_bu_mapping
ORDER BY merchant_sort