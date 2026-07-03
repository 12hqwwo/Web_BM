-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 03_SECURITY_YEN.sql
-- ============================================================
-- ==============================================================================
-- TẬP LỆNH BẢO MẬT CƠ SỞ DỮ LIỆU ORACLE
-- Tác giả: Tấn Yên (Thành viên 1)
-- ==============================================================================

ALTER SESSION SET CURRENT_SCHEMA = TRASUA;

-- ==============================================================================
-- 1. MỨC ĐỘ DỄ (Profile & RBAC)
-- ==============================================================================
PROMPT --- 1. SETUP PROFILE AND RBAC ---

-- Tạo Profile giới hạn đăng nhập và mật khẩu
BEGIN
    EXECUTE IMMEDIATE 'CREATE PROFILE USER_SEC_PROFILE LIMIT FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LIFE_TIME 90';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -2379 THEN -- Profile already exists
            RAISE;
        END IF;
END;
/

-- Phân quyền cho ROLE_USER và PUBLIC
BEGIN
    EXECUTE IMMEDIATE 'GRANT SELECT ON product TO ROLE_USER';
    EXECUTE IMMEDIATE 'GRANT SELECT ON product_detail TO ROLE_USER';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
GRANT SELECT ON product TO PUBLIC;
GRANT SELECT ON product_detail TO PUBLIC;

-- ==============================================================================
-- 2. MỨC ĐỘ VỪA (VPD Cơ bản)
-- ==============================================================================
PROMPT --- 2. SETUP VPD CHO CART (GIO HANG) ---

-- Tạo Context
CREATE OR REPLACE CONTEXT auth_ctx USING pkg_auth_yen;

-- Tạo Package
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

-- Tạo Policy Function cho Cart
CREATE OR REPLACE FUNCTION FN_VPD_CART (
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
) RETURN VARCHAR2
IS
    v_account_id VARCHAR2(50);
BEGIN
    v_account_id := SYS_CONTEXT('auth_ctx', 'account_id');
    
    -- Giỏ hàng là 100% cá nhân hóa, không ai được xem của ai khác kể cả Admin
    -- Nếu không có tài khoản đăng nhập (Khách vãng lai), chặn không cho xem
    IF v_account_id IS NULL THEN
        RETURN '1=0';
    END IF;

    RETURN 'account_id = ' || v_account_id;
END FN_VPD_CART;
/

-- Áp dụng Policy cho Cart
BEGIN
    BEGIN DBMS_RLS.DROP_POLICY('TRASUA', 'CART', 'POL_CART_VPD'); EXCEPTION WHEN OTHERS THEN NULL; END;
    
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'CART',
        policy_name     => 'POL_CART_VPD',
        function_schema => 'TRASUA',
        policy_function => 'FN_VPD_CART',
        enable          => TRUE
    );
END;
/

-- ==============================================================================
-- 3. MỨC ĐỘ KHÓ (OLS & Redaction)
-- ==============================================================================
PROMPT --- 3. SETUP OLS AND REDACTION TRÊN BẢNG CUSTOMER ---

-- 3A. DATA REDACTION
BEGIN
    -- Xoa redaction policy cu (tu file 06) neu co
    BEGIN
        DBMS_REDACT.DROP_POLICY(
            object_schema => 'TRASUA',
            object_name   => 'CUSTOMER',
            policy_name   => 'REDACT_CUSTOMER_PII'
        );
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

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
        expression          => q'[SYS_CONTEXT('branch_ctx','user_role') = 'ROLE_STAFF']',
        policy_description  => 'Che so dien thoai khach hang voi ROLE_STAFF'
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
    DBMS_OUTPUT.PUT_LINE('Data Redaction da duoc cai dat: che SDT va Email tren bang CUSTOMER');
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Chua the tao Redaction. Vui long cap quyen: GRANT EXECUTE ON DBMS_REDACT TO TRASUA;');
END;
/

-- 3B. OLS (Oracle Label Security)
BEGIN
    -- Gỡ policy cũ trước khi gán lại với trạng thái NO_CONTROL
    BEGIN SA_POLICY_ADMIN.REMOVE_TABLE_POLICY('ACCESS_POLICY', 'TRASUA', 'CUSTOMER'); EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Áp dụng OLS với NO_CONTROL để tạo cột ols_label (trường hợp bảng chưa có)
    SA_POLICY_ADMIN.APPLY_TABLE_POLICY('ACCESS_POLICY', 'TRASUA', 'CUSTOMER', 'NO_CONTROL');
END;
/

-- Update nhãn mặc định cho những record có sẵn
UPDATE CUSTOMER SET ols_label = CHAR_TO_LABEL('ACCESS_POLICY', 'PUB') WHERE ols_label IS NULL;
COMMIT;

-- Tạo Trigger gán nhãn tự động
CREATE OR REPLACE TRIGGER trg_ols_customer_insert
BEFORE INSERT ON CUSTOMER
FOR EACH ROW
BEGIN
    :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB');
END;
/

-- Chuyển sang kiểm soát thực sự
BEGIN
    BEGIN SA_POLICY_ADMIN.REMOVE_TABLE_POLICY('ACCESS_POLICY', 'TRASUA', 'CUSTOMER'); EXCEPTION WHEN OTHERS THEN NULL; END;

    SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
        policy_name    => 'ACCESS_POLICY',
        schema_name    => 'TRASUA',
        table_name     => 'CUSTOMER',
        table_options  => 'READ_CONTROL,WRITE_CONTROL,CHECK_CONTROL'
    );
    DBMS_OUTPUT.PUT_LINE('OLS ACCESS_POLICY da duoc ap dung len bang CUSTOMER');
END;
/

PROMPT === HOAN TAT TREN KICH BAN BAO MAT CUA YEN ===


