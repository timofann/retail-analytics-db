-- \connect "dbname=retail_analytics user=retail_user";

-- DROP VIEW IF EXISTS groups;
-- CREATE OR REPLACE VIEW groups AS(

-- );

INSERT INTO retail_analitycs_config VALUES (
    DEFAULT, 'groups_margin_calculation_method', 'by all transactions',
    'Three options are available: "by period" or "by number of transactions" or "by all transactions" (default)');

-- INSERT INTO retail_analitycs_config VALUES (
--     DEFAULT, 'groups_margin_days_from_analysis_formation', '356',
--     'If the option "groups_margin_calculation_method" is set to "by period"');

-- INSERT INTO retail_analitycs_config VALUES (
--     DEFAULT, 'groups_margin_number_of_transactions', '5',
--     'If the option "groups_margin_calculation_method" is set to "by number of transactions"');



CREATE OR REPLACE FUNCTION get_groups_transactions() 
RETURNS TABLE (
    customer_id             BIGINT,
    transaction_id          BIGINT,
    transaction_datetime    TIMESTAMP,
    group_id                BIGINT
) AS $$
DECLARE
    calculation_method VARCHAR := (
        SELECT setting AS calculation_method
        FROM retail_analitycs_config 
        WHERE name = 'groups_margin_calculation_method' );
    days_from_analysis_formation INT := (
        SELECT setting::INT AS days_from_analysis_formation
        FROM retail_analitycs_config
        WHERE name = 'groups_margin_days_from_analysis_formation' );
    number_of_transactions INT := (
        SELECT setting::INT AS number_of_transactions
        FROM retail_analitycs_config
        WHERE name = 'groups_margin_number_of_transactions' );
    last_date_by_period DATE := (
        SELECT MAX(analysis_formation)::DATE - days_from_analysis_formation AS last_date_by_period
        FROM date_of_analysis_formation
    );
BEGIN
    IF calculation_method = 'by all transactions' THEN
        RETURN QUERY (
            SELECT h.customer_id, h.transaction_id, h.transaction_datetime::TIMESTAMP, h.group_id
            FROM purchase_history h
        );
    ELSIF calculation_method = 'by period' THEN
        RETURN QUERY (
            SELECT customer_id, transaction_id, transaction_datetime, group_id
            FROM purchase_history
            WHERE transaction_datetime::TIMESTAMP >= last_date_by_period
        );
    ELSIF calculation_method = 'by number of transactions' THEN
        RETURN QUERY (
            SELECT customer_id, transaction_id, transaction_datetime, group_id
            FROM (
                SELECT customer_id, transaction_id, transaction_datetime, group_id,
                    ROW_NUMBER() OVER (PARTITION BY customer_id, transaction_id ORDER BY transaction_datetime DESC) AS row_n
                FROM purchase_history ) h
            WHERE row_n <= number_of_transactions
        );
    ELSE
        RAISE 'retail_analitycs_config.groups_margin_calculation_method should be set up correctly.';
    END IF;
END $$
LANGUAGE plpgsql;

SELECT * FROM retail_analitycs_config;
SELECT * FROM date_of_analysis_formation;

SELECT * FROM get_groups_transactions();



WITH
checks AS (
    SELECT transaction_id, sku_id FROM checks
),
products AS (
    SELECT sku_id, group_id FROM products
),
transactions AS (
    SELECT transaction_id, card_id, transaction_datetime FROM transactions
),
general_transactions AS ( -- all transactions for groups inside the period of bying
    SELECT p.customer_id, group_id, COUNT(transaction_id) AS transactions_count
    FROM periods p 
    JOIN purchase_history h ON p.customer_id = h.customer_id AND p.group_id = h.group_id
    WHERE 
        transaction_datetime >= first_group_purchase_date::TIMESTAMP AND 
        transaction_datetime <= last_group_purchase_date::TIMESTAMP
    GROUP BY p.customer_id, group_id
),
group_transactions AS ( -- transactions for groups inside the period of bying where the group was bought
    SELECT customer_id, group_id, COUNT(transaction_id) AS transactions_count
    FROM purchase_history
    GROUP BY customer_id, group_id
), 
affinity_index AS (
    SELECT 
        gen.customer_id, 
        gen.group_id, 
        gr.transactions_count::NUMERIC / gen.transactions_count AS group_affinity_index
    FROM general_transactions gen JOIN
        group_transactions gr ON gen.customer_id = gr.customer_id AND gen.group_id = gr.group_id
),
churn_rate AS (
    SELECT 
        p.customer_id,
        p.group_id,
        (analysis_formation::DATE - last_group_purchase_date::DATE)::NUMERIC / group_frequency AS group_churn_rate 
    FROM periods p
    CROSS JOIN (
        SELECT MAX(analysis_formation) AS analysis_formation
        FROM date_of_analysis_formation ) d
),
stability_index AS (
    SELECT 
        h.customer_id,
        h.group_id,
        AVG(ABS(h.purchase_interval - p.group_frequency) / p.group_frequency) AS group_stability_index 
    FROM (
        SELECT
            customer_id, 
            group_id,
            (LAG(transaction_datetime, -1) OVER (PARTITION BY customer_id, group_id ORDER BY transaction_datetime::TIMESTAMP))::DATE - transaction_datetime::DATE AS purchase_interval
        FROM purchase_history ) h
    JOIN periods p ON h.customer_id = p.customer_id AND h.group_id = p.group_id
    WHERE h.purchase_interval IS NOT NULL
    GROUP BY h.customer_id, h.group_id
)
SELECT

CALL import_default_dataset();
SELECT * FROM personal_information;