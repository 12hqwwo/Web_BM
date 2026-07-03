-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 02_SECURITY_OLS_FGA_VPD_PROFILE_Tindeptry.sql
-- ============================================================
-- ==============================================================================
-- TẬP LỆNH BẢO MẬT CƠ SỞ DỮ LIỆU ORACLE (Mức độ Dễ, Vừa, Khó)
-- Tác giả: Tín (Thành viên 4)
-- Yêu cầu: 
-- 1. Chạy tập lệnh này bằng user SYS hoặc user có đặc quyền DBA (SYSDBA).
-- 2. Đã kích hoạt Oracle Label Security (chopt enable ols).
-- ==============================================================================

-- Thay đổi session context thành schema của dự án
ALTER SESSION SET CURRENT_SCHEMA = TRASUA;


-- ==============================================================================
-- MỨC ĐỘ DỄ: THIẾT LẬP RBAC CƠ BẢN (ROLES & PRIVILEGES)
-- Mục tiêu: Quản trị Dashboard và Chi nhánh
-- ==============================================================================
PROMPT --- 1. SETUP RBAC ROLES ---

-- Tạo các Roles
CREATE ROLE ROLE_ADMIN;
CREATE ROLE ROLE_VENDOR;
CREATE ROLE ROLE_STAFF;

-- Phân quyền cho ADMIN (Full quyền trên Dashboard và Quản lý)
GRANT SELECT, INSERT, UPDATE, DELETE ON branch TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON account TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON bill TO ROLE_ADMIN;

-- Phân quyền cho VENDOR (Chỉ được xem/cập nhật branch của mình, quản lý bill)
GRANT SELECT ON branch TO ROLE_VENDOR;
GRANT SELECT, INSERT, UPDATE ON bill TO ROLE_VENDOR;
GRANT SELECT ON account TO ROLE_VENDOR;

-- Phân quyền cho STAFF (Chỉ xử lý đơn hàng POS)
GRANT SELECT, INSERT, UPDATE ON bill TO ROLE_STAFF;
GRANT SELECT ON branch TO ROLE_STAFF;

-- Ghi chú: Cần Grant trực tiếp ROLE này cho các Oracle User tương ứng nếu ứng dụng map User Database với User App.
-- Ví dụ: GRANT ROLE_ADMIN TO C##ADMIN_USER;


-- ==============================================================================
-- MỨC ĐỘ VỪA: GIÁM SÁT FGA (FINE-GRAINED AUDITING)
-- Mục tiêu: Giám sát mã giảm giá và giảm giá sản phẩm
-- ==============================================================================
PROMPT --- 2. SETUP FINE-GRAINED AUDITING (FGA) ---

BEGIN
    -- Xóa policy cũ nếu tồn tại để tránh lỗi
    BEGIN DBMS_FGA.DROP_POLICY(object_schema => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), object_name => 'discount_code', policy_name => 'AUDIT_DISCOUNT_CODE'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN DBMS_FGA.DROP_POLICY(object_schema => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), object_name => 'product_discount', policy_name => 'AUDIT_PRODUCT_DISCOUNT'); EXCEPTION WHEN OTHERS THEN NULL; END;

    -- 1. Audit bảng discount_code (Giám sát khi ROLE_STAFF thực hiện INSERT, UPDATE, DELETE)
    DBMS_FGA.ADD_POLICY(
        object_schema   => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        object_name     => 'discount_code',
        policy_name     => 'AUDIT_DISCOUNT_CODE',
        audit_condition => 'SYS_CONTEXT(''branch_ctx'', ''user_role'') = ''ROLE_STAFF''',
        audit_column    => NULL,
        statement_types => 'INSERT, UPDATE, DELETE'
    );

    -- 2. Audit bảng product_discount (Giám sát khi ROLE_STAFF thay đổi discount_percentage hoặc status)
    DBMS_FGA.ADD_POLICY(
        object_schema   => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        object_name     => 'product_discount',
        policy_name     => 'AUDIT_PRODUCT_DISCOUNT',
        audit_condition => 'SYS_CONTEXT(''branch_ctx'', ''user_role'') = ''ROLE_STAFF''', 
        audit_column    => 'discountedamount, closed',
        statement_types => 'INSERT, UPDATE, DELETE'
    );
