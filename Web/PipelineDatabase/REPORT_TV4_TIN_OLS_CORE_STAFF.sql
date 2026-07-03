-- ==============================================================================
-- BÁO CÁO CƠ SỞ DỮ LIỆU BẢO MẬT ORACLE
-- THÀNH VIÊN 4: TÍN (OLS Core, Phân quyền POS Staff)
-- KHẮC PHỤC TRIỆT ĐỂ CÁC LỖI ORA- & NULL POINTER EXCEPTION
-- ==============================================================================

-- ==============================================================================
-- NHIỆM VỤ CHUNG: THIẾT LẬP CỐT LÕI OLS (ORACLE LABEL SECURITY)
-- ==============================================================================
-- Yêu cầu chạy bằng LBACSYS hoặc user có quyền quản trị OLS SA_SYSDBA

BEGIN
    BEGIN SA_SYSDBA.CREATE_POLICY(policy_name => 'ACCESS_POLICY', column_name => 'ols_label'); EXCEPTION WHEN OTHERS THEN NULL; END;

    -- 1. Levels
    BEGIN SA_COMPONENTS.CREATE_LEVEL('ACCESS_POLICY', 1000, 'PUB', 'PUBLIC'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN SA_COMPONENTS.CREATE_LEVEL('ACCESS_POLICY', 2000, 'CONF', 'CONFIDENTIAL'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN SA_COMPONENTS.CREATE_LEVEL('ACCESS_POLICY', 3000, 'SEC', 'SENSITIVE'); EXCEPTION WHEN OTHERS THEN NULL; END;

    -- 2. Compartments
    BEGIN SA_COMPONENTS.CREATE_COMPARTMENT('ACCESS_POLICY', 100, 'BR1', 'BRANCH 1'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN SA_COMPONENTS.CREATE_COMPARTMENT('ACCESS_POLICY', 200, 'BR2', 'BRANCH 2'); EXCEPTION WHEN OTHERS THEN NULL; END;

    -- 3. Groups
    BEGIN SA_COMPONENTS.CREATE_GROUP('ACCESS_POLICY', 10, 'MNG', 'MANAGEMENT'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN SA_COMPONENTS.CREATE_GROUP('ACCESS_POLICY', 20, 'OPR', 'OPERATIONS'); EXCEPTION WHEN OTHERS THEN NULL; END;
END;
/

-- Gỡ Policy cũ ra trước khi Cập nhật Label để không bị lỗi
BEGIN 
    BEGIN SA_POLICY_ADMIN.REMOVE_TABLE_POLICY('ACCESS_POLICY', 'TRASUA', 'ACCOUNT'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN SA_POLICY_ADMIN.REMOVE_TABLE_POLICY('ACCESS_POLICY', 'TRASUA', 'BILL'); EXCEPTION WHEN OTHERS THEN NULL; END;
END;
/

-- Cập nhật label cho TẤT CẢ Account thành PUB để Staff có thể SELECT được tài khoản của chính mình (Khắc phục lỗi EntityNotFoundException id 201)
UPDATE TRASUA.account SET ols_label = CHAR_TO_LABEL('ACCESS_POLICY', 'PUB');
-- Cập nhật Bill cũ thành PUB để tránh lỗi
UPDATE TRASUA.bill SET ols_label = CHAR_TO_LABEL('ACCESS_POLICY', 'PUB') WHERE ols_label IS NULL;
COMMIT;

-- Bật kiểm soát thực sự
BEGIN
    SA_POLICY_ADMIN.APPLY_TABLE_POLICY('ACCESS_POLICY', 'TRASUA', 'ACCOUNT', 'READ_CONTROL,WRITE_CONTROL,CHECK_CONTROL');
    SA_POLICY_ADMIN.APPLY_TABLE_POLICY('ACCESS_POLICY', 'TRASUA', 'BILL', 'READ_CONTROL,WRITE_CONTROL,CHECK_CONTROL');
END;
/

-- ==============================================================================
-- MỨC ĐỘ DỄ: RBAC CƠ BẢN (Block Staff)
-- ==============================================================================
GRANT SELECT ON TRASUA.branch TO ROLE_STAFF; 

-- ==============================================================================
-- MỨC ĐỘ VỪA: GIÁM SÁT FGA (Mã giảm giá, Giảm giá sản phẩm)
-- ==============================================================================
ALTER SESSION SET CURRENT_SCHEMA = TRASUA;

BEGIN
    BEGIN DBMS_FGA.DROP_POLICY('TRASUA', 'DISCOUNT_CODE', 'AUDIT_DISCOUNT_CODE_STAFF'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_FGA.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'DISCOUNT_CODE',
        policy_name     => 'AUDIT_DISCOUNT_CODE_STAFF',
        audit_condition => 'SYS_CONTEXT(''branch_ctx'', ''user_role'') = ''ROLE_STAFF''',
        audit_column    => NULL,
        statement_types => 'INSERT, UPDATE, DELETE'
    );

    BEGIN DBMS_FGA.DROP_POLICY('TRASUA', 'PRODUCT_DISCOUNT', 'AUDIT_PRODUCT_DISCOUNT_STAFF'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_FGA.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'PRODUCT_DISCOUNT',
        policy_name     => 'AUDIT_PRODUCT_DISCOUNT_STAFF',
        audit_condition => 'SYS_CONTEXT(''branch_ctx'', ''user_role'') = ''ROLE_STAFF''', 
        audit_column    => 'discountedamount, closed',
        statement_types => 'INSERT, UPDATE, DELETE'
    );
END;
/

-- ==============================================================================
-- MỨC ĐỘ KHÓ: TÍCH HỢP OLS, VPD & PROFILE CHO POS
-- ==============================================================================
-- 1. ORACLE PROFILE: Giới hạn SESSIONS_PER_USER = 1 cho máy POS (Chống share account)
-- (Lưu ý: Đã giải thích cho báo cáo rằng Profile này chỉ áp dụng Client-Server, còn Web phải dùng Spring Security)
BEGIN
    EXECUTE IMMEDIATE 'CREATE PROFILE POS_PROFILE LIMIT SESSIONS_PER_USER 1 IDLE_TIME 60';
EXCEPTION WHEN OTHERS THEN NULL; -- Bỏ qua nếu Profile đã tồn tại
END;
/

-- 2. VPD: Quản lý Tài Khoản & Doanh thu
CREATE OR REPLACE CONTEXT branch_ctx USING pkg_branch_sec;
/

CREATE OR REPLACE FUNCTION fn_vpd_staff_restriction(p_schema IN VARCHAR2, p_table IN VARCHAR2)
RETURN VARCHAR2 IS
    v_role VARCHAR2(100);
    v_branch_id VARCHAR2(10);
    v_account_id VARCHAR2(20);
BEGIN
    v_role := SYS_CONTEXT('branch_ctx', 'user_role');
    v_branch_id := SYS_CONTEXT('branch_ctx', 'branch_id');
    v_account_id := SYS_CONTEXT('branch_ctx', 'account_id');
    
    IF v_role = 'ROLE_ADMIN' OR v_role IS NULL THEN RETURN ''; END IF;
    IF v_role = 'ROLE_USER' THEN RETURN ''; END IF;
    
    IF v_role = 'ROLE_STAFF' THEN
        IF UPPER(p_table) = 'ACCOUNT' THEN
            RETURN 'id = ' || v_account_id; -- Khắc phục lỗi NullPointerException Profile
        ELSIF UPPER(p_table) = 'BILL' THEN
            RETURN 'branch_id = ' || v_branch_id; -- Staff xem được toàn bộ hoá đơn của chi nhánh
        END IF;
    END IF;
    
    RETURN 'branch_id = ' || v_branch_id; -- Dành cho Vendor
END;
/

BEGIN
    BEGIN DBMS_RLS.DROP_POLICY('TRASUA', 'ACCOUNT', 'VPD_POL_ACCOUNT_STAFF'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_RLS.ADD_POLICY('TRASUA', 'ACCOUNT', 'VPD_POL_ACCOUNT_STAFF', 'TRASUA', 'fn_vpd_staff_restriction', 'SELECT, UPDATE, DELETE');

    BEGIN DBMS_RLS.DROP_POLICY('TRASUA', 'BILL', 'VPD_POL_BILL_STAFF'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_RLS.ADD_POLICY('TRASUA', 'BILL', 'VPD_POL_BILL_STAFF', 'TRASUA', 'fn_vpd_staff_restriction', 'SELECT, UPDATE, DELETE');
END;
/

-- ==============================================================================
-- 3. TRIGGER: Tự động gán người tạo (Cashier) từ Context để VPD không ẩn mất hóa đơn
-- ==============================================================================
CREATE OR REPLACE TRIGGER TRASUA.trg_ols_bill_insert
BEFORE INSERT ON TRASUA.bill FOR EACH ROW
BEGIN
    -- Thiết lập OLS Label
    IF :new.branch_id = 1 THEN :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB:BR1:OPR');
    ELSIF :new.branch_id = 2 THEN :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB:BR2:OPR');
    ELSE :new.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB'); END IF;
    
    -- Tự động gán người tạo (Cashier) từ Context nếu chưa có (Khắc phục lỗi Null BillDetail)
    IF :new.cashier_account_id IS NULL AND SYS_CONTEXT('branch_ctx', 'account_id') IS NOT NULL THEN
        :new.cashier_account_id := TO_NUMBER(SYS_CONTEXT('branch_ctx', 'account_id'));
    END IF;
    -- Tương tự cho branch_id nếu ứng dụng quên truyền
    IF :new.branch_id IS NULL AND SYS_CONTEXT('branch_ctx', 'branch_id') IS NOT NULL THEN
        :new.branch_id := TO_NUMBER(SYS_CONTEXT('branch_ctx', 'branch_id'));
    END IF;
END;
/
