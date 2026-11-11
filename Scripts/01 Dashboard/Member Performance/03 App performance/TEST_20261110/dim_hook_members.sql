SELECT member_id
    , register_datetime AS register_datetime_og
    , CASE
            WHEN DATE_TRUNC('day', register_datetime) = DATE_TRUNC('day', '2026-05-08'::DATE) THEN DATEADD('day', 1, register_datetime)
            ELSE register_datetime
            END AS register_datetime
    , CASE
        WHEN registration_source = 'ADMIN' THEN 'ADMIN (staff)'
        WHEN registration_source = 'APP' THEN 'APP (Organic)'
        WHEN registration_source = 'QR_COMMON' THEN 'COMMON AREA QR'
        WHEN registration_source = 'QR_DRIVING_RANGE' THEN 'DRIVING RANGE QR'
        WHEN registration_source = 'QR_EASTIN' THEN 'EASTIN QR'
        WHEN registration_source = 'QR_EVENT' THEN 'EVENT'
        WHEN registration_source = 'QR_GOLF_CLUB' THEN 'GOLF CLUB QR'
        WHEN registration_source = 'QR_HOOK EVENT' THEN 'EVENT'
        WHEN registration_source = 'QR_SHARK_BITE' THEN 'SHARK BITE QR'
        WHEN registration_source = 'QR_SPLASH' THEN 'SPLASH QR'
        WHEN registration_source = 'QR_SPORT_CLUB' THEN 'SPORT CLUB QR'
        WHEN registration_source = 'QR_TURTLE_SHOP' THEN 'TURTLE SHOP QR'
        WHEN registration_source = 'TURTLEDELIVERY-HOOK-SHOPIFY' THEN 'TURTLE DELIVERY WEB (Quick Registration)'
        WHEN registration_source = 'QR_DAS_HAUS' THEN 'DAS HAUS QR'
        WHEN registration_source = 'DASHAUSBKK-SHOPIFY' THEN 'DAS HAUS WEB (Quick Registration)'
        WHEN registration_source = 'SHOPIFY' THEN 'SHOPIFY'
        WHEN registration_source = 'WEB' THEN 'WEB (Quick Registration)'
        ELSE registration_source
                END AS registration_source
    , activated_wallet
    , activated_wallet_datetime
    , is_staff
    , referred_staff_id
    , member_status
    , member_type
    , member_house_type
    , member_house_zone
    , NVL(INITCAP(gender), 'Unknown') AS gender
    , CASE
        WHEN date_of_birth IS NULL THEN 'Unknown'
        WHEN datediff(year, date_of_birth, current_date) < 16 THEN '<16'
        WHEN datediff(year, date_of_birth, current_date) BETWEEN 16 AND 25 THEN '16-25'
        WHEN datediff(year, date_of_birth, current_date) BETWEEN 26 AND 35 THEN '26-35'
        WHEN datediff(year, date_of_birth, current_date) BETWEEN 36 AND 45 THEN '36-45'
        WHEN datediff(year, date_of_birth, current_date) BETWEEN 46 AND 55 THEN '46-55'
        WHEN datediff(year, date_of_birth, current_date) >= 56 THEN '56+'
        ELSE 'Invalid'
        END AS age_range
    , register_hook_app
    , first_app_launch_datetime
        , created_at
    , updated_at
FROM refined.dim_hook_member