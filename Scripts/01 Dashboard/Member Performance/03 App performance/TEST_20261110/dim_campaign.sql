WITH push_sent AS (
        SELECT eventprops_campaign_id AS campaign_key
                , MAX(eventprops_rewards_name) AS reward_name
                , MAX(eventprops_merchant_name) AS merchant_name
                , MAX(eventprops_rewards_category) AS rewards_category
                , MIN(event_datetime) AS first_seen_datetime
                , MAX(event_datetime) AS last_seen_datetime
        FROM "trusted".clevertap_webhook_reward_push
        WHERE eventprops_campaign_id IS NOT NULL
        GROUP BY 1
)
, notif_viewed AS (
        SELECT eventprops_campaign_id AS campaign_key
                , MAX(eventprops_campaign_name) AS campaign_name
                , MAX(eventprops_campaign_type) AS campaign_type
                , MAX(eventprops_campaign_labels) AS campaign_labels
                , MIN(event_datetime) AS first_seen_datetime
                , MAX(event_datetime) AS last_seen_datetime
        FROM "trusted".clevertap_notification_viewed
        WHERE eventprops_campaign_id IS NOT NULL
        GROUP BY 1
)
, click_base AS (
        SELECT CASE
                        WHEN eventprops_element_name ~ '^btn_(banner|announcement|article)_' THEN REGEXP_SUBSTR(eventprops_element_name, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
                        WHEN eventprops_element_name ~ '^btn_notification_[0-9]+_' THEN 'notif_' || SPLIT_PART(eventprops_element_name, '_', 3)
                        END AS campaign_key
                , CASE
                        WHEN eventprops_element_name ~ '^btn_notification_' THEN 'In-app Notification'
                        ELSE INITCAP(SPLIT_PART(eventprops_element_name, '_', 2))
                        END AS click_channel
                , eventprops_element_display_name AS element_display_name
                , event_datetime
        FROM "trusted".clevertap_click
        WHERE profile_identity IS NOT NULL
                AND eventprops_element_name ~ '^btn_(banner|announcement|article|notification)_'
)
, clicked AS (
        SELECT campaign_key
                , MAX(click_channel) AS click_channel
                , MAX(element_display_name) AS click_display_name
                , MIN(event_datetime) AS first_seen_datetime
                , MAX(event_datetime) AS last_seen_datetime
        FROM click_base
        WHERE campaign_key IS NOT NULL
        GROUP BY 1
)
, article AS (
        SELECT id::VARCHAR AS campaign_key
                , NVL(NULLIF(title.en::TEXT, ''), NULLIF(title.th::TEXT, '')) AS article_title
        FROM "trusted".hook_articles
)
, all_keys AS (
        SELECT campaign_key FROM push_sent
        UNION
        SELECT campaign_key FROM notif_viewed
        UNION
        SELECT campaign_key FROM clicked
)
SELECT k.campaign_key
        , CASE
                WHEN c.click_channel IS NOT NULL THEN c.click_channel
                WHEN v.campaign_type ILIKE '%push%' THEN 'Push'
                WHEN v.campaign_type IS NOT NULL THEN INITCAP(v.campaign_type)
                WHEN p.campaign_key IS NOT NULL THEN 'Reward Push'
                ELSE 'Unknown'
                END AS channel
        , NVL(v.campaign_name, ar.article_title, c.click_display_name, p.reward_name, k.campaign_key) AS campaign_name
        , v.campaign_type
        , v.campaign_labels
        , p.reward_name
        , p.merchant_name
        , p.rewards_category
        , CASE WHEN p.campaign_key IS NOT NULL THEN 1 ELSE 0 END AS has_sent_log
        , CASE WHEN v.campaign_key IS NOT NULL THEN 1 ELSE 0 END AS has_view_log
        , CASE WHEN c.campaign_key IS NOT NULL THEN 1 ELSE 0 END AS has_click_log
        , LEAST(p.first_seen_datetime, v.first_seen_datetime, c.first_seen_datetime) AS first_seen_datetime
        , GREATEST(p.last_seen_datetime, v.last_seen_datetime, c.last_seen_datetime) AS last_seen_datetime
FROM all_keys k
LEFT JOIN push_sent p ON k.campaign_key = p.campaign_key
LEFT JOIN notif_viewed v ON k.campaign_key = v.campaign_key
LEFT JOIN clicked c ON k.campaign_key = c.campaign_key
LEFT JOIN article ar ON k.campaign_key = ar.campaign_key