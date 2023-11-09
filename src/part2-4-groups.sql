\connect "dbname=retail_analytics user=retail_user";

CREATE OR REPLACE FUNCTION get_calculation_method()
RETURNS VARCHAR
AS $$
BEGIN
    RETURN (
        SELECT setting
        FROM retail_analitycs_config
        WHERE name = 'groups_margin_calculation_method' );
END $$
LANGUAGE plpgsql;

DROP VIEW IF EXISTS groups;
CREATE OR REPLACE VIEW groups AS (
    SELECT 
        customer_id,
        group_id,
        group_transactions_count / general_transactions_count AS group_affinity_index,
        (analysis_formation_epoch - last_group_purchase_epoch) / (60 * 60 * 24) AS group_churn_rate,
        average_frequency_deviation / group_frequency AS group_stability_index,
        group_margin,
        discount_transactions_count / group_purchase AS group_discount_share,
        group_min_discount AS group_minimum_discount
    FROM (
        SELECT 
            customer_id,
            group_id,
            COUNT(transaction_id) FILTER (WHERE 
                transaction_datetime <= last_group_purchase_date AND
                transaction_datetime >= first_group_purchase_date)
                AS general_transactions_count,
            (COUNT(transaction_id) FILTER (WHERE
                purchased_group_id = group_id))::NUMERIC 
                AS group_transactions_count,
            EXTRACT(EPOCH FROM MAX(analysis_formation) FILTER (WHERE 
                row_n = 1)) AS analysis_formation_epoch,
            EXTRACT(EPOCH FROM MAX(last_group_purchase_date) FILTER (WHERE 
                row_n = 1)) AS last_group_purchase_epoch,
            MAX(group_frequency) FILTER (WHERE row_n = 1) AS group_frequency,
            AVG(ABS((next_transaction_epoch - current_transaction_epoch) / (60 * 60 * 24) - 
                group_frequency)) FILTER (WHERE purchased_group_id = group_id)
                AS average_frequency_deviation,
            CASE
                WHEN get_calculation_method() = 'by all transactions' THEN
                    SUM(group_summ_paid - group_cost) FILTER (WHERE 
                        purchased_group_id = group_id)
                ELSE
                    NULL
                    -- RAISE 'You should set up /retail_analytics_config.tsv:groups_margin_calculation_method correctly.'
                END AS group_margin,
            (COUNT(transaction_id) FILTER (WHERE
                purchased_group_id = group_id AND group_summ - group_summ_paid != 0)
                )::NUMERIC AS discount_transactions_count,
            MAX(group_purchase) FILTER (WHERE row_n = 1) AS group_purchase,
            MAX(group_min_discount) FILTER (WHERE row_n = 1) AS group_min_discount,
            AVG(group_summ_paid / group_summ) FILTER (WHERE
                purchased_group_id = group_id AND group_summ - group_summ_paid != 0)
                AS group_average_discount
        FROM (
            SELECT
                ph.customer_id,
                ph.transaction_id,
                ph.transaction_datetime,
                ph.group_id AS purchased_group_id,
                EXTRACT(EPOCH FROM (ph.transaction_datetime)) AS current_transaction_epoch,
                EXTRACT(EPOCH FROM (
                    LAG(ph.transaction_datetime, -1) OVER purchase_intervals))
                    AS next_transaction_epoch,
                ph.group_summ_paid,
                ph.group_cost,
                ph.group_summ,
                p.group_id,
                p.group_frequency,
                p.group_purchase,
                p.first_group_purchase_date,
                p.last_group_purchase_date,
                p.group_min_discount,
                ROW_NUMBER() OVER group_analysis AS row_n,
                d.analysis_formation
            FROM purchase_history ph
            JOIN periods p ON ph.customer_id = p.customer_id
            CROSS JOIN (
                SELECT MAX(analysis_formation) AS analysis_formation
                FROM date_of_analysis_formation ) d
            WINDOW 
                purchase_intervals AS (
                    PARTITION BY ph.customer_id, ph.group_id, p.group_id ORDER BY ph.transaction_datetime),
                group_analysis AS (
                    PARTITION BY ph.customer_id, p.group_id ORDER BY ph.transaction_datetime)
        ) accumulation
        GROUP BY customer_id, group_id) grouped_accumulation
);

