WITH data_register AS (
        SELECT member_id
                , CASE
                        WHEN DATE_TRUNC('day', register_datetime) = DATE_TRUNC('day', '2026-05-08'::DATE) THEN DATEADD('day', 1, register_datetime)
                        ELSE register_datetime
                END AS event_datetime
                , 'Register' AS event_name
                , 'Membership' AS event_category
                , FALSE AS is_app_event
                , NULL::TEXT AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM refined.dim_hook_member
)
, data_wallet_activated AS (
        SELECT member_id
                , activated_wallet_datetime AS event_datetime
                , 'Activate Wallet' AS event_name
                , 'Wallet' AS event_category
                , FALSE AS is_app_event
                , NULL::TEXT AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM refined.dim_hook_member
        WHERE activated_wallet = TRUE
)
, data_topup AS (
        SELECT member_id
                , transaction_datetime AS event_datetime
                , 'Coin Top-up' AS event_name
                , 'Wallet' AS event_category
                , FALSE AS is_app_event
                , NULL::TEXT AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , campaign_name AS element_name
                , NULL::TEXT AS element_display_name
                , total_coin_value::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM refined.fact_hook_coin_issue
        WHERE data_date >= '2026-05-09'::DATE
                AND transaction_type IN ('topup', 'admin_credit')
                AND coin_type = 'cash'
                AND transaction_status = 'confirmed'
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
, push_log AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , eventprops_campaign_id AS push_campaign_id
                , eventprops_rewards_id AS reward_id
                , eventprops_rewards_name AS reward_name
                , eventprops_merchant_name AS merchant_name
                , eventprops_rewards_category AS rewards_category
                , eventprops_status AS push_status
                , eventprops_fail_reason AS fail_reason
        FROM "trusted".clevertap_webhook_reward_push
        WHERE profile_identity IS NOT NULL
)
, coupon_ranked AS (
        SELECT f.transaction_id::TEXT AS coupon_txn_id
                , f.redeem_member_id
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
, coupon_enriched AS (
        SELECT *
        FROM coupon_ranked
        WHERE rn = 1
)
, data_coupon_issued AS (
        SELECT redeem_member_id AS member_id
                , redeem_datetime AS event_datetime
                , 'Coupon Issued' AS event_name
                , 'Coupon' AS event_category
                , FALSE AS is_app_event
                , redeem_type AS app_feature
                , coupon_status AS app_sub_feature
                , NULL::TEXT AS screen_name
                , campaign_name AS element_name
                , coupon_name_en AS element_display_name
                , total_coin_value::DECIMAL(18,2) AS value
                , redeem_from_bu AS bu
                , redeem_from_merchant AS merchant
                , coupon_txn_id
                , reward_id
                , push_campaign_id AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , expired_datetime
        FROM coupon_enriched
)
, data_coupon_used AS (
        SELECT redeem_member_id AS member_id
                , used_datetime AS event_datetime
                , 'Coupon Used' AS event_name
                , 'Coupon' AS event_category
                , FALSE AS is_app_event
                , redeem_type AS app_feature
                , coupon_status AS app_sub_feature
                , NULL::TEXT AS screen_name
                , campaign_name AS element_name
                , coupon_name_en AS element_display_name
                , total_coin_value::DECIMAL(18,2) AS value
                , redeem_from_bu AS bu
                , redeem_from_merchant AS merchant
                , coupon_txn_id
                , reward_id
                , push_campaign_id AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , expired_datetime
        FROM coupon_enriched
        WHERE coupon_status = 'used'
)
, data_push_sent AS (
        SELECT member_id
                , event_datetime
                , 'Push Sent' AS event_name
                , 'Coupon' AS event_category
                , FALSE AS is_app_event
                , push_status AS app_feature
                , fail_reason AS app_sub_feature
                , NULL::TEXT AS screen_name
                , rewards_category AS element_name
                , reward_name AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , merchant_name AS merchant
                , NULL::TEXT AS coupon_txn_id
                , reward_id
                , push_campaign_id AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM push_log
)
, data_sales AS (
        SELECT NVL(member_id_coin, member_id_pos) AS member_id
                , transaction_datetime AS event_datetime
                , 'Sales' AS event_name
                , 'Transaction' AS event_category
                , FALSE AS is_app_event
                , coin_payment_portion AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , paid_amount::DECIMAL(18,2) AS value
                , 'Super Turtle' AS bu
                , 'Turtle X' AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM refined.fact_sales_txn_turtle
        WHERE is_valid = TRUE
                AND NVL(member_id_coin, member_id_pos) IS NOT NULL
        UNION ALL
        SELECT NVL(member_id_coin, member_id_pos, member_id_reward) AS member_id
                , transaction_datetime AS event_datetime
                , 'Sales' AS event_name
                , 'Transaction' AS event_category
                , FALSE AS is_app_event
                , coin_payment_portion AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , paid_amount::DECIMAL(18,2) AS value
                , bu
                , merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM refined.fact_sales_txn_bss_merchant
        WHERE is_valid = TRUE
                AND NVL(member_id_coin, member_id_pos, member_id_reward) IS NOT NULL
                AND NVL(bu, '') <> 'BU Test'
        UNION ALL
        SELECT NVL(member_id_coin, member_id_pos, member_id_reward) AS member_id
                , transaction_datetime AS event_datetime
                , 'Sales' AS event_name
                , 'Transaction' AS event_category
                , FALSE AS is_app_event
                , coin_payment_portion AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , paid_amount::DECIMAL(18,2) AS value
                , 'Chef Man' AS bu
                , 'Chef Man' AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM refined.fact_sales_txn_chefman
        WHERE is_valid = TRUE
                AND NVL(member_id_coin, member_id_pos, member_id_reward) IS NOT NULL
)
, data_pay_with_coin AS (
        SELECT NVL(member_id_coin, member_id_pos) AS member_id
                , transaction_datetime AS event_datetime
                , 'Pay with Coin' AS event_name
                , 'Transaction' AS event_category
                , FALSE AS is_app_event
                , coin_payment_portion AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , paid_coin::DECIMAL(18,2) AS value
                , 'Super Turtle' AS bu
                , 'Turtle X' AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM refined.fact_sales_txn_turtle
        WHERE is_valid = TRUE
                AND NVL(member_id_coin, member_id_pos) IS NOT NULL
                AND paid_coin > 0
        UNION ALL
        SELECT NVL(member_id_coin, member_id_pos, member_id_reward) AS member_id
                , transaction_datetime AS event_datetime
                , 'Pay with Coin' AS event_name
                , 'Transaction' AS event_category
                , FALSE AS is_app_event
                , coin_payment_portion AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , paid_coin::DECIMAL(18,2) AS value
                , bu
                , merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM refined.fact_sales_txn_bss_merchant
        WHERE is_valid = TRUE
                AND NVL(member_id_coin, member_id_pos, member_id_reward) IS NOT NULL
                AND paid_coin > 0
                AND NVL(bu, '') <> 'BU Test'
        UNION ALL
        SELECT NVL(member_id_coin, member_id_pos, member_id_reward) AS member_id
                , transaction_datetime AS event_datetime
                , 'Pay with Coin' AS event_name
                , 'Transaction' AS event_category
                , FALSE AS is_app_event
                , coin_payment_portion AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , paid_coin::DECIMAL(18,2) AS value
                , 'Chef Man' AS bu
                , 'Chef Man' AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , NULL::TEXT AS app_version
                , NULL::TEXT AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM refined.fact_sales_txn_chefman
        WHERE is_valid = TRUE
                AND NVL(member_id_coin, member_id_pos, member_id_reward) IS NOT NULL
                AND paid_coin > 0
)
, ct_app_installed AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'App Installed' AS event_name
                , 'Lifecycle' AS event_category
                , TRUE AS is_app_event
                , NULL::TEXT AS app_feature
                , eventprops_ct_source AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_app_installed
        WHERE profile_identity IS NOT NULL
)
, ct_app_launched AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'App Launched' AS event_name
                , 'Lifecycle' AS event_category
                , TRUE AS is_app_event
                , NULL::TEXT AS app_feature
                , eventprops_ct_source AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_app_launched
        WHERE profile_identity IS NOT NULL
)
, ct_login AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Login' AS event_name
                , 'Lifecycle' AS event_category
                , TRUE AS is_app_event
                , eventprops_status AS app_feature
                , eventprops_channel AS app_sub_feature
                , NULL::TEXT AS screen_name
                , eventprops_user_type AS element_name
                , NULL::TEXT AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_login
        WHERE profile_identity IS NOT NULL
)
, ct_tutorial AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Tutorial' AS event_name
                , 'Onboarding' AS event_category
                , TRUE AS is_app_event
                , NULL::TEXT AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , eventprops_tutorial AS element_name
                , NULL::TEXT AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_tutorial
        WHERE profile_identity IS NOT NULL
)
, ct_view AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'View' AS event_name
                , 'App Usage' AS event_category
                , TRUE AS is_app_event
                , eventprops_app_feature AS app_feature
                , NULL::TEXT AS app_sub_feature
                , eventprops_screen_name AS screen_name
                , NULL::TEXT AS element_name
                , NULL::TEXT AS element_display_name
                , CASE
                        WHEN DATEDIFF(second, event_datetime, LEAD(event_datetime) OVER (PARTITION BY profile_identity ORDER BY event_datetime)) <= 1200 THEN DATEDIFF(second, event_datetime, LEAD(event_datetime) OVER (PARTITION BY profile_identity ORDER BY event_datetime))::DECIMAL(18,2)
                END AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , eventprops_language AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_view
        WHERE profile_identity IS NOT NULL
)
, ct_click AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Click' AS event_name
                , 'App Usage' AS event_category
                , TRUE AS is_app_event
                , eventprops_app_feature AS app_feature
                , eventprops_app_sub_feature AS app_sub_feature
                , eventprops_screen_name AS screen_name
                , eventprops_element_name AS element_name
                , eventprops_element_display_name AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , CASE WHEN eventprops_element_name LIKE 'btn_coupon_%' THEN SUBSTRING(eventprops_element_name, 12) END AS coupon_txn_id
                , CASE WHEN eventprops_element_name LIKE 'btn_reward_%' THEN SUBSTRING(eventprops_element_name, 12) END AS reward_id
                , CASE
                        WHEN eventprops_element_name ~ '^btn_(banner|announcement|article)_' THEN REGEXP_SUBSTR(eventprops_element_name, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
                        WHEN eventprops_element_name ~ '^btn_notification_[0-9]+_' THEN 'notif_' || SPLIT_PART(eventprops_element_name, '_', 3)
                END AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , eventprops_language AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_click
        WHERE profile_identity IS NOT NULL
)
, ct_searched AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Searched' AS event_name
                , 'App Usage' AS event_category
                , TRUE AS is_app_event
                , NULL::TEXT AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , eventprops_keyword AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_searched
        WHERE profile_identity IS NOT NULL
)
, ct_category_viewed AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Category Viewed' AS event_name
                , 'Rewards' AS event_category
                , TRUE AS is_app_event
                , 'rewards' AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , NULL::TEXT AS element_name
                , eventprops_category_name AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , NULL::TEXT AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_category_viewed
        WHERE profile_identity IS NOT NULL
)
, ct_rewards_viewed AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Reward Viewed' AS event_name
                , 'Rewards' AS event_category
                , TRUE AS is_app_event
                , 'rewards' AS app_feature
                , eventprops_product_category AS app_sub_feature
                , NULL::TEXT AS screen_name
                , eventprops_merchant_name AS element_name
                , eventprops_rewards_name AS element_display_name
                , NULLIF(REGEXP_REPLACE(eventprops_coin_to_redeemed, '[^0-9.]', ''), '')::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , eventprops_merchant_name AS merchant
                , NULL::TEXT AS coupon_txn_id
                , eventprops_rewards_id AS reward_id
                , NULL::TEXT AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_rewards_viewed
        WHERE profile_identity IS NOT NULL
)
, ct_notification_viewed AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Notification Viewed' AS event_name
                , 'Engagement' AS event_category
                , TRUE AS is_app_event
                , eventprops_campaign_type AS app_feature
                , NULL::TEXT AS app_sub_feature
                , NULL::TEXT AS screen_name
                , eventprops_campaign_name AS element_name
                , eventprops_campaign_labels AS element_display_name
                , NULL::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , eventprops_campaign_id AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_notification_viewed
        WHERE profile_identity IS NOT NULL
)
, ct_rating_submitted AS (
        SELECT profile_identity AS member_id
                , event_datetime
                , 'Rating Submitted' AS event_name
                , 'Feedback' AS event_category
                , TRUE AS is_app_event
                , eventprops_nps_classification AS app_feature
                , eventprops_input_type AS app_sub_feature
                , NULL::TEXT AS screen_name
                , eventprops_label AS element_name
                , eventprops_comment AS element_display_name
                , eventprops_user_rating::DECIMAL(18,2) AS value
                , NULL::TEXT AS bu
                , NULL::TEXT AS merchant
                , NULL::TEXT AS coupon_txn_id
                , NULL::TEXT AS reward_id
                , eventprops_campaign_id AS campaign_id
                , eventprops_ct_app_version AS app_version
                , profile_platform AS platform
                , NULL::TEXT AS language
                , NULL::TIMESTAMP AS expired_datetime
        FROM "trusted".clevertap_rating_submitted
        WHERE profile_identity IS NOT NULL
)
, app_events AS (
        SELECT * FROM ct_app_installed
        UNION ALL
        SELECT * FROM ct_app_launched
        UNION ALL
        SELECT * FROM ct_login
        UNION ALL
        SELECT * FROM ct_tutorial
        UNION ALL
        SELECT * FROM ct_view
        UNION ALL
        SELECT * FROM ct_click
        UNION ALL
        SELECT * FROM ct_searched
        UNION ALL
        SELECT * FROM ct_category_viewed
        UNION ALL
        SELECT * FROM ct_rewards_viewed
        UNION ALL
        SELECT * FROM ct_notification_viewed
        UNION ALL
        SELECT * FROM ct_rating_submitted
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
        SELECT member_id
                , event_datetime
                , event_name
                , event_category
                , is_app_event
                , app_feature
                , app_sub_feature
                , screen_name
                , element_name
                , element_display_name
                , value
                , bu
                , merchant
                , coupon_txn_id
                , reward_id
                , campaign_id
                , app_version
                , platform
                , language
                , expired_datetime
                , member_id || '_' || session_no AS session_id
                , is_new_session AS is_session_start
                , CASE
                        WHEN is_new_session = 1 THEN DATEDIFF(second, event_datetime, MAX(event_datetime) OVER (PARTITION BY member_id, session_no))
                        END AS session_duration_sec
                , FIRST_VALUE(CASE WHEN event_name = 'View' THEN screen_name END) IGNORE NULLS OVER (PARTITION BY member_id, session_no ORDER BY event_datetime, event_sort, screen_name, element_name ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING) AS next_screen
                -- new columns: page journey
                , session_no AS member_session_no
                , MIN(event_datetime) OVER (PARTITION BY member_id, session_no) AS session_start_datetime
                , MAX(event_datetime) OVER (PARTITION BY member_id, session_no) AS session_end_datetime
                , ROW_NUMBER() OVER (PARTITION BY member_id, session_no ORDER BY event_datetime, event_sort, screen_name, element_name) AS event_seq
                , FIRST_VALUE(CASE WHEN event_name = 'View' THEN screen_name END) IGNORE NULLS OVER (PARTITION BY member_id, session_no ORDER BY event_datetime, event_sort, screen_name, element_name ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS entry_screen
                , LAST_VALUE(CASE WHEN event_name = 'View' THEN screen_name END) IGNORE NULLS OVER (PARTITION BY member_id, session_no ORDER BY event_datetime, event_sort, screen_name, element_name ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS exit_screen
                , LAST_VALUE(CASE WHEN event_name = 'View' THEN screen_name END) IGNORE NULLS OVER (PARTITION BY member_id, session_no ORDER BY event_datetime, event_sort, screen_name, element_name ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_screen
                , LEAD(event_name) OVER (PARTITION BY member_id, session_no ORDER BY event_datetime, event_sort, screen_name, element_name) AS next_event_name
                , LEAD(NVL(element_name, screen_name)) OVER (PARTITION BY member_id, session_no ORDER BY event_datetime, event_sort, screen_name, element_name) AS next_event_detail
                , CASE
                        WHEN LEAD(event_datetime) OVER (PARTITION BY member_id, session_no ORDER BY event_datetime, event_sort, screen_name, element_name) IS NULL THEN 1
                        ELSE 0
                        END AS is_session_end
        FROM app_numbered
)
, app_view_flag AS (
        SELECT *
                , CASE
                        WHEN event_name = 'View' AND screen_name IS NOT NULL AND NVL(prev_screen, '#') <> screen_name THEN 1
                        ELSE 0
                        END AS is_new_view
        FROM app_sessioned
)
, app_stepped AS (
        -- view_step = order of page views in the session after removing consecutive duplicates (A > A > B = 1, -, 2)
        SELECT *
                , CASE
                        WHEN is_new_view = 1 THEN SUM(is_new_view) OVER (PARTITION BY member_id, member_session_no ORDER BY event_seq ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                        END AS view_step
                , SUM(is_new_view) OVER (PARTITION BY member_id, member_session_no) AS session_view_steps
        FROM app_view_flag
)
, backend_events AS (
        SELECT * FROM data_register
        UNION ALL
        SELECT * FROM data_wallet_activated
        UNION ALL
        SELECT * FROM data_topup
        UNION ALL
        SELECT * FROM data_coupon_issued
        UNION ALL
        SELECT * FROM data_coupon_used
        UNION ALL
        SELECT * FROM data_push_sent
        UNION ALL
        SELECT * FROM data_sales
        UNION ALL
        SELECT * FROM data_pay_with_coin
)
, session_window AS (
        SELECT DISTINCT member_id::TEXT AS member_id
                , session_id
                , member_session_no
                , session_start_datetime
                , session_end_datetime
        FROM app_stepped
)
, backend_sessioned AS (
        -- attach backend events to the app session they happened in (session start to 20 min after the last app event)
        -- windows never overlap because sessions are split by a > 20 min gap
        SELECT b.*
                , s.session_id
                , s.member_session_no
                , s.session_start_datetime
                , s.session_end_datetime
        FROM backend_events b
        LEFT JOIN session_window s ON b.member_id::TEXT = s.member_id
                AND b.event_datetime BETWEEN s.session_start_datetime AND DATEADD(minute, 20, s.session_end_datetime)
)
, union_all AS (
        SELECT member_id
                , event_datetime
                , event_name
                , event_category
                , is_app_event
                , app_feature
                , app_sub_feature
                , screen_name
                , element_name
                , element_display_name
                , value
                , bu
                , merchant
                , coupon_txn_id
                , reward_id
                , campaign_id
                , app_version
                , platform
                , language
                , expired_datetime
                , session_id
                , is_session_start
                , session_duration_sec
                , next_screen
                , member_session_no
                , session_start_datetime
                , session_end_datetime
                , event_seq
                , entry_screen
                , exit_screen
                , prev_screen
                , next_event_name
                , next_event_detail
                , is_session_end
                , view_step
                , session_view_steps
        FROM app_stepped
        UNION ALL
        SELECT member_id
                , event_datetime
                , event_name
                , event_category
                , is_app_event
                , app_feature
                , app_sub_feature
                , screen_name
                , element_name
                , element_display_name
                , value
                , bu
                , merchant
                , coupon_txn_id
                , reward_id
                , campaign_id
                , app_version
                , platform
                , language
                , expired_datetime
                , session_id
                , NULL::INT AS is_session_start
                , NULL::INT AS session_duration_sec
                , NULL::TEXT AS next_screen
                , member_session_no
                , session_start_datetime
                , session_end_datetime
                , NULL::BIGINT AS event_seq
                , NULL::TEXT AS entry_screen
                , NULL::TEXT AS exit_screen
                , NULL::TEXT AS prev_screen
                , NULL::TEXT AS next_event_name
                , NULL::TEXT AS next_event_detail
                , NULL::INT AS is_session_end
                , NULL::BIGINT AS view_step
                , NULL::BIGINT AS session_view_steps
        FROM backend_sessioned
)
SELECT *
FROM union_all