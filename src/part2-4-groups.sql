-- \connect "dbname=retail_analytics user=retail_user";

-- DROP VIEW IF EXISTS groups;
-- CREATE OR REPLACE VIEW groups AS(

-- );

-- INSERT INTO retail_analitycs_config VALUES (
--     DEFAULT, 'groups_margin_calculation_method', 'by period',
--     'Two options are available: "by period" or "by number of transactions"');

-- INSERT INTO retail_analitycs_config VALUES (
--     DEFAULT, 'groups_margin_days_from_analysis_formation', '356',
--     'If the option "groups_margin_days_from_analysis_formation" is set to "by period"');

-- INSERT INTO retail_analitycs_config VALUES (
--     DEFAULT, 'groups_margin_number_of_transactions', '5',
--     'If the option "groups_margin_days_from_analysis_formation" is set to "by number of transactions"');



CREATE FUNCTION get_groups_transactions() RETURNS TABLE




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
transaction_customer AS ( -- list of all transactions with customer-owner
    SELECT transaction_id, transaction_datetime, customer_id 
    FROM transactions t JOIN 
        cards ON cards.card_id = t.card_id
),
bying_groups AS (
    SELECT DISTINCT t.transaction_id, customer_id, group_id, transaction_datetime
    FROM checks c JOIN 
        products p ON c.sku_id = p.sku_id JOIN 
        transactions t ON t.transaction_id = c.transaction_id JOIN
        cards ON cards.card_id = t.card_id
),
periods_of_bying_groups AS ( -- start and end date of buying certain group by customer
    SELECT DISTINCT
        customer_id,
        group_id,
        MIN(transaction_datetime) AS start_period,
        MAX(transaction_datetime) AS end_period
    FROM bying_groups
    GROUP BY customer_id, group_id
),
general_transactions AS ( -- all transactions for groups inside the period of bying
    SELECT p.customer_id, group_id, COUNT(transaction_id) AS transactions_count
    FROM periods_of_bying_groups p JOIN transaction_customer tc ON p.customer_id = tc.customer_id
        WHERE transaction_datetime >= start_period AND transaction_datetime <= end_period
    GROUP BY p.customer_id, group_id
),
group_transactions AS ( -- transactions for groups inside the period of bying where the group was bought
    SELECT customer_id, group_id, COUNT(transaction_id) AS transactions_count
    FROM bying_groups
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
frequency AS (
    SELECT 
        p.customer_id, 
        p.group_id, 
        (end_period::DATE - start_period::DATE + 1)::NUMERIC / transactions_count AS group_frequency
    FROM periods_of_bying_groups p JOIN 
        group_transactions gt ON p.customer_id = gt.customer_id AND p.group_id = gt.group_id
),
date_of_analysis_formation AS (
    SELECT MAX(analysis_formation) AS analysis_formation 
    FROM date_of_analysis_formation
),
churn_rate AS (
    SELECT 
        p.customer_id,
        p.group_id,
        (analysis_formation::DATE - end_period::DATE)::NUMERIC / group_frequency AS group_churn_rate 
    FROM periods_of_bying_groups p CROSS JOIN 
        date_of_analysis_formation d JOIN 
        frequency f ON p.customer_id = f.customer_id AND p.group_id = f.group_id
),
stability_index AS (
    SELECT i.customer_id, i.group_id, AVG(ABS(interv - group_frequency) / group_frequency) AS group_stability_index 
    FROM
        (SELECT *, (LAG(transaction_datetime, -1) OVER (PARTITION BY customer_id, group_id ORDER BY transaction_datetime))::DATE - transaction_datetime::DATE AS interv
        FROM bying_groups) i JOIN
        frequency f ON i.customer_id = f.customer_id AND i.group_id = f.group_id
    WHERE interv IS NOT NULL
    GROUP BY i.customer_id, i.group_id
)
SELECT

CALL import_default_dataset();
SELECT * FROM personal_information;