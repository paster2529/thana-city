WITH hook_member AS (
	SELECT member_id
		, member_type
		, member_status
	FROM refined.dim_hook_member
)
, event_raw AS (
    SELECT event_datetime
        , eventname
        , 1 AS event_seq
        , profile_identity
        , NULL::TEXT AS event_details
    FROM trusted.clevertap_app_installed
    WHERE profile_identity IS NOT NULL
    UNION ALL
    SELECT event_datetime
        , eventname
        , 2 AS event_seq
        , profile_identity
        , NULL::TEXT AS event_details
    FROM trusted.clevertap_app_launched
    WHERE profile_identity IS NOT NULL
    UNION ALL
    SELECT event_datetime
        , eventname
        , 3 AS event_seq
        , profile_identity
        , NULL::TEXT AS event_details
    FROM trusted.clevertap_sign_up
    WHERE profile_identity IS NOT NULL
    UNION ALL
    SELECT event_datetime
        , eventname
        , 4 AS event_seq
        , profile_identity
        , NULL::TEXT AS event_details
    FROM trusted.clevertap_login
    WHERE profile_identity IS NOT NULL
    UNION ALL
    SELECT event_datetime
		, eventname
		, 5 AS event_seq
		, profile_identity
		, eventprops_app_feature || '|' || eventprops_screen_name AS event_details
	FROM trusted.clevertap_view
	WHERE profile_identity IS NOT NULL
)
SELECT DISTINCT event_seq
	, eventname
	, event_details
FROM event_raw
ORDER BY 1,3