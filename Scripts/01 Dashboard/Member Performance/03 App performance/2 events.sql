WITH evt_app_launched AS (
    SELECT NVL(profile_identity, profile_push_token) AS profile_identity
        , CASE WHEN profile_identity IS NULL THEN FALSE ELSE TRUE END AS is_member
        , event_datetime
        , INITCAP(REPLACE(eventname, '_', ' ')) AS eventname
    FROM "trusted".clevertap_app_launched
    ORDER BY 1,2
)
, evt_register AS (
    SELECT member_id AS profile_identity
        , TRUE::BOOLEAN AS is_member
        , register_datetime AS event_datetime
        , 'Registered' AS eventname
    FROM refined.dim_hook_member
	WHERE member_status = 'active'
)
, evt_view AS (
    SELECT NVL(profile_identity, profile_push_token) AS profile_identity
        , CASE WHEN profile_identity IS NULL THEN FALSE ELSE TRUE END AS is_member
        , event_datetime
        , INITCAP(REPLACE(eventname, '_', ' ')) AS eventname
    FROM "trusted".clevertap_view
    ORDER BY 1,2
)
, evt_click AS (
    SELECT NVL(profile_identity, profile_push_token) AS profile_identity
        , CASE WHEN profile_identity IS NULL THEN FALSE ELSE TRUE END AS is_member
        , event_datetime
        , INITCAP(REPLACE(eventname, '_', ' ')) AS eventname
    FROM "trusted".clevertap_click
    ORDER BY 1,2
)
, evt_login AS (
    SELECT NVL(profile_identity, profile_push_token) AS profile_identity
        , CASE WHEN profile_identity IS NULL THEN FALSE ELSE TRUE END AS is_member
        , event_datetime
        , INITCAP(REPLACE(eventname, '_', ' ')) AS eventname
    FROM "trusted".clevertap_login
    ORDER BY 1,2
)
, evt_notification_viewed AS (
    SELECT NVL(profile_identity, profile_push_token) AS profile_identity
        , CASE WHEN profile_identity IS NULL THEN FALSE ELSE TRUE END AS is_member
        , event_datetime
        , INITCAP(REPLACE(eventname, '_', ' ')) AS eventname
    FROM "trusted".clevertap_notification_viewed
    ORDER BY 1,2
)
, evt_activated_wallet AS (
    SELECT member_id AS profile_identity
        , TRUE::BOOLEAN AS is_member
        , activated_wallet_datetime AS event_datetime
        , 'Activated Wallet' AS eventname
    FROM refined.dim_hook_member
	WHERE activated_wallet = TRUE 
		AND member_status = 'active'
)
, evt_topup AS (
    SELECT member_id AS profile_identity
        , TRUE::BOOLEAN AS is_member
        , transaction_datetime AS event_datetime
        , 'Coin Topup' AS eventname
    FROM refined.fact_hook_coin_issue
    WHERE transaction_status = 'confirmed'
    	AND transaction_type = 'topup'
)
, evt_payment AS (
    SELECT member_id AS profile_identity
        , CASE WHEN member_id IS NULL THEN FALSE ELSE TRUE END AS is_member
        , transaction_datetime AS event_datetime
        , 'Payment' AS eventname
    FROM (
        SELECT transaction_datetime
            , transaction_id
            , NVL(member_id_coin, member_id_pos) AS member_id
        FROM refined.fact_sales_txn_turtle
        WHERE is_valid = TRUE
        UNION ALL
        SELECT transaction_datetime
            , transaction_no AS transaction_id
            , NVL(member_id_coin, member_id_reward, member_id_pos) AS member_id
        FROM refined.fact_sales_txn_bss_merchant
        WHERE is_valid = TRUE
    )
)
, evt_redeem AS (
    SELECT NVL(used_member_id, redeem_member_id) AS profile_identity
        , CASE WHEN NVL(used_member_id, redeem_member_id) IS NULL THEN FALSE ELSE TRUE END AS is_member
        , NVL(used_datetime, redeem_datetime) AS event_datetime
        , 'Redemption' AS eventname
    FROM refined.fact_hook_coupon_redeem
    WHERE (coupon_status = 'used' OR redeem_type = 'coin')
    GROUP BY ALL
)
, evt_gate_in AS (
    SELECT NVL(profile_identity, profile_push_token) AS profile_identity
        , CASE WHEN profile_identity IS NULL THEN FALSE ELSE TRUE END AS is_member
        , event_datetime
        , INITCAP(REPLACE(eventname, '_', ' ')) AS eventname
    FROM "trusted".clevertap_gate_in
    WHERE eventprops_access_method = 'QR'
    ORDER BY 1,2
)
, evt_gate_out AS (
    SELECT NVL(profile_identity, profile_push_token) AS profile_identity
        , CASE WHEN profile_identity IS NULL THEN FALSE ELSE TRUE END AS is_member
        , event_datetime
        , INITCAP(REPLACE(eventname, '_', ' ')) AS eventname
    FROM "trusted".clevertap_gate_out
    WHERE eventprops_access_method = 'QR'
    ORDER BY 1,2
)
, evt_fitness_in AS (
    SELECT NVL(profile_identity, profile_push_token) AS profile_identity
        , CASE WHEN profile_identity IS NULL THEN FALSE ELSE TRUE END AS is_member
        , event_datetime
        , INITCAP(REPLACE(eventname, '_', ' ')) AS eventname
    FROM "trusted".clevertap_fitness_in
    WHERE eventprops_access_method = 'QR'
    ORDER BY 1,2
)
, evt_common_fee_payment AS (
    SELECT NVL(profile_identity, profile_push_token) AS profile_identity
        , CASE WHEN profile_identity IS NULL THEN FALSE ELSE TRUE END AS is_member
        , event_datetime
        , INITCAP(REPLACE(eventname, '_', ' ')) AS eventname
    FROM "trusted".clevertap_common_fee_payment
    WHERE eventprops_complete_payment = TRUE
    ORDER BY 1,2
)
, event_raw AS (
    SELECT * FROM evt_app_launched
    UNION ALL
    SELECT * FROM evt_view
    UNION ALL
    SELECT * FROM evt_click
    UNION ALL
    SELECT * FROM evt_register
    UNION ALL
    SELECT * FROM evt_login
    UNION ALL
    SELECT * FROM evt_notification_viewed
    UNION ALL
    SELECT * FROM evt_activated_wallet
    UNION ALL
    SELECT * FROM evt_topup
    UNION ALL
    SELECT * FROM evt_payment
    UNION ALL
    SELECT * FROM evt_redeem
    UNION ALL
    SELECT * FROM evt_gate_in
    UNION ALL
    SELECT * FROM evt_gate_out
    UNION ALL
    SELECT * FROM evt_fitness_in
    UNION ALL
    SELECT * FROM evt_common_fee_payment
) 
, distinct_timestamps AS (
	SELECT DISTINCT profile_identity
		, event_datetime
	FROM event_raw
)
, ts_lagged AS (
	SELECT *
		, LAG(event_datetime) OVER (
			PARTITION BY profile_identity
			ORDER BY event_datetime
		) AS prev_event_datetime
	FROM distinct_timestamps
)
, ts_flagged AS (
	SELECT *
		, CASE
			WHEN prev_event_datetime IS NULL THEN 1
			WHEN DATEDIFF(minute, prev_event_datetime, event_datetime) >= 20 THEN 1
			ELSE 0
		END AS is_new_session
	FROM ts_lagged
)
, ts_numbered AS (
	SELECT *
		, SUM(is_new_session) OVER (
			PARTITION BY profile_identity
			ORDER BY event_datetime
			ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
		) AS session_seq
	FROM ts_flagged
)
, event_prioritized AS (
	SELECT *
		, CASE eventname
			WHEN 'App Launched' THEN 1
			WHEN 'Registered' THEN 2
			ELSE 99
		END AS event_priority
	FROM event_raw
)
, event_sessionized AS (
	SELECT e.profile_identity AS member_id
		, e.event_datetime
		, e.eventname
		, e.event_priority
		, e.profile_identity || '_' || t.session_seq AS session_id
	FROM event_prioritized e
	INNER JOIN ts_numbered t
		ON e.profile_identity = t.profile_identity
		AND e.event_datetime = t.event_datetime
)
, session_agg AS (
	SELECT session_id
		, member_id
		, MIN(event_datetime) AS session_start
		, MAX(event_datetime) AS session_end
		, DATEDIFF(second, MIN(event_datetime), MAX(event_datetime)) AS session_duration_sec
		, COUNT(*) AS num_events
	FROM event_sessionized
	GROUP BY session_id
		, member_id
)
, last_event AS (
	SELECT DISTINCT session_id
		, LAST_VALUE(eventname) OVER (
			PARTITION BY session_id
			ORDER BY event_datetime, event_priority
			ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
		) AS last_event_in_session
	FROM event_sessionized
)
, event_path_list AS (
	SELECT session_id
		, LISTAGG(eventname, ' > ') WITHIN GROUP (ORDER BY event_datetime, event_priority) AS event_list_dist
	FROM event_sessionized
	GROUP BY session_id
)
, event_final AS (
	SELECT a.session_id
		, a.member_id AS member_id_event
		, a.session_start
		, a.session_end
		, a.session_duration_sec
		, a.num_events
		, l.last_event_in_session
		, p.event_list_dist
		, trunc(a.session_start) AS data_date
		, last_day(a.session_start) AS data_month
	FROM session_agg a
	LEFT JOIN last_event l ON a.session_id = l.session_id
	LEFT JOIN event_path_list p ON a.session_id = p.session_id
)
, joined_member AS (
	SELECT a.member_id
		, a.member_type
--		, a.member_status
		, a.is_staff
		, b.*
	FROM refined.dim_hook_member a
	LEFT JOIN event_final b ON a.member_id = b.member_id_event
)
SELECT session_id
	, member_id
	, member_type
--	, member_status
	, is_staff
	, session_start
	, session_end
	, session_duration_sec
	, num_events
	, last_event_in_session
	, event_list_dist
	, data_date
	, data_month
FROM joined_member
WHERE session_id IS NOT NULL