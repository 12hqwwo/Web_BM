-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 02_ddl_trasua.sql
-- ============================================================
-- ============================================================
-- PHAN 2: TAO SCHEMA (TABLES, SEQUENCES, INDEXES, FK)
-- Chay bang chinh user TRASUA (hoac prefix TRASUA. neu chay tu DBA)
-- Tuong thich: Oracle 21c / 23ai + Spring Boot 2.7.x + Hibernate 5
-- Naming strategy: PhysicalNamingStrategyStandardImpl
--   => ten cot trong DB phai khop CHINH XAC voi @Column(name=...) trong Entity
--      hoac ten field Java (neu khong co @Column)
-- ============================================================

-- ============================================================
-- LUU Y TRUOC KHI CHAY:
--   1. Dang nhap bang user TRASUA: CONNECT TRASUA/"TraSua@2024"
--   2. Tat cac bang se luu vao TS_TRASUA (DEFAULT TABLESPACE cua TRASUA)
--   3. Khong dung hibernate_sequence vi toan bo bang dung IDENTITY
-- ============================================================

-- ============================================================
-- TABLE: role
-- Entity: Role.java  | @Table(name = "role")
-- ============================================================
CREATE TABLE role (
    id          NUMBER(19)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    create_date TIMESTAMP(6)  NULL,
    name        VARCHAR2(50)  NOT NULL,
    update_date TIMESTAMP(6)  NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: customer
-- Entity: Customer.java  | @Table(name = "customer")
-- ============================================================
CREATE TABLE customer (
    id           NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code         VARCHAR2(255)  NULL,
    email        VARCHAR2(255)  NULL,
    name         NVARCHAR2(255) NULL,
    phone_number VARCHAR2(255)  NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: branch
-- Entity: Branch.java  | @Table(name = "branch")
-- ============================================================
CREATE TABLE branch (
    id          NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_name NVARCHAR2(255) NOT NULL,
    address     NVARCHAR2(255) NULL,
    phone       NVARCHAR2(20)  NULL,
    email       NVARCHAR2(100) NULL,
    is_active   NUMBER(1)      DEFAULT 1 NULL,
    create_date TIMESTAMP(6)   NULL,
    update_date TIMESTAMP(6)   NULL,
    branch_code NVARCHAR2(255) NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: account
-- Entity: Account.java  | @Table(name = "account")
-- Fields: code, birth_day, email, password, create_date,
--         update_date, is_non_locked, customer_id, role_id, branch_id
-- ============================================================
CREATE TABLE account (
    id            NUMBER(19)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    birth_day     TIMESTAMP(6)  NULL,
    code          VARCHAR2(255) NULL,
    create_date   TIMESTAMP(6)  NULL,
    email         VARCHAR2(255) NULL,
    is_non_locked NUMBER(1)     DEFAULT 1 NOT NULL,   -- true = khong bi khoa
    password      VARCHAR2(255) NULL,
    update_date   TIMESTAMP(6)  NULL,
    customer_id   NUMBER(19)    NULL,
    role_id       NUMBER(19)    NULL,
    branch_id     NUMBER(19)    NULL,
    CONSTRAINT UK_account_code UNIQUE (code)
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: address_shipping
-- Entity: AddressShipping.java  | @Table(name = "address_shipping")
-- ============================================================
CREATE TABLE address_shipping (
    id          NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    address     NVARCHAR2(150) NOT NULL,
    customer_id NUMBER(19)     NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: payment_method
-- Entity: PaymentMethod.java  | @Table(name = "payment_method")
-- Ghi chu: @Id khong dung @GeneratedValue => id duoc set thu cong
-- ============================================================
CREATE TABLE payment_method (
    id     NUMBER(19)    NOT NULL,
    name   VARCHAR2(255) NULL,
    status NUMBER(10)    DEFAULT 0 NOT NULL,
    CONSTRAINT PK_payment_method PRIMARY KEY (id)
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: discount_code
-- Entity: DiscountCode.java  | @Table(name = "discount_code")
-- ============================================================
CREATE TABLE discount_code (
    id                     NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code                   NVARCHAR2(255) NULL,
    delete_flag            NUMBER(1)      DEFAULT 0 NOT NULL,
    detail                 NVARCHAR2(255) NULL,
    discount_amount        FLOAT(53)      NULL,
    end_date               TIMESTAMP(6)   NULL,
    maximum_amount         NUMBER(10)     NULL,
    maximum_usage          NUMBER(10)     NULL,
    minimum_amount_in_cart FLOAT(53)      NULL,
    percentage             NUMBER(10)     NULL,
    start_date             TIMESTAMP(6)   NULL,
    status                 NUMBER(10)     DEFAULT 0 NOT NULL,
    type                   NUMBER(10)     DEFAULT 0 NOT NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: discount_code_backup
-- (Bang luu lich su, khong co Entity tuong ung)
-- ============================================================
CREATE TABLE discount_code_backup (
    id                     NUMBER(19)     NOT NULL,
    code                   NVARCHAR2(255) NULL,
    delete_flag            NUMBER(1)      DEFAULT 0 NOT NULL,
    detail                 NVARCHAR2(255) NULL,
    discount_amount        FLOAT(53)      NULL,
    end_date               TIMESTAMP(6)   NULL,
    maximum_amount         NUMBER(10)     NULL,
    maximum_usage          NUMBER(10)     NULL,
    minimum_amount_in_cart FLOAT(53)      NULL,
    percentage             NUMBER(10)     NULL,
    start_date             TIMESTAMP(6)   NULL,
    status                 NUMBER(10)     DEFAULT 0 NOT NULL,
    type                   NUMBER(10)     DEFAULT 0 NOT NULL,
    CONSTRAINT PK_discount_code_backup PRIMARY KEY (id)
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: bill
-- Entity: Bill.java  | @Table(name = "bill")
-- ============================================================
CREATE TABLE bill (
    id                NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    amount            FLOAT(53)      NULL,
    billing_address   NVARCHAR2(255) NULL,
    code              VARCHAR2(50)   NOT NULL,
    create_date       TIMESTAMP(6)   NULL,
    invoice_type      VARCHAR2(255)  NULL,
    promotion_price   FLOAT(53)      DEFAULT 0 NOT NULL,
    return_status     NUMBER(1)      NULL,
    status            VARCHAR2(255)  NULL,
    update_date       TIMESTAMP(6)   NULL,
    customer_id       NUMBER(19)     NULL,
    discount_code_id  NUMBER(19)     NULL,
    payment_method_id NUMBER(19)     NULL,
    branch_id         NUMBER(19)     NULL,
    cashier_account_id NUMBER(19)    NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: brand
-- Entity: Brand.java  | @Table(name = "brand")
-- ============================================================
CREATE TABLE brand (
    id          NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        VARCHAR2(255)  NULL,
    name        NVARCHAR2(255) NULL,
    status      NUMBER(10)     DEFAULT 0 NOT NULL,
    delete_flag NUMBER(1)      DEFAULT 0 NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: category
-- Entity: Category.java  | @Table(name = "category")
-- ============================================================
CREATE TABLE category (
    id          NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        VARCHAR2(255)  NULL,
    name        NVARCHAR2(255) NULL,
    status      NUMBER(10)     DEFAULT 0 NOT NULL,
    delete_flag NUMBER(1)      DEFAULT 0 NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: material
-- Entity: Material.java  | @Table(name = "material")
-- ============================================================
CREATE TABLE material (
    id          NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        VARCHAR2(255)  NULL,
    name        NVARCHAR2(255) NULL,
    status      NUMBER(10)     DEFAULT 0 NOT NULL,
    delete_flag NUMBER(1)      DEFAULT 0 NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: color
-- Entity: Color.java  | @Table(name = "color")
-- ============================================================
CREATE TABLE color (
    id          NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        VARCHAR2(255)  NULL,
    name        NVARCHAR2(255) NULL,
    delete_flag NUMBER(1)      DEFAULT 0 NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: size_product
-- Entity: Size.java  | @Table(name = "size_product")
-- Ghi chu: "SIZE" la reserved keyword trong Oracle, doi thanh size_product.
-- ============================================================
CREATE TABLE size_product (
    id          NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        VARCHAR2(255)  NULL,
    name        NVARCHAR2(255) NULL,
    delete_flag NUMBER(1)      DEFAULT 0 NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: product
-- Entity: Product.java  | @Table(name = "product")
-- ============================================================
CREATE TABLE product (
    id           NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code         VARCHAR2(255)  NULL,
    create_date  TIMESTAMP(6)   NULL,
    delete_flag  NUMBER(1)      DEFAULT 0 NOT NULL,
    describe     NVARCHAR2(255) NULL,
    gender       NUMBER(10)     DEFAULT 0 NOT NULL,
    name         NVARCHAR2(255) NULL,
    price        FLOAT(53)      DEFAULT 0 NOT NULL,
    status       NUMBER(10)     DEFAULT 0 NOT NULL,
    updated_date TIMESTAMP(6)   NULL,
    brand_id     NUMBER(19)     NULL,
    category_id  NUMBER(19)     NULL,
    material_id  NUMBER(19)     NULL,
    color_id     NUMBER(19)     NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: product_detail
-- Entity: ProductDetail.java  | @Table(name = "product_detail")
-- ============================================================
CREATE TABLE product_detail (
    id         NUMBER(19)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    barcode    VARCHAR2(255) NULL,
    price      FLOAT(53)     DEFAULT 0 NOT NULL,
    quantity   NUMBER(10)    DEFAULT 0 NOT NULL,
    color_id   NUMBER(19)    NULL,
    product_id NUMBER(19)    NULL,
    size_id    NUMBER(19)    NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: image
-- Entity: Image.java  | @Table(name = "image")
-- ============================================================
CREATE TABLE image (
    id          NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    create_date TIMESTAMP(6)   NULL,
    file_type   VARCHAR2(255)  NULL,
    link        VARCHAR2(255)  NULL,
    name        NVARCHAR2(255) NULL,
    update_date TIMESTAMP(6)   NULL,
    product_id  NUMBER(19)     NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: topping
-- Entity: Topping.java  | @Table(name = "topping")
-- ============================================================
CREATE TABLE topping (
    id          NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    description NVARCHAR2(255) NULL,
    name        NVARCHAR2(255) NULL,
    price       NUMBER(19,2)   DEFAULT 0 NOT NULL,
    status      NUMBER(1)      DEFAULT 0 NOT NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: bill_detail
-- Entity: BillDetail.java  | @Table(name = "bill_detail")
-- ============================================================
CREATE TABLE bill_detail (
    id                NUMBER(19)  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    moment_price      FLOAT(53)   NULL,
    quantity          NUMBER(10)  NULL,
    return_quantity   NUMBER(10)  NULL,
    bill_id           NUMBER(19)  NULL,
    product_detail_id NUMBER(19)  NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: bill_detail_topping
-- Entity: BillDetailTopping.java  | @Table(name = "bill_detail_topping")
-- ============================================================
CREATE TABLE bill_detail_topping (
    id             NUMBER(19)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    topping_name   VARCHAR2(255) NULL,
    topping_price  FLOAT(53)     NULL,
    bill_detail_id NUMBER(19)    NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: bill_return
-- Entity: BillReturn.java  | @Table(name = "bill_return")
-- Fields (PhysicalNamingStrategyStandardImpl map truc tiep):
--   code, returnReason, returnDate, percentFeeExchange,
--   returnMoney, isCancel, returnStatus, bill_id (FK)
-- ============================================================
CREATE TABLE bill_return (
    id                   NUMBER(19)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code                 VARCHAR2(255)  NULL,
    isCancel             NUMBER(1)      DEFAULT 0 NOT NULL,
    percentFeeExchange   NUMBER(10)     NULL,
    returnDate           TIMESTAMP(6)   NULL,
    returnMoney          FLOAT(53)      NULL,
    returnReason         NVARCHAR2(255) NULL,
    returnStatus         NUMBER(10)     DEFAULT 0 NOT NULL,
    bill_id              NUMBER(19)     NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: branch_inventory
-- Entity: BranchInventory.java  | @Table(name = "branch_inventory")
-- Fields: branch_id, product_detail_id, quantity,
--         minQuantity, maxQuantity, isActive, createDate, updateDate
-- ============================================================
CREATE TABLE branch_inventory (
    id                NUMBER(19)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id         NUMBER(19)    NOT NULL,
    product_detail_id NUMBER(19)    NOT NULL,
    quantity          NUMBER(10)    DEFAULT 0 NULL,
    createDate        TIMESTAMP(6)  NULL,
    isActive          NUMBER(1)     DEFAULT 0 NOT NULL,
    maxQuantity       NUMBER(10)    NULL,
    minQuantity       NUMBER(10)    NULL,
    updateDate        TIMESTAMP(6)  NULL,
    CONSTRAINT UQ_branch_inventory UNIQUE (branch_id, product_detail_id)
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: cart
-- Entity: Cart.java  | @Table(name = "cart")
-- ============================================================
CREATE TABLE cart (
    id                NUMBER(19)   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    create_date       TIMESTAMP(6) NULL,
    quantity          NUMBER(10)   DEFAULT 0 NOT NULL,
    update_date       TIMESTAMP(6) NULL,
    account_id        NUMBER(19)   NULL,
    product_detail_id NUMBER(19)   NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: chat_message
-- Entity: ChatMessageEntity.java  | @Table(name = "chat_message")
-- Fields: content, sender, room_id, sender_id, receiver_id,
--         seen, create_date, created_at
-- ============================================================
CREATE TABLE chat_message (
    id          NUMBER(19)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    content     CLOB          NULL,
    create_date TIMESTAMP(6)  NULL,
    created_at  TIMESTAMP(6)  NULL,
    receiver_id NUMBER(19)    NULL,
    seen        NUMBER(1)     DEFAULT 0 NOT NULL,
    sender_id   NUMBER(19)    NULL,
    room_id     VARCHAR2(255) NULL,
    sender      VARCHAR2(255) NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: payment
-- Entity: Payment.java  | @Table(name = "payment")
-- Fields (map truc tiep tu ten field Java):
--   orderId, amount, orderStatus, paymentDate, statusExchange, bill_id (FK)
-- ============================================================
CREATE TABLE payment (
    id              NUMBER(19)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    amount          VARCHAR2(255) NULL,
    orderId         VARCHAR2(255) NULL,
    orderStatus     VARCHAR2(255) NULL,
    paymentDate     TIMESTAMP(6)  NULL,
    statusExchange  NUMBER(10)    NULL,
    bill_id         NUMBER(19)    NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: product_discount
-- Entity: ProductDiscount.java  | @Table(name = "product_discount")
-- Fields (map truc tiep tu ten field Java):
--   discountedAmount, startDate, endDate, closed, product_detail_id (FK)
-- ============================================================
CREATE TABLE product_discount (
    id                 NUMBER(19)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    closed             NUMBER(1)     DEFAULT 0 NOT NULL,
    discountedAmount   FLOAT(53)     NULL,
    endDate            TIMESTAMP(6)  NULL,
    startDate          TIMESTAMP(6)  NULL,
    product_detail_id  NUMBER(19)    NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: return_detail
-- Entity: ReturnDetail.java  | @Table(name = "return_detail")
-- Fields (map truc tiep tu ten field Java):
--   quantityReturn, momentPriceRefund, return_id (FK), product_detail_id (FK)
-- ============================================================
CREATE TABLE return_detail (
    id                  NUMBER(19)  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    momentPriceRefund   FLOAT(53)   NULL,
    quantityReturn      NUMBER(10)  NULL,
    return_id           NUMBER(19)  NULL,
    product_detail_id   NUMBER(19)  NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- TABLE: verification_code
-- Entity: VerificationCode.java  | @Table(name = "verification_code")
-- ============================================================
CREATE TABLE verification_code (
    id          NUMBER(19)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        VARCHAR2(6)   NOT NULL,
    expiry_time TIMESTAMP(6)  NOT NULL,
    account_id  NUMBER(19)    NOT NULL
) TABLESPACE TS_TRASUA;

-- ============================================================
-- INDEXES (kem TABLESPACE tuong minh)
-- ============================================================

CREATE INDEX idx_account_customer
    ON account (customer_id)
    TABLESPACE TS_TRASUA;

CREATE INDEX idx_account_role
    ON account (role_id)
    TABLESPACE TS_TRASUA;

CREATE INDEX idx_account_branch
    ON account (branch_id)
    TABLESPACE TS_TRASUA;

CREATE INDEX idx_branch_inventory_branch
    ON branch_inventory (branch_id)
    TABLESPACE TS_TRASUA;

CREATE INDEX idx_branch_inventory_product
    ON branch_inventory (product_detail_id)
    TABLESPACE TS_TRASUA;

CREATE INDEX idx_bill_customer
    ON bill (customer_id)
    TABLESPACE TS_TRASUA;

CREATE INDEX idx_bill_detail_bill
    ON bill_detail (bill_id)
    TABLESPACE TS_TRASUA;

CREATE INDEX idx_product_detail_product
    ON product_detail (product_id)
    TABLESPACE TS_TRASUA;

CREATE INDEX idx_verification_account
    ON verification_code (account_id)
    TABLESPACE TS_TRASUA;

-- ============================================================
-- FOREIGN KEY CONSTRAINTS
-- ============================================================

-- account
ALTER TABLE account ADD CONSTRAINT fk_account_customer
    FOREIGN KEY (customer_id) REFERENCES customer (id) ON DELETE SET NULL;

ALTER TABLE account ADD CONSTRAINT fk_account_role
    FOREIGN KEY (role_id) REFERENCES role (id);

ALTER TABLE account ADD CONSTRAINT fk_account_branch
    FOREIGN KEY (branch_id) REFERENCES branch (id) ON DELETE SET NULL;

-- address_shipping
ALTER TABLE address_shipping ADD CONSTRAINT fk_addr_shipping_customer
    FOREIGN KEY (customer_id) REFERENCES customer (id);

-- bill
ALTER TABLE bill ADD CONSTRAINT fk_bill_branch
    FOREIGN KEY (branch_id) REFERENCES branch (id);

ALTER TABLE bill ADD CONSTRAINT fk_bill_customer
    FOREIGN KEY (customer_id) REFERENCES customer (id);

ALTER TABLE bill ADD CONSTRAINT fk_bill_payment_method
    FOREIGN KEY (payment_method_id) REFERENCES payment_method (id);

ALTER TABLE bill ADD CONSTRAINT fk_bill_discount_code
    FOREIGN KEY (discount_code_id) REFERENCES discount_code (id);

-- bill_detail
ALTER TABLE bill_detail ADD CONSTRAINT fk_bill_detail_product_detail
    FOREIGN KEY (product_detail_id) REFERENCES product_detail (id);

ALTER TABLE bill_detail ADD CONSTRAINT fk_bill_detail_bill
    FOREIGN KEY (bill_id) REFERENCES bill (id);

-- bill_detail_topping
ALTER TABLE bill_detail_topping ADD CONSTRAINT fk_bdt_bill_detail
    FOREIGN KEY (bill_detail_id) REFERENCES bill_detail (id);

-- bill_return
ALTER TABLE bill_return ADD CONSTRAINT fk_bill_return_bill
    FOREIGN KEY (bill_id) REFERENCES bill (id);

-- branch_inventory
ALTER TABLE branch_inventory ADD CONSTRAINT fk_branch_inv_branch
    FOREIGN KEY (branch_id) REFERENCES branch (id) ON DELETE CASCADE;

ALTER TABLE branch_inventory ADD CONSTRAINT fk_branch_inv_product
    FOREIGN KEY (product_detail_id) REFERENCES product_detail (id);

-- cart
ALTER TABLE cart ADD CONSTRAINT fk_cart_account
    FOREIGN KEY (account_id) REFERENCES account (id);

ALTER TABLE cart ADD CONSTRAINT fk_cart_product_detail
    FOREIGN KEY (product_detail_id) REFERENCES product_detail (id);

-- image
ALTER TABLE image ADD CONSTRAINT fk_image_product
    FOREIGN KEY (product_id) REFERENCES product (id);

-- payment
ALTER TABLE payment ADD CONSTRAINT fk_payment_bill
    FOREIGN KEY (bill_id) REFERENCES bill (id);

-- product
ALTER TABLE product ADD CONSTRAINT fk_product_brand
    FOREIGN KEY (brand_id) REFERENCES brand (id);

ALTER TABLE product ADD CONSTRAINT fk_product_category
    FOREIGN KEY (category_id) REFERENCES category (id);

ALTER TABLE product ADD CONSTRAINT fk_product_material
    FOREIGN KEY (material_id) REFERENCES material (id);

ALTER TABLE product ADD CONSTRAINT fk_product_color
    FOREIGN KEY (color_id) REFERENCES color (id);

-- product_detail
ALTER TABLE product_detail ADD CONSTRAINT fk_pd_product
    FOREIGN KEY (product_id) REFERENCES product (id);

ALTER TABLE product_detail ADD CONSTRAINT fk_pd_color
    FOREIGN KEY (color_id) REFERENCES color (id);

ALTER TABLE product_detail ADD CONSTRAINT fk_pd_size
    FOREIGN KEY (size_id) REFERENCES size_product (id);

-- product_discount
ALTER TABLE product_discount ADD CONSTRAINT fk_pdiscount_product_detail
    FOREIGN KEY (product_detail_id) REFERENCES product_detail (id);

-- return_detail
ALTER TABLE return_detail ADD CONSTRAINT fk_return_detail_bill_return
    FOREIGN KEY (return_id) REFERENCES bill_return (id);

ALTER TABLE return_detail ADD CONSTRAINT fk_return_detail_product
    FOREIGN KEY (product_detail_id) REFERENCES product_detail (id);

-- verification_code
ALTER TABLE verification_code ADD CONSTRAINT fk_verification_account
    FOREIGN KEY (account_id) REFERENCES account (id);

COMMIT;

-- ============================================================
-- Kiem tra nhanh sau khi chay xong:
--   SELECT table_name, tablespace_name
--   FROM user_tables
--   ORDER BY table_name;
--
--   SELECT constraint_name, constraint_type, table_name, status
--   FROM user_constraints
--   ORDER BY table_name, constraint_type;
-- ============================================================

-- ============================================================
-- END OF SCRIPT
-- ============================================================
ALTER TABLE bill ADD cashier_account_id NUMBER(19) NULL;


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 03_seed_data_trasua.sql
-- ============================================================
-- ============================================================
-- PHAN 3: DU LIEU KHOI TAO (SEED DATA)
-- ============================================================

-- ============================================================
-- XÓA DỮ LIỆU CŨ (Tránh lỗi duplicate và subquery trả về nhiều dòng)
-- Xóa theo thứ tự con -> cha để không dính Foreign Key
-- ============================================================
DELETE FROM address_shipping;
DELETE FROM account;
DELETE FROM product_detail;
DELETE FROM product;
DELETE FROM topping;
DELETE FROM size_product;
DELETE FROM color;
DELETE FROM material;
DELETE FROM brand;
DELETE FROM category;
DELETE FROM customer;
DELETE FROM branch;
DELETE FROM role;
DELETE FROM payment_method;
DELETE FROM discount_code;
COMMIT;

-- ============================================================
-- 1. ROLES
-- ============================================================
INSERT INTO role (name) VALUES ('ROLE_ADMIN');
INSERT INTO role (name) VALUES ('ROLE_STAFF');
INSERT INTO role (name) VALUES ('ROLE_VENDOR');
INSERT INTO role (name) VALUES ('ROLE_USER');
INSERT INTO role (name) VALUES ('ROLE_GUEST');

-- ============================================================
-- 2. PAYMENT METHODS (id dat thu cong vi Entity khong co @GeneratedValue)
-- ============================================================
INSERT INTO payment_method (id, name, status) VALUES (1, 'TIEN_MAT', 1);
INSERT INTO payment_method (id, name, status) VALUES (2, 'CHUYEN_KHOAN', 1);
INSERT INTO payment_method (id, name, status) VALUES (3, 'THE', 1);

-- ============================================================
-- 3. BRANCH (Chi nhanh)
-- ============================================================
INSERT INTO branch (branch_name, address, phone, email, is_active, create_date, update_date, branch_code)
VALUES (N'Chi nhánh Trà Sữa Hà Nội', N'123 Phố Huế, Hai Bà Trưng, Hà Nội',
        '0901234567', 'hanoi@trasua.vn', 1, SYSDATE, SYSDATE, 'CN001');

INSERT INTO branch (branch_name, address, phone, email, is_active, create_date, update_date, branch_code)
VALUES (N'Chi nhánh Trà Sữa HCM', N'456 Nguyễn Trãi, Quận 5, TP.HCM',
        '0902345678', 'hcm@trasua.vn', 1, SYSDATE, SYSDATE, 'CN002');

-- ============================================================
-- 4. CUSTOMER (Khach hang cho ADMIN)
-- ============================================================
INSERT INTO customer (code, name, email, phone_number)
VALUES ('KH0001', N'Quản Trị Viên', 'admin@trasua.vn', '0900000000');

INSERT INTO customer (code, name, email, phone_number)
VALUES ('KH0002', N'Nguyễn Văn An', 'nguyenvanan@gmail.com', '0911111111');

INSERT INTO customer (code, name, email, phone_number)
VALUES ('KH0003', N'Trần Thị Bình', 'tranthib@gmail.com', '0922222222');

INSERT INTO customer (code, name, email, phone_number)
VALUES ('KH0004', N'Lê Văn Cường', 'levanc@gmail.com', '0933333333');

-- ============================================================
-- 5. ACCOUNT
-- Password: 'Admin@123' -> BCrypt hash
-- Su dung hash nay de dang nhap bang mat khau 'Admin@123'
-- Them ROWNUM = 1 de dam bao khong bao loi neu ban insert nhieu lan
-- ============================================================

-- ADMIN account
INSERT INTO account (code, email, password, is_non_locked, create_date, update_date, customer_id, role_id, branch_id)
VALUES ('AC0001', 'admin@trasua.vn',
        '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH',
        1, SYSDATE, SYSDATE,
        (SELECT id FROM customer WHERE code = 'KH0001' AND ROWNUM = 1),
        (SELECT id FROM role WHERE name = 'ROLE_ADMIN' AND ROWNUM = 1),
        NULL);

-- STAFF account (Chi nhanh HN)
INSERT INTO account (code, email, password, is_non_locked, create_date, update_date, customer_id, role_id, branch_id)
VALUES ('AC0002', 'staff@trasua.vn',
        '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH',
        1, SYSDATE, SYSDATE,
        (SELECT id FROM customer WHERE code = 'KH0002' AND ROWNUM = 1),
        (SELECT id FROM role WHERE name = 'ROLE_STAFF' AND ROWNUM = 1),
        (SELECT id FROM branch WHERE branch_code = 'CN001' AND ROWNUM = 1));

-- USER account
INSERT INTO account (code, email, password, is_non_locked, create_date, update_date, customer_id, role_id, branch_id)
VALUES ('AC0003', 'user@trasua.vn',
        '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH',
        1, SYSDATE, SYSDATE,
        (SELECT id FROM customer WHERE code = 'KH0003' AND ROWNUM = 1),
        (SELECT id FROM role WHERE name = 'ROLE_USER' AND ROWNUM = 1),
        NULL);

-- ============================================================
-- 6. CATEGORY (Danh muc)
-- ============================================================
INSERT INTO category (code, name, status, delete_flag) VALUES ('DM001', N'Trà Sữa', 1, 0);
INSERT INTO category (code, name, status, delete_flag) VALUES ('DM002', N'Trà Trái Cây', 1, 0);
INSERT INTO category (code, name, status, delete_flag) VALUES ('DM003', N'Cà Phê', 1, 0);
INSERT INTO category (code, name, status, delete_flag) VALUES ('DM004', N'Trà Xanh', 1, 0);
INSERT INTO category (code, name, status, delete_flag) VALUES ('DM005', N'Sinh Tố', 1, 0);

-- ============================================================
-- 7. BRAND (Thuong hieu)
-- ============================================================
INSERT INTO brand (code, name, status, delete_flag) VALUES ('TH001', N'Gong Cha', 1, 0);
INSERT INTO brand (code, name, status, delete_flag) VALUES ('TH002', N'The Alley', 1, 0);
INSERT INTO brand (code, name, status, delete_flag) VALUES ('TH003', N'Phúc Long', 1, 0);
INSERT INTO brand (code, name, status, delete_flag) VALUES ('TH004', N'Highlands Coffee', 1, 0);

-- ============================================================
-- 8. MATERIAL (Chat lieu / Nguyen lieu)
-- ============================================================
INSERT INTO material (code, name, status, delete_flag) VALUES ('NL001', N'Trà Đen', 1, 0);
INSERT INTO material (code, name, status, delete_flag) VALUES ('NL002', N'Trà Xanh Matcha', 1, 0);
INSERT INTO material (code, name, status, delete_flag) VALUES ('NL003', N'Trà Ô Long', 1, 0);
INSERT INTO material (code, name, status, delete_flag) VALUES ('NL004', N'Cà Phê Arabica', 1, 0);
INSERT INTO material (code, name, status, delete_flag) VALUES ('NL005', N'Trà Hoa Quả', 1, 0);

-- ============================================================
-- 9. COLOR (Dung cho cup/ly: mau sac)
-- ============================================================
INSERT INTO color (code, name, delete_flag) VALUES ('MK001', N'Nóng', 0);
INSERT INTO color (code, name, delete_flag) VALUES ('MK002', N'Lạnh', 0);
INSERT INTO color (code, name, delete_flag) VALUES ('MK003', N'Đá Xay', 0);

-- ============================================================
-- 10. SIZE_PRODUCT (Kich co: S/M/L)
-- ============================================================
INSERT INTO size_product (code, name, delete_flag) VALUES ('KH001', 'S (Nhỏ - 300ml)', 0);
INSERT INTO size_product (code, name, delete_flag) VALUES ('KH002', 'M (Vừa - 500ml)', 0);
INSERT INTO size_product (code, name, delete_flag) VALUES ('KH003', 'L (Lớn - 700ml)', 0);

-- ============================================================
-- 11. TOPPING
-- ============================================================
INSERT INTO topping (name, description, price, status)
VALUES (N'Trân Châu Đen', N'Trân châu đen dai, ngọt', 5000, 1);

INSERT INTO topping (name, description, price, status)
VALUES (N'Trân Châu Trắng', N'Trân châu trắng mềm', 5000, 1);

INSERT INTO topping (name, description, price, status)
VALUES (N'Pudding', N'Pudding trứng mềm mịn', 8000, 1);

INSERT INTO topping (name, description, price, status)
VALUES (N'Thạch Dừa', N'Thạch dừa giòn ngon', 5000, 1);

INSERT INTO topping (name, description, price, status)
VALUES (N'Kem Cheese', N'Kem phô mai béo ngậy', 10000, 1);

INSERT INTO topping (name, description, price, status)
VALUES (N'Hạt Ngũ Cốc', N'Hạt ngũ cốc giòn', 7000, 1);

-- ============================================================
-- 12. PRODUCT (San pham)
-- ============================================================

-- SP001: Tra Sua Truyen Thong
INSERT INTO product (code, name, create_date, delete_flag, describe, gender, price, status, updated_date,
                     brand_id, category_id, material_id, color_id)
VALUES ('SP0001', N'Trà Sữa Truyền Thống', SYSDATE, 0,
        N'Trà sữa truyền thống thơm ngon, béo ngậy với trà đen hảo hạng',
        0, 35000, 1, SYSDATE,
        (SELECT id FROM brand WHERE code = 'TH001' AND ROWNUM = 1),
        (SELECT id FROM category WHERE code = 'DM001' AND ROWNUM = 1),
        (SELECT id FROM material WHERE code = 'NL001' AND ROWNUM = 1),
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1));

-- SP002: Matcha Sua
INSERT INTO product (code, name, create_date, delete_flag, describe, gender, price, status, updated_date,
                     brand_id, category_id, material_id, color_id)
VALUES ('SP0002', N'Matcha Sữa', SYSDATE, 0,
        N'Matcha Nhật Bản nguyên chất pha cùng sữa tươi đặc biệt',
        0, 45000, 1, SYSDATE,
        (SELECT id FROM brand WHERE code = 'TH001' AND ROWNUM = 1),
        (SELECT id FROM category WHERE code = 'DM001' AND ROWNUM = 1),
        (SELECT id FROM material WHERE code = 'NL002' AND ROWNUM = 1),
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1));

-- SP003: Tra Xanh Dao
INSERT INTO product (code, name, create_date, delete_flag, describe, gender, price, status, updated_date,
                     brand_id, category_id, material_id, color_id)
VALUES ('SP0003', N'Trà Xanh Đào', SYSDATE, 0,
        N'Trà xanh kết hợp vị đào tươi mát, thanh nhiệt giải khát',
        0, 40000, 1, SYSDATE,
        (SELECT id FROM brand WHERE code = 'TH002' AND ROWNUM = 1),
        (SELECT id FROM category WHERE code = 'DM004' AND ROWNUM = 1),
        (SELECT id FROM material WHERE code = 'NL002' AND ROWNUM = 1),
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1));

-- SP004: Ca Phe Sua Da
INSERT INTO product (code, name, create_date, delete_flag, describe, gender, price, status, updated_date,
                     brand_id, category_id, material_id, color_id)
VALUES ('SP0004', N'Cà Phê Sữa Đá', SYSDATE, 0,
        N'Cà phê Arabica đậm đà pha cùng sữa đặc Việt Nam',
        0, 38000, 1, SYSDATE,
        (SELECT id FROM brand WHERE code = 'TH004' AND ROWNUM = 1),
        (SELECT id FROM category WHERE code = 'DM003' AND ROWNUM = 1),
        (SELECT id FROM material WHERE code = 'NL004' AND ROWNUM = 1),
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1));

-- SP005: Tra O Long Sua Tuoi
INSERT INTO product (code, name, create_date, delete_flag, describe, gender, price, status, updated_date,
                     brand_id, category_id, material_id, color_id)
VALUES ('SP0005', N'Trà Ô Long Sữa Tươi', SYSDATE, 0,
        N'Trà Ô Long thượng hạng kết hợp sữa tươi nguyên kem',
        0, 50000, 1, SYSDATE,
        (SELECT id FROM brand WHERE code = 'TH002' AND ROWNUM = 1),
        (SELECT id FROM category WHERE code = 'DM001' AND ROWNUM = 1),
        (SELECT id FROM material WHERE code = 'NL003' AND ROWNUM = 1),
        (SELECT id FROM color WHERE code = 'MK001' AND ROWNUM = 1));

-- ============================================================
-- 13. PRODUCT_DETAIL (Chi tiet san pham: S/M/L x Nong/Lanh)
-- ============================================================

-- SP0001 - Tra Sua Truyen Thong
INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0001-LANH-S', 35000, 100,
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0001' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH001' AND ROWNUM = 1));

INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0001-LANH-M', 40000, 100,
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0001' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH002' AND ROWNUM = 1));

INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0001-LANH-L', 45000, 100,
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0001' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH003' AND ROWNUM = 1));

-- SP0002 - Matcha Sua
INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0002-LANH-S', 45000, 80,
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0002' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH001' AND ROWNUM = 1));

INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0002-LANH-M', 50000, 80,
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0002' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH002' AND ROWNUM = 1));

INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0002-LANH-L', 55000, 80,
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0002' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH003' AND ROWNUM = 1));

-- SP0003 - Tra Xanh Dao
INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0003-LANH-M', 40000, 120,
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0003' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH002' AND ROWNUM = 1));

INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0003-LANH-L', 45000, 120,
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0003' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH003' AND ROWNUM = 1));

-- SP0004 - Ca Phe Sua Da
INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0004-LANH-M', 38000, 200,
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0004' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH002' AND ROWNUM = 1));

INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0004-NONG-M', 38000, 150,
        (SELECT id FROM color WHERE code = 'MK001' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0004' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH002' AND ROWNUM = 1));

-- SP0005 - Tra O Long
INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0005-NONG-M', 50000, 60,
        (SELECT id FROM color WHERE code = 'MK001' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0005' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH002' AND ROWNUM = 1));

INSERT INTO product_detail (barcode, price, quantity, color_id, product_id, size_id)
VALUES ('SP0005-LANH-L', 55000, 60,
        (SELECT id FROM color WHERE code = 'MK002' AND ROWNUM = 1),
        (SELECT id FROM product WHERE code = 'SP0005' AND ROWNUM = 1),
        (SELECT id FROM size_product WHERE code = 'KH003' AND ROWNUM = 1));

-- ============================================================
-- 14. DISCOUNT_CODE (Ma giam gia)
-- ============================================================
INSERT INTO discount_code (code, detail, type, percentage, discount_amount,
                            minimum_amount_in_cart, maximum_amount, maximum_usage,
                            start_date, end_date, status, delete_flag)
VALUES ('WELCOME10', N'Giảm 10% cho đơn hàng đầu tiên', 1, 10, NULL,
        100000, 50000, 100,
        SYSDATE - 1, SYSDATE + 30, 1, 0);

INSERT INTO discount_code (code, detail, type, percentage, discount_amount,
                            minimum_amount_in_cart, maximum_amount, maximum_usage,
                            start_date, end_date, status, delete_flag)
VALUES ('SALE20K', N'Giảm 20.000đ cho đơn từ 150.000đ', 0, NULL, 20000,
        150000, NULL, 50,
        SYSDATE - 1, SYSDATE + 15, 1, 0);

INSERT INTO discount_code (code, detail, type, percentage, discount_amount,
                            minimum_amount_in_cart, maximum_amount, maximum_usage,
                            start_date, end_date, status, delete_flag)
VALUES ('VIP15', N'Giảm 15% cho khách VIP', 1, 15, NULL,
        200000, 100000, 200,
        SYSDATE - 1, SYSDATE + 60, 1, 0);

-- ============================================================
-- 15. ADDRESS_SHIPPING (Dia chi giao hang)
-- ============================================================
INSERT INTO address_shipping (address, customer_id)
VALUES (N'123 Phố Huế, Hai Bà Trưng, Hà Nội',
        (SELECT id FROM customer WHERE code = 'KH0002' AND ROWNUM = 1));

INSERT INTO address_shipping (address, customer_id)
VALUES (N'456 Nguyễn Trãi, Quận 5, TP.HCM',
        (SELECT id FROM customer WHERE code = 'KH0003' AND ROWNUM = 1));

-- ============================================================
-- COMMIT
-- ============================================================
-- ============================================================
-- 15. BRANCH INVENTORY (Kho hàng)
-- ============================================================
-- Gán toàn bộ sản phẩm vào Chi nhánh 1 (Hà Nội) với số lượng 100
INSERT INTO branch_inventory (branch_id, product_detail_id, quantity, "isActive", "createDate", "updateDate", "minQuantity")
SELECT 
    (SELECT MIN(id) FROM branch),
    id, 
    100, 
    1, 
    SYSDATE, 
    SYSDATE,
    0
FROM product_detail;

COMMIT;


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 09_sync_sequences.sql
-- ============================================================
-- Dong bo hoa lai Sequence cho cac cot Identity sau khi import data
-- Trong Oracle, khi INSERT cung gia tri ID, sequence se KHONG tu dong tang.
-- Chung ta phai cap nhat lai de sequence tiep tuc tu muc MAX(id) + 1, tranh loi ORA-00001 (Unique constraint)

ALTER TABLE role MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE customer MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE branch MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE account MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE address_shipping MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE payment_method MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);

COMMIT;
BEGIN DBMS_OUTPUT.PUT_LINE('>>> Da cap nhat ID Identity thanh cong!'); END;
/


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 06_oracle_procedures.sql
-- ============================================================
-- ============================================================
-- FILE: 06_oracle_procedures.sql
-- MUC DICH: Trien khai cac co che bao mat Oracle theo yeu cau
--   tu file mo ta: Nhom04_motadexuat.docx
--
-- NOI DUNG:
--   PHAN 1: Stored Procedures (PROC_CREATE_ORDER, PROC_INIT_INVENTORY)
--   PHAN 2: Functions (FN_GET_BRANCH_REVENUE, FN_CHECK_STOCK)
--   PHAN 3: VPD - Virtual Private Database (loc du lieu theo branch/customer)
--   PHAN 4: FGA - Fine-Grained Auditing (giam sat thao tac rui ro)
--   PHAN 5: Data Redaction (che SiT/Email khach hang)
--
-- HUONG DAN: Dang nhap bang SYSDBA hoac user TRASUA co quyen DBA
--   CONNECT TRASUA/"TraSua@2024"@//localhost:1521/FREEPDB1
-- Sau do chay tung PHAN (F5 hoac Run Script)
-- ============================================================


-- ============================================================
-- PHAN 1: STORED PROCEDURES
-- ============================================================

-- Tao sequence cho hoa don (neu chua co)
BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_bill_code START WITH 1 INCREMENT BY 1';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -955 THEN -- -955 is "name is already used by an existing object"
            RAISE;
        END IF;
END;
/

-- -------------------------------------------------------
-- 1A. PROC_INIT_BRANCH_INVENTORY
--     Muc dich: Phan bo toan bo san pham ve mot chi nhanh
--               voi so luong mac dinh. Dung khi them chi nhanh moi.
--     Cach chay: EXEC PROC_INIT_BRANCH_INVENTORY(p_branch_id => 1, p_default_qty => 100);
-- -------------------------------------------------------
CREATE OR REPLACE PROCEDURE PROC_INIT_BRANCH_INVENTORY (
    p_branch_id     IN NUMBER,
    p_default_qty   IN NUMBER DEFAULT 100
)
AS
    v_count NUMBER;
    v_inserted NUMBER := 0;
BEGIN
    -- Kiem tra chi nhanh ton tai
    SELECT COUNT(*) INTO v_count
    FROM branch WHERE id = p_branch_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Chi nhanh ID = ' || p_branch_id || ' khong ton tai!');
    END IF;

    -- Insert cac san pham chua co trong kho chi nhanh nay
    INSERT INTO branch_inventory (branch_id, product_detail_id, quantity, isActive, createDate, updateDate, minQuantity)
    SELECT
        p_branch_id,
        pd.id,
        p_default_qty,
        1,
        SYSTIMESTAMP,
        SYSTIMESTAMP,
        0
    FROM product_detail pd
    WHERE NOT EXISTS (
        SELECT 1 FROM branch_inventory bi
        WHERE bi.product_detail_id = pd.id
          AND bi.branch_id = p_branch_id
    );

    v_inserted := SQL%ROWCOUNT;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('PROC_INIT_BRANCH_INVENTORY - Hoan thanh!');
    DBMS_OUTPUT.PUT_LINE('  Chi nhanh ID : ' || p_branch_id);
    DBMS_OUTPUT.PUT_LINE('  San pham duoc them: ' || v_inserted || ' dong');
    DBMS_OUTPUT.PUT_LINE('  So luong mac dinh : ' || p_default_qty);
    DBMS_OUTPUT.PUT_LINE('============================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('LOI: ' || SQLERRM);
        RAISE;
END PROC_INIT_BRANCH_INVENTORY;
/


-- -------------------------------------------------------
-- 1B. PROC_CREATE_ORDER
--     Muc dich: Tao hoa don theo luong chuan cua ung dung.
--               Kiem tra ton kho truoc khi ghi bill.
--               Tru ton kho sau khi xac nhan.
--     Dau vao:
--       p_customer_id, p_branch_id, p_payment_method_id,
--       p_billing_address, p_invoice_type,
--       p_product_detail_ids  (danh sach san pham, cach nhau dau phay)
--       p_quantities          (so luong tuong ung)
--       p_cashier_account_id  (nhan vien thu ngan, NULL neu dat online)
--     Dau ra:
--       p_bill_code           (ma hoa don duoc tao)
--       p_result_msg          (thong bao ket qua)
--     Cach chay (demo):
--       DECLARE
--         v_code VARCHAR2(50);
--         v_msg  VARCHAR2(500);
--       BEGIN
--         PROC_CREATE_ORDER(
--           p_customer_id => 1,
--           p_branch_id   => 1,
--           p_payment_method_id => 1,
--           p_billing_address => N'123 Pho Hue, Ha Noi',
--           p_invoice_type    => 'POS',
--           p_product_detail_ids => '1,2',
--           p_quantities         => '2,1',
--           p_cashier_account_id => NULL,
--           p_bill_code  => v_code,
--           p_result_msg => v_msg
--         );
--         DBMS_OUTPUT.PUT_LINE('Ma hoa don: ' || v_code);
--         DBMS_OUTPUT.PUT_LINE('Ket qua   : ' || v_msg);
--       END;
-- -------------------------------------------------------
CREATE OR REPLACE PROCEDURE PROC_CREATE_ORDER (
    p_customer_id           IN  NUMBER,
    p_branch_id             IN  NUMBER,
    p_payment_method_id     IN  NUMBER,
    p_billing_address       IN  NVARCHAR2,
    p_invoice_type          IN  VARCHAR2,
    p_product_detail_ids    IN  VARCHAR2,   -- VD: '1,3,7'
    p_quantities            IN  VARCHAR2,   -- VD: '2,1,3'
    p_cashier_account_id    IN  NUMBER DEFAULT NULL,
    p_bill_code             OUT VARCHAR2,
    p_result_msg            OUT VARCHAR2
)
AS
    v_bill_id       NUMBER;
    v_total_amount  NUMBER := 0;
    v_moment_price  NUMBER;
    v_stock_qty     NUMBER;
    v_pd_id         NUMBER;
    v_qty           NUMBER;
    v_bill_code     VARCHAR2(50);

    -- Phan tach chuoi id va quantity
    TYPE t_numlist IS TABLE OF NUMBER;
    v_pd_ids  t_numlist := t_numlist();
    v_qtys    t_numlist := t_numlist();

    v_pos     INTEGER;
    v_str     VARCHAR2(4000);
    v_idx     INTEGER;
BEGIN
    -- === Phan tach product_detail_ids ===
    v_str := p_product_detail_ids || ',';
    v_idx := 1;
    LOOP
        v_pos := INSTR(v_str, ',');
        EXIT WHEN v_pos = 0;
        v_pd_ids.EXTEND;
        v_pd_ids(v_idx) := TO_NUMBER(TRIM(SUBSTR(v_str, 1, v_pos - 1)));
        v_str := SUBSTR(v_str, v_pos + 1);
        v_idx := v_idx + 1;
    END LOOP;

    -- === Phan tach quantities ===
    v_str := p_quantities || ',';
    v_idx := 1;
    LOOP
        v_pos := INSTR(v_str, ',');
        EXIT WHEN v_pos = 0;
        v_qtys.EXTEND;
        v_qtys(v_idx) := TO_NUMBER(TRIM(SUBSTR(v_str, 1, v_pos - 1)));
        v_str := SUBSTR(v_str, v_pos + 1);
        v_idx := v_idx + 1;
    END LOOP;

    IF v_pd_ids.COUNT != v_qtys.COUNT THEN
        RAISE_APPLICATION_ERROR(-20010,
            'So san pham va so luong khong khop!');
    END IF;

    -- === Kiem tra ton kho truoc khi tao bill ===
    FOR i IN 1..v_pd_ids.COUNT LOOP
        v_pd_id := v_pd_ids(i);
        v_qty   := v_qtys(i);

        SELECT NVL(bi.quantity, 0)
        INTO   v_stock_qty
        FROM   branch_inventory bi
        WHERE  bi.branch_id = p_branch_id
          AND  bi.product_detail_id = v_pd_id
          AND  bi.isActive = 1;

        IF v_stock_qty < v_qty THEN
            RAISE_APPLICATION_ERROR(-20011,
                'San pham ID=' || v_pd_id ||
                ' khong du hang. Ton kho: ' || v_stock_qty ||
                ', Yeu cau: ' || v_qty);
        END IF;
    END LOOP;

    -- === Sinh ma hoa don ===
    BEGIN
        SELECT 'HD' || TO_CHAR(SYSDATE, 'YYYYMMDD') || LPAD(seq_bill_code.NEXTVAL, 5, '0')
        INTO v_bill_code
        FROM DUAL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Neu chua co sequence thi dung timestamp
            v_bill_code := 'HD' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS');
    END;

    -- === Tao ban ghi BILL ===
    INSERT INTO bill (
        code, status, invoice_type, billing_address,
        create_date, update_date,
        customer_id, payment_method_id, branch_id,
        cashier_account_id, promotion_price
    ) VALUES (
        v_bill_code, 'PENDING', p_invoice_type, p_billing_address,
        SYSTIMESTAMP, SYSTIMESTAMP,
        p_customer_id, p_payment_method_id, p_branch_id,
        p_cashier_account_id, 0
    )
    RETURNING id INTO v_bill_id;

    -- === Tao BILL_DETAIL va tru ton kho ===
    FOR i IN 1..v_pd_ids.COUNT LOOP
        v_pd_id := v_pd_ids(i);
        v_qty   := v_qtys(i);

        -- Lay gia tai thoi diem dat hang
        SELECT NVL(pd.price, 0)
        INTO   v_moment_price
        FROM   product_detail pd
        WHERE  pd.id = v_pd_id;

        -- Tao bill_detail
        INSERT INTO bill_detail (bill_id, product_detail_id, quantity, moment_price)
        VALUES (v_bill_id, v_pd_id, v_qty, v_moment_price);

        -- Tru ton kho
        UPDATE branch_inventory
        SET    quantity   = quantity - v_qty,
               updateDate = SYSTIMESTAMP
        WHERE  branch_id = p_branch_id
          AND  product_detail_id = v_pd_id;

        v_total_amount := v_total_amount + (v_moment_price * v_qty);
    END LOOP;

    -- === Cap nhat tong tien hoa don ===
    UPDATE bill SET amount = v_total_amount WHERE id = v_bill_id;

    COMMIT;

    p_bill_code  := v_bill_code;
    p_result_msg := 'Tao hoa don thanh cong! Ma: ' || v_bill_code ||
                    ' | Tong tien: ' || TO_CHAR(v_total_amount, 'FM999,999,999') || ' VND';

    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('PROC_CREATE_ORDER - Thanh cong!');
    DBMS_OUTPUT.PUT_LINE('  Ma hoa don : ' || v_bill_code);
    DBMS_OUTPUT.PUT_LINE('  Tong tien  : ' || TO_CHAR(v_total_amount, 'FM999,999,999') || ' VND');
    DBMS_OUTPUT.PUT_LINE('  Chi nhanh  : ' || p_branch_id);
    DBMS_OUTPUT.PUT_LINE('============================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_bill_code  := NULL;
        p_result_msg := 'LOI: ' || SQLERRM;
        DBMS_OUTPUT.PUT_LINE('LOI tao hoa don: ' || SQLERRM);
        RAISE;
END PROC_CREATE_ORDER;
/


-- ============================================================
-- PHAN 2: FUNCTIONS
-- ============================================================

-- -------------------------------------------------------
-- 2A. FN_GET_BRANCH_REVENUE
--     Tinh doanh thu cua mot chi nhanh trong khoang thoi gian
--     Cach dung:
--       SELECT FN_GET_BRANCH_REVENUE(1, DATE '2026-06-01', DATE '2026-06-30') AS doanh_thu FROM DUAL;
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_GET_BRANCH_REVENUE (
    p_branch_id  IN NUMBER,
    p_from_date  IN DATE DEFAULT TRUNC(SYSDATE, 'MM'),
    p_to_date    IN DATE DEFAULT SYSDATE
) RETURN NUMBER
AS
    v_revenue NUMBER := 0;
BEGIN
    SELECT NVL(SUM(b.amount), 0)
    INTO   v_revenue
    FROM   bill b
    WHERE  b.branch_id = p_branch_id
      AND  b.status NOT IN ('CANCELLED', 'RETURNED')
      AND  TRUNC(b.create_date) BETWEEN p_from_date AND p_to_date;

    RETURN v_revenue;
EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;
END FN_GET_BRANCH_REVENUE;
/


-- -------------------------------------------------------
-- 2B. FN_CHECK_STOCK
--     Kiem tra so luong ton kho cua mot san pham tai chi nhanh
--     Cach dung:
--       SELECT FN_CHECK_STOCK(1, 5) AS so_luong_con FROM DUAL;
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_CHECK_STOCK (
    p_branch_id         IN NUMBER,
    p_product_detail_id IN NUMBER
) RETURN NUMBER
AS
    v_qty NUMBER := 0;
BEGIN
    SELECT NVL(quantity, 0)
    INTO   v_qty
    FROM   branch_inventory
    WHERE  branch_id = p_branch_id
      AND  product_detail_id = p_product_detail_id
      AND  isActive = 1;

    RETURN v_qty;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
    WHEN OTHERS        THEN RETURN -1;
END FN_CHECK_STOCK;
/


-- ============================================================
-- PHAN 3: VPD - Virtual Private Database
-- Loc du lieu theo branch_id (Vendor chi thay chi nhanh minh)
-- va theo customer_id (User chi thay don hang cua minh)
-- ============================================================

-- -------------------------------------------------------
-- 3A. Policy Function: loc BRANCH_INVENTORY theo branch_id cua Vendor
--     Cach hoat dong: moi lan Vendor chay SELECT tren branch_inventory,
--     Oracle tu dong them menh de WHERE branch_id = <branch cua Vendor>
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_VPD_BRANCH_INVENTORY (
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
) RETURN VARCHAR2
AS
    v_branch_id NUMBER;
    v_username  VARCHAR2(100);
    v_role      VARCHAR2(50);
BEGIN
    v_username := SYS_CONTEXT('USERENV', 'SESSION_USER');

    -- Admin khong bi loc
    v_role := 'ROLE_USER'; -- default
    BEGIN
        SELECT r.name INTO v_role
        FROM account a
        JOIN role r ON a.role_id = r.id
        WHERE a.email = SYS_CONTEXT('APEX$SESSION', 'APP_USER')
          AND ROWNUM = 1;
        
        IF v_role = 'ROLE_ADMIN' THEN
            RETURN NULL; -- Admin: khong them dieu kien, xem het
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
    END;

    -- Vendor: loc theo branch_id
    BEGIN
        SELECT a.branch_id INTO v_branch_id
        FROM account a
        JOIN role r ON a.role_id = r.id
        WHERE a.email = SYS_CONTEXT('APEX$SESSION', 'APP_USER')
          AND r.name IN ('ROLE_VENDOR', 'ROLE_STAFF')
          AND ROWNUM = 1;

        IF v_branch_id IS NOT NULL THEN
            RETURN 'branch_id = ' || v_branch_id;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
    END;

    -- Mac dinh: khong thay gi neu khong xac dinh duoc branch
    RETURN '1=0';
END FN_VPD_BRANCH_INVENTORY;
/


-- -------------------------------------------------------
-- 3B. Ap dung VPD len bang BRANCH_INVENTORY
-- -------------------------------------------------------
BEGIN
    -- Xoa policy cu neu co
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_RLS.DROP_POLICY(
            object_schema => ''TRASUA'',
            object_name   => ''BRANCH_INVENTORY'',
            policy_name   => ''POL_BRANCH_INVENTORY''
        );
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;';
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Loi xoa VPD Policy: ' || SQLERRM);
END;
/

BEGIN
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_RLS.ADD_POLICY(
            object_schema   => ''TRASUA'',
            object_name     => ''BRANCH_INVENTORY'',
            policy_name     => ''POL_BRANCH_INVENTORY'',
            function_schema => ''TRASUA'',
            policy_function => ''FN_VPD_BRANCH_INVENTORY'',
            statement_types => ''SELECT'',
            enable          => TRUE
        );
    END;';
    DBMS_OUTPUT.PUT_LINE('VPD da duoc ap dung len bang BRANCH_INVENTORY');
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Chua the tao VPD. Vui long cap quyen: GRANT EXECUTE ON DBMS_RLS TO TRASUA;');
END;
/


-- -------------------------------------------------------
-- 3C. Policy Function: loc CART/BILL theo customer_id cua User
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_VPD_CUSTOMER_DATA (
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
) RETURN VARCHAR2
AS
    v_customer_id NUMBER;
BEGIN
    -- Admin va Vendor: xem het
    BEGIN
        SELECT 1 INTO v_customer_id
        FROM account a
        JOIN role r ON a.role_id = r.id
        WHERE a.email = SYS_CONTEXT('APEX$SESSION', 'APP_USER')
          AND r.name IN ('ROLE_ADMIN', 'ROLE_VENDOR', 'ROLE_STAFF')
          AND ROWNUM = 1;
        RETURN NULL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
    END;

    -- User: chi thay du lieu cua minh
    BEGIN
        SELECT a.customer_id INTO v_customer_id
        FROM account a
        WHERE a.email = SYS_CONTEXT('APEX$SESSION', 'APP_USER')
          AND ROWNUM = 1;

        IF v_customer_id IS NOT NULL THEN
            RETURN 'customer_id = ' || v_customer_id;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
    END;

    RETURN '1=0';
END FN_VPD_CUSTOMER_DATA;
/


-- ============================================================
-- PHAN 4: FGA - Fine-Grained Auditing
-- Giam sat cac thao tac co rui ro gian lan
-- ============================================================

-- -------------------------------------------------------
-- 4A. Ghi log khi ai UPDATE so luong ton kho (branch_inventory)
--     Bang thu cong (khong qua ung dung)
-- -------------------------------------------------------
BEGIN
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_FGA.DROP_POLICY(
            object_schema => ''TRASUA'',
            object_name   => ''BRANCH_INVENTORY'',
            policy_name   => ''FGA_INVENTORY_UPDATE''
        );
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_FGA.ADD_POLICY(
            object_schema   => ''TRASUA'',
            object_name     => ''BRANCH_INVENTORY'',
            policy_name     => ''FGA_INVENTORY_UPDATE'',
            audit_condition => NULL,  
            audit_column    => ''QUANTITY'',
            statement_types => ''UPDATE'',
            audit_trail     => DBMS_FGA.DB + DBMS_FGA.EXTENDED
        );
    END;';
    DBMS_OUTPUT.PUT_LINE('FGA da duoc cai dat: giam sat UPDATE QUANTITY tren BRANCH_INVENTORY');
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Chua the tao FGA. Vui long cap quyen: GRANT EXECUTE ON DBMS_FGA TO TRASUA;');
END;
/


-- -------------------------------------------------------
-- 4B. Ghi log khi ai UPDATE ty le giam gia (product_discount)
-- -------------------------------------------------------
BEGIN
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_FGA.DROP_POLICY(
            object_schema => ''TRASUA'',
            object_name   => ''PRODUCT_DISCOUNT'',
            policy_name   => ''FGA_DISCOUNT_UPDATE''
        );
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_FGA.ADD_POLICY(
            object_schema   => ''TRASUA'',
            object_name     => ''PRODUCT_DISCOUNT'',
            policy_name     => ''FGA_DISCOUNT_UPDATE'',
            audit_condition => NULL,
            audit_column    => ''DISCOUNTEDAMOUNT'',
            statement_types => ''UPDATE'',
            audit_trail     => DBMS_FGA.DB + DBMS_FGA.EXTENDED
        );
    END;';
    DBMS_OUTPUT.PUT_LINE('FGA da duoc cai dat: giam sat UPDATE DISCOUNTEDAMOUNT tren PRODUCT_DISCOUNT');
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/


-- -------------------------------------------------------
-- 4C. Ghi log khi tao phieu hoan tien bat thuong (bill_return)
-- -------------------------------------------------------
BEGIN
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_FGA.DROP_POLICY(
            object_schema => ''TRASUA'',
            object_name   => ''BILL_RETURN'',
            policy_name   => ''FGA_BILL_RETURN_INSERT''
        );
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_FGA.ADD_POLICY(
            object_schema   => ''TRASUA'',
            object_name     => ''BILL_RETURN'',
            policy_name     => ''FGA_BILL_RETURN_INSERT'',
            audit_condition => NULL,
            audit_column    => ''RETURNMONEY'',
            statement_types => ''INSERT'',
            audit_trail     => DBMS_FGA.DB + DBMS_FGA.EXTENDED
        );
    END;';
    DBMS_OUTPUT.PUT_LINE('FGA da duoc cai dat: giam sat INSERT tren BILL_RETURN');
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/


-- ============================================================
-- PHAN 5: DATA REDACTION
-- (Da duoc chuyen sang file 03_SECURITY_YEN.sql do Tan Yen phu trach)
-- ============================================================


-- ============================================================
-- PHAN 6: KIEM TRA VA BAO CAO KET QUA
-- Chay phan nay sau khi da chay xong tat ca cac Phan tren
-- ============================================================

-- Xem danh sach tat ca Stored Procedures da tao
SELECT object_name, object_type, status, last_ddl_time
FROM user_objects
WHERE object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE')
ORDER BY object_type, object_name;

-- Xem cac VPD Policies da ap dung
SELECT object_owner, object_name, policy_name, function, enable
FROM all_policies
WHERE object_owner = 'TRASUA'
ORDER BY object_name;

-- Xem cac FGA Policies (LUU Y: FGA chi co tren Oracle Enterprise Edition)
-- Neu dung Oracle Free/XE thi bo qua query nay
-- SELECT object_name, policy_name, statement_types, enabled FROM user_audit_policies;
-- Thay the: kiem tra Standard Audit
SELECT username, action_name, obj_name, timestamp
FROM user_audit_trail
WHERE timestamp > SYSDATE - 1
ORDER BY timestamp DESC;

-- Xem cac Redaction Policies (LUU Y: Data Redaction chi co tren Oracle Enterprise Edition)
-- Neu dung Oracle Free/XE thi bo qua query nay
-- Kiem tra cac object da tao thay the:
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PROCEDURE', 'FUNCTION', 'TRIGGER')
ORDER BY object_type, object_name;

-- Demo chay Procedure phan bo san pham vao Chi nhanh 1
SET SERVEROUTPUT ON;
DECLARE
    v_min_branch NUMBER;
BEGIN
    SELECT MIN(id) INTO v_min_branch FROM branch;
    PROC_INIT_BRANCH_INVENTORY(
        p_branch_id   => v_min_branch,
        p_default_qty => 100
    );
END;
/

-- Demo tinh doanh thu Chi nhanh 1 thang nay
SELECT
    b.branch_name                                   AS ten_chi_nhanh,
    FN_GET_BRANCH_REVENUE(b.id)                     AS doanh_thu_thang_nay,
    FN_GET_BRANCH_REVENUE(b.id,
        TRUNC(SYSDATE)-30, SYSDATE)                 AS doanh_thu_30_ngay,
    (SELECT COUNT(*) FROM branch_inventory bi
     WHERE bi.branch_id = b.id AND bi.isActive = 1) AS tong_mat_hang
FROM branch b
ORDER BY b.id;

-- Xem ket qua kho hang chi nhanh sau khi chay Procedure
SELECT
    p.name      AS ten_san_pham,
    sp.name     AS "size",
    c.name      AS duong,
    bi.quantity AS so_luong_ton_kho,
    CASE bi.isActive
        WHEN 1 THEN 'Dang ban'
        ELSE 'Ngung ban'
    END         AS trang_thai
FROM branch_inventory bi
JOIN product_detail pd ON bi.product_detail_id = pd.id
JOIN product        p  ON pd.product_id = p.id
JOIN size_product   sp ON pd.size_id = sp.id
JOIN color          c  ON pd.color_id = c.id
JOIN branch         b  ON bi.branch_id = b.id
WHERE b.id = (SELECT MIN(id) FROM branch)
ORDER BY p.name, sp.name;


-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 05_fix_inventory.sql
-- ============================================================
-- ============================================================
-- FILE: 05_fix_inventory.sql
-- MUC DICH: Fix loi kho hang trong (branch_inventory chua co du lieu)
-- NGUYEN NHAN: Cot trong bang branch_inventory dung camelCase
--   (isActive, createDate, updateDate, minQuantity)
--   khac voi snake_case (is_active, create_date...)
-- HUONG DAN: Chay file nay 1 LAN DUY NHAT trong SQL Developer
-- ============================================================

-- Kiem tra xem da co du lieu chua
SELECT COUNT(*) AS "So ban ghi trong branch_inventory"
FROM branch_inventory;

-- Kiem tra so product_detail hien co
SELECT COUNT(*) AS "So product_detail"
FROM product_detail;

-- INSERT toan bo product_detail vao Chi nhanh 1 (Ha Noi)
-- Chi insert nhung san pham CHUA co trong kho
INSERT INTO branch_inventory (branch_id, product_detail_id, quantity, isActive, createDate, updateDate, minQuantity)
SELECT
    (SELECT MIN(id) FROM branch)  AS branch_id,
    pd.id                         AS product_detail_id,
    100                           AS quantity,
    1                             AS isActive,
    SYSTIMESTAMP                  AS createDate,
    SYSTIMESTAMP                  AS updateDate,
    0                             AS minQuantity
FROM product_detail pd
WHERE NOT EXISTS (
    SELECT 1
    FROM branch_inventory bi
    WHERE bi.product_detail_id = pd.id
      AND bi.branch_id = (SELECT MIN(id) FROM branch)
);

COMMIT;

-- Xac nhan sau khi insert
SELECT
    bi.id          AS inventory_id,
    b.branch_name  AS chi_nhanh,
    p.name         AS ten_san_pham,
    sp.name        AS "size",
    c.name         AS duong,
    bi.quantity    AS so_luong,
    bi.isActive    AS con_kinh_doanh
FROM branch_inventory bi
JOIN branch           b  ON bi.branch_id = b.id
JOIN product_detail   pd ON bi.product_detail_id = pd.id
JOIN product          p  ON pd.product_id = p.id
JOIN size_product     sp ON pd.size_id = sp.id
JOIN color            c  ON pd.color_id = c.id
ORDER BY p.name, sp.name;



-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 07_update_bill_status.sql
-- ============================================================
-- ============================================================
-- 1C. PROC_UPDATE_BILL_STATUS
--     Muc dich: Cap nhat trang thai hoa don,
--               (vd: tu CHO_XAC_NHAN -> CHO_LAY_HANG)
--     Dau vao:
--       p_bill_id      (ID hoa don)
--       p_new_status   (Trang thai moi)
--     Dau ra:
--       p_result_msg   (Thong bao ket qua)
-- ============================================================
CREATE OR REPLACE PROCEDURE PROC_UPDATE_BILL_STATUS (
    p_bill_id     IN NUMBER,
    p_new_status  IN VARCHAR2,
    p_result_msg  OUT VARCHAR2
)
AS
    v_count NUMBER;
BEGIN
    -- Kiem tra hoa don ton tai
    SELECT COUNT(*) INTO v_count
    FROM bill WHERE id = p_bill_id;

    IF v_count = 0 THEN
        p_result_msg := 'Lỗi: Không tìm thấy hóa đơn ID = ' || p_bill_id;
        RETURN;
    END IF;

    UPDATE bill 
    SET status = p_new_status, 
        update_date = SYSTIMESTAMP 
    WHERE id = p_bill_id;
    
    COMMIT;
    p_result_msg := 'SUCCESS';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_result_msg := 'Lỗi: ' || SQLERRM;
END PROC_UPDATE_BILL_STATUS;
/