END;
/


-- ==============================================================================
-- MỨC ĐỘ KHÓ: TÍCH HỢP OLS & PROFILE PHỨC TẠP
-- Mục tiêu: Quản lý tài khoản (OLS), Doanh thu (VPD+OLS), Vendor (VPD+OLS), POS (Profile+OLS)
-- ==============================================================================

PROMPT --- 3.1 SETUP ORACLE PROFILES ---
-- Giới hạn session = 1 cho máy POS tại quầy
CREATE PROFILE POS_PROFILE LIMIT
    SESSIONS_PER_USER 1
    IDLE_TIME 60;

-- Gán profile này cho các user Staff/POS (Ví dụ)
-- ALTER USER c##pos_user1 PROFILE POS_PROFILE;


PROMPT --- 3.2 SETUP OLS (ORACLE LABEL SECURITY) ---

EXEC SA_SYSDBA.CREATE_POLICY(policy_name => 'ACCESS_POLICY', column_name => 'ols_label');

-- 1. Tạo Levels
EXEC SA_COMPONENTS.CREATE_LEVEL('ACCESS_POLICY', 1000, 'PUB', 'PUBLIC');
EXEC SA_COMPONENTS.CREATE_LEVEL('ACCESS_POLICY', 2000, 'CONF', 'CONFIDENTIAL');
EXEC SA_COMPONENTS.CREATE_LEVEL('ACCESS_POLICY', 3000, 'SEC', 'SECRET');

-- 2. Tạo Compartments (Theo Chi nhánh)
EXEC SA_COMPONENTS.CREATE_COMPARTMENT('ACCESS_POLICY', 100, 'BR1', 'BRANCH 1');
EXEC SA_COMPONENTS.CREATE_COMPARTMENT('ACCESS_POLICY', 200, 'BR2', 'BRANCH 2');

-- 3. Tạo Groups (Theo Bộ phận)
EXEC SA_COMPONENTS.CREATE_GROUP('ACCESS_POLICY', 10, 'MNG', 'MANAGEMENT');
EXEC SA_COMPONENTS.CREATE_GROUP('ACCESS_POLICY', 20, 'OPR', 'OPERATIONS');

-- A. THIẾT LẬP NHÃN CHO USER (USER AUTHORIZATION)
-- Cấp nhãn cho Admin (Được đọc ghi mọi thứ)
-- EXEC SA_USER_ADMIN.SET_USER_LABELS('ACCESS_POLICY', 'C##ADMIN', 'SEC:BR1,BR2:MNG,OPR');
-- Cấp nhãn cho Vendor Chi Nhánh 1 (Chỉ đọc/ghi dữ liệu Management & Operation của Branch 1)
-- EXEC SA_USER_ADMIN.SET_USER_LABELS('ACCESS_POLICY', 'C##VENDOR_BR1', 'CONF:BR1:MNG,OPR');
-- Cấp nhãn cho Staff Chi Nhánh 1 (Chỉ đọc/ghi dữ liệu Operation của Branch 1)
-- EXEC SA_USER_ADMIN.SET_USER_LABELS('ACCESS_POLICY', 'C##STAFF_BR1', 'PUB:BR1:OPR');


-- D. XỬ LÝ TRẠNG THÁI 'NO_CONTROL' (Bật kiểm soát thực sự)
-- Bước 1: Áp dụng Policy với NO_CONTROL để tạo cột ols_label
EXEC SA_POLICY_ADMIN.APPLY_TABLE_POLICY('ACCESS_POLICY', SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), 'account', 'NO_CONTROL');
EXEC SA_POLICY_ADMIN.APPLY_TABLE_POLICY('ACCESS_POLICY', SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), 'bill', 'NO_CONTROL');

