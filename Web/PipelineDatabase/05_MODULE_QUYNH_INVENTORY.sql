-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 10_SECURITY_QUYNH_INVENTORY_PRODUCTS.sql
-- ============================================================
-- ==============================================================================
-- Táº¬P Lá»†NH Báº¢O Máº¬T CÆ  Sá» Dá»® LIá»†U ORACLE
-- TĂ¡c giáº£: Quá»³nh (ThĂ nh viĂªn 2 - Cá»¥m HĂ ng HĂ³a & Tá»“n Kho)
-- YĂªu cáº§u: 
-- 1. Cháº¡y táº­p lá»‡nh nĂ y báº±ng user SYS hoáº·c user cĂ³ Ä‘áº·c quyá»n DBA (SYSDBA).
-- 2. Chá»‰ cháº¡y SAU KHI Ä‘Ă£ cháº¡y xong file 01_create_user_trasua.sql vĂ  00_MASTER_TRASUA.sql
-- ==============================================================================

ALTER SESSION SET CURRENT_SCHEMA = TRASUA;

GRANT EXECUTE ON LBACSYS.SA_USER_ADMIN TO TRASUA;
GRANT EXECUTE ON LBACSYS.SA_COMPONENTS TO TRASUA;
GRANT EXECUTE ON LBACSYS.SA_LABEL_ADMIN TO TRASUA;


-- ==============================================================================
-- 1. Má»¨C Äá»˜ Dá»„: RBAC (PhĂ¢n quyá»n Role-Based Access Control)
-- ==============================================================================
BEGIN EXECUTE IMMEDIATE 'CREATE ROLE ROLE_ADMIN'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'CREATE ROLE ROLE_VENDOR'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'CREATE ROLE ROLE_STAFF'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- GĂN QUYá»€N CHO ADMIN (Full)
GRANT SELECT, INSERT, UPDATE, DELETE ON TRASUA.category TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON TRASUA.brand TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON TRASUA.size_product TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON TRASUA.material TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON TRASUA.topping TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON TRASUA.product TO ROLE_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON TRASUA.branch_inventory TO ROLE_ADMIN;

-- GĂN QUYá»€N CHO VENDOR (Quáº£n lĂ½ chi nhĂ¡nh - Chá»‰ Ä‘Æ°á»£c Xem, Cáº­p nháº­t Tá»“n kho)
GRANT SELECT ON TRASUA.category TO ROLE_VENDOR;
GRANT SELECT ON TRASUA.brand TO ROLE_VENDOR;
GRANT SELECT ON TRASUA.size_product TO ROLE_VENDOR;
GRANT SELECT ON TRASUA.material TO ROLE_VENDOR;
GRANT SELECT ON TRASUA.topping TO ROLE_VENDOR;
GRANT SELECT ON TRASUA.product TO ROLE_VENDOR;
GRANT SELECT, UPDATE ON TRASUA.branch_inventory TO ROLE_VENDOR;

-- GĂN QUYá»€N CHO STAFF (NhĂ¢n viĂªn bĂ¡n hĂ ng - Chá»‰ Ä‘Æ°á»£c Xem)
GRANT SELECT ON TRASUA.category TO ROLE_STAFF;
GRANT SELECT ON TRASUA.brand TO ROLE_STAFF;
GRANT SELECT ON TRASUA.size_product TO ROLE_STAFF;
GRANT SELECT ON TRASUA.material TO ROLE_STAFF;
GRANT SELECT ON TRASUA.topping TO ROLE_STAFF;
GRANT SELECT ON TRASUA.product TO ROLE_STAFF;
GRANT SELECT ON TRASUA.branch_inventory TO ROLE_STAFF;

-- GĂN ROLE CHO CĂC USER MáºªU (Thay tháº¿ admin_user / vendor_user báº±ng tĂªn thá»±c táº¿ náº¿u cĂ³)
-- GRANT ROLE_ADMIN TO admin_user;
-- GRANT ROLE_VENDOR TO vendor_user;
-- GRANT ROLE_STAFF TO staff_user;


