-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 1_PROC_CREATE_ORDER.sql
-- ============================================================
-- ==========================================
-- 0. T?O SEQUENCE CHO M? H�A ��N
-- ==========================================
BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE SEQ_BILL_CODE START WITH 1 INCREMENT BY 1 NOCACHE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -955 THEN RAISE; END IF;
END;
/
-- =================================================================
-- PROC_CREATE_ORDER.sql
-- Stored Procedure: Tạo đơn hàng (Bắt buộc sử dụng)
-- Schema: TRASUA (Oracle 12c+)
-- Mọi đặt hàng phải đi qua procedure này.
-- Không cho phép thực thi business logic Java trực tiếp.
-- =================================================================

-- RBAC: Grant quyền EXECUTE (chạy bởi DBA 1 lần)
-- GRANT EXECUTE ON PROC_CREATE_ORDER TO TRASUA;
-- REVOKE EXECUTE ON PROC_CREATE_ORDER FROM PUBLIC;

CREATE OR REPLACE PROCEDURE PROC_CREATE_ORDER (
    -- ===== INPUT: thông tin đơn hàng =====
    p_billing_address   IN NVARCHAR2,    -- địa chỉ giao hàng
    p_invoice_type      IN VARCHAR2,     -- 'ONLINE' | 'OFFLINE'
    p_payment_method_id IN NUMBER,       -- ID phương thức thanh toán
    p_customer_id       IN NUMBER,       -- NULL nếu khách vãng lai
    p_voucher_id        IN NUMBER,       -- NULL nếu không dùng voucher
    p_promotion_price   IN NUMBER,       -- số tiền giảm từ voucher
    p_order_id_vnpay    IN VARCHAR2,     -- mã VNPay (chuyển khoản), NULL nếu tiền mặt
    p_branch_id         IN NUMBER,       -- NULL nếu online không chọn chi nhánh
    -- ===== INPUT: chi tiết sản phẩm (JSON Array) =====
    -- Format: '[{"productDetailId":1,"quantity":2,"toppings":[{"name":"Trân châu","price":5000}]}]'
    p_order_details_json IN CLOB,
    -- ===== OUTPUT =====
    p_bill_id           OUT NUMBER,      -- ID hóa đơn vừa tạo
    p_bill_code         OUT VARCHAR2,    -- mã hóa đơn (HDxxx)
    p_final_amount      OUT NUMBER,      -- tổng tiền cuối cùng
    p_error_code        OUT NUMBER,      -- 0 = thành công, âm = lỗi nghiệp vụ
    p_error_msg         OUT NVARCHAR2    -- mô tả lỗi nếu có
)
IS
    -- ===== Biến nội bộ =====
    v_bill_id           NUMBER(19);
    v_bill_code         VARCHAR2(50);
    v_last_code         VARCHAR2(50);
    v_next_num          NUMBER := 1;
    v_num_part          VARCHAR2(50);
    v_total             NUMBER(19,2) := 0;
    v_final_total       NUMBER(19,2) := 0;
    v_promotion         NUMBER(19,2) := 0;

    -- ===== Biến xử lý sản phẩm =====
    v_pd_id             NUMBER(19);
    v_qty               NUMBER(10);
    v_pd_price          NUMBER(19,2);
    v_pd_qty_stock      NUMBER(10);
    v_pd_status         NUMBER(10);
    v_product_id        NUMBER(19);
    v_product_name      NVARCHAR2(255);
    v_discount_price    NUMBER(19,2);
    v_unit_price        NUMBER(19,2);
    v_topping_total     NUMBER(19,2);
    v_bill_detail_id    NUMBER(19);

    -- ===== Biến phụ =====
    v_discount_usage    NUMBER(10);
    v_pay_method_name   VARCHAR2(255);

    -- ===== Cursor: parse từng item trong JSON =====
    CURSOR c_items IS
        SELECT jt.product_detail_id,
               jt.quantity,
               jt.toppings_json
        FROM JSON_TABLE(p_order_details_json, '$[*]'
            COLUMNS (
                product_detail_id NUMBER        PATH '$.productDetailId',
                quantity          NUMBER        PATH '$.quantity',
                toppings_json     CLOB FORMAT JSON PATH '$.toppings'
            )
        ) jt;

