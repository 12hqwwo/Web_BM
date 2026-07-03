-- ==============================================================================
-- BÁO CÁO CƠ SỞ DỮ LIỆU BẢO MẬT ORACLE
-- THÀNH VIÊN 2: QUỲNH (Cụm Hàng hóa & Tồn kho)
-- ==============================================================================
ALTER SESSION SET CURRENT_SCHEMA = TRASUA;

-- ==============================================================================
-- NHIỆM VỤ CHUNG: TẠO CÁC ROLE CƠ BẢN
-- ==============================================================================
BEGIN EXECUTE IMMEDIATE 'CREATE ROLE ROLE_ADMIN'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'CREATE ROLE ROLE_VENDOR'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'CREATE ROLE ROLE_STAFF'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ==============================================================================
-- MỨC ĐỘ DỄ: Lệnh GRANT phân quyền cho Danh mục, Thương hiệu, Thuộc tính
-- ==============================================================================
-- ADMIN: Toàn quyền
GRANT SELECT, INSERT, UPDATE, DELETE ON category TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON brand TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON size_product TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON material TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON topping TO ROLE_ADMIN;

-- VENDOR/STAFF: Chỉ được xem (Read-only) các danh mục cốt lõi
GRANT SELECT ON category TO ROLE_VENDOR;
GRANT SELECT ON brand TO ROLE_VENDOR;
GRANT SELECT ON size_product TO ROLE_VENDOR;
GRANT SELECT ON material TO ROLE_VENDOR;
GRANT SELECT ON topping TO ROLE_VENDOR;

GRANT SELECT ON category TO ROLE_STAFF;
GRANT SELECT ON brand TO ROLE_STAFF;
GRANT SELECT ON size_product TO ROLE_STAFF;
GRANT SELECT ON material TO ROLE_STAFF;
GRANT SELECT ON topping TO ROLE_STAFF;

-- ==============================================================================
-- MỨC ĐỘ VỪA: Viết Policy VPD cho Shop Sản phẩm (Lọc cờ xóa)
-- ==============================================================================
CREATE OR REPLACE FUNCTION fn_vpd_hide_deleted_product (
    p_schema IN VARCHAR2, 
    p_table IN VARCHAR2
) RETURN VARCHAR2 AS
    v_role VARCHAR2(50);
BEGIN
    v_role := SYS_CONTEXT('branch_ctx', 'user_role');
    -- Trả về tất cả nếu là DBA hoặc Admin
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') IN ('SYS', 'SYSTEM') OR v_role = 'ROLE_ADMIN' THEN
        RETURN '1=1';
    END IF;
    -- Với Vendor, Staff hoặc Khách hàng: Chỉ hiển thị sản phẩm có status = 1 (Đang bán)
    RETURN 'status = 1';
END;
/

BEGIN
    BEGIN DBMS_RLS.DROP_POLICY('TRASUA', 'PRODUCT', 'POL_HIDE_DELETED_PRODUCT'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'PRODUCT',
        policy_name     => 'POL_HIDE_DELETED_PRODUCT',
        function_schema => 'TRASUA',
        policy_function => 'fn_vpd_hide_deleted_product',
        statement_types => 'SELECT',
        enable          => TRUE
    );
END;
/

-- ==============================================================================
-- MỨC ĐỘ KHÓ: Kết hợp đa cơ chế (VPD + OLS + FGA) cho Tồn Kho Chi Nhánh
-- ==============================================================================
-- 1. FGA: Viết Audit giám sát khi cập nhật số lượng tồn kho bằng tay
BEGIN
    BEGIN DBMS_FGA.DROP_POLICY('TRASUA', 'BRANCH_INVENTORY', 'AUDIT_INVENTORY_UPDATE'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_FGA.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'BRANCH_INVENTORY',
        policy_name     => 'AUDIT_INVENTORY_UPDATE',
        audit_condition => '1=1',
        audit_column    => 'quantity',
        statement_types => 'UPDATE, INSERT, DELETE',
        enable          => TRUE
    );
END;
/

-- 2. VPD: Giới hạn Staff/Vendor chỉ xem tồn kho của chi nhánh mình
CREATE OR REPLACE FUNCTION fn_vpd_branch_inventory (p_schema IN VARCHAR2, p_table IN VARCHAR2) RETURN VARCHAR2 AS
    v_role VARCHAR2(50);
    v_branch_id VARCHAR2(10);
BEGIN
    v_role := SYS_CONTEXT('branch_ctx', 'user_role');
    v_branch_id := SYS_CONTEXT('branch_ctx', 'branch_id');
    
    IF v_role = 'ROLE_ADMIN' OR v_role IS NULL THEN RETURN '1=1'; END IF;
    RETURN 'branch_id = ' || v_branch_id;
END;
/
BEGIN
    BEGIN DBMS_RLS.DROP_POLICY('TRASUA', 'BRANCH_INVENTORY', 'POL_BRANCH_INVENTORY_VPD'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'BRANCH_INVENTORY',
        policy_name     => 'POL_BRANCH_INVENTORY_VPD',
        function_schema => 'TRASUA',
        policy_function => 'fn_vpd_branch_inventory',
        statement_types => 'SELECT, UPDATE'
    );
END;
/

-- 3. OLS: Gắn nhãn Confidential cho Branch Inventory (Tuỳ chọn cấu hình bởi Tín)
-- Kế thừa ACCESS_POLICY từ OLS Core của Tín
CREATE OR REPLACE TRIGGER trg_ols_branch_inventory
BEFORE INSERT ON BRANCH_INVENTORY
FOR EACH ROW
BEGIN
    :NEW.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'CONF:BR' || :NEW.branch_id || ':OPR');
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
