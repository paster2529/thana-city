SELECT data_date
	, DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', data_date)))::DATE AS data_month
    , COALESCE(member_id, device_id) AS member_id
    , transaction_id
    , transaction_type
    , transaction_subtype
    , utm_source
    , utm_media
    , utm_campaign
    , TRUE::BOOLEAN AS is_download
FROM refined.fact_customer_engage_app
WHERE data_date >= '2026-05-09'::DATE
    AND transaction_type = 'installed app'
GROUP BY ALL



--------------------------------------------------
------------------------------------- For Tableau
--------------------------------------------------
SELECT data_date AS "data_date (01 install hook app)"
	, DATEADD('day', -1, DATEADD('month', 1, date_trunc('month', data_date)))::DATE AS "data month (01 install hook app)"
    , COALESCE(member_id, device_id) AS "member id (01 install hook app)"
    , transaction_id AS "transaction id (01 install hook app)"
    , transaction_type AS "transaction type (01 install hook app)"
    , transaction_subtype AS "transaction subtype (01 install hook app)"
    , utm_source AS "utm source (01 install hook app)"
    , utm_media AS "utm media (01 install hook app)"
    , utm_campaign AS "utm campaign (01 install hook app)"
    , TRUE::BOOLEAN AS "is download (01 install hook app)"
FROM refined.fact_customer_engage_app
WHERE data_date >= '2026-05-09'::DATE
    AND transaction_type = 'installed app'
GROUP BY ALL