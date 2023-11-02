/*                         === NEW DATABASE ===                       */

CREATE USER retail_user SUPERUSER CREATEDB CREATEROLE;

CREATE DATABASE retail_analytics
    OWNER retail_user
    TEMPLATE template0;

ALTER DATABASE retail_analytics
    SET datestyle TO 'ISO, DMY';

-- if file is running with psql then run:
\connect "dbname=retail_analytics user=retail_user"; 
-- or simply create new connection with IDE tools

/*                       === SESSION SETTINGS ===                     */

DROP TABLE IF EXISTS retail_analitycs_config CASCADE;
CREATE TABLE retail_analitycs_config (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR NOT NULL UNIQUE,
    setting         VARCHAR NOT NULL,
    description     VARCHAR NOT NULL
);

INSERT INTO retail_analitycs_config VALUES (
    DEFAULT, 'data_path', '/Volumes/PortableSSD/School21_Projects/SQL2/src/data',
    'Absolute path to csv and tsv files directory which is used for import and export data');



/*                     === TABLES MANIPULATION ===                    */

DROP PROCEDURE IF EXISTS drop_tables CASCADE;
CREATE PROCEDURE drop_tables(
) AS $$
BEGIN
    DROP TABLE IF EXISTS personal_information CASCADE;
    DROP TABLE IF EXISTS cards CASCADE;
    DROP TABLE IF EXISTS sku_groups CASCADE;
    DROP TABLE IF EXISTS products CASCADE;
    DROP TABLE IF EXISTS stores CASCADE;
    DROP TABLE IF EXISTS stores_products CASCADE;
    DROP TABLE IF EXISTS transactions CASCADE;
    DROP TABLE IF EXISTS checks CASCADE;
    DROP TABLE IF EXISTS date_of_analysis_formation CASCADE;
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS truncate_tables CASCADE;
CREATE PROCEDURE truncate_tables(
) AS $$
BEGIN
    TRUNCATE TABLE personal_information RESTART IDENTITY CASCADE;
    TRUNCATE TABLE cards RESTART IDENTITY CASCADE;
    TRUNCATE TABLE sku_groups RESTART IDENTITY CASCADE;
    TRUNCATE TABLE products RESTART IDENTITY CASCADE;
    TRUNCATE TABLE stores RESTART IDENTITY CASCADE;
    TRUNCATE TABLE stores_products RESTART IDENTITY CASCADE;
    TRUNCATE TABLE transactions RESTART IDENTITY CASCADE;
    TRUNCATE TABLE checks RESTART IDENTITY CASCADE;
    TRUNCATE TABLE date_of_analysis_formation RESTART IDENTITY CASCADE;
END $$
LANGUAGE plpgsql;

/*                         === DATA EXPORT ===                        */

DROP PROCEDURE IF EXISTS export_to_tsv CASCADE;
CREATE PROCEDURE export_to_tsv(
    table_name      VARCHAR
) AS $$
DECLARE file_name VARCHAR := (SELECT current_database()) 
    || '.' || table_name || ' shot ' || TO_CHAR(now(), 'YYYY-MM-DD at HH24:MI:SS.US') || '.tsv';
BEGIN
    EXECUTE FORMAT('COPY %s TO %s WITH DELIMITER AS E''\t''',
        quote_ident(table_name),  
        quote_literal(
            (SELECT setting FROM retail_analitycs_config WHERE name = 'data_path') 
                || '/' || file_name));
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS export_to_csv CASCADE;
CREATE PROCEDURE export_to_csv(
    table_name      VARCHAR
) AS $$
DECLARE file_name VARCHAR := (SELECT current_database()) 
    || '.' || table_name || ' shot ' || TO_CHAR(now(), 'YYYY-MM-DD at HH24:MI:SS.US') || '.csv';
BEGIN
    EXECUTE FORMAT('COPY %s TO %s WITH DELIMITER AS '',''',
        quote_ident(table_name),  
        quote_literal(
            (SELECT setting FROM retail_analitycs_config WHERE name = 'data_path') 
                || '/' || file_name));
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS export(CHAR, VARCHAR) CASCADE;
CREATE PROCEDURE export(
    mark            CHAR,
    table_name      VARCHAR
) AS $$
BEGIN
    IF mark <> ',' AND mark <> E'\t' THEN
        RAISE 'Using export with wrong mark symbol. Use '','' or ''\t'''; END IF;
    IF mark = ',' THEN
        CALL export_to_csv(table_name); END IF;
    IF mark = E'\t' THEN
        CALL export_to_tsv(table_name); END IF;
END $$
LANGUAGE plpgsql;

/*                         === DATA IMPORT ===                        */

