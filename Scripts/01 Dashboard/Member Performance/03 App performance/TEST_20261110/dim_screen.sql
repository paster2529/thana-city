WITH screen_map AS (
        SELECT 'home_screen'::VARCHAR(100) AS screen_name, 'Home'::VARCHAR(100) AS screen_display_name, 'Home'::VARCHAR(50) AS screen_group, 1 AS is_journey_screen
        UNION ALL SELECT 'rewards_screen', 'Rewards Home', 'Rewards', 1
        UNION ALL SELECT 'reward_all_screen', 'All Rewards', 'Rewards', 1
        UNION ALL SELECT 'reward_detail_screen', 'Reward Detail', 'Rewards', 1
        UNION ALL SELECT 'reward_filter_screen', 'Reward Filter', 'Rewards', 1
        UNION ALL SELECT 'reward_filter_results_screen', 'Reward Filter Results', 'Rewards', 1
        UNION ALL SELECT 'search_screen', 'Search', 'Rewards', 1
        UNION ALL SELECT 'merchant_selection_screen', 'Select Merchant', 'Rewards', 1
        UNION ALL SELECT 'rewards_wallet_screen', 'My Coupons', 'Coupon', 1
        UNION ALL SELECT 'live_coupon_screen', 'Live Coupon (show to cashier)', 'Coupon', 1
        UNION ALL SELECT 'wallet_dashboard_screen', 'Wallet Dashboard', 'Wallet', 1
        UNION ALL SELECT 'wallet_top_up_screen', 'Wallet Top-up', 'Wallet', 1
        UNION ALL SELECT 'wallet_locked_screen', 'Wallet Locked', 'Wallet', 1
        UNION ALL SELECT 'qr_scanner_screen', 'QR Scanner', 'Payment', 1
        UNION ALL SELECT 'payment_review_screen', 'Payment Review', 'Payment', 1
        UNION ALL SELECT 'pin_verification_screen', 'PIN Verification', 'Payment', 1
        UNION ALL SELECT 'c_scan_b_transaction_detail_screen', 'Scan-to-Pay Result', 'Payment', 1
        UNION ALL SELECT 'transaction_detail_screen', 'Transaction Detail', 'Payment', 1
        UNION ALL SELECT 'notification_screen', 'Notification List', 'Notification', 1
        UNION ALL SELECT 'notification_detail_screen', 'Notification Detail', 'Notification', 1
        UNION ALL SELECT 'announcement_list_screen', 'Announcement List', 'Content', 1
        UNION ALL SELECT 'announcement_detail_screen', 'Announcement Detail', 'Content', 1
        UNION ALL SELECT 'article_list_screen', 'Article List', 'Content', 1
        UNION ALL SELECT 'article_detail_screen', 'Article Detail', 'Content', 1
        UNION ALL SELECT 'info_detail_screen', 'Info Detail', 'Content', 1
        UNION ALL SELECT 'service_link_detail', 'Service Link', 'Content', 1
        UNION ALL SELECT 'clever_tap_web_view_screen', 'CleverTap Web View', 'Content', 1
        UNION ALL SELECT 'member_detail_screen', 'Member Card', 'Account', 1
        UNION ALL SELECT 'member_information_screen', 'Member Information', 'Account', 1
        UNION ALL SELECT 'edit_profile_screen', 'Edit Profile', 'Account', 1
        UNION ALL SELECT 'edit_email_screen', 'Edit Email', 'Account', 1
        UNION ALL SELECT 'edit_phone_screen', 'Edit Phone', 'Account', 1
        UNION ALL SELECT 'edit_pin_screen', 'Edit PIN', 'Account', 1
        UNION ALL SELECT 'license_plate_list_screen', 'License Plates', 'Account', 1
        UNION ALL SELECT 'license_plate_add_screen', 'Add License Plate', 'Account', 1
        UNION ALL SELECT 'license_plate_edit_screen', 'Edit License Plate', 'Account', 1
        UNION ALL SELECT 'kyc_verification_screen', 'KYC Verification', 'Account', 1
        UNION ALL SELECT 'update_info_detection_screen', 'Update Info Prompt', 'Account', 1
        UNION ALL SELECT 'update_info_otp_screen', 'Update Info OTP', 'Account', 1
        UNION ALL SELECT 'delete_account_form_screen', 'Delete Account', 'Account', 1
        UNION ALL SELECT 'delete_account_otp_screen', 'Delete Account OTP', 'Account', 1
        UNION ALL SELECT 'login_screen', 'Login', 'Login', 0
        UNION ALL SELECT 'login_email_screen', 'Login Email', 'Login', 0
        UNION ALL SELECT 'login_otp_screen', 'Login OTP', 'Login', 0
        UNION ALL SELECT 'login_pin_screen', 'Login PIN', 'Login', 0
        UNION ALL SELECT 'login_verification_method_screen', 'Login Verify Method', 'Login', 0
        UNION ALL SELECT 'login_verify_do_b_screen', 'Login Verify DOB', 'Login', 0
        UNION ALL SELECT 'login_account_status_screen', 'Login Account Status', 'Login', 0
        UNION ALL SELECT 'account_exists_screen', 'Account Exists', 'Login', 0
        UNION ALL SELECT 'device_confirmation_screen', 'Device Confirmation', 'Login', 0
        UNION ALL SELECT 'forgot_pin_otp_screen', 'Forgot PIN OTP', 'Login', 0
        UNION ALL SELECT 'reset_pin_screen', 'Reset PIN', 'Login', 0
        UNION ALL SELECT 'welcome_screen', 'Welcome', 'Onboarding', 0
        UNION ALL SELECT 'onboarding_screen', 'Onboarding', 'Onboarding', 0
        UNION ALL SELECT 'registration_introduction_screen', 'Register Intro', 'Registration', 0
        UNION ALL SELECT 'registration_policy_screen', 'Register Policy', 'Registration', 0
        UNION ALL SELECT 'registration_step1_screen', 'Register Step 1', 'Registration', 0
        UNION ALL SELECT 'registration_step2_otp_screen', 'Register Step 2 OTP', 'Registration', 0
        UNION ALL SELECT 'registration_step3_pin_screen', 'Register Step 3 PIN', 'Registration', 0
        UNION ALL SELECT 'consent_form_screen', 'Consent Form', 'Registration', 0
        UNION ALL SELECT 'force_update_screen', 'Force Update', 'System', 0
        UNION ALL SELECT 'general_error_screen', 'General Error', 'System', 0
)
, screen_seen AS (
        SELECT DISTINCT eventprops_screen_name AS screen_name
        FROM "trusted".clevertap_view
        WHERE eventprops_screen_name IS NOT NULL
        UNION
        SELECT DISTINCT eventprops_screen_name
        FROM "trusted".clevertap_click
        WHERE eventprops_screen_name IS NOT NULL
)
SELECT s.screen_name
        , NVL(m.screen_display_name, INITCAP(REPLACE(REPLACE(s.screen_name, '_screen', ''), '_', ' '))) AS screen_display_name
        , NVL(m.screen_group, 'Other') AS screen_group
        , NVL(m.is_journey_screen, 1) AS is_journey_screen
        , CASE WHEN m.screen_name IS NULL THEN 1 ELSE 0 END AS is_unmapped
FROM screen_seen s
LEFT JOIN screen_map m ON s.screen_name = m.screen_name