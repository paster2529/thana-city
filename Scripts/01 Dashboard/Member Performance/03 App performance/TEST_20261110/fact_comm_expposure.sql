WITH push_log AS (
        SELECT profile_identity::TEXT AS member_id
                , event_datetime
                , eventprops_campaign_id AS push_campaign_id
                , eventprops_rewards_name AS reward_name
                , eventprops_status AS push_status
        FROM "trusted".clevertap_webhook_reward_push
        WHERE profile_identity IS NOT NULL
)
, coupon_ranked AS (
        SELECT f.transaction_id::TEXT AS coupon_txn_id
                , f.redeem_member_id::TEXT AS member_id
                , f.redeem_datetime
                , f.used_datetime
                , f.expired_datetime
                , f.coupon_status
                , f.redeem_type
                , f.campaign_name
                , f.coupon_name_en
                , f.total_coin_value
                , f.redeem_from_bu
                , f.redeem_from_merchant
                , p.push_campaign_id
                , ROW_NUMBER() OVER (PARTITION BY f.transaction_id ORDER BY ABS(DATEDIFF(second, p.event_datetime, f.redeem_datetime))) AS rn
        FROM refined.fact_hook_coupon_redeem f
        LEFT JOIN push_log p ON f.redeem_member_id::TEXT = p.member_id
                AND f.coupon_name_en = p.reward_name
                AND LOWER(p.push_status) = 'complete'
                AND p.event_datetime BETWEEN DATEADD(minute, -5, f.redeem_datetime) AND DATEADD(minute, 5, f.redeem_datetime)
        WHERE NVL(f.redeem_from_bu, '') <> 'BU Test'
)
, coupon_base AS (
        SELECT coupon_txn_id
                , member_id
                , redeem_datetime
                , used_datetime
                , expired_datetime
                , coupon_status
                , redeem_type
                , campaign_name
                , coupon_name_en
                , total_coin_value
                , redeem_from_bu
                , redeem_from_merchant
                , push_campaign_id
        FROM coupon_ranked
        WHERE rn = 1
)
-- ===== shared app-session block: keep identical to fact_event_raw (same 11 CleverTap tables, same 20-min gap) =====
, app_events AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'App Installed' AS event_name
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS coupon_txn_id
        FROM "trusted".clevertap_app_installed
        WHERE profile_identity IS NOT NULL
        UNION ALL
        SELECT profile_identity AS member_id
                , event_datetime
                , 'App Launched' AS event_name
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS coupon_txn_id
        FROM "trusted".clevertap_app_launched
        WHERE profile_identity IS NOT NULL
        UNION ALL
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Login' AS event_name
                , NULL::TEXT AS screen_name
                , eventprops_user_type AS element_name
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS coupon_txn_id
        FROM "trusted".clevertap_login
        WHERE profile_identity IS NOT NULL
        UNION ALL
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Tutorial' AS event_name
                , NULL::TEXT AS screen_name
                , eventprops_tutorial AS element_name
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS coupon_txn_id
        FROM "trusted".clevertap_tutorial
        WHERE profile_identity IS NOT NULL
        UNION ALL
        SELECT profile_identity AS member_id
                , event_datetime
                , 'View' AS event_name
                , eventprops_screen_name AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS coupon_txn_id
        FROM "trusted".clevertap_view
        WHERE profile_identity IS NOT NULL
        UNION ALL
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Click' AS event_name
                , eventprops_screen_name AS screen_name
                , eventprops_element_name AS element_name
                , CASE
                        WHEN eventprops_element_name ~ '^btn_(banner|announcement|article)_' THEN REGEXP_SUBSTR(eventprops_element_name, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
                        WHEN eventprops_element_name ~ '^btn_notification_[0-9]+_' THEN 'notif_' || SPLIT_PART(eventprops_element_name, '_', 3)
                        END AS campaign_id
                , CASE WHEN eventprops_element_name LIKE 'btn_coupon_%' THEN SUBSTRING(eventprops_element_name, 12) END AS coupon_txn_id
        FROM "trusted".clevertap_click
        WHERE profile_identity IS NOT NULL
        UNION ALL
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Searched' AS event_name
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS coupon_txn_id
        FROM "trusted".clevertap_searched
        WHERE profile_identity IS NOT NULL
        UNION ALL
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Category Viewed' AS event_name
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS coupon_txn_id
        FROM "trusted".clevertap_category_viewed
        WHERE profile_identity IS NOT NULL
        UNION ALL
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Reward Viewed' AS event_name
                , NULL::TEXT AS screen_name
                , eventprops_merchant_name AS element_name
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS coupon_txn_id
        FROM "trusted".clevertap_rewards_viewed
        WHERE profile_identity IS NOT NULL
        UNION ALL
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Notification Viewed' AS event_name
                , NULL::TEXT AS screen_name
                , eventprops_campaign_name AS element_name
                , eventprops_campaign_id AS campaign_id
                , NULL::TEXT AS coupon_txn_id
        FROM "trusted".clevertap_notification_viewed
        WHERE profile_identity IS NOT NULL
        UNION ALL
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Rating Submitted' AS event_name
                , NULL::TEXT AS screen_name
                , eventprops_label AS element_name
                , eventprops_campaign_id AS campaign_id
                , NULL::TEXT AS coupon_txn_id
        FROM "trusted".clevertap_rating_submitted
        WHERE profile_identity IS NOT NULL
)
, app_sorted AS (
        SELECT *
                , CASE
                        WHEN event_name = 'App Installed' THEN 1
                        WHEN event_name = 'App Launched' THEN 2
                        WHEN event_name = 'Login' THEN 3
                        WHEN event_name = 'Notification Viewed' THEN 4
                        WHEN event_name = 'View' THEN 5
                        ELSE 6
                        END AS event_sort
        FROM app_events
)
, app_flagged AS (
        SELECT *
                , CASE
                        WHEN LAG(event_datetime) OVER (PARTITION BY member_id ORDER BY event_datetime, event_sort, screen_name, element_name) IS NULL THEN 1
                        WHEN DATEDIFF(second, LAG(event_datetime) OVER (PARTITION BY member_id ORDER BY event_datetime, event_sort, screen_name, element_name), event_datetime) > 1200 THEN 1
                        ELSE 0
                        END AS is_new_session
        FROM app_sorted
)
, app_numbered AS (
        SELECT *
                , SUM(is_new_session) OVER (PARTITION BY member_id ORDER BY event_datetime, event_sort, screen_name, element_name ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS session_no
        FROM app_flagged
)
, app_sessioned AS (
        SELECT member_id::TEXT AS member_id
                , event_datetime
                , event_name
                , screen_name
                , element_name
                , campaign_id
                , coupon_txn_id
                , member_id || '_' || session_no AS session_id
                , session_no AS member_session_no
                , MIN(event_datetime) OVER (PARTITION BY member_id, session_no) AS session_start_datetime
                , MAX(event_datetime) OVER (PARTITION BY member_id, session_no) AS session_end_datetime
                , ROW_NUMBER() OVER (PARTITION BY member_id, session_no ORDER BY event_datetime, event_sort, screen_name, element_name) AS event_seq
                , COUNT(*) OVER (PARTITION BY member_id, session_no) AS session_event_count
        FROM app_numbered
)
, session_window AS (
        SELECT DISTINCT member_id
                , session_id
                , member_session_no
                , session_start_datetime
                , session_end_datetime
        FROM app_sessioned
)
-- ===== end shared block =====
, touch_events AS (
        SELECT member_id
                , push_campaign_id AS campaign_key
                , 'Sent' AS touch_type
                , event_datetime
                , NULL::TEXT AS session_id
                , NULL::BIGINT AS event_seq
        FROM push_log
        WHERE LOWER(push_status) = 'complete'
                AND push_campaign_id IS NOT NULL
        UNION ALL
        SELECT member_id
                , campaign_id AS campaign_key
                , CASE
                        WHEN event_name = 'Notification Viewed' THEN 'Viewed'
                        ELSE 'Clicked'
                        END AS touch_type
                , event_datetime
                , session_id
                , event_seq
        FROM app_sessioned
        WHERE campaign_id IS NOT NULL
                AND event_name IN ('Notification Viewed', 'Click')
)
, touch_agg AS (
        SELECT member_id
                , campaign_key
                , MIN(CASE WHEN touch_type = 'Sent' THEN event_datetime END) AS first_sent_datetime
                , MIN(CASE WHEN touch_type = 'Viewed' THEN event_datetime END) AS first_viewed_datetime
                , MIN(CASE WHEN touch_type = 'Clicked' THEN event_datetime END) AS first_clicked_datetime
                , COUNT(CASE WHEN touch_type = 'Sent' THEN 1 END) AS n_sent
                , COUNT(CASE WHEN touch_type = 'Viewed' THEN 1 END) AS n_viewed
                , COUNT(CASE WHEN touch_type = 'Clicked' THEN 1 END) AS n_clicked
        FROM touch_events
        GROUP BY 1, 2
)
, anchor AS (
        -- engagement moment = first click, else first view
        SELECT t.*
                , NVL(t.first_clicked_datetime, t.first_viewed_datetime) AS engaged_datetime
                , CASE
                        WHEN t.first_clicked_datetime IS NOT NULL THEN 'Clicked'
                        WHEN t.first_viewed_datetime IS NOT NULL THEN 'Viewed'
                        END AS engaged_type
        FROM touch_agg t
)
, anchor_event AS (
        SELECT a.member_id
                , a.campaign_key
                , e.session_id
                , e.event_seq
                , ROW_NUMBER() OVER (PARTITION BY a.member_id, a.campaign_key ORDER BY e.event_seq) AS rn
        FROM anchor a
        JOIN touch_events e ON a.member_id = e.member_id
                AND a.campaign_key = e.campaign_key
                AND a.engaged_datetime = e.event_datetime
                AND a.engaged_type = e.touch_type
)
, after_engage AS (
        -- what the member did after seeing / clicking, inside the same session
        SELECT ae.member_id
                , ae.campaign_key
                , ae.session_id AS engaged_session_id
                , MAX(s.session_event_count) - ae.event_seq AS n_events_after
                , MAX(CASE WHEN s.event_seq = ae.event_seq + 1 THEN s.event_name END) AS next_event_name
                , MAX(CASE WHEN s.event_seq = ae.event_seq + 1 THEN NVL(s.element_name, s.screen_name) END) AS next_event_detail
                , MAX(s.session_end_datetime) AS session_end_datetime
                , MIN(CASE WHEN s.event_seq > ae.event_seq AND s.event_name = 'View' THEN s.event_seq END) AS next_view_seq
        FROM anchor_event ae
        JOIN app_sessioned s ON ae.session_id = s.session_id
        WHERE ae.rn = 1
        GROUP BY 1, 2, 3, ae.event_seq
)
, next_screen AS (
        SELECT x.member_id
                , x.campaign_key
                , s.screen_name AS next_screen_after_engage
        FROM after_engage x
        JOIN app_sessioned s ON x.engaged_session_id = s.session_id
                AND x.next_view_seq = s.event_seq
)
, conversion AS (
        SELECT a.member_id
                , a.campaign_key
                -- redeem conversion excludes the coupon gifted by this campaign itself (reward push issues the coupon with the push)
                , MIN(CASE WHEN c.redeem_datetime BETWEEN NVL(a.engaged_datetime, a.first_sent_datetime) AND DATEADD(day, 7, NVL(a.engaged_datetime, a.first_sent_datetime)) AND NVL(c.push_campaign_id::TEXT, '#') <> a.campaign_key THEN c.redeem_datetime END) AS first_redeem_7d_datetime
                , MIN(CASE WHEN c.used_datetime BETWEEN NVL(a.engaged_datetime, a.first_sent_datetime) AND DATEADD(day, 7, NVL(a.engaged_datetime, a.first_sent_datetime)) THEN c.used_datetime END) AS first_used_7d_datetime
                , COUNT(CASE WHEN c.push_campaign_id = a.campaign_key THEN 1 END) AS n_campaign_coupon_issued
                , COUNT(CASE WHEN c.push_campaign_id = a.campaign_key AND c.used_datetime IS NOT NULL THEN 1 END) AS n_campaign_coupon_used
        FROM anchor a
        JOIN coupon_base c ON a.member_id = c.member_id
        GROUP BY 1, 2
)
SELECT a.member_id
        , a.campaign_key
        , a.first_sent_datetime
        , a.first_viewed_datetime
        , a.first_clicked_datetime
        , a.n_sent
        , a.n_viewed
        , a.n_clicked
        , CASE WHEN a.n_sent > 0 THEN 1 ELSE 0 END AS is_sent
        , CASE WHEN a.n_viewed > 0 THEN 1 ELSE 0 END AS is_viewed
        , CASE WHEN a.n_clicked > 0 THEN 1 ELSE 0 END AS is_clicked
        , a.engaged_datetime
        , a.engaged_type
        , x.engaged_session_id
        , x.next_event_name
        , x.next_event_detail
        , n.next_screen_after_engage
        , x.n_events_after
        , DATEDIFF(second, a.engaged_datetime, x.session_end_datetime) AS sec_engage_to_session_end
        , CASE
                WHEN a.engaged_datetime IS NULL THEN NULL
                WHEN NVL(x.n_events_after, 0) = 0 THEN 1
                ELSE 0
                END AS is_exit_after_engage
        , c.first_redeem_7d_datetime
        , c.first_used_7d_datetime
        , CASE WHEN c.first_redeem_7d_datetime IS NOT NULL THEN 1 ELSE 0 END AS is_redeem_7d
        , CASE WHEN c.first_used_7d_datetime IS NOT NULL THEN 1 ELSE 0 END AS is_used_7d
        , NVL(c.n_campaign_coupon_issued, 0) AS n_campaign_coupon_issued
        , NVL(c.n_campaign_coupon_used, 0) AS n_campaign_coupon_used
FROM anchor a
LEFT JOIN after_engage x ON a.member_id = x.member_id
        AND a.campaign_key = x.campaign_key
LEFT JOIN next_screen n ON a.member_id = n.member_id
        AND a.campaign_key = n.campaign_key
LEFT JOIN conversion c ON a.member_id = c.member_id
        AND a.campaign_key = c.campaign_key