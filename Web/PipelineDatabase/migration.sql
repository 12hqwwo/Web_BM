CONNECT TRASUA/"TraSua@2024"@localhost:1521/FREEPDB1
ALTER TABLE bill ADD (account_id NUMBER(19));
UPDATE bill b SET account_id = (SELECT MIN(id) FROM account a WHERE a.customer_id = b.customer_id) WHERE b.customer_id IS NOT NULL;
ALTER TABLE bill ADD CONSTRAINT fk_bill_account FOREIGN KEY (account_id) REFERENCES account(id);
COMMIT;
EXIT;
