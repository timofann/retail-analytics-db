\connect "dbname=retail_analytics user=retail_user";

-- Get interval between dates
DROP FUNCTION IF EXISTS get_interval_between_dates() CASCADE;
CREATE OR REPLACE FUNCTION get_interval_between_dates(
    init_date TIMESTAMP, 
    stop_date TIMESTAMP
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


CREATE OR REPLACE FUNCTION form_personal_offer_by_customer_frequency(
    start_date TIMESTAMP, 
    end_date TIMESTAMP,
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
AS $$
BEGIN
    RETURN QUERY
    SELECT
        customer.customer_id,
        start_date,
        end_date,
        ROUND(get_interval_between_dates(start_date, end_date) / customer.customer_frequency) + added_number_of_transactions,
        

    
END; $$


period = get_interval_between_dates(start_date, end_date);

current_frequensy = period / SELECT customer_frequency FROM VIEW Customers;



SELECT 
    ph.customer_id, ph.group_id
FROM purchase_history ph 
LEFT JOIN groups g ON ph.customer_id = g.customer_id AND ph.group_id = g.group_id
LEFT JOIN customers c ON ph.customer_id = c.customer_id
WHERE
    group_churn_rate < 600.0 AND
    group_discount_share < 34 / 100 AND
    group_margin > (group_minimum_discount / 34 / 100)
GROUP BY ph.customer_id, ph.group_id
HAVING group_affinity_index = MAX(group_affinity_index);

CALL import_default_dataset_mini();