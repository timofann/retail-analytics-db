-- \connect "dbname=retail_analytics user=retail_user";

-- DROP VIEW IF EXISTS groups;
-- CREATE OR REPLACE VIEW groups AS(

-- );

DROP FUNCTION IF EXISTS get_groups_transactions;
CREATE FUNCTION get_groups_transactions() 
RETURNS TABLE (
    customer_id             BIGINT,
    transaction_id          BIGINT,
    transaction_datetime    TIMESTAMP,
    group_id                BIGINT,
    group_summ_paid         NUMERIC,
    group_cost              NUMERIC
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
            SELECT h.customer_id, h.transaction_id, h.transaction_datetime::TIMESTAMP, h.group_id, h.group_summ_paid, h.group_cost
            FROM purchase_history h
        );
    ELSIF calculation_method = 'by period' THEN
        IF days_from_analysis_formation IS NULL THEN
            RAISE 'retail_analitycs_config.groups_margin_days_from_analysis_formation should be set up correctly.';
        END IF;
        RETURN QUERY (
            SELECT h.customer_id, h.transaction_id, h.transaction_datetime::TIMESTAMP, h.group_id, h.group_summ_paid, h.group_cost
            FROM purchase_history h
            WHERE h.transaction_datetime::TIMESTAMP >= last_date_by_period
        );
    ELSIF calculation_method = 'by number of transactions' THEN
        IF number_of_transactions IS NULL THEN
            RAISE 'retail_analitycs_config.groups_margin_number_of_transactions should be set up correctly.';
        END IF;
        RETURN QUERY (
            SELECT ph.customer_id, ph.transaction_id, ph.transaction_datetime::TIMESTAMP, ph.group_id, ph.group_summ_paid, ph.group_cost
            FROM (
                SELECT rowed_ph.customer_id, rowed_ph.transaction_id
                FROM (
                    SELECT 
                        dist_ph.customer_id, 
                        dist_ph.transaction_id,
                        ROW_NUMBER() OVER (PARTITION BY dist_ph.customer_id ORDER BY dist_ph.transaction_datetime::TIMESTAMP DESC) AS row_n
                    FROM (
                        SELECT DISTINCT ph.customer_id, ph.transaction_id, ph.transaction_datetime 
                        FROM purchase_history ph ) dist_ph ) rowed_ph 
                WHERE rowed_ph.row_n <= number_of_transactions ) n_last
                JOIN purchase_history ph ON ph.customer_id = n_last.customer_id AND ph.transaction_id = n_last.transaction_id
        );
    ELSE
        RAISE 'retail_analitycs_config.groups_margin_calculation_method should be set up correctly.';
    END IF;
END $$
LANGUAGE plpgsql;

SELECT * FROM get_groups_transactions() WHERE group_cost > group;

CALL import_default_dataset_mini();
REFRESH MATERIALIZED VIEW purchase_history;
REFRESH MATERIALIZED VIEW periods;



SELECT 
    average_frequency_deviation / group_frequency AS group_stability_index,
    group_transactions_count / general_transactions_count AS group_affinity_index
    analysis_formation - last_date_by_period / group_frequency AS 



SELECT * FROM purchase_history

SELECT 
    customer_id,
    group_id,
    COUNT(transaction_id) FILTER (WHERE 
        transaction_datetime <= last_group_purchase_date AND
        transaction_datetime >= first_group_purchase_date)
        AS general_transactions_count,
    COUNT(transaction_id) FILTER (WHERE
        purchased_group_id = group_id) AS group_transactions_count,
    EXTRACT(EPOCH FROM MAX(analysis_formation) FILTER (WHERE 
        row_n = 1)) AS analysis_formation_epoch,
    EXTRACT(EPOCH FROM MAX(last_group_purchase_date) FILTER (WHERE 
        row_n = 1)) AS last_group_purchase_epoch,
    MAX(group_frequency) FILTER (WHERE row_n = 1) AS group_frequency,
    AVG(ABS((next_transaction_epoch - current_transaction_epoch) / (60 * 60 * 24) - 
        group_frequency)) FILTER (WHERE purchased_group_id = group_id)
        AS average_frequency_deviation
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
        p.group_id,
        p.group_frequency,
        p.first_group_purchase_date,
        p.last_group_purchase_date,
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
GROUP BY customer_id, group_id;