BEGIN
    p_error_code := 0;
    p_error_msg  := NULL;

    -- ==============================================================
    -- BƯỚC 1: Sinh mã hóa đơn tự động bằng SEQUENCE (HD + YYYYMMDD + SEQ)
    -- Giải quyết triệt để lỗi Race Condition khi Concurrency cao
    -- ==============================================================
    SELECT 'HD' || TO_CHAR(SYSDATE, 'YYYYMMDD') || LPAD(SEQ_BILL_CODE.NEXTVAL, 4, '0') 
    INTO v_bill_code FROM DUAL;

    -- ==============================================================
    -- BƯỚC 2: Chuẩn hóa promotion price
    -- ==============================================================
    IF p_promotion_price IS NULL OR p_promotion_price < 0 THEN
        v_promotion := 0;
    ELSE
        v_promotion := p_promotion_price;
    END IF;

    -- ==============================================================
    -- BƯỚC 3: Kiểm tra voucher (nếu có)
    -- ==============================================================
    IF p_voucher_id IS NOT NULL THEN
        BEGIN
            SELECT maximum_usage INTO v_discount_usage
            FROM discount_code
            WHERE id = p_voucher_id;

            IF v_discount_usage <= 0 THEN
                p_error_code := -2;
                p_error_msg  := 'Mã giảm giá đã hết lượt sử dụng';
                RETURN;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_error_code := -3;
                p_error_msg  := 'Không tìm thấy voucher ID=' || p_voucher_id;
                RETURN;
        END;
    END IF;

    -- ==============================================================
    -- BƯỚC 4: Tạo bản ghi BILL
    -- Status tự động: OFFLINE → HOAN_THANH, ONLINE → CHO_XAC_NHAN
    -- ==============================================================
    INSERT INTO bill (
        amount, billing_address, code, create_date,
        invoice_type, promotion_price, return_status, status,
        update_date, customer_id, discount_code_id,
        payment_method_id, branch_id
    ) VALUES (
        0,
        p_billing_address,
        v_bill_code,
        SYSTIMESTAMP,
        p_invoice_type,
        v_promotion,
        0,
        CASE WHEN p_invoice_type = 'OFFLINE' THEN 'HOAN_THANH' ELSE 'CHO_XAC_NHAN' END,
        SYSTIMESTAMP,
        p_customer_id,
        p_voucher_id,
        p_payment_method_id,
        p_branch_id
    ) RETURNING id INTO v_bill_id;

    -- ==============================================================
    -- BƯỚC 5: Xử lý từng sản phẩm trong đơn hàng
    -- ==============================================================
    FOR rec IN c_items LOOP
        v_pd_id := rec.product_detail_id;
        v_qty   := rec.quantity;

        -- Lấy thông tin product_detail + product
        BEGIN
            SELECT pd.price, pd.quantity, p.status, p.id, p.name
            INTO   v_pd_price, v_pd_qty_stock, v_pd_status, v_product_id, v_product_name
            FROM   product_detail pd
            JOIN   product p ON p.id = pd.product_id
            WHERE  pd.id = v_pd_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                ROLLBACK;
                p_error_code := -4;
                p_error_msg  := 'Không tìm thấy sản phẩm ID=' || v_pd_id;
                RETURN;
        END;

        IF p_invoice_type = 'OFFLINE' THEN
            BEGIN
                SELECT quantity INTO v_pd_qty_stock
                FROM   branch_inventory
                WHERE  branch_id = p_branch_id AND product_detail_id = v_pd_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    ROLLBACK;
                    p_error_code := -6;
                    p_error_msg  := 'Sản phẩm ' || v_product_name || ' không có trong kho chi nhánh này';
                    RETURN;
            END;
        END IF;

        -- Kiểm tra ngừng bán (status = 2)
        IF v_pd_status = 2 THEN
            ROLLBACK;
            p_error_code := -5;
            p_error_msg  := 'Sản phẩm "' || v_product_name || '" đã ngừng bán';
            RETURN;
        END IF;

        -- Kiểm tra tồn kho đủ không
        IF v_pd_qty_stock - v_qty < 0 THEN
            ROLLBACK;
            p_error_code := -6;
            p_error_msg  := 'Sản phẩm "' || v_product_name
                         || '" chỉ còn lại ' || v_pd_qty_stock || ' sản phẩm';
            RETURN;
        END IF;

        BEGIN
            SELECT DISCOUNTEDAMOUNT INTO v_discount_price
            FROM   product_discount
            WHERE  product_detail_id = v_pd_id
              AND  closed = 0
              AND  STARTDATE <= SYSTIMESTAMP
              AND  ENDDATE   >= SYSTIMESTAMP
              AND  ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_discount_price := NULL;
        END;

        -- Giá đơn vị: ưu tiên giá giảm, fallback về giá gốc
        IF v_discount_price IS NOT NULL THEN
            v_unit_price := v_discount_price;
        ELSE
            v_unit_price := v_pd_price;
        END IF;

        -- Tính tổng topping của item này
        v_topping_total := 0;
        BEGIN
            SELECT NVL(SUM(jt.topping_price), 0)
            INTO   v_topping_total
            FROM   JSON_TABLE(rec.toppings_json, '$[*]'
                       COLUMNS (topping_price NUMBER PATH '$.price')
                   ) jt
            WHERE  jt.topping_price IS NOT NULL;
        EXCEPTION
            WHEN OTHERS THEN
                v_topping_total := 0;
        END;

        v_unit_price := v_unit_price + v_topping_total;
        v_total      := v_total + (v_unit_price * v_qty);

        -- Insert BILL_DETAIL
        INSERT INTO bill_detail (moment_price, quantity, return_quantity, bill_id, product_detail_id)
        VALUES (v_unit_price, v_qty, NULL, v_bill_id, v_pd_id)
        RETURNING id INTO v_bill_detail_id;

        -- Insert BILL_DETAIL_TOPPING (từng topping của item)
        IF rec.toppings_json IS NOT NULL THEN
            INSERT INTO bill_detail_topping (topping_name, topping_price, bill_detail_id)
            SELECT jt.topping_name, jt.topping_price, v_bill_detail_id
            FROM   JSON_TABLE(rec.toppings_json, '$[*]'
                       COLUMNS (
                           topping_name  NVARCHAR2(255) PATH '$.name',
                           topping_price NUMBER(19,2)   PATH '$.price'
                       )
                   ) jt
            WHERE  jt.topping_price IS NOT NULL;
        END IF;

        -- Trừ tồn kho
        IF p_invoice_type = 'OFFLINE' THEN
            UPDATE branch_inventory
            SET    quantity = quantity - v_qty
            WHERE  branch_id = p_branch_id AND product_detail_id = v_pd_id;
        ELSE
            UPDATE product_detail
            SET    quantity = quantity - v_qty
            WHERE  id = v_pd_id;
        END IF;

    END LOOP;

    -- ==============================================================
    -- BƯỚC 6: Giảm lượt dùng voucher
    -- ==============================================================
    IF p_voucher_id IS NOT NULL THEN
        UPDATE discount_code
        SET    maximum_usage = maximum_usage - 1
        WHERE  id = p_voucher_id;
    END IF;

    -- ==============================================================
    -- BƯỚC 7: Tính tổng tiền cuối (trừ khuyến mãi)
    -- ==============================================================
    v_final_total := v_total - v_promotion;
    IF v_final_total < 0 THEN
        v_final_total := 0;
    END IF;

    UPDATE bill
    SET    amount = v_final_total
    WHERE  id = v_bill_id;

    -- ==============================================================
    -- BƯỚC 8: Tạo bản ghi PAYMENT
    -- ==============================================================
    SELECT name INTO v_pay_method_name
    FROM   payment_method
    WHERE  id = p_payment_method_id;

    IF v_pay_method_name = 'TIEN_MAT' THEN
        -- Tiền mặt: tạo payment hoàn tất ngay
        INSERT INTO payment (amount, ORDERID, ORDERSTATUS, PAYMENTDATE, STATUSEXCHANGE, bill_id)
        VALUES (
            TO_CHAR(v_final_total),
            DBMS_RANDOM.STRING('X', 8),
            '1',
            SYSTIMESTAMP,
            0,
            v_bill_id
        );
    ELSIF p_order_id_vnpay IS NOT NULL THEN
        -- Chuyển khoản VNPay: gán bill_id vào payment đã tạo trước
        UPDATE payment
        SET    bill_id = v_bill_id,
               STATUSEXCHANGE = 0
        WHERE  ORDERID = p_order_id_vnpay;
    ELSE
        -- Offline / trường hợp khác: tạo payment
        INSERT INTO payment (amount, ORDERID, ORDERSTATUS, PAYMENTDATE, STATUSEXCHANGE, bill_id)
        VALUES (
            TO_CHAR(v_final_total),
            DBMS_RANDOM.STRING('X', 8),
            '1',
            SYSTIMESTAMP,
            0,
            v_bill_id
        );
    END IF;

    -- ==============================================================
    -- BƯỚC 9: Gán OUT parameters and commit
    -- ==============================================================
    p_bill_id      := v_bill_id;
    p_bill_code    := v_bill_code;
    p_final_amount := v_final_total;
    p_error_code   := 0;
    p_error_msg    := NULL;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_error_code   := -99;
        p_error_msg    := SQLERRM;
        p_bill_id      := NULL;
        p_bill_code    := NULL;
        p_final_amount := NULL;