-- Bước 2: Cập nhật nhãn mặc định cho các dữ liệu cũ (Nếu không có bước này thì dữ liệu cũ bị NULL nhãn và sẽ biến mất khi bật OLS)
UPDATE account SET ols_label = CHAR_TO_LABEL('ACCESS_POLICY', 'PUB') WHERE ols_label IS NULL;
UPDATE bill SET ols_label = CHAR_TO_LABEL('ACCESS_POLICY', 'PUB') WHERE ols_label IS NULL;
COMMIT;

-- B. TẠO TRIGGER TỰ ĐỘNG GÁN NHÃN KHI INSERT (Thay thế cho Label Function bị lỗi)
-- Sử dụng Database Trigger là giải pháp an toàn và ổn định nhất thay vì phụ thuộc vào SA_POLICY_ADMIN.APPLY_TABLE_POLICY label_function

CREATE OR REPLACE TRIGGER TRASUA.trg_ols_bill_insert
BEFORE INSERT ON TRASUA.bill
FOR EACH ROW
BEGIN
    IF :new.branch_id = 1 THEN
        :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB:BR1:OPR');
    ELSIF :new.branch_id = 2 THEN
        :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB:BR2:OPR');
    ELSE
        :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRASUA.trg_ols_account_insert
BEFORE INSERT ON TRASUA.account
FOR EACH ROW
BEGIN
    IF :new.branch_id = 1 THEN
        :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'CONF:BR1:MNG');
    ELSIF :new.branch_id = 2 THEN
        :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'CONF:BR2:MNG');
    ELSE
        :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB');
    END IF;
END;
/

-- Bước 3: Đổi Policy sang thực thi (Có bật READ_CONTROL, WRITE_CONTROL và tự động gọi Label Function)
BEGIN
    -- Remove trước, bọc riêng để xử lý trường hợp policy chưa áp dụng
    BEGIN SA_POLICY_ADMIN.REMOVE_TABLE_POLICY('ACCESS_POLICY', SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), 'account'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN SA_POLICY_ADMIN.REMOVE_TABLE_POLICY('ACCESS_POLICY', SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), 'bill');    EXCEPTION WHEN OTHERS THEN NULL; END;

    SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
        policy_name    => 'ACCESS_POLICY',
        schema_name    => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        table_name     => 'account',
        table_options  => 'READ_CONTROL,WRITE_CONTROL,CHECK_CONTROL'
    );

    SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
        policy_name    => 'ACCESS_POLICY',
        schema_name    => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        table_name     => 'bill',
        table_options  => 'READ_CONTROL,WRITE_CONTROL,CHECK_CONTROL'
    );
END;
/


PROMPT --- 3.3 SETUP VPD (VIRTUAL PRIVATE DATABASE) ---

-- Tạo một Context package để quản lý VPD
CREATE OR REPLACE CONTEXT branch_ctx USING pkg_branch_sec;

-- Tạo Package Set Context
CREATE OR REPLACE PACKAGE pkg_branch_sec IS
    PROCEDURE set_context(p_branch_id NUMBER, p_role_name VARCHAR2, p_account_id NUMBER);
END;
/
CREATE OR REPLACE PACKAGE BODY pkg_branch_sec IS
    PROCEDURE set_context(p_branch_id NUMBER, p_role_name VARCHAR2, p_account_id NUMBER) IS
    BEGIN
        DBMS_SESSION.SET_CONTEXT('branch_ctx', 'branch_id', TO_CHAR(p_branch_id));
        DBMS_SESSION.SET_CONTEXT('branch_ctx', 'user_role', p_role_name);
        DBMS_SESSION.SET_CONTEXT('branch_ctx', 'account_id', TO_CHAR(p_account_id));
    END;
END;
/

-- C. BẢO MẬT GÓI VPD (IMPEDANCE MISMATCH VỚI JAVA)
-- Thu hồi quyền gọi hàm của tất cả người dùng (Để tránh bị gọi lụi từ user khác)
REVOKE EXECUTE ON pkg_branch_sec FROM PUBLIC;
-- Chỉ cấp quyền gọi cho User đang được Spring Boot sử dụng (Bạn sửa tên user cho phù hợp)
-- GRANT EXECUTE ON pkg_branch_sec TO C##DB_APP;