EXPLAIN ANALYSE
WITH

    -- general_transactions AS ( -- all transactions for all groups (ph.group_id) inside the period of bying certain group (p.group_id)
    --     SELECT p.customer_id, p.group_id, COUNT(ph.transaction_id) AS transactions_count
    --     FROM purchase_history ph
    --     LEFT JOIN periods p ON ph.customer_id = p.customer_id
    --     WHERE transaction_datetime::TIMESTAMP >= first_group_purchase_date::TIMESTAMP AND
    --         transaction_datetime::TIMESTAMP <= last_group_purchase_date::TIMESTAMP
    --     GROUP BY p.customer_id, p.group_id
    -- ),

    -- group_transactions AS ( -- all transactions for certain group (ph.group_id) inside the period of bying certain group (ph.group_id)
    --     SELECT ph.customer_id, ph.group_id, COUNT(ph.transaction_id) AS transactions_count
    --     FROM purchase_history ph
    --     GROUP BY ph.customer_id, ph.group_id
    -- ), 

    -- affinity_index AS ( -- 0.0 for non-founded customer-group pairs
    --     SELECT 
    --         gen.customer_id,
    --         gen.group_id,
    --         COALESCE(gr.transactions_count, 0)::NUMERIC / gen.transactions_count AS group_affinity_index
    --     FROM general_transactions gen
    --     LEFT JOIN group_transactions gr ON gen.customer_id = gr.customer_id AND gen.group_id = gr.group_id
    -- ),

    -- churn_rate AS ( -- inf for non-founded customer-group pairs
    --     SELECT 
    --         p.customer_id,
    --         p.group_id,
    --         (analysis_formation::DATE - last_group_purchase_date::DATE)::NUMERIC / group_frequency AS group_churn_rate 
    --     FROM periods p
    --     CROSS JOIN (
    --         SELECT MAX(analysis_formation) AS analysis_formation
    --         FROM date_of_analysis_formation ) d
    -- ),

    -- stability_index AS ( -- null
    --     SELECT 
    --         h.customer_id,
    --         h.group_id,
    --         AVG(ABS(h.purchase_interval - p.group_frequency) / p.group_frequency) AS group_stability_index 
    --     FROM (
    --         SELECT
    --             ph.customer_id, 
    --             ph.group_id,
    --             (LAG(ph.transaction_datetime, -1) OVER (PARTITION BY ph.customer_id, ph.group_id ORDER BY ph.transaction_datetime::TIMESTAMP))::DATE - ph.transaction_datetime::DATE AS purchase_interval
    --         FROM purchase_history ph ) h
    --     JOIN periods p ON h.customer_id = p.customer_id AND h.group_id = p.group_id
    --     WHERE h.purchase_interval IS NOT NULL
    --     GROUP BY h.customer_id, h.group_id
    -- ),

    margin AS (
        SELECT ph.customer_id, ph.group_id, SUM(ph.group_summ_paid - ph.group_cost) AS group_margin
        FROM get_groups_transactions() ph
        GROUP BY ph.customer_id, ph.group_id
    ),

    distinct_discount_checks AS (
        SELECT DISTINCT dc.transaction_id, dc.sku_id, c.customer_id, p.group_id
        FROM (
            SELECT transaction_id, sku_id
            FROM checks
            WHERE sku_discount != 0 ) dc
        JOIN transactions t ON t.transaction_id = dc.transaction_id
        JOIN cards c ON t.card_id = c.card_id
        JOIN products p ON p.sku_id = dc.sku_id
    ),

    discount_share AS (
        SELECT 
            p.customer_id, 
            p.group_id, 
            ddc_count.transactions_count::NUMERIC / p.group_purchase AS group_discount_share,
            p.group_min_discount AS group_minimum_discount
        FROM (
            SELECT customer_id, group_id, COUNT(transaction_id) AS transactions_count
            FROM distinct_discount_checks ddc
            GROUP BY customer_id, group_id ) ddc_count
        LEFT JOIN periods p ON p.customer_id = ddc_count.customer_id AND p.group_id = ddc_count.group_id
    ),

    average_discount AS (
        SELECT 
            ph.group_id, 
            ph.customer_id, 
            AVG(ph.group_summ_paid / ph.group_summ) AS group_average_discount
        FROM (
            SELECT DISTINCT transaction_id, group_id, customer_id
            FROM distinct_discount_checks ) ddc
        LEFT JOIN (
            SELECT transaction_id, customer_id, group_id, group_summ_paid, group_summ
            FROM purchase_history ) ph ON 
            ph.transaction_id = ddc.transaction_id AND 
            ph.customer_id = ddc.customer_id AND 
            ph.group_id = ddc.customer_id
        GROUP BY ph.customer_id, ph.group_id
    )

SELECT
    ai.customer_id,
    ai.group_id,
    ai.group_affinity_index,
    cr.group_churn_rate,
    si.group_stability_index,
    m.group_margin,
    COALESCE(ds.group_discount_share, 0) AS group_discount_share,
    COALESCE(ds.group_minimum_discount, 0) AS group_minimum_discount,
    COALESCE(ad.group_average_discount, 0) AS group_average_discount
FROM affinity_index ai
LEFT JOIN churn_rate cr ON ai.customer_id = cr.customer_id AND ai.group_id = cr.group_id
LEFT JOIN stability_index si ON ai.customer_id = cr.customer_id AND ai.group_id = cr.group_id
LEFT JOIN margin m ON ai.customer_id = si.customer_id AND ai.group_id = si.group_id
LEFT JOIN discount_share ds ON ai.customer_id = ds.customer_id AND ai.group_id = ds.group_id
LEFT JOIN average_discount ad ON ai.customer_id = ad.customer_id AND ai.group_id = ad.group_id;

SELECT * FROM periods; -- 55 шт


SELECT * FROM retail_analitycs_config;
CALL export_to_tsv('retail_analitycs_config');

UPDATE retail_analitycs_config SET setting =
'by all transactions' WHERE name = 'groups_margin_calculation_method'