SELECT * FROM groups;

-- DROP FUNCTION IF EXISTS get_groups_transactions;
-- CREATE FUNCTION get_groups_transactions() 
-- RETURNS TABLE (
--     customer_id             BIGINT,
--     transaction_id          BIGINT,
--     transaction_datetime    TIMESTAMP,
--     group_id                BIGINT,
--     group_summ_paid         NUMERIC,
--     group_cost              NUMERIC
-- ) AS $$
-- DECLARE
--     calculation_method VARCHAR := (
--         SELECT setting AS calculation_method
--         FROM retail_analitycs_config 
--         WHERE name = 'groups_margin_calculation_method' );
--     days_from_analysis_formation INT := (
--         SELECT setting::INT AS days_from_analysis_formation
--         FROM retail_analitycs_config
--         WHERE name = 'groups_margin_days_from_analysis_formation' );
--     number_of_transactions INT := (
--         SELECT setting::INT AS number_of_transactions
--         FROM retail_analitycs_config
--         WHERE name = 'groups_margin_number_of_transactions' );
--     last_date_by_period DATE := (
--         SELECT MAX(analysis_formation)::DATE - days_from_analysis_formation AS last_date_by_period
--         FROM date_of_analysis_formation
--     );
-- BEGIN
--     IF calculation_method = 'by all transactions' THEN
--         RETURN QUERY (
--             SELECT h.customer_id, h.transaction_id, h.transaction_datetime::TIMESTAMP, h.group_id, h.group_summ_paid, h.group_cost
--             FROM purchase_history h
--         );
--     ELSIF calculation_method = 'by period' THEN
--         IF days_from_analysis_formation IS NULL THEN
--             RAISE 'retail_analitycs_config.groups_margin_days_from_analysis_formation should be set up correctly.';
--         END IF;
--         RETURN QUERY (
--             SELECT h.customer_id, h.transaction_id, h.transaction_datetime::TIMESTAMP, h.group_id, h.group_summ_paid, h.group_cost
--             FROM purchase_history h
--             WHERE h.transaction_datetime::TIMESTAMP >= last_date_by_period
--         );
--     ELSIF calculation_method = 'by number of transactions' THEN
--         IF number_of_transactions IS NULL THEN
--             RAISE 'retail_analitycs_config.groups_margin_number_of_transactions should be set up correctly.';
--         END IF;
--         RETURN QUERY (
--             SELECT ph.customer_id, ph.transaction_id, ph.transaction_datetime::TIMESTAMP, ph.group_id, ph.group_summ_paid, ph.group_cost
--             FROM (
--                 SELECT rowed_ph.customer_id, rowed_ph.transaction_id
--                 FROM (
--                     SELECT 
--                         dist_ph.customer_id, 
--                         dist_ph.transaction_id,
--                         ROW_NUMBER() OVER (PARTITION BY dist_ph.customer_id ORDER BY dist_ph.transaction_datetime::TIMESTAMP DESC) AS row_n
--                     FROM (
--                         SELECT DISTINCT ph.customer_id, ph.transaction_id, ph.transaction_datetime 
--                         FROM purchase_history ph ) dist_ph ) rowed_ph 
--                 WHERE rowed_ph.row_n <= number_of_transactions ) n_last
--                 JOIN purchase_history ph ON ph.customer_id = n_last.customer_id AND ph.transaction_id = n_last.transaction_id
--         );
--     ELSE
--         RAISE 'retail_analitycs_config.groups_margin_calculation_method should be set up correctly.';
--     END IF;
-- END $$
-- LANGUAGE plpgsql;
