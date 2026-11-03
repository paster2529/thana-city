SELECT TRUNC(DATE_TRUNC('day', event_datetime)) AS event_date
	, 'COIN_TOPUP' AS eventname
	, eventprops_status AS status
	, eventprops_fail_reason AS fail_reason
	, COUNT(*) AS event_count
FROM trusted.clevertap_coin_topup
GROUP BY ALL
UNION ALL
SELECT TRUNC(DATE_TRUNC('day', event_datetime)) AS event_date
	, 'WEBHOOK_COIN_ISSUED' AS eventname
	, eventprops_status AS status
	, NULL::TEXT AS fail_reason
	, COUNT(*) AS event_count
FROM trusted.clevertap_webhook_coin_issued
GROUP BY ALL
UNION ALL
SELECT TRUNC(DATE_TRUNC('day', event_datetime)) AS event_date
	, 'WEBHOOK_REWARD_PUSH' AS eventname
	, eventprops_status AS status
	, eventprops_fail_reason AS fail_reason
	, COUNT(*) AS event_count
FROM trusted.clevertap_webhook_reward_push
GROUP BY ALL
ORDER BY 1,2,3;