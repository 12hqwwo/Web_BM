-- ============================================================
-- đŸ“Œ MODULE Gá»˜P Tá»ª FILE: 01_create_user_trasua.sql
-- ============================================================
-- ============================================================
-- PHAN 1: TAO TABLESPACE & USER & CAP QUYEN
-- Chay bang tai khoan SYS AS SYSDBA hoac DBA co quyen tao tablespace
-- Oracle Database 21c / 23ai compatible
-- ============================================================

-- ============================================================
-- BUOC 1: TAO TABLESPACE (neu chua ton tai)
-- Dieu chinh duong dan datafile phu hop voi he thong cua ban:
--   Windows : C:\oracle\oradata\ORCL\ts_trasua01.dbf
--   Linux   : /u01/app/oracle/oradata/ORCL/ts_trasua01.dbf
-- ============================================================
ALTER DATABASE OPEN;
CREATE TABLESPACE TS_TRASUA
    DATAFILE 'ts_trasua01.dbf'   -- Oracle tu tim thu muc data mac dinh
    SIZE 256M
    AUTOEXTEND ON NEXT 64M MAXSIZE UNLIMITED
    SEGMENT SPACE MANAGEMENT AUTO;

-- ============================================================
-- BUOC 2: TAO USER TRASUA
-- ============================================================
-- Kiem tra & xoa user cu neu can thiet (bo comment khi can reset):
-- DROP USER TRASUA CASCADE;

CREATE USER TRASUA
    IDENTIFIED BY "TraSua@2024"       -- Doi mat khau theo yeu cau
    DEFAULT   TABLESPACE TS_TRASUA
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON TS_TRASUA;

-- ============================================================
-- BUOC 3: CAP QUYEN CO BAN
-- ============================================================

-- Quyen dang nhap
GRANT CREATE SESSION TO TRASUA;

-- Quyen tao doi tuong trong schema cua chinh minh
GRANT CREATE TABLE     TO TRASUA;
GRANT CREATE SEQUENCE  TO TRASUA;
GRANT CREATE VIEW      TO TRASUA;
GRANT CREATE PROCEDURE TO TRASUA;
GRANT CREATE TRIGGER   TO TRASUA;
GRANT CREATE TYPE      TO TRASUA;
GRANT CREATE SYNONYM   TO TRASUA;
GRANT CREATE INDEX     TO TRASUA;

-- ============================================================
-- BUOC 4: QUYEN HO TRO HIBERNATE / SPRING DATA JPA
-- ============================================================

-- Cho phep Spring Data JPA doc metadata he thong (bat buoc)
GRANT SELECT ON SYS.V_$SESSION TO TRASUA;
GRANT SELECT ON SYS.V_$MYSTAT  TO TRASUA;  -- tuy chon, dung de monitoring

-- Cho phep Hibernate doc system sequences & constraints
GRANT SELECT ON SYS.ALL_SEQUENCES   TO TRASUA;
GRANT SELECT ON SYS.ALL_TABLES      TO TRASUA;
GRANT SELECT ON SYS.ALL_CONSTRAINTS TO TRASUA;

-- (Tuy chon) Neu dung spring.jpa.hibernate.ddl-auto=update:
-- GRANT ALTER ANY TABLE TO TRASUA;
-- Khong nen dung tren moi truong Production.

COMMIT;

-- ============================================================
-- Kiem tra lai sau khi chay:
--   SELECT username, default_tablespace, temporary_tablespace, account_status
--   FROM dba_users WHERE username = 'TRASUA';
--
--   SELECT tablespace_name, status, contents
--   FROM dba_tablespaces WHERE tablespace_name = 'TS_TRASUA';
-- ============================================================


