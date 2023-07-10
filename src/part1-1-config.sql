DROP TABLE IF EXISTS retail_analitycs_config CASCADE;
CREATE TABLE retail_analitycs_config (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR NOT NULL UNIQUE,
    setting         VARCHAR NOT NULL,
    description     VARCHAR NOT NULL
);

INSERT INTO retail_analitycs_config VALUES (
    DEFAULT, 'data_path', '/Volumes/PortableSSD/School21 Projects/SQL2/src/data',
    'Absolute path to csv and tsv files directory which is used for import and export data');

SELECT * FROM retail_analitycs_config;

/*                     === TABLES MANIPULATION ===                    */

CREATE OR REPLACE PROCEDURE drop_tables ()
AS $$
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

CREATE OR REPLACE PROCEDURE truncate_tables ()
AS $$
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
CREATE OR REPLACE PROCEDURE export_to_tsv(
    table_name      VARCHAR
) AS $$
DECLARE file_name VARCHAR := (SELECT current_database()) 
    || '.' || table_name || ' shot ' || TO_CHAR(now(), 'YYYY-MM-DD at HH24:MI:SS.US') || '.tsv';
BEGIN
    EXECUTE FORMAT('COPY %s TO %s WITH DELIMITER AS E''\t'' CSV HEADER FORCE QUOTE *',
        quote_ident(table_name),  
        quote_literal(
            (SELECT setting FROM retail_analitycs_config WHERE name = 'data_path') 
                || '/' || file_name));
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS export_to_csv CASCADE;
CREATE OR REPLACE PROCEDURE export_to_csv(
    table_name      VARCHAR
) AS $$
DECLARE file_name VARCHAR := (SELECT current_database()) 
    || '.' || table_name || ' shot ' || TO_CHAR(now(), 'YYYY-MM-DD at HH24:MI:SS.US') || '.csv';
BEGIN
    EXECUTE FORMAT('COPY %s TO %s WITH DELIMITER AS '','' CSV HEADER FORCE QUOTE *',
        quote_ident(table_name),  
        quote_literal(
            (SELECT setting FROM retail_analitycs_config WHERE name = 'data_path') 
                || '/' || file_name));
END $$
LANGUAGE plpgsql;

/*                         === DATA IMPORT ===                        */

DROP PROCEDURE IF EXISTS import_from_tsv(VARCHAR, VARCHAR) CASCADE;
CREATE OR REPLACE PROCEDURE import_from_tsv(
    table_name      VARCHAR,
    file_name       VARCHAR
) AS $$
BEGIN
    IF NOT (file_name SIMILAR TO '%.tsv') THEN
        RAISE 'Using import_from_tsv with wrong file extension'; END IF;
    EXECUTE FORMAT('COPY %s FROM %s WITH DELIMITER AS E''\t'' CSV HEADER',
        quote_ident(table_name),  
        quote_literal(
            (SELECT setting FROM retail_analitycs_config WHERE name = 'data_path') 
                || '/' || file_name));
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import_from_tsv(VARCHAR) CASCADE;
CREATE OR REPLACE PROCEDURE import_from_tsv(
    table_name      VARCHAR
) AS $$
BEGIN
    CALL import_from_tsv(table_name, table_name || '.tsv');
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import_from_csv(VARCHAR, VARCHAR) CASCADE;
CREATE OR REPLACE PROCEDURE import_from_csv(
    table_name      VARCHAR,
    file_name       VARCHAR
) AS $$
BEGIN
    IF NOT (file_name SIMILAR TO '%.csv') THEN
        RAISE 'Using import_from_csv with wrong file extension'; END IF;
    EXECUTE FORMAT('COPY %s FROM %s WITH DELIMITER AS '','' CSV HEADER',
        quote_ident(table_name),  
        quote_literal(
            (SELECT setting FROM retail_analitycs_config WHERE name = 'data_path') 
                || '/' || file_name));
END $$
LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import_from_csv(VARCHAR) CASCADE;
CREATE OR REPLACE PROCEDURE import_from_csv(
    table_name      VARCHAR
) AS $$
BEGIN
    CALL import_from_csv(table_name, table_name || '.csv');
END $$
LANGUAGE plpgsql;