-- ==============================================================================
-- 2. Má»¨C Äá»˜ Vá»ªA: VPD (Virtual Private Database) - Lá»c sáº£n pháº©m tráº¡ng thĂ¡i 0
-- ==============================================================================
CREATE OR REPLACE FUNCTION filter_active_product (
    p_schema IN VARCHAR2, 
    p_table IN VARCHAR2
) 
RETURN VARCHAR2 AS
    v_role VARCHAR2(50);
BEGIN
    -- Láº¥y Role tá»« Spring Boot Web Context (Ä‘Ă£ Ä‘Æ°á»£c VpdContextFilter set qua pkg_branch_sec)
    v_role := SYS_CONTEXT('branch_ctx', 'user_role');
    
    -- Tráº£ vá» táº¥t cáº£ náº¿u lĂ  DBA truy cáº­p qua SQL Developer
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') IN ('SYS', 'SYSTEM') THEN
        RETURN '1=1';
    -- Tráº£ vá» táº¥t cáº£ náº¿u lĂ  Admin truy cáº­p qua Web
    ELSIF v_role = 'ROLE_ADMIN' THEN
        RETURN '1=1';
    ELSE
        -- Chá»‰ áº©n sáº£n pháº©m vá»›i User Guest/Staff giá»›i háº¡n
        RETURN 'status = 1';
    END IF;
END filter_active_product;
/

BEGIN
    -- XoĂ¡ policy cÅ© náº¿u cĂ³ Ä‘á»ƒ trĂ¡nh lá»—i khi cháº¡y láº¡i
    BEGIN
        DBMS_RLS.DROP_POLICY('TRASUA', 'product', 'hide_deleted_product_vpd');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    DBMS_RLS.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'product',
        policy_name     => 'hide_deleted_product_vpd',
        function_schema => 'TRASUA',
        policy_function => 'filter_active_product',
        statement_types => 'SELECT',
        enable          => TRUE
    );
END;
/


-- ==============================================================================
-- 3. Má»¨C Äá»˜ KHĂ“: TĂCH Há»¢P OLS & TRIGGER Báº¢O Máº¬T & FGA
-- YĂªu cáº§u: CHáº Y Báº°NG LBACSYS HOáº¶C USER CĂ“ á»¦Y QUYá»€N LBAC_DBA
-- ==============================================================================