END PROC_CREATE_ORDER;
/

-- =================================================================
-- Kiểm tra procedure đã tạo thành công
-- =================================================================
SELECT object_name, status
FROM   user_objects
WHERE  object_name = 'PROC_CREATE_ORDER';







-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 2_PROC_PAYMENT.sql
-- ============================================================
-- =================================================================
-- PROC_INIT_PAYMENT.sql
-- Procedure 1: Khởi tạo bản ghi Payment trước khi chuyển lên VNPay
-- Gọi TRƯỚC khi redirect sang cổng VNPay
-- Schema: TRASUA (Oracle 12c+)
-- RBAC: GRANT EXECUTE ON PROC_INIT_PAYMENT TO TRASUA;
-- =================================================================

CREATE OR REPLACE PROCEDURE PROC_INIT_PAYMENT (
    p_order_id      IN  VARCHAR2,       -- mã giao dịch ngẫu nhiên (8 ký tự)
    p_amount        IN  VARCHAR2,       -- số tiền (string, đơn vị VND)
    p_error_code    OUT NUMBER,         -- 0 = OK, khác = lỗi
    p_error_msg     OUT NVARCHAR2
)
IS
    v_exists NUMBER;
BEGIN
    p_error_code := 0;
    p_error_msg  := NULL;

    -- Kiểm tra trùng ORDERID
    SELECT COUNT(*) INTO v_exists FROM payment WHERE ORDERID = p_order_id;
    IF v_exists > 0 THEN
        p_error_code := -1;
        p_error_msg  := 'ORDERID đã tồn tại: ' || p_order_id;
        RETURN;
    END IF;

    INSERT INTO payment (amount, ORDERID, ORDERSTATUS, PAYMENTDATE, STATUSEXCHANGE, bill_id)
    VALUES (p_amount, p_order_id, '0', SYSTIMESTAMP, 0, NULL);

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_error_code := -99;
        p_error_msg  := SQLERRM;
END PROC_INIT_PAYMENT;
/

-- =================================================================
-- PROC_CONFIRM_PAYMENT.sql
-- Procedure 2: Xác nhận thanh toán VNPay thành công
-- Gọi SAU khi VNPay callback về, tạo Bill và liên kết Payment
-- RBAC: Không yêu cầu role cụ thể (callback từ VNPay server)
--       Bảo vệ bằng chữ ký HMAC ở tầng Java trước khi gọi procedure
-- =================================================================

CREATE OR REPLACE PROCEDURE PROC_CONFIRM_PAYMENT (
    -- ===== INPUT: từ VNPay callback =====
    p_order_id_vnpay    IN  VARCHAR2,   -- vnp_TxnRef (mã giao dịch VNPay)
    -- ===== INPUT: từ session (đơn hàng tạm) =====
    p_billing_address   IN  NVARCHAR2,
    p_payment_method_id IN  NUMBER,
    p_customer_id       IN  NUMBER,
    p_voucher_id        IN  NUMBER,
    p_promotion_price   IN  NUMBER,
    p_branch_id         IN  NUMBER,
    p_order_details_json IN CLOB,       -- JSON array sản phẩm + topping
    -- ===== OUTPUT =====
    p_bill_id           OUT NUMBER,
    p_bill_code         OUT VARCHAR2,
    p_final_amount      OUT NUMBER,
    p_error_code        OUT NUMBER,
    p_error_msg         OUT NVARCHAR2
)
IS
    v_bill_id           NUMBER(19);
    v_bill_code         VARCHAR2(50);
    v_last_code         VARCHAR2(50);
    v_next_num          NUMBER := 1;
    v_num_part          VARCHAR2(50);
    v_total             NUMBER(19,2) := 0;
    v_final_total       NUMBER(19,2) := 0;
    v_promotion         NUMBER(19,2) := 0;

    v_pd_id             NUMBER(19);
    v_qty               NUMBER(10);
    v_pd_price          NUMBER(19,2);
    v_pd_qty_stock      NUMBER(10);
    v_pd_status         NUMBER(10);
    v_product_name      NVARCHAR2(255);
    v_discount_price    NUMBER(19,2);
    v_unit_price        NUMBER(19,2);
    v_topping_total     NUMBER(19,2);
    v_bill_detail_id    NUMBER(19);
    v_discount_usage    NUMBER(10);
    v_payment_id        NUMBER(19);

    CURSOR c_items IS
        SELECT jt.product_detail_id,
               jt.quantity,
               jt.toppings_json
        FROM JSON_TABLE(p_order_details_json, '$[*]'
            COLUMNS (
                product_detail_id NUMBER        PATH '$.productDetailId',
                quantity          NUMBER        PATH '$.quantity',
                toppings_json     CLOB FORMAT JSON PATH '$.toppings'
            )
        ) jt;

