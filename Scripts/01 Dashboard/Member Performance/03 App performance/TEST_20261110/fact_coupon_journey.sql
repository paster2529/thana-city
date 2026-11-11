WITH push_log AS (
        SELECT profile_identity::TEXT AS member_id
                , event_datetime
                , eventprops_campaign_id AS push_campaign_id
                , eventprops_rewards_id::TEXT AS reward_id
                , eventprops_rewards_name AS reward_name
                , eventprops_status AS push_status
        FROM "trusted".clevertap_webhook_reward_push
        WHERE profile_identity IS NOT NULL
)
, reward_map AS (
        SELECT DISTINCT a.redeem_type
                , a.campaign_name
                , a.coupon_name_en
                , NVL(b.reward_id, c.reward_id)::TEXT AS reward_id
                , TRUNC(d.valid_from) AS valid_from
                , TRUNC(d.valid_until) AS valid_to
        FROM (
                SELECT DISTINCT redeem_type
                        , campaign_name
                        , coupon_name_en
                FROM refined.fact_hook_coupon_redeem
        ) a
        LEFT JOIN "trusted".ggsheets_mkt_campaign b ON a.coupon_name_en = b.rewards_name_en
        LEFT JOIN (
                SELECT reward_id
                        , name
                FROM "trusted".hook_reward_translations
                WHERE language_code = 'en'
        ) c ON a.coupon_name_en = c.name
        LEFT JOIN "trusted".hook_merchant_rewards d ON c.reward_id = d.id
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
                , NVL(p.reward_id, m.reward_id) AS reward_id
                , p.push_campaign_id
                , ROW_NUMBER() OVER (PARTITION BY f.transaction_id ORDER BY ABS(DATEDIFF(second, p.event_datetime, f.redeem_datetime)), CASE WHEN TRUNC(f.redeem_datetime) BETWEEN m.valid_from AND m.valid_to THEN 0 ELSE 1 END, m.valid_from DESC) AS rn
        FROM refined.fact_hook_coupon_redeem f
        LEFT JOIN push_log p ON f.redeem_member_id::TEXT = p.member_id
                AND f.coupon_name_en = p.reward_name
                AND LOWER(p.push_status) = 'complete'
                AND p.event_datetime BETWEEN DATEADD(minute, -5, f.redeem_datetime) AND DATEADD(minute, 5, f.redeem_datetime)
        LEFT JOIN reward_map m ON f.coupon_name_en = m.coupon_name_en
                AND f.redeem_type = m.redeem_type
                AND NVL(f.campaign_name, '') = NVL(m.campaign_name, '')
        WHERE NVL(f.redeem_from_bu, '') <> 'BU Test'
)
, coupon_base AS (
        -- coupon_key = the coupon itself (reward_id, else coupon name); first issue = member's first coupon_txn_id of that coupon
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
                , reward_id
                , push_campaign_id
                , NVL(reward_id, coupon_name_en) AS coupon_key
                , ROW_NUMBER() OVER (PARTITION BY member_id, NVL(reward_id, coupon_name_en) ORDER BY redeem_datetime, coupon_txn_id) AS issue_seq
                , CASE
                        WHEN redeem_type = 'coin' THEN 'Self Redeem (coin)'
                        WHEN push_campaign_id IS NOT NULL THEN 'Push Reward'
                        ELSE 'Other Issued'
                        END AS journey_type
                , NVL(used_datetime, LEAST(expired_datetime, GETDATE())) AS watch_end_datetime
        FROM coupon_ranked
        WHERE rn = 1
)
, tracking AS (
        -- coupon click tracking starts with the new CleverTap SDK: first btn_coupon_<id> click in the data
        SELECT MIN(event_datetime) AS tracking_start_datetime
        FROM "trusted".clevertap_click
        WHERE profile_identity IS NOT NULL
                AND eventprops_element_name LIKE 'btn_coupon_%'
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
, view_steps AS (
        -- page views with consecutive duplicate screens removed (A > A > B becomes A > B)
        SELECT member_id
                , session_id
                , event_datetime
                , screen_name
        FROM (
                SELECT member_id
                        , session_id
                        , event_datetime
                        , event_seq
                        , screen_name
                        , LAG(screen_name) OVER (PARTITION BY session_id ORDER BY event_seq) AS prev_view_screen
                FROM app_sessioned
                WHERE event_name = 'View'
                        AND screen_name IS NOT NULL
        )
        WHERE prev_view_screen IS NULL
                OR prev_view_screen <> screen_name
)
, coupon_session AS (
        SELECT c.*
                , rs.session_id AS redeem_session_id
                , rs.member_session_no AS redeem_member_session_no
                , rs.session_start_datetime AS redeem_session_start_datetime
                , rs.session_end_datetime AS redeem_session_end_datetime
                , us.session_id AS used_session_id
                , us.session_start_datetime AS used_session_start_datetime
        FROM coupon_base c
        LEFT JOIN session_window rs ON c.member_id = rs.member_id
                AND c.redeem_datetime BETWEEN rs.session_start_datetime AND DATEADD(minute, 20, rs.session_end_datetime)
        LEFT JOIN session_window us ON c.member_id = us.member_id
                AND c.used_datetime BETWEEN us.session_start_datetime AND DATEADD(minute, 20, us.session_end_datetime)
)
, before_redeem AS (
        -- screens in the redeem session before the redeem moment, numbered from the redeem backwards
        SELECT c.coupon_txn_id
                , v.event_datetime
                , v.screen_name
                , ROW_NUMBER() OVER (PARTITION BY c.coupon_txn_id ORDER BY v.event_datetime DESC) AS rn_desc
        FROM coupon_session c
        JOIN view_steps v ON c.redeem_session_id = v.session_id
                AND v.event_datetime <= c.redeem_datetime
)
, path_before_redeem AS (
        SELECT coupon_txn_id
                , LISTAGG(CASE WHEN rn_desc <= 15 THEN screen_name END, ' > ') WITHIN GROUP (ORDER BY event_datetime) AS path_before_redeem
                , COUNT(*) AS n_screens_before_redeem
                , MAX(CASE WHEN rn_desc = 3 THEN screen_name END) AS pre_screen_3
                , MAX(CASE WHEN rn_desc = 2 THEN screen_name END) AS pre_screen_2
                , MAX(CASE WHEN rn_desc = 1 THEN screen_name END) AS pre_screen_1
        FROM before_redeem
        GROUP BY 1
)
, path_before_used AS (
        -- last 15 screens in the used session before the used moment
        SELECT coupon_txn_id
                , LISTAGG(screen_name, ' > ') WITHIN GROUP (ORDER BY event_datetime) AS path_before_used
                , COUNT(*) AS n_screens_before_used
        FROM (
                SELECT c.coupon_txn_id
                        , v.event_datetime
                        , v.screen_name
                        , ROW_NUMBER() OVER (PARTITION BY c.coupon_txn_id ORDER BY v.event_datetime DESC) AS rn_desc
                FROM coupon_session c
                JOIN view_steps v ON c.used_session_id = v.session_id
                        AND v.event_datetime <= c.used_datetime
        )
        WHERE rn_desc <= 15
        GROUP BY 1
)
, next_session AS (
        -- first app session that is running or starts after the issue (used for push / other coupons)
        SELECT c.coupon_txn_id
                , s.session_id
                , ROW_NUMBER() OVER (PARTITION BY c.coupon_txn_id ORDER BY s.session_start_datetime) AS rn
        FROM coupon_session c
        JOIN session_window s ON c.member_id = s.member_id
                AND s.session_end_datetime >= c.redeem_datetime
                AND s.session_start_datetime <= c.watch_end_datetime
        WHERE c.journey_type <> 'Self Redeem (coin)'
)
, after_issue_session AS (
        -- session to follow after the coupon is issued:
        -- self redeem = the redeem session; push / other = the first app session after the issue
        SELECT c.coupon_txn_id
                , CASE
                        WHEN c.journey_type = 'Self Redeem (coin)' THEN c.redeem_session_id
                        ELSE n.session_id
                        END AS follow_session_id
        FROM coupon_session c
        LEFT JOIN next_session n ON c.coupon_txn_id = n.coupon_txn_id
                AND n.rn = 1
)
, after_issue_views AS (
        SELECT c.coupon_txn_id
                , v.event_datetime
                , v.screen_name
                , ROW_NUMBER() OVER (PARTITION BY c.coupon_txn_id ORDER BY v.event_datetime) AS rn_asc
        FROM coupon_session c
        JOIN after_issue_session f ON c.coupon_txn_id = f.coupon_txn_id
        JOIN view_steps v ON f.follow_session_id = v.session_id
                AND v.event_datetime > c.redeem_datetime
)
, path_after_issue AS (
        SELECT coupon_txn_id
                , MAX(CASE WHEN rn_asc = 1 THEN screen_name END) AS next_screen_after_issue
                , LISTAGG(CASE WHEN rn_asc <= 10 THEN screen_name END, ' > ') WITHIN GROUP (ORDER BY event_datetime) AS path_after_issue
                , COUNT(*) AS n_screens_after_issue
        FROM after_issue_views
        GROUP BY 1
)
, seen_stats AS (
        -- evidence that the member looked at the coupon between issue and use / expiry / today
        SELECT c.coupon_txn_id
                , MIN(CASE WHEN a.coupon_txn_id = c.coupon_txn_id THEN a.event_datetime END) AS first_coupon_click_datetime
                , COUNT(CASE WHEN a.coupon_txn_id = c.coupon_txn_id THEN 1 END) AS n_coupon_clicks
                , MIN(CASE WHEN a.event_name = 'View' AND a.screen_name IN ('rewards_wallet_screen', 'live_coupon_screen') THEN a.event_datetime END) AS first_coupon_screen_view_datetime
                , COUNT(DISTINCT a.session_id) AS n_sessions_issue_to_end
                , MAX(CASE WHEN f.follow_session_id = a.session_id AND a.event_name = 'View' AND a.screen_name IN ('rewards_wallet_screen', 'live_coupon_screen') THEN 1 ELSE 0 END) AS is_coupon_screen_in_follow_session
                , MAX(CASE WHEN f.follow_session_id = a.session_id AND a.coupon_txn_id = c.coupon_txn_id THEN 1 ELSE 0 END) AS is_coupon_click_in_follow_session
        FROM coupon_session c
        JOIN after_issue_session f ON c.coupon_txn_id = f.coupon_txn_id
        JOIN app_sessioned a ON c.member_id = a.member_id
                AND a.event_datetime > c.redeem_datetime
                AND a.event_datetime <= c.watch_end_datetime
        GROUP BY 1
)
, final AS (
        SELECT c.coupon_txn_id
                , c.member_id
                , c.coupon_key
                , c.reward_id
                , c.issue_seq
                , CASE WHEN c.issue_seq = 1 THEN 1 ELSE 0 END AS is_first_issue
                , c.redeem_type
                , c.journey_type
                , c.campaign_name
                , UPPER(c.campaign_name) AS campaign_name_upper
                , c.coupon_name_en
                , c.total_coin_value
                , c.redeem_from_bu
                , c.redeem_from_merchant
                , c.push_campaign_id
                , c.coupon_status
                , t.tracking_start_datetime
                -- 1 = issued after coupon click tracking started, so seen / not seen can be judged
                , CASE WHEN c.redeem_datetime >= t.tracking_start_datetime THEN 1 ELSE 0 END AS is_tracked
                , CASE
                        WHEN c.used_datetime IS NOT NULL THEN '3 Used'
                        WHEN c.expired_datetime < GETDATE() THEN '9 Expired'
                        ELSE '2 Redeemed (not used)'
                        END AS stage_reached
                , c.redeem_session_start_datetime AS launch_datetime
                , c.redeem_datetime
                , s.first_coupon_click_datetime
                , s.first_coupon_screen_view_datetime
                , c.used_datetime
                , c.expired_datetime
                , c.redeem_session_id
                , c.redeem_member_session_no
                , c.used_session_id
                , f.follow_session_id
                , CASE WHEN c.redeem_session_id IS NOT NULL THEN 1 ELSE 0 END AS is_redeem_in_app_session
                , CASE WHEN c.used_session_id IS NOT NULL THEN 1 ELSE 0 END AS is_used_in_app_session
                , CASE WHEN c.redeem_session_id = c.used_session_id THEN 1 ELSE 0 END AS is_used_same_session
                -- before issue (Sankey left side): 3 screens before redeem, closest last
                , CASE
                        WHEN c.journey_type = 'Push Reward' THEN 'Push received'
                        WHEN c.journey_type = 'Other Issued' THEN 'Coupon given'
                        WHEN c.redeem_session_id IS NULL THEN '(no app session)'
                        ELSE NVL(pr.pre_screen_3, '(session start)')
                        END AS pre_step_1
                , CASE
                        WHEN c.journey_type <> 'Self Redeem (coin)' OR c.redeem_session_id IS NULL THEN NULL
                        ELSE NVL(pr.pre_screen_2, '(session start)')
                        END AS pre_step_2
                , CASE
                        WHEN c.journey_type <> 'Self Redeem (coin)' OR c.redeem_session_id IS NULL THEN NULL
                        ELSE NVL(pr.pre_screen_1, '(session start)')
                        END AS pre_step_3
                -- what happened after the coupon was issued
                , CASE
                        WHEN c.journey_type = 'Self Redeem (coin)' AND c.redeem_session_id IS NULL THEN 'No app session'
                        WHEN c.journey_type = 'Self Redeem (coin)' AND c.redeem_session_id = c.used_session_id THEN 'Used in same session'
                        WHEN c.journey_type = 'Self Redeem (coin)' AND (NVL(s.is_coupon_screen_in_follow_session, 0) = 1 OR NVL(s.is_coupon_click_in_follow_session, 0) = 1) THEN 'Opened My Coupons'
                        WHEN c.journey_type = 'Self Redeem (coin)' AND NVL(pa.n_screens_after_issue, 0) > 0 THEN 'Went to other page'
                        WHEN c.journey_type = 'Self Redeem (coin)' THEN 'End session'
                        WHEN c.redeem_datetime < t.tracking_start_datetime THEN 'Not tracked (before SDK)'
                        WHEN s.first_coupon_click_datetime IS NOT NULL THEN 'Seen: clicked coupon'
                        WHEN s.first_coupon_screen_view_datetime IS NOT NULL THEN 'Seen: viewed My Coupons'
                        WHEN c.used_datetime IS NOT NULL OR c.expired_datetime < GETDATE() THEN 'Not seen'
                        ELSE 'Not seen yet'
                        END AS after_issue_action
                , pa.next_screen_after_issue
                , pa.path_after_issue
                , NVL(pa.n_screens_after_issue, 0) AS n_screens_after_issue
                , DATEDIFF(second, c.redeem_session_start_datetime, c.redeem_datetime) AS sec_launch_to_redeem
                , DATEDIFF(minute, c.redeem_datetime, NVL(s.first_coupon_click_datetime, s.first_coupon_screen_view_datetime)) / 60.0 AS hrs_issue_to_seen
                , DATEDIFF(minute, c.redeem_datetime, c.used_datetime) / 60.0 AS hrs_redeem_to_used
                , NVL(s.n_sessions_issue_to_end, 0) AS n_sessions_redeem_to_used
                , NVL(s.n_coupon_clicks, 0) AS n_coupon_clicks
                , pr.path_before_redeem
                , NVL(pr.n_screens_before_redeem, 0) AS n_screens_before_redeem
                , pu.path_before_used
                , NVL(pu.n_screens_before_used, 0) AS n_screens_before_used
        FROM coupon_session c
        CROSS JOIN tracking t
        LEFT JOIN after_issue_session f ON c.coupon_txn_id = f.coupon_txn_id
        LEFT JOIN seen_stats s ON c.coupon_txn_id = s.coupon_txn_id
        LEFT JOIN path_before_redeem pr ON c.coupon_txn_id = pr.coupon_txn_id
        LEFT JOIN path_before_used pu ON c.coupon_txn_id = pu.coupon_txn_id
        LEFT JOIN path_after_issue pa ON c.coupon_txn_id = pa.coupon_txn_id
)
SELECT *
FROM final