-- 3.1 Khá»Ÿi táº¡o Policy OLS (MĂ´ phá»ng)
-- (Pháº§n nĂ y LBACSYS thá»±c hiá»‡n. XoĂ¡ Policy cÅ© náº¿u muá»‘n reset)
/*
EXEC SA_SYSDBA.DROP_POLICY('BRANCH_OLS_POLICY', TRUE);
*/
BEGIN
    BEGIN SA_SYSDBA.CREATE_POLICY('BRANCH_OLS_POLICY', 'branch_label'); EXCEPTION WHEN OTHERS THEN NULL; END;
    
    -- Táº¡o Levels
    BEGIN SA_COMPONENTS.CREATE_LEVEL('BRANCH_OLS_POLICY', 10, 'PUBLIC', 'Public Data'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN SA_COMPONENTS.CREATE_LEVEL('BRANCH_OLS_POLICY', 20, 'CONFIDENTIAL', 'Branch Confidential'); EXCEPTION WHEN OTHERS THEN NULL; END;
    
    -- Tá»± Ä‘á»™ng Táº¡o Compartments vĂ  Labels cho Táº¤T Cáº¢ cĂ¡c chi nhĂ¡nh Ä‘ang cĂ³ trong báº£ng TRASUA.branch_inventory
    FOR b IN (SELECT DISTINCT branch_id FROM TRASUA.branch_inventory WHERE branch_id IS NOT NULL) LOOP
        -- Táº¡o Compartment
        BEGIN SA_COMPONENTS.CREATE_COMPARTMENT('BRANCH_OLS_POLICY', b.branch_id * 1000, 'CN' || b.branch_id, 'Chi Nhanh ' || b.branch_id); EXCEPTION WHEN OTHERS THEN NULL; END;
        -- Táº¡o Label
        BEGIN SA_LABEL_ADMIN.CREATE_LABEL('BRANCH_OLS_POLICY', 200000 + (b.branch_id * 1000), 'CONFIDENTIAL:CN' || b.branch_id); EXCEPTION WHEN OTHERS THEN NULL; END;
    END LOOP;
    
    -- Gáº¯n Policy vĂ o báº£ng branch_inventory
    BEGIN SA_POLICY_ADMIN.APPLY_TABLE_POLICY('BRANCH_OLS_POLICY', 'TRASUA', 'branch_inventory', 'READ_CONTROL, WRITE_CONTROL'); EXCEPTION WHEN OTHERS THEN NULL; END;
END;
/


-- 3.2 Tá»± Ä‘á»™ng hoĂ¡ NhĂ£n OLS (Trigger)
CREATE OR REPLACE TRIGGER trg_assign_inventory_ols_label
BEFORE INSERT ON TRASUA.branch_inventory
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    -- Thá»­ táº¡o Compartment vĂ  Label náº¿u chÆ°a cĂ³ sáºµn Ä‘á»ƒ trĂ¡nh lá»—i ORA-12401
    BEGIN LBACSYS.SA_COMPONENTS.CREATE_COMPARTMENT('BRANCH_OLS_POLICY', :NEW.branch_id * 1000, 'CN' || :NEW.branch_id, 'Chi Nhanh ' || :NEW.branch_id); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN LBACSYS.SA_LABEL_ADMIN.CREATE_LABEL('BRANCH_OLS_POLICY', 200000 + (:NEW.branch_id * 1000), 'CONFIDENTIAL:CN' || :NEW.branch_id); EXCEPTION WHEN OTHERS THEN NULL; END;
    COMMIT;
    
    :NEW.branch_label := CHAR_TO_LABEL('BRANCH_OLS_POLICY', 'CONFIDENTIAL:CN' || :NEW.branch_id);
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- 3.2.1 Cáº­p nháº­t NhĂ£n OLS cho dá»¯ liá»‡u Tá»“n Kho cÅ© (Kháº¯c phá»¥c lá»—i máº¥t dá»¯ liá»‡u khi gĂ¡n Policy)
BEGIN
    -- VĂ´ hiá»‡u hoĂ¡ Policy táº¡m thá»i Ä‘á»ƒ cáº¥p phĂ©p cáº­p nháº­t nhĂ£n cho dá»¯ liá»‡u cÅ© (TrĂ¡nh lá»—i ORA-12406)
    BEGIN SA_POLICY_ADMIN.DISABLE_TABLE_POLICY('BRANCH_OLS_POLICY', 'TRASUA', 'branch_inventory'); EXCEPTION WHEN OTHERS THEN NULL; END;
    
    UPDATE TRASUA.branch_inventory
    SET branch_label = CHAR_TO_LABEL('BRANCH_OLS_POLICY', 'CONFIDENTIAL:CN' || branch_id)
    WHERE branch_label IS NULL;
    
    -- KĂ­ch hoáº¡t láº¡i Policy
    BEGIN SA_POLICY_ADMIN.ENABLE_TABLE_POLICY('BRANCH_OLS_POLICY', 'TRASUA', 'branch_inventory'); EXCEPTION WHEN OTHERS THEN NULL; END;
    
    COMMIT;
END;
/


-- 3.3 TĂ­ch há»£p OLS vá»›i Spring Boot Web App (KhĂ´ng dĂ¹ng Trigger gĂ¡n nhĂ£n cá»©ng cho DB User)
-- VĂŒ SAO XOĂ TRIGGER Báº¢NG ACCOUNT CÅ¨?
-- -> Há»‡ thá»‘ng Web App sá»­ dá»¥ng 1 DB User chung (Connection Pool). Viá»‡c lÆ°u email vĂ o Oracle OLS User
-- sáº½ gĂ¢y lá»—i ORA-12461 (user does not exist).
-- CĂCH GIáº¢I QUYáº¾T: Web App (Java) sáº½ pháº£i gá»i lá»‡nh SA_SESSION.SET_LABEL má»—i khi cĂ³ request tá»›i!

-- Cáº¥p quyá»n Profile/Label tá»‘i Ä‘a cho user káº¿t ná»‘i Pool (vd: TRASUA) Ä‘á»ƒ Java cĂ³ thá»ƒ tuá»³ Ă½ set label
-- LÆ°u Ă½: Pháº£i cháº¡y báº±ng LBACSYS hoáº·c SYSDBA
BEGIN
    LBACSYS.SA_USER_ADMIN.SET_USER_PRIVS(
        policy_name => 'BRANCH_OLS_POLICY',
        user_name   => 'TRASUA',
        privileges  => 'READ,PROFILE_ACCESS'
    );
END;
/

-- ==============================================================================
-- 4. FGA (Fine-Grained Auditing)
-- ==============================================================================
BEGIN
    BEGIN
        DBMS_FGA.DROP_POLICY(object_schema => 'TRASUA', object_name => 'branch_inventory', policy_name => 'audit_inventory_update');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    DBMS_FGA.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'branch_inventory',
        policy_name     => 'audit_inventory_update',
        audit_condition => '1=1',
        audit_column    => 'quantity',
        statement_types => 'UPDATE',
        enable          => TRUE
    );