BEGIN
    p_error_code := 0;
    p_error_msg  := NULL;

    -- ====================================================
    -- 1. Kiểm tra payment tồn tại và chưa xử lý (ORDERSTATUS='0')
    -- ====================================================
    BEGIN
        SELECT id INTO v_payment_id
        FROM   payment
        WHERE  ORDERID    = p_order_id_vnpay
          AND  ORDERSTATUS = '0';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_error_code := -1;
            p_error_msg  := 'Giao dịch không tồn tại hoặc đã được xử lý: ' || p_order_id_vnpay;
            RETURN;
    END;

    -- ====================================================
    -- 2. Sinh mã hóa đơn
    -- ====================================================
    BEGIN
        -- Sinh mã hóa đơn mới từ Sequence
        SELECT 'HD' || TO_CHAR(SYSDATE, 'YYYYMMDD') || LPAD(SEQ_BILL_CODE.NEXTVAL, 4, '0') 
        INTO v_bill_code FROM DUAL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN v_next_num := 1;
    END;

    -- ====================================================
    -- 3. Promotion price
    -- ====================================================
    IF p_promotion_price IS NULL OR p_promotion_price < 0 THEN
        v_promotion := 0;
    ELSE
        v_promotion := p_promotion_price;
    END IF;

    -- ====================================================
    -- 4. Kiểm tra voucher (nếu có)
    -- ====================================================
    IF p_voucher_id IS NOT NULL THEN
        BEGIN
            SELECT maximum_usage INTO v_discount_usage
            FROM   discount_code WHERE id = p_voucher_id;
            IF v_discount_usage <= 0 THEN
                p_error_code := -2;
                p_error_msg  := 'Mã giảm giá đã hết lượt sử dụng';
                RETURN;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_error_code := -3;
                p_error_msg  := 'Không tìm thấy voucher';
                RETURN;
        END;
    END IF;

    -- ====================================================
    -- 5. Tạo BILL (ONLINE, status CHO_XAC_NHAN)
    -- ====================================================
    INSERT INTO bill (
        amount, billing_address, code, create_date,
        invoice_type, promotion_price, return_status, status,
        update_date, customer_id, discount_code_id,
        payment_method_id, branch_id
    ) VALUES (
        0, p_billing_address, v_bill_code, SYSTIMESTAMP,
        'ONLINE', v_promotion, 0, 'CHO_XAC_NHAN',
        SYSTIMESTAMP, p_customer_id, p_voucher_id,
        p_payment_method_id, p_branch_id
    ) RETURNING id INTO v_bill_id;

    -- ====================================================
    -- 6. Xử lý từng sản phẩm
    -- ====================================================
    FOR rec IN c_items LOOP
        v_pd_id := rec.product_detail_id;
        v_qty   := rec.quantity;

        BEGIN
            SELECT pd.price, pd.quantity, p.status, p.name
            INTO   v_pd_price, v_pd_qty_stock, v_pd_status, v_product_name
            FROM   product_detail pd
            JOIN   product p ON p.id = pd.product_id
            WHERE  pd.id = v_pd_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                ROLLBACK;
                p_error_code := -4;
                p_error_msg  := 'Không tìm thấy sản phẩm ID=' || v_pd_id;
                RETURN;
        END;

        IF v_pd_status = 2 THEN
            ROLLBACK;
            p_error_code := -5;
            p_error_msg  := 'Sản phẩm "' || v_product_name || '" đã ngừng bán';
            RETURN;
        END IF;

        IF v_pd_qty_stock - v_qty < 0 THEN
            ROLLBACK;
            p_error_code := -6;
            p_error_msg  := 'Sản phẩm "' || v_product_name || '" chỉ còn lại ' || v_pd_qty_stock;
            RETURN;
        END IF;

        BEGIN
            SELECT DISCOUNTEDAMOUNT INTO v_discount_price
            FROM   product_discount
            WHERE  product_detail_id = v_pd_id
              AND  closed = 0
              AND  STARTDATE <= SYSTIMESTAMP
              AND  ENDDATE   >= SYSTIMESTAMP
              AND  ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN v_discount_price := NULL;
        END;

        v_unit_price := NVL(v_discount_price, v_pd_price);

        v_topping_total := 0;
        BEGIN
            SELECT NVL(SUM(jt.topping_price), 0) INTO v_topping_total
            FROM   JSON_TABLE(rec.toppings_json, '$[*]'
                       COLUMNS(topping_price NUMBER PATH '$.price')) jt
            WHERE  jt.topping_price IS NOT NULL;
        EXCEPTION WHEN OTHERS THEN v_topping_total := 0;
        END;

        v_unit_price := v_unit_price + v_topping_total;
        v_total      := v_total + (v_unit_price * v_qty);

        INSERT INTO bill_detail (moment_price, quantity, return_quantity, bill_id, product_detail_id)
        VALUES (v_unit_price, v_qty, NULL, v_bill_id, v_pd_id)
        RETURNING id INTO v_bill_detail_id;

        IF rec.toppings_json IS NOT NULL THEN
            INSERT INTO bill_detail_topping (topping_name, topping_price, bill_detail_id)
            SELECT jt.topping_name, jt.topping_price, v_bill_detail_id
            FROM   JSON_TABLE(rec.toppings_json, '$[*]'
                       COLUMNS(
                           topping_name  NVARCHAR2(255) PATH '$.name',
                           topping_price NUMBER(19,2)   PATH '$.price'
                       )) jt
            WHERE  jt.topping_price IS NOT NULL;
        END IF;

        UPDATE product_detail SET quantity = quantity - v_qty WHERE id = v_pd_id;
    END LOOP;

    -- ====================================================
    -- 7. Voucher + tổng tiền
    -- ====================================================
    IF p_voucher_id IS NOT NULL THEN
        UPDATE discount_code SET maximum_usage = maximum_usage - 1 WHERE id = p_voucher_id;
    END IF;

    v_final_total := GREATEST(v_total - v_promotion, 0);
    UPDATE bill SET amount = v_final_total WHERE id = v_bill_id;

    -- ====================================================
    -- 8. Liên kết Payment → Bill, đánh dấu đã thanh toán
    -- ====================================================
    UPDATE payment
    SET    bill_id      = v_bill_id,
           ORDERSTATUS = '1',
           PAYMENTDATE = SYSTIMESTAMP,
           STATUSEXCHANGE = 0
    WHERE  id = v_payment_id;

    -- ====================================================
    -- 9. OUT + COMMIT
    -- ====================================================
    p_bill_id      := v_bill_id;
    p_bill_code    := v_bill_code;
    p_final_amount := v_final_total;
    p_error_code   := 0;
    p_error_msg    := NULL;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_error_code   := -99;
        p_error_msg    := SQLERRM;
        p_bill_id      := NULL;
        p_bill_code    := NULL;
        p_final_amount := NULL;
END PROC_CONFIRM_PAYMENT;
/

-- =================================================================
-- Kiểm tra sau khi tạo
-- =================================================================
SELECT object_name, status FROM user_objects
WHERE  object_name IN ('PROC_INIT_PAYMENT', 'PROC_CONFIRM_PAYMENT');

-- =================================================================
-- RBAC: Grant execute (DBA chạy 1 lần)
-- GRANT EXECUTE ON PROC_INIT_PAYMENT    TO TRASUA;
-- GRANT EXECUTE ON PROC_CONFIRM_PAYMENT TO TRASUA;
-- REVOKE EXECUTE ON PROC_INIT_PAYMENT    FROM PUBLIC;
-- REVOKE EXECUTE ON PROC_CONFIRM_PAYMENT FROM PUBLIC;
-- =================================================================





-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 3_VPD_CART.sql
-- ============================================================
-- 3. VPD GIỎ HÀNG (Lọc CART theo customer_id)
-- Tối ưu: Bảo mật cao & Hiệu năng tốt (Best Practices cho VPD)

ALTER SESSION SET CURRENT_SCHEMA = TRASUA;

-- 1. Tạo Context
CREATE OR REPLACE CONTEXT ctx_trasua USING TRASUA.pkg_vpd_security;

-- 2. Package quản lý Context
CREATE OR REPLACE PACKAGE pkg_vpd_security AS
    PROCEDURE set_account_id(p_account_id IN NUMBER);
END pkg_vpd_security;
/

CREATE OR REPLACE PACKAGE BODY pkg_vpd_security AS
    PROCEDURE set_account_id(p_account_id IN NUMBER) IS
        v_customer_id account.customer_id%TYPE;
        v_role_id     account.role_id%TYPE;
        v_branch_id   account.branch_id%TYPE;
    BEGIN
        -- Clear context cũ trước khi set mới tránh rò rỉ dữ liệu (Best practice)
        DBMS_SESSION.CLEAR_CONTEXT('ctx_trasua', 'account_id');
        DBMS_SESSION.CLEAR_CONTEXT('ctx_trasua', 'customer_id');
        DBMS_SESSION.CLEAR_CONTEXT('ctx_trasua', 'role_id');
        DBMS_SESSION.CLEAR_CONTEXT('ctx_trasua', 'branch_id');

        IF p_account_id IS NOT NULL THEN
            DBMS_SESSION.SET_CONTEXT('ctx_trasua', 'account_id', p_account_id);
            BEGIN
                SELECT customer_id, role_id, branch_id 
                INTO v_customer_id, v_role_id, v_branch_id 
                FROM account WHERE id = p_account_id;
                
                IF v_customer_id IS NOT NULL THEN
                    DBMS_SESSION.SET_CONTEXT('ctx_trasua', 'customer_id', v_customer_id);
                END IF;
                IF v_role_id IS NOT NULL THEN
                    DBMS_SESSION.SET_CONTEXT('ctx_trasua', 'role_id', v_role_id);
                END IF;
                IF v_branch_id IS NOT NULL THEN
                    DBMS_SESSION.SET_CONTEXT('ctx_trasua', 'branch_id', v_branch_id);
                END IF;
            EXCEPTION 
                WHEN NO_DATA_FOUND THEN NULL; 
            END;
        END IF;
    END set_account_id;
END pkg_vpd_security;
/

-- 3. Policy Function
CREATE OR REPLACE FUNCTION fn_vpd_cart (p_schema IN VARCHAR2, p_table IN VARCHAR2) RETURN VARCHAR2 AS
    v_acc_id VARCHAR2(100);
    v_role_id VARCHAR2(100);
BEGIN
    v_acc_id := SYS_CONTEXT('ctx_trasua', 'account_id');
    v_role_id := SYS_CONTEXT('ctx_trasua', 'role_id');

    -- TH1: DBA chạy trực tiếp trên DB bằng quyền cao nhất (SYS/SYSTEM) -> Cho xem hết
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') IN ('SYSTEM', 'SYS') AND v_acc_id IS NULL THEN 
        RETURN '1=1'; 
    END IF;

    -- TH2: Ứng dụng chưa login -> Block toàn bộ (1=2) tránh rò rỉ dữ liệu.
    IF v_acc_id IS NULL THEN 
        RETURN '1=2'; 
    END IF;
    
    -- TH3: GIỎ HÀNG LÀ CÁ NHÂN HÓA 100%
    -- Kể cả Admin (1), Staff (2), Vendor (5) hay Customer (3, 4) khi mua hàng
    -- đều chỉ được nhìn thấy giỏ hàng của chính bản thân mình (Tránh lỗi trộn giỏ hàng)
    RETURN 'account_id = SYS_CONTEXT(''ctx_trasua'', ''account_id'')';
END;
/

-- 4. Áp dụng Policy
BEGIN
    BEGIN 
        DBMS_RLS.DROP_POLICY('TRASUA', 'CART', 'POLICY_CART'); 
    EXCEPTION 
        WHEN OTHERS THEN NULL; 
    END;
    
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'CART',
        policy_name     => 'POLICY_CART',
        function_schema => 'TRASUA',
        policy_function => 'fn_vpd_cart',
        statement_types => 'SELECT, UPDATE, DELETE',
        update_check    => TRUE -- Chặn UPDATE dữ liệu sang quyền người khác
    );
END;
/


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 4_VPD_ADDRESS.sql
-- ============================================================
-- 4. VPD ĐỊA CHỈ GIAO HÀNG (Lọc ADDRESS_SHIPPING theo customer_id)
-- Tối ưu: Bảo mật cao & Hiệu năng tốt (Best Practices cho VPD)

ALTER SESSION SET CURRENT_SCHEMA = TRASUA;

-- 1. Policy Function
CREATE OR REPLACE FUNCTION fn_vpd_address (p_schema IN VARCHAR2, p_table IN VARCHAR2) RETURN VARCHAR2 AS
    v_acc_id VARCHAR2(100);
    v_role_id VARCHAR2(100);
BEGIN
    v_acc_id := SYS_CONTEXT('ctx_trasua', 'account_id');
    v_role_id := SYS_CONTEXT('ctx_trasua', 'role_id');

    -- TH1: DBA chạy trực tiếp trên DB bằng quyền cao nhất -> Cho xem hết
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') IN ('SYSTEM', 'SYS') AND v_acc_id IS NULL THEN 
        RETURN '1=1'; 
    END IF;
    IF v_acc_id IS NULL THEN RETURN '1=2'; END IF;
    
    -- Admin(1), Staff(2), Vendor(5)
    IF v_role_id IN ('1', '2', '5') THEN
        RETURN '1=1';
    END IF;

    RETURN 'customer_id = SYS_CONTEXT(''ctx_trasua'', ''customer_id'')';
END;
/

-- 2. Áp dụng Policy
BEGIN
    BEGIN 
        DBMS_RLS.DROP_POLICY('TRASUA', 'ADDRESS_SHIPPING', 'POLICY_ADDRESS'); 
    EXCEPTION 
        WHEN OTHERS THEN NULL; 
    END;
    
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'ADDRESS_SHIPPING',
        policy_name     => 'POLICY_ADDRESS',
        function_schema => 'TRASUA',
        policy_function => 'fn_vpd_address',
        statement_types => 'SELECT, UPDATE, DELETE',
        update_check    => TRUE -- Chặn UPDATE địa chỉ sang ID người khác
    );
END;
/


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 5_VPD_ORDERSTATUS.sql
-- ============================================================
-- 5. VPD TRẠNG THÁI ĐƠN HÀNG (Lọc BILL theo customer_id)
-- Tối ưu: Bảo mật cao & Hiệu năng tốt (Best Practices cho VPD)
-- LƯU Ý: File này chỉ áp dụng VPD cho OrderStatus (user thường xem đơn của mình).
--         Bảng BILL còn có OLS (file 8) cho phân quyền cấp quản lý (STAFF/MANAGER/DIRECTOR).
--         Hai cơ chế hoạt động cùng nhau không xung đột.

ALTER SESSION SET CURRENT_SCHEMA = TRASUA;

-- 1. Policy Function
CREATE OR REPLACE FUNCTION fn_vpd_bill (p_schema IN VARCHAR2, p_table IN VARCHAR2) RETURN VARCHAR2 AS
    v_acc_id VARCHAR2(100);
    v_role_id VARCHAR2(100);
BEGIN
    v_acc_id := SYS_CONTEXT('ctx_trasua', 'account_id');
    v_role_id := SYS_CONTEXT('ctx_trasua', 'role_id');

    -- TH1: DBA chạy trực tiếp trên DB bằng quyền cao nhất -> Cho xem hết
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') IN ('SYSTEM', 'SYS') AND v_acc_id IS NULL THEN 
        RETURN '1=1'; 
    END IF;

    -- TH2: Ứng dụng chưa login -> Block toàn bộ.
    IF v_acc_id IS NULL THEN
        RETURN '1=2';
    END IF;
    
    -- TH3: Admin(1) hoặc Vendor(5) -> Xem toàn bộ
    IF v_role_id IN ('1', '5') THEN
        RETURN '1=1';
    END IF;
    
    -- TH4: Staff(2) -> Xem theo chi nhánh của mình
    IF v_role_id = '2' THEN
        RETURN 'branch_id = SYS_CONTEXT(''ctx_trasua'', ''branch_id'')';
    END IF;

    -- TH5: Customer (3, 4) -> Xem theo customer_id
    RETURN 'customer_id = SYS_CONTEXT(''ctx_trasua'', ''customer_id'')';
END;
/

-- 2. Áp dụng Policy
BEGIN
    BEGIN
        DBMS_RLS.DROP_POLICY('TRASUA', 'BILL', 'POLICY_BILL_STATUS');
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    DBMS_RLS.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'BILL',
        policy_name     => 'POLICY_BILL_STATUS',
        function_schema => 'TRASUA',
        policy_function => 'fn_vpd_bill',
        statement_types => 'SELECT, UPDATE, DELETE',
        update_check    => TRUE -- Chặn UPDATE bill_id sang customer khác
    );
END;
/


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 6_FGA_REFUND.sql
-- ============================================================
-- 6. FGA HOÀN TIỀN (Kiểm toán bảng PAYMENT)
-- Fine-Grained Auditing: Ghi log MỌI thao tác hoàn tiền nhạy cảm
-- Log xem tại: SELECT * FROM DBA_FGA_AUDIT_TRAIL WHERE policy_name = 'AUDIT_REFUND_PAYMENT';

ALTER SESSION SET CURRENT_SCHEMA = TRASUA;

BEGIN
    -- Xóa policy cũ (idempotent)
    BEGIN
        DBMS_FGA.DROP_POLICY('TRASUA', 'PAYMENT', 'AUDIT_REFUND_PAYMENT');
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    -- FGA: Ghi log khi UPDATE/DELETE trên cột nhạy cảm AMOUNT, STATUS_EXCHANGE
    -- audit_condition = NULL: Ghi log TẤT CẢ (không lọc điều kiện). Cũ dùng
    -- 'STATUS_EXCHANGE IS NOT NULL' có thể bỏ sót dòng vừa được reset về NULL.
    DBMS_FGA.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'PAYMENT',
        policy_name     => 'AUDIT_REFUND_PAYMENT',
        audit_condition => NULL,                        -- Bắt tất cả
        audit_column    => 'AMOUNT, STATUSEXCHANGE',    -- Chỉ khi 2 cột này bị chạm
        statement_types => 'UPDATE, DELETE',
        audit_trail     => DBMS_FGA.DB + DBMS_FGA.EXTENDED -- Lưu cả SQL text + bind var
    );
END;
/


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 7_FGA_BILLRETURN.sql
-- ============================================================
-- 7. FGA TRẢ HÀNG (BẢNG BILL_RETURN)
ALTER SESSION SET CURRENT_SCHEMA = TRASUA;
BEGIN
    BEGIN DBMS_FGA.DROP_POLICY('TRASUA', 'BILL_RETURN', 'AUDIT_BILL_RETURN'); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_FGA.ADD_POLICY(
        object_schema   => 'TRASUA',
        object_name     => 'BILL_RETURN',
        policy_name     => 'AUDIT_BILL_RETURN',
        audit_condition => '1=1', 
        audit_column    => 'RETURNMONEY, RETURNSTATUS',
        statement_types => 'INSERT, UPDATE, DELETE',
        audit_trail     => DBMS_FGA.DB + DBMS_FGA.EXTENDED
    );
END;
/


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 8_OLS_BILL.sql
-- ============================================================
-- 8. OLS HÓA ĐƠN (PHÂN QUYỀN TRÊN BẢNG BILL THEO COMPARTMENT)
-- ==========================================
-- PHẦN 1: CHẠY BẰNG USER CÓ QUYỀN LBAC_DBA (VD: LBACSYS hoặc SYS)
-- ==========================================
GRANT INHERIT PRIVILEGES ON USER SYS TO LBACSYS;

BEGIN
    -- 1. Xóa Policy cũ nếu có
    BEGIN
        SA_SYSDBA.DROP_POLICY('BILL_OLS_POL', TRUE);
    EXCEPTION WHEN OTHERS THEN NULL; END;

    -- 2. Tạo Policy
    SA_SYSDBA.CREATE_POLICY(
        policy_name => 'BILL_OLS_POL', 
        column_name => 'OLS_LABEL',
        default_options => 'READ_CONTROL,WRITE_CONTROL'
    );

    -- 3. Tạo Levels (Cấp bậc: 10, 20, 30, 40)
    SA_COMPONENTS.CREATE_LEVEL('BILL_OLS_POL', 10, 'CUSTOMER', 'Customer Level');
    SA_COMPONENTS.CREATE_LEVEL('BILL_OLS_POL', 20, 'VENDOR', 'Vendor Level');
    SA_COMPONENTS.CREATE_LEVEL('BILL_OLS_POL', 30, 'STAFF', 'Staff Level');
    SA_COMPONENTS.CREATE_LEVEL('BILL_OLS_POL', 40, 'ADMIN', 'Admin Level');

    -- 3.1 Tạo Compartments cho các chi nhánh (Dựa trên branch_id và branch_code)
    SA_COMPONENTS.CREATE_COMPARTMENT('BILL_OLS_POL', 10, 'CN008', 'Chi nhanh CN008');
    SA_COMPONENTS.CREATE_COMPARTMENT('BILL_OLS_POL', 20, 'CN009', 'Chi nhanh CN009');
    SA_COMPONENTS.CREATE_COMPARTMENT('BILL_OLS_POL', 30, 'CN011', 'Chi nhanh CN011');
    SA_COMPONENTS.CREATE_COMPARTMENT('BILL_OLS_POL', 40, 'CN012', 'Chi nhanh CN012');
    SA_COMPONENTS.CREATE_COMPARTMENT('BILL_OLS_POL', 50, 'BR_AG', 'Chi nhanh BR_AG');

    -- 4. Tạo Labels
    SA_LABEL_ADMIN.CREATE_LABEL('BILL_OLS_POL', 10, 'CUSTOMER');
    SA_LABEL_ADMIN.CREATE_LABEL('BILL_OLS_POL', 20, 'VENDOR');
    SA_LABEL_ADMIN.CREATE_LABEL('BILL_OLS_POL', 30, 'STAFF');
    SA_LABEL_ADMIN.CREATE_LABEL('BILL_OLS_POL', 40, 'ADMIN');

    -- Tạo Label kết hợp Level và Compartment cho nhân viên từng chi nhánh
    SA_LABEL_ADMIN.CREATE_LABEL('BILL_OLS_POL', 31, 'STAFF:CN008');
    SA_LABEL_ADMIN.CREATE_LABEL('BILL_OLS_POL', 32, 'STAFF:CN009');
    SA_LABEL_ADMIN.CREATE_LABEL('BILL_OLS_POL', 33, 'STAFF:CN011');
    SA_LABEL_ADMIN.CREATE_LABEL('BILL_OLS_POL', 34, 'STAFF:CN012');
    SA_LABEL_ADMIN.CREATE_LABEL('BILL_OLS_POL', 35, 'STAFF:BR_AG');

    -- Tạo Label cao nhất cho Admin (Thấy tất cả các chi nhánh)
    SA_LABEL_ADMIN.CREATE_LABEL('BILL_OLS_POL', 41, 'ADMIN:CN008,CN009,CN011,CN012,BR_AG');

    -- 5. Gắn Policy vào bảng TRASUA.BILL
    SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
        policy_name => 'BILL_OLS_POL', 
        schema_name => 'TRASUA', 
        table_name  => 'BILL'
    );

    -- 6. Phân quyền nhãn cao nhất cho User Database (TRASUA)
    -- Giúp user TRASUA có thể thao tác với mọi Compartment
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name => 'BILL_OLS_POL',
        user_name   => 'TRASUA',
        max_read_label => 'ADMIN:CN008,CN009,CN011,CN012,BR_AG'
    );
END;
/

-- Cấp quyền dùng package Session cho ứng dụng Java
GRANT EXECUTE ON SA_SESSION TO TRASUA;

-- ==========================================
-- PHẦN 2: CHẠY BẰNG USER TRASUA
-- Phân loại nhãn cho dữ liệu hiện có trong Database theo Chi nhánh
-- ==========================================
UPDATE TRASUA.BILL SET OLS_LABEL = CHAR_TO_LABEL('BILL_OLS_POL', 'STAFF:CN008') WHERE branch_id = 8;
UPDATE TRASUA.BILL SET OLS_LABEL = CHAR_TO_LABEL('BILL_OLS_POL', 'STAFF:CN009') WHERE branch_id = 9;
UPDATE TRASUA.BILL SET OLS_LABEL = CHAR_TO_LABEL('BILL_OLS_POL', 'STAFF:CN011') WHERE branch_id = 11;
UPDATE TRASUA.BILL SET OLS_LABEL = CHAR_TO_LABEL('BILL_OLS_POL', 'STAFF:CN012') WHERE branch_id = 12;
UPDATE TRASUA.BILL SET OLS_LABEL = CHAR_TO_LABEL('BILL_OLS_POL', 'STAFF:BR_AG') WHERE branch_id = 13;

-- Các đơn hàng không thuộc chi nhánh cụ thể (online)
UPDATE TRASUA.BILL SET OLS_LABEL = CHAR_TO_LABEL('BILL_OLS_POL', 'STAFF') WHERE branch_id IS NULL;

COMMIT;




-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 9_PROC_UPDATE_BILL_STATUS.sql
-- ============================================================
-- =================================================================
-- 9_PROC_UPDATE_BILL_STATUS.sql
-- Stored Procedure: Cập nhật trạng thái hóa đơn
-- Được gọi bởi BillServiceImpl.updateStatus() trong Java
-- Schema: TRASUA (Oracle 12c+)
-- RBAC: GRANT EXECUTE ON PROC_UPDATE_BILL_STATUS TO TRASUA;
-- =================================================================

CREATE OR REPLACE PROCEDURE PROC_UPDATE_BILL_STATUS (
    p_bill_id    IN  NUMBER,      -- ID hóa đơn cần cập nhật
    p_new_status IN  VARCHAR2,    -- Trạng thái mới: CHO_XAC_NHAN | CHO_LAY_HANG | CHO_GIAO_HANG | HOAN_THANH | HUY | TRA_HANG
    p_result_msg OUT VARCHAR2     -- 'SUCCESS' hoặc mô tả lỗi
)
IS
    v_count NUMBER;
BEGIN
    -- Kiểm tra bill tồn tại
    SELECT COUNT(*) INTO v_count FROM bill WHERE id = p_bill_id;
    IF v_count = 0 THEN
        p_result_msg := 'BILL_NOT_FOUND:' || p_bill_id;
        RETURN;
    END IF;

    -- Validate trạng thái hợp lệ
    IF p_new_status NOT IN ('CHO_XAC_NHAN','CHO_LAY_HANG','CHO_GIAO_HANG','HOAN_THANH','HUY','TRA_HANG') THEN
        p_result_msg := 'INVALID_STATUS:' || p_new_status;
        RETURN;
    END IF;

    -- Cập nhật trạng thái
    UPDATE bill
    SET    status      = p_new_status,
           update_date = SYSTIMESTAMP
    WHERE  id = p_bill_id;

    COMMIT;
    p_result_msg := 'SUCCESS';

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_result_msg := SQLERRM;
END PROC_UPDATE_BILL_STATUS;
/

-- Kiểm tra sau khi tạo
SELECT object_name, status FROM user_objects WHERE object_name = 'PROC_UPDATE_BILL_STATUS';


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 12_PROC_INVENTORY_REQUISITION.sql
-- ============================================================

-- ==============================================================================
-- 6. Procedure: PROC_INVENTORY_REQUISITION
-- Xử lý duyệt yêu cầu cấp phát hàng hóa (Admin duyệt)
-- ==============================================================================
CREATE OR REPLACE PROCEDURE TRASUA.PROC_INVENTORY_REQUISITION (
    p_request_id IN NUMBER,
    p_status IN VARCHAR2, -- 'APPROVED' hoặc 'REJECTED' hoặc 'PARTIAL_APPROVED'
    p_error_msg OUT VARCHAR2
) 
AS
    v_branch_id NUMBER;
    v_old_status VARCHAR2(20);
    v_product_id NUMBER;
    v_req_qty NUMBER;
    v_appr_qty NUMBER;
    
    CURSOR c_req_details IS 
        SELECT id, product_detail_id, requested_quantity, approved_quantity 
        FROM TRASUA.inventory_request_detail
        WHERE request_id = p_request_id;
BEGIN
    p_error_msg := 'SUCCESS';

    -- 1. Lấy thông tin phiếu
    SELECT COUNT(*) INTO v_product_id FROM TRASUA.inventory_request WHERE id = p_request_id;
    IF v_product_id = 0 THEN
        p_error_msg := 'Request ID does not exist.';
        RETURN;
    END IF;

    SELECT branch_id, status INTO v_branch_id, v_old_status
    FROM TRASUA.inventory_request
    WHERE id = p_request_id FOR UPDATE;

    -- 2. Kiểm tra trạng thái
    IF v_old_status != 'PENDING' THEN
        p_error_msg := 'Only PENDING request can be approved or rejected.';
        RETURN;
    END IF;

    -- 3. Xử lý theo trạng thái duyệt
    IF p_status = 'REJECTED' THEN
        UPDATE TRASUA.inventory_request SET status = 'REJECTED', updated_at = SYSTIMESTAMP WHERE id = p_request_id;
    ELSIF p_status = 'APPROVED' OR p_status = 'PARTIAL_APPROVED' THEN
        -- Duyệt qua từng sản phẩm trong phiếu
        FOR r_detail IN c_req_details LOOP
            v_product_id := r_detail.product_detail_id;
            v_appr_qty := r_detail.approved_quantity;
            v_req_qty := r_detail.requested_quantity;
            
            IF p_status = 'APPROVED' THEN
                v_appr_qty := v_req_qty; -- Nếu APPROVED toàn bộ, lấy nguyên số lượng yêu cầu
                UPDATE TRASUA.inventory_request_detail 
                SET approved_quantity = v_req_qty 
                WHERE id = r_detail.id;
            END IF;

            IF v_appr_qty > 0 THEN
                -- Trừ kho tổng (product_detail)
                UPDATE TRASUA.product_detail
                SET quantity = quantity - v_appr_qty
                WHERE id = v_product_id;
                
                -- Cập nhật hoặc Thêm mới vào kho chi nhánh (branch_inventory)
                UPDATE TRASUA.branch_inventory
                SET quantity = quantity + v_appr_qty, updateDate = SYSTIMESTAMP
                WHERE branch_id = v_branch_id AND product_detail_id = v_product_id;
                
                IF SQL%ROWCOUNT = 0 THEN
                    INSERT INTO TRASUA.branch_inventory (branch_id, product_detail_id, quantity, isActive, createDate, updateDate)
                    VALUES (v_branch_id, v_product_id, v_appr_qty, 1, SYSTIMESTAMP, SYSTIMESTAMP);
                END IF;
            END IF;
        END LOOP;
        
        -- Cập nhật trạng thái phiếu
        UPDATE TRASUA.inventory_request SET status = p_status, updated_at = SYSTIMESTAMP WHERE id = p_request_id;
    ELSE
        p_error_msg := 'Invalid status. Must be APPROVED, REJECTED or PARTIAL_APPROVED.';
        RETURN;
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_error_msg := 'ERROR: ' || SQLERRM;
END;
/
SHOW ERRORS PROCEDURE TRASUA.PROC_INVENTORY_REQUISITION;  
EXIT; 