-- Tạo Policy Function cho VPD
CREATE OR REPLACE FUNCTION fn_vpd_branch_sec(p_schema IN VARCHAR2, p_table IN VARCHAR2)
RETURN VARCHAR2
IS
    v_role VARCHAR2(100);
    v_branch_id VARCHAR2(10);
    v_account_id VARCHAR2(20);
BEGIN
    -- Lấy role, branch id, account id từ ứng dụng truyền vào qua Context
    v_role := SYS_CONTEXT('branch_ctx', 'user_role');
    v_branch_id := SYS_CONTEXT('branch_ctx', 'branch_id');
    v_account_id := SYS_CONTEXT('branch_ctx', 'account_id');
    
    -- Nếu là Admin (hoặc chưa đăng nhập), được xem tất cả (hoặc fallback policy)
    IF v_role = 'ROLE_ADMIN' OR v_role IS NULL THEN
        RETURN ''; 
    ELSIF v_role = 'ROLE_VENDOR' THEN
        -- Nếu là Vendor, được xem toàn bộ row thuộc chi nhánh của mình
        RETURN 'branch_id = ' || v_branch_id;
    ELSIF v_role = 'ROLE_STAFF' THEN
        -- Nếu là Staff, tùy theo bảng
        IF UPPER(p_table) = 'BILL' THEN
            -- Staff chỉ xem được hóa đơn do chính mình tạo (cashier) tại chi nhánh của mình
            RETURN 'branch_id = ' || v_branch_id || ' AND cashier_account_id = ' || v_account_id;
        ELSIF UPPER(p_table) = 'ACCOUNT' THEN
            -- Staff bị cấm hoàn toàn không được xem bảng ACCOUNT
            RETURN '1=0';
        ELSE
            -- Mặc định an toàn cho các bảng khác
            RETURN 'branch_id = ' || v_branch_id;
        END IF;
    ELSE
        RETURN '1=0'; -- Chặn hoàn toàn nếu role không hợp lệ
    END IF;
END;
/

-- Add RLS Policy cho bảng BILL (Thống kê doanh thu)
BEGIN
    BEGIN DBMS_RLS.DROP_POLICY(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), 'bill', 'VPD_POLICY_BILL_BRANCH'); EXCEPTION WHEN OTHERS THEN NULL; END;
    
    DBMS_RLS.ADD_POLICY(
        object_schema   => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        object_name     => 'bill',
        policy_name     => 'VPD_POLICY_BILL_BRANCH',
        function_schema => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        policy_function => 'fn_vpd_branch_sec',
        statement_types => 'SELECT, UPDATE, DELETE'
    );
END;
/

-- Add RLS Policy cho bảng ACCOUNT (Tài khoản Vendor theo nhánh)
BEGIN
    BEGIN DBMS_RLS.DROP_POLICY(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), 'account', 'VPD_POLICY_ACCOUNT_BRANCH'); EXCEPTION WHEN OTHERS THEN NULL; END;
    
    DBMS_RLS.ADD_POLICY(
        object_schema   => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        object_name     => 'account',
        policy_name     => 'VPD_POLICY_ACCOUNT_BRANCH',
        function_schema => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        policy_function => 'fn_vpd_branch_sec',
        statement_types => 'SELECT, UPDATE, DELETE'
    );
END;
/

PROMPT === HOÀN TẤT THIẾT LẬP BẢO MẬT OLS, FGA, VPD, PROFILE, RBAC ===


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: fix_vpd.sql
-- ============================================================
BEGIN
  BEGIN
    DBMS_RLS.DROP_POLICY(object_schema => 'TRASUA', object_name => 'BRANCH_INVENTORY', policy_name => 'POL_BRANCH_INVENTORY');
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    DBMS_RLS.DROP_POLICY(object_schema => 'TRASUA', object_name => 'BILL', policy_name => 'POLICY_BILL_STATUS');
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    DBMS_RLS.DROP_POLICY(object_schema => 'TRASUA', object_name => 'BILL', policy_name => 'VPD_POLICY_BILL_BRANCH');
  EXCEPTION WHEN OTHERS THEN NULL; END;
END;
/