END;
/

-- ==============================================================================
-- 5. BĂ¡ÂºÂ£ng Inventory_Request vÄ‚Â  Inventory_Request_Detail
-- ==============================================================================
BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE TRASUA.inventory_request (
        id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
        branch_id NUMBER NOT NULL,
        created_by NUMBER NOT NULL,
        status VARCHAR2(20) DEFAULT ''PENDING'',
        note NVARCHAR2(500),
        created_at TIMESTAMP DEFAULT SYSTIMESTAMP,
        updated_at TIMESTAMP DEFAULT SYSTIMESTAMP,
        CONSTRAINT fk_inv_req_branch FOREIGN KEY (branch_id) REFERENCES TRASUA.branch(id)
    )';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE TRASUA.inventory_request_detail (
        id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
        request_id NUMBER NOT NULL,
        product_detail_id NUMBER NOT NULL,
        requested_quantity NUMBER DEFAULT 0,
        approved_quantity NUMBER DEFAULT 0,
        CONSTRAINT fk_inv_reqd_req FOREIGN KEY (request_id) REFERENCES TRASUA.inventory_request(id),
        CONSTRAINT fk_inv_reqd_pd FOREIGN KEY (product_detail_id) REFERENCES TRASUA.product_detail(id)
    )';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
/

-- Ä‚Âp dĂ¡Â»Â¥ng OLS cho inventory_request
BEGIN
    BEGIN
        LBACSYS.SA_POLICY_ADMIN.REMOVE_TABLE_POLICY('BRANCH_OLS_POLICY', 'TRASUA', 'inventory_request');
    EXCEPTION WHEN OTHERS THEN NULL; END;
    
    LBACSYS.SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
        policy_name    => 'BRANCH_OLS_POLICY',
        schema_name    => 'TRASUA',
        table_name     => 'inventory_request',
        table_options  => 'READ_CONTROL,WRITE_CONTROL,CHECK_CONTROL'
    );
END;
/

-- TĂ¡ÂºÂ¡o Trigger tĂ¡Â»Â± Ă„â€˜Ă¡Â»â„¢ng gĂ¡ÂºÂ¯n nhÄ‚Â£n OLS cho bĂ¡ÂºÂ£ng inventory_request khi INSERT
CREATE OR REPLACE TRIGGER TRASUA.trg_ols_inventory_request
BEFORE INSERT ON TRASUA.inventory_request
FOR EACH ROW
BEGIN
    :NEW.branch_label := CHAR_TO_LABEL('BRANCH_OLS_POLICY', 'CONFIDENTIAL:CN' || :NEW.branch_id);
END;
/


