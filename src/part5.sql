-- Get interval between dates
CREATE OR REPLACE FUNCTION get_interval_between_dates(
    init_date TIMESTAMPTZ, 
    stop_date TIMESTAMPTZ
) RETURNS NUMERIC 
AS $$
DECLARE
    date_interval INTERVAL := init_date - stop_date;
BEGIN
    RETURN ABS(date_part('day', date_interval)
        + date_part('hour', date_interval)/24
        + date_part('minute', date_interval)/(24*60)
        + date_part('second', date_interval)/(24*60*60));
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION form_personal_offer_by_customer_frequency (
    start_date TIMESTAMPTZ, 
    end_date TIMESTAMPTZ,
    added_number_of_transactions BIGINT,
    maximum_churn_index NUMERIC,
    maximum_discount_share NUMERIC,
    acceptable_margin_share NUMERIC
) RETURNS TABLE (
    customer_id INTEGER,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    required_transactions_count NUMERIC,
    group_name VARCHAR,
    offer_discount_depth NUMERIC
)


period = get_interval_between_dates(start_date, end_date);

current_frequensy = period / SELECT customer_frequency FROM VIEW Customers;