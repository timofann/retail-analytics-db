\connect -reuse-previous=on "dbname=retail_analytics user=retail_user"; 

DROP FUNCTION IF EXISTS get_calculation_method CASCADE;
CREATE FUNCTION get_calculation_method()
RETURNS VARCHAR
AS $$
DECLARE
    _res VARCHAR := (
        SELECT setting
        FROM retail_analitycs_config
        WHERE name = 'groups_margin_calculation_method' );
BEGIN
    IF _res IS NULL THEN
        RAISE 'retail_analitycs_config.groups_margin_calculation_method should be set up correctly.';
    END IF;
    RETURN _res;
END $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_transactions_count CASCADE;
CREATE FUNCTION get_transactions_count()
RETURNS BIGINT
AS $$
DECLARE
    _res BIGINT := (
        SELECT setting
        FROM retail_analitycs_config
        WHERE name = 'groups_margin_transactions_count' );
BEGIN
    IF _res IS NULL THEN
        RAISE 'retail_analitycs_config.groups_margin_transactions_count should be set up correctly.';
    END IF;
    RETURN _res;
END $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_days_from_analysis_formation CASCADE;
CREATE FUNCTION get_days_from_analysis_formation()
RETURNS INTERVAL
AS $$
DECLARE
    _res INTERVAL := (
        SELECT MAKE_INTERVAL(DAYS => setting::INT)
        FROM retail_analitycs_config
        WHERE name = 'groups_margin_days_from_analysis_formation' );
BEGIN
    IF _res IS NULL THEN
        RAISE 'retail_analitycs_config.groups_margin_days_from_analysis_formation should be set up correctly.';
    END IF;
    RETURN _res;
END $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_interval_between_dates CASCADE;
CREATE FUNCTION get_interval_between_dates(
    init_date TIMESTAMP, 
    stop_date TIMESTAMP
) RETURNS NUMERIC
AS $$
DECLARE
    _period NUMERIC;
BEGIN
    _period := EXTRACT(EPOCH FROM (init_date - stop_date))::NUMERIC / (24 * 60 * 60);
    RETURN _period;
END; $$
LANGUAGE plpgsql; 

DROP FUNCTION IF EXISTS round_discount CASCADE;
CREATE OR REPLACE FUNCTION round_discount(discount NUMERIC)
    RETURNS NUMERIC
AS $$
BEGIN
    RETURN ((FLOOR(discount / 5)) + (discount % 5 != 0)::INT) * 5.0;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_last_analysis_date CASCADE;
CREATE FUNCTION get_last_analysis_date()
RETURNS TIMESTAMP
AS $$
BEGIN
    RETURN (
        SELECT max(analysis_formation) 
        FROM date_of_analysis_formation
    );
END; $$
LANGUAGE plpgsql;
