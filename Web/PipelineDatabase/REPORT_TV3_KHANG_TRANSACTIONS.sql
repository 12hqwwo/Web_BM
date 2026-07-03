-- ==============================================================================
-- BÁO CÁO CƠ SỞ DỮ LIỆU BẢO MẬT ORACLE
-- THÀNH VIÊN 3: KHANG (Cụm Giao dịch & Kế toán)
-- ==============================================================================
ALTER SESSION SET CURRENT_SCHEMA = TRASUA;

-- ==============================================================================
-- NHIỆM VỤ CHUNG: DBMS_FGA (Audit) Ghi log thao tác tài chính
-- ==============================================================================
-- FGA: Giám sát thao tác Hoàn tiền (Refund) và Trả hàng (Bill_Return)
BEGIN
    BEGIN DBMS_FGA.DROP_POLICY('TRASUA', 'BILL_RETURN', 'AUDIT_BILL_RETURN'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_FGA.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'BILL_RETURN',
        policy_name     => 'AUDIT_BILL_RETURN',
        audit_condition => '1=1',
        audit_column    => 'status, refund_amount',
        statement_types => 'INSERT, UPDATE, DELETE',
        enable          => TRUE
    );
END;
/

-- ==============================================================================
-- MỨC ĐỘ DỄ/VỪA: Viết PL/SQL Procedures cho Đơn hàng và Thanh toán
-- ==============================================================================
-- 1. Sequence sinh mã Hóa Đơn
BEGIN EXECUTE IMMEDIATE 'CREATE SEQUENCE SEQ_BILL_CODE START WITH 1 INCREMENT BY 1 NOCACHE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- 2. Procedure PROC_CREATE_ORDER (Thay thế CRUD)
CREATE OR REPLACE PROCEDURE PROC_CREATE_ORDER (
    p_billing_address   IN NVARCHAR2,    
    p_invoice_type      IN VARCHAR2,     
    p_payment_method_id IN NUMBER,       
    p_customer_id       IN NUMBER,       
    p_voucher_id        IN NUMBER,       
    p_promotion_price   IN NUMBER,       
    p_order_id_vnpay    IN VARCHAR2,     
    p_branch_id         IN NUMBER,       
    p_order_details_json IN CLOB,
    p_bill_id           OUT NUMBER,      
    p_bill_code         OUT VARCHAR2,    
    p_final_amount      OUT NUMBER,      
    p_error_code        OUT NUMBER,      
    p_error_msg         OUT NVARCHAR2    
) IS
    v_bill_code VARCHAR2(50);
    v_bill_id NUMBER;
BEGIN
    p_error_code := 0;
    -- Sinh mã Hóa đơn
    SELECT 'HD' || TO_CHAR(SYSDATE, 'YYYYMMDD') || LPAD(SEQ_BILL_CODE.NEXTVAL, 4, '0') INTO v_bill_code FROM DUAL;
    
    -- Khởi tạo Bill
    INSERT INTO bill (
        amount, billing_address, code, create_date, invoice_type, 
        promotion_price, status, customer_id, branch_id, payment_method_id
    ) VALUES (
        0, p_billing_address, v_bill_code, SYSTIMESTAMP, p_invoice_type, 
        NVL(p_promotion_price, 0), 'CHO_XAC_NHAN', p_customer_id, p_branch_id, p_payment_method_id
    ) RETURNING id INTO v_bill_id;

    -- (Logic parse JSON và tính tiền, trừ tồn kho chi tiết được thu gọn cho báo cáo)
    -- ...
    
    p_bill_id := v_bill_id;
    p_bill_code := v_bill_code;
    COMMIT;
EXCEPTION WHEN OTHERS THEN
    ROLLBACK; p_error_code := -1; p_error_msg := SQLERRM;
END;
/

-- ==============================================================================
-- MỨC ĐỘ VỪA: Viết Policy VPD (Giỏ hàng, Địa chỉ, Trạng thái)
-- ==============================================================================
-- Hàm dùng chung: Lọc theo account_id của khách hàng
CREATE OR REPLACE FUNCTION fn_vpd_customer_only (p_schema IN VARCHAR2, p_table IN VARCHAR2) RETURN VARCHAR2 AS
    v_acc_id VARCHAR2(100);
BEGIN
    v_acc_id := SYS_CONTEXT('auth_ctx', 'account_id');
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') IN ('SYSTEM', 'SYS') THEN RETURN '1=1'; END IF;
    IF v_acc_id IS NULL THEN RETURN '1=2'; END IF;
    RETURN 'account_id = ' || v_acc_id;
END;
/

-- 1. Giỏ hàng (CART)
BEGIN
    BEGIN DBMS_RLS.DROP_POLICY('TRASUA', 'CART', 'POL_CART_VPD'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_RLS.ADD_POLICY('TRASUA', 'CART', 'POL_CART_VPD', 'TRASUA', 'fn_vpd_customer_only', 'SELECT, UPDATE, DELETE');
END;
/

-- 2. Địa chỉ giao hàng (ADDRESS_SHIPPING)
BEGIN
    BEGIN DBMS_RLS.DROP_POLICY('TRASUA', 'ADDRESS_SHIPPING', 'POL_ADDRESS_VPD'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_RLS.ADD_POLICY('TRASUA', 'ADDRESS_SHIPPING', 'POL_ADDRESS_VPD', 'TRASUA', 'fn_vpd_customer_only', 'SELECT, UPDATE, DELETE');
END;
/

-- ==============================================================================
-- MỨC ĐỘ KHÓ: Hóa đơn (BILL) - Phân quyền dữ liệu OLS & RBAC
-- ==============================================================================
-- OLS: Gắn nhãn tự động cho Hóa đơn (Thực hiện bởi Trigger dựa trên OLS Core của Tín)
CREATE OR REPLACE TRIGGER trg_ols_bill_insert
BEFORE INSERT ON BILL
FOR EACH ROW
BEGIN
    IF :NEW.branch_id IS NOT NULL THEN
        :NEW.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB:BR' || :NEW.branch_id || ':OPR');
    ELSE
        :NEW.ols_label := CHAR_TO_LABEL('ACCESS_POLICY', 'PUB');
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
