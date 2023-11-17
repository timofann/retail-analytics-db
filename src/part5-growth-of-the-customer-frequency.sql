\connect "dbname=retail_analytics user=retail_user";

-- Get interval between dates
DROP FUNCTION IF EXISTS get_interval_between_dates CASCADE;
CREATE OR REPLACE FUNCTION get_interval_between_dates(
    init_date TIMESTAMPTZ, 
    stop_date TIMESTAMPTZ
) RETURNS NUMERIC 
AS $$
DECLARE
    period NUMERIC;
BEGIN
    period := (EXTRACT(EPOCH FROM (init_date-stop_date))::DECIMAL / 60 / 60 / 24)::NUMERIC;
    RETURN period;
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

DROP FUNCTION IF EXISTS form_personal_offer_by_customer_frequency CASCADE;
CREATE FUNCTION form_personal_offer_by_customer_frequency(
    init_date TIMESTAMP, 
    stop_date TIMESTAMP,
    added_number_of_transactions BIGINT,
    maximum_churn_rate NUMERIC,
    maximum_discount_share NUMERIC,
    allowable_margin_share NUMERIC
) RETURNS TABLE (
    customer_id BIGINT,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    required_transactions_count BIGINT,
    group_name VARCHAR,
    offer_discount_depth NUMERIC
)
AS $$
BEGIN
    RETURN QUERY (
    WITH

        allowable_groups AS (
            SELECT
                g.customer_id,
                g.group_id,
                round_discount(g.group_minimum_discount * 100) AS offer_discount_depth,
                ROW_NUMBER() OVER affinity_window AS rating
            FROM groups g
            WHERE
                group_churn_rate IS NOT NULL AND
                group_churn_rate < maximum_churn_rate AND
                group_discount_share < (maximum_discount_share / 100) AND
                group_margin > (round_discount(group_minimum_discount * 100)) / allowable_margin_share
            WINDOW 
                affinity_window AS (
                    PARTITION BY g.customer_id
                    ORDER BY g.group_affinity_index DESC, g.group_minimum_discount DESC )
        )

    SELECT
        c.customer_id AS customer_id,
        init_date AS start_date,
        stop_date AS end_date,
        ROUND(get_interval_between_dates(init_date, stop_date) /
        c.customer_frequency)::BIGINT + added_number_of_transactions AS required_transactions_count,
        s.group_name AS group_name,
        g.offer_discount_depth AS offer_discount_depth
    FROM customers c
    LEFT JOIN (
        SELECT * FROM allowable_groups WHERE rating = 1 ) g 
        ON c.customer_id = g.customer_id
    LEFT JOIN sku_groups sku ON g.group_id = sku.group_id );
END; $$
LANGUAGE plpgsql;

-- SELECT * FROM form_personal_offer_by_customer_frequency('18.08.2022 00:00:00', '18.08.2024 00:00:00', 1);
SELECT * FROM form_personal_offer_by_customer_frequency('18.08.2022 00:00:00', '18.08.2024 00:00:00', 5, 1000, 90, 1.2);


SELECT * from Customers;
SELECT * from customers;

CALL import_default_dataset_mini();

    SELECT i.customer_id, c.required_check_measure, s.group_name, g.offer_discount_depth
    FROM personal_information i
    LEFT JOIN required_average_check c ON i.customer_id = c.customer_id
    LEFT JOIN (
        SELECT * FROM allowable_groups WHERE rating = 1 ) g 
        ON i.customer_id = g.customer_id
    LEFT JOIN sku_group s ON g.group_id = s.group_id );