DROP PROCEDURE IF EXISTS import_from_tsv(VARCHAR, VARCHAR) CASCADE;
CREATE PROCEDURE import_from_tsv(
    table_name      VARCHAR,
    file_name       VARCHAR
) AS $$
BEGIN
    IF NOT (file_name SIMILAR TO '%.tsv') THEN
        RAISE 'Using import_from_tsv with wrong file extension'; END IF;
    EXECUTE FORMAT('COPY %s FROM %s WITH DELIMITER AS E''\t''',
        quote_ident(table_name),  
        quote_literal(
            (SELECT setting FROM retail_analitycs_config WHERE name = 'data_path') 
                || '/' || file_name));
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import_from_tsv(VARCHAR) CASCADE;
CREATE PROCEDURE import_from_tsv(
    table_name      VARCHAR
) AS $$
BEGIN
    CALL import_from_tsv(table_name, table_name || '.tsv');
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import_from_csv(VARCHAR, VARCHAR) CASCADE;
CREATE PROCEDURE import_from_csv(
    table_name      VARCHAR,
    file_name       VARCHAR
) AS $$
BEGIN
    IF NOT (file_name SIMILAR TO '%.csv') THEN
        RAISE 'Using import_from_csv with wrong file extension'; END IF;
    EXECUTE FORMAT('COPY %s FROM %s WITH DELIMITER AS '',''',
        quote_ident(table_name),  
        quote_literal(
            (SELECT setting FROM retail_analitycs_config WHERE name = 'data_path') 
                || '/' || file_name));
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import_from_csv(VARCHAR) CASCADE;
CREATE PROCEDURE import_from_csv(
    table_name      VARCHAR
) AS $$
BEGIN
    CALL import_from_csv(table_name, table_name || '.csv');
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import(CHAR, VARCHAR, VARCHAR) CASCADE;
CREATE PROCEDURE import(
    mark            CHAR,
    table_name      VARCHAR,
    file_name       VARCHAR
) AS $$
BEGIN
    IF mark <> ',' AND mark <> E'\t' THEN
        RAISE 'Using import with wrong mark symbol. Use '','' or ''\t'''; END IF;
    IF mark = ',' THEN
        CALL import_from_csv(table_name, file_name); END IF;
    IF mark = E'\t' THEN
        CALL import_from_tsv(table_name, file_name); END IF;
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import(CHAR, VARCHAR) CASCADE;
CREATE PROCEDURE import(
    mark            CHAR,
    table_name      VARCHAR
) AS $$
BEGIN
    IF mark <> ',' AND mark <> E'\t' THEN
        RAISE 'Using import with wrong mark symbol. Use '','' or ''\t'''; END IF;
    IF mark = ',' THEN
        CALL import_from_csv(table_name); END IF;
    IF mark = E'\t' THEN
        CALL import_from_tsv(table_name); END IF;
END $$
LANGUAGE plpgsql;

/*                       === DEFAULT DATASETS ===                      */

DROP PROCEDURE IF EXISTS setval_for_tables_sequences CASCADE;
CREATE PROCEDURE setval_for_tables_sequences(
) AS $$
BEGIN
    PERFORM setval('personal_information_customer_id_seq', 
        (SELECT MAX(customer_id) FROM personal_information));
    PERFORM setval('cards_card_id_seq', 
        (SELECT MAX(card_id) FROM cards));
    PERFORM setval('sku_groups_group_id_seq', 
        (SELECT MAX(group_id) FROM sku_groups));
    PERFORM setval('products_sku_id_seq', 
        (SELECT MAX(sku_id) FROM products));
    PERFORM setval('stores_store_id_seq', 
        (SELECT MAX(store_id) FROM stores));
    PERFORM setval('transactions_transaction_id_seq', 
        (SELECT MAX(transaction_id) FROM transactions));
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import_default_dataset CASCADE;
CREATE PROCEDURE import_default_dataset(
) AS $$
BEGIN
    CALL truncate_tables();
    CALL import(E'\t', 'personal_information', '../../datasets/Personal_Data_Mini.tsv');
    CALL import(E'\t', 'cards', '../../datasets/Cards_Mini.tsv');
    CALL import(E'\t', 'sku_groups', '../../datasets/Groups_SKU_Mini.tsv');
    CALL import(E'\t', 'products', '../../datasets/SKU_Mini.tsv');
    CALL import(E'\t', 'stores', '../../datasets/Unique_Stores_Mini.tsv');
    CALL import(E'\t', 'stores_products', '../../datasets/Stores_Mini.tsv');
    CALL import(E'\t', 'transactions', '../../datasets/Transactions_Mini.tsv');
    CALL import(E'\t', 'checks', '../../datasets/Checks_Mini.tsv');
    CALL import(E'\t', 'date_of_analysis_formation', '../../datasets/Date_Of_Analysis_Formation.tsv');
    CALL setval_for_tables_sequences();
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import_default_dataset_mini CASCADE;
CREATE PROCEDURE import_default_dataset_mini(
) AS $$
BEGIN
    CALL truncate_tables();
    CALL import(E'\t', 'personal_information', '../../datasets/Personal_Data_Mini.tsv');
    CALL import(E'\t', 'cards', '../../datasets/Cards_Mini.tsv');
    CALL import(E'\t', 'sku_groups', '../../datasets/Groups_SKU_Mini.tsv');
    CALL import(E'\t', 'products', '../../datasets/SKU_Mini.tsv');
    CALL import(E'\t', 'stores', '../../datasets/Unique_Stores_Mini.tsv');
    CALL import(E'\t', 'stores_products', '../../datasets/Stores_Mini.tsv');
    CALL import(E'\t', 'transactions', '../../datasets/Transactions_Mini.tsv');
    CALL import(E'\t', 'checks', '../../datasets/Checks_Mini.tsv');
    CALL import(E'\t', 'date_of_analysis_formation', '../../datasets/Date_Of_Analysis_Formation.tsv');
    CALL setval_for_tables_sequences();
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import_custom_dataset CASCADE;
CREATE PROCEDURE import_custom_dataset(
) AS $$
BEGIN
    CALL truncate_tables();
    CALL import(',', 'personal_information');
    CALL import(',', 'cards');
    CALL import(',', 'sku_groups');
    CALL import(',', 'products');
    CALL import(',', 'stores');
    CALL import(',', 'stores_products');
    CALL import(',', 'transactions');
    CALL import(',', 'checks');
    CALL import(',', 'date_of_analysis_formation');
    CALL setval_for_tables_sequences();
END $$
LANGUAGE plpgsql;