\connect -reuse-previous=on "dbname=retail_analytics user=retail_user"; 

DROP FUNCTION IF EXISTS contains_only_letters_spaces_dashes CASCADE;
CREATE FUNCTION contains_only_letters_spaces_dashes (
    str VARCHAR, table_name VARCHAR, field_name VARCHAR )
    RETURNS BOOLEAN
AS $$
BEGIN
    IF str SIMILAR TO '[А-Яа-яA-Za-z -]*' THEN
        RETURN TRUE;
    END IF;
    RAISE '%.% value should consist of the letters, spases and dashes only', table_name, field_name;
END; $$
LANGUAGE plpgsql
IMMUTABLE;

DROP FUNCTION IF EXISTS starts_with_capitalised_letter CASCADE;
CREATE FUNCTION starts_with_capitalised_letter (
    str VARCHAR, table_name VARCHAR, field_name VARCHAR )
    RETURNS BOOLEAN
AS $$
BEGIN
    IF str SIMILAR TO '[A-ZА-Я]%' THEN
        RETURN TRUE;
    END IF;
    RAISE '%.% value should starts with the capitalized letter', table_name, field_name;
END; $$
LANGUAGE plpgsql
IMMUTABLE;

DROP FUNCTION IF EXISTS has_email_format CASCADE;
CREATE FUNCTION has_email_format (
    str VARCHAR, table_name VARCHAR, field_name VARCHAR )
    RETURNS BOOLEAN
AS $$
BEGIN
    IF str SIMILAR TO '([^@]*)@(([^@]+).+)([^@.]+)' THEN
        RETURN TRUE;
    END IF;
    RAISE '%.% value should correspond the next pattern: <login>@...<secondleveldomain>.<firstleveldomain>', table_name, field_name;
END; $$
LANGUAGE plpgsql
IMMUTABLE;

DROP FUNCTION IF EXISTS has_correct_login CASCADE;
CREATE FUNCTION has_correct_login (
    str VARCHAR, table_name VARCHAR, field_name VARCHAR )
    RETURNS BOOLEAN
AS $$
BEGIN
    IF str SIMILAR TO '([a-zA-Z0-9.!?#$%&+/=^_`’{|}~½-]+)@%' THEN
        RETURN TRUE;
    END IF;
    RAISE '%.% : login can consist of the characters a-zA-Z0-9.!?#$&+/=^_`’{|}~½-', table_name, field_name; --fix %
END; $$
LANGUAGE plpgsql
IMMUTABLE;

DROP FUNCTION IF EXISTS has_correct_nleveldomain CASCADE;
CREATE FUNCTION has_correct_nleveldomain (
    str VARCHAR, table_name VARCHAR, field_name VARCHAR )
    RETURNS BOOLEAN
AS $$
BEGIN
    IF str SIMILAR TO '([^@]+)@(([a-zA-Z0-9-]+).+)%' THEN
        RETURN TRUE;
    END IF;
    RAISE '%.% : nleveldomain can consist of the characters [a-zA-Z0-9-] and should not be empty', table_name, field_name;
END; $$
LANGUAGE plpgsql
IMMUTABLE;

DROP FUNCTION IF EXISTS has_correct_firstleveldomain CASCADE;
CREATE FUNCTION has_correct_firstleveldomain (
    str VARCHAR, table_name VARCHAR, field_name VARCHAR )
    RETURNS BOOLEAN
AS $$
BEGIN
    IF str SIMILAR TO '([^@]+)@(([^@]+).+)([a-zA-Z0-9]-*)([a-zA-Z0-9]+)' THEN
        RETURN TRUE;
    END IF;
    RAISE '%.% : firstleveldomain can consist of the characters [a-zA-Z0-9-] and should end with [a-zA-Z0-9]', table_name, field_name;
END; $$
LANGUAGE plpgsql
IMMUTABLE;

DROP FUNCTION IF EXISTS has_phone_format CASCADE;
CREATE FUNCTION has_phone_format (
    str VARCHAR, table_name VARCHAR, field_name VARCHAR )
    RETURNS BOOLEAN
AS $$
BEGIN
    IF str SIMILAR TO '[+]{1}7[0-9]{10}%' THEN
        RETURN TRUE;
    END IF;
    RAISE '%.% : phone number should consist of +7 and 10 arabic numerals', table_name, field_name;
END; $$
LANGUAGE plpgsql
IMMUTABLE;

DROP FUNCTION IF EXISTS check_sku_is_in_the_shop CASCADE;
CREATE FUNCTION check_sku_is_in_the_shop()
    RETURNS TRIGGER
AS $$
BEGIN
    IF (
        SELECT (
            SELECT COUNT(transaction_store_id)
            FROM stores
            WHERE transaction_store_id = (
                SELECT transaction_store_id
                FROM transactions
                WHERE transaction_id = NEW.transaction_id) AND
                  sku_id = NEW.sku_id) = 0 )
    THEN
        RAISE 'sku not in the shop, cant add to check: transaction %, sku %',
            NEW.transaction_id, NEW.sku_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
