-- ==============================================================================
-- BÁO CÁO CƠ SỞ DỮ LIỆU BẢO MẬT ORACLE
-- THÀNH VIÊN 1: TẤN YÊN (Cụm Xác thực & Khách hàng)
-- ==============================================================================
ALTER SESSION SET CURRENT_SCHEMA = TRASUA;

-- ==============================================================================
-- NHIỆM VỤ CHUNG: KHỞI TẠO APPLICATION CONTEXT CHO VPD
-- ==============================================================================
CREATE OR REPLACE CONTEXT auth_ctx USING pkg_auth_yen;

CREATE OR REPLACE PACKAGE pkg_auth_yen IS
    PROCEDURE set_account_id(p_account_id NUMBER);
END;
/
CREATE OR REPLACE PACKAGE BODY pkg_auth_yen IS
    PROCEDURE set_account_id(p_account_id NUMBER) IS
    BEGIN
        DBMS_SESSION.SET_CONTEXT('auth_ctx', 'account_id', TO_CHAR(p_account_id));
    END;
END;
/

-- ==============================================================================
-- MỨC ĐỘ DỄ: Cấu hình Profile & Phân quyền RBAC cơ bản
-- ==============================================================================
-- 1. Profile giới hạn đăng nhập, áp dụng cho Auth (Đăng nhập, Quên MK)
BEGIN
    EXECUTE IMMEDIATE 'CREATE PROFILE USER_SEC_PROFILE LIMIT FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LIFE_TIME 90';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
-- (Tuỳ chọn gán profile cho user DB nếu dùng DB Authentication)
-- ALTER USER C##CUSTOMER PROFILE USER_SEC_PROFILE;

-- 2. Quản lý sản phẩm (RBAC) - Ai cũng có thể xem sản phẩm
GRANT SELECT ON product TO PUBLIC;
GRANT SELECT ON product_detail TO PUBLIC;

-- ==============================================================================
-- MỨC ĐỘ VỪA: Viết Policy VPD cơ bản (User Profile, Wishlist)
-- ==============================================================================
-- Policy: Chỉ xem được hồ sơ và wishlist của chính mình
CREATE OR REPLACE FUNCTION fn_vpd_personal_data (
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
) RETURN VARCHAR2 IS
    v_account_id VARCHAR2(50);
BEGIN
    v_account_id := SYS_CONTEXT('auth_ctx', 'account_id');
    IF v_account_id IS NULL THEN RETURN '1=0'; END IF;
    RETURN 'account_id = ' || v_account_id;
END;
/

-- Áp dụng VPD cho Wishlist
BEGIN
    BEGIN DBMS_RLS.DROP_POLICY('TRASUA', 'WISHLIST', 'POL_WISHLIST_VPD'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'WISHLIST',
        policy_name     => 'POL_WISHLIST_VPD',
        function_schema => 'TRASUA',
        policy_function => 'fn_vpd_personal_data',
        statement_types => 'SELECT, UPDATE, DELETE'
    );
END;
/

-- ==============================================================================
-- MỨC ĐỘ KHÓ: Kết hợp OLS & Data Redaction (Che dữ liệu nhạy cảm Khách hàng)
-- ==============================================================================
-- 1. DATA REDACTION: Che SĐT và Email của khách hàng đối với ROLE_STAFF
BEGIN
    BEGIN DBMS_REDACT.DROP_POLICY('TRASUA', 'CUSTOMER', 'REDACT_CUSTOMER_PII'); EXCEPTION WHEN OTHERS THEN NULL; END;

    DBMS_REDACT.ADD_POLICY(
        object_schema       => 'TRASUA',
        object_name         => 'CUSTOMER',
        policy_name         => 'REDACT_CUSTOMER_PII',
        column_name         => 'PHONE_NUMBER',
        function_type       => DBMS_REDACT.REGEXP,
        function_parameters => '(\d{2})(\d+)(\d{3})',
        regexp_pattern      => '(\d{2})(\d+)(\d{3})',
        regexp_replace_string => '\1***\3',
        regexp_position     => 1,
        regexp_occurrence   => 0,
        regexp_match_parameter => 'i',
        expression          => 'SYS_CONTEXT(''branch_ctx'',''user_role'') = ''ROLE_STAFF'''
    );

    DBMS_REDACT.ALTER_POLICY(
        object_schema       => 'TRASUA',
        object_name         => 'CUSTOMER',
        policy_name         => 'REDACT_CUSTOMER_PII',
        action              => DBMS_REDACT.ADD_COLUMN,
        column_name         => 'EMAIL',
        function_type       => DBMS_REDACT.REGEXP,
        regexp_pattern      => '^(.{1})(.+)(@.+)$',
        regexp_replace_string => '\1***\3',
        regexp_position     => 1,
        regexp_occurrence   => 0,
        regexp_match_parameter => 'i'
    );
END;
/

-- 2. OLS (Oracle Label Security): Gắn nhãn cho CUSTOMER
BEGIN
    BEGIN SA_POLICY_ADMIN.REMOVE_TABLE_POLICY('ACCESS_POLICY', 'TRASUA', 'CUSTOMER'); EXCEPTION WHEN OTHERS THEN NULL; END;
    SA_POLICY_ADMIN.APPLY_TABLE_POLICY('ACCESS_POLICY', 'TRASUA', 'CUSTOMER', 'NO_CONTROL');
END;
/
UPDATE CUSTOMER SET ols_label = CHAR_TO_LABEL('ACCESS_POLICY', 'PUB') WHERE ols_label IS NULL;
COMMIT;

CREATE OR REPLACE TRIGGER trg_ols_customer_insert
BEFORE INSERT ON CUSTOMER
FOR EACH ROW
BEGIN
    :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB');
END;
/

BEGIN
    BEGIN SA_POLICY_ADMIN.REMOVE_TABLE_POLICY('ACCESS_POLICY', 'TRASUA', 'CUSTOMER'); EXCEPTION WHEN OTHERS THEN NULL; END;
    SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
        policy_name    => 'ACCESS_POLICY',
        schema_name    => 'TRASUA',
        table_name     => 'CUSTOMER',
        table_options  => 'READ_CONTROL,WRITE_CONTROL,CHECK_CONTROL'
    );
END;
/
