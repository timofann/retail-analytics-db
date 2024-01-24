\connect -reuse-previous=on "dbname=retail_analytics user=retail_user";

/*  =========================  Groups View  ========================== 
    - stores customer affinity index for the certain group (
      Group_Purchase / customer transactions count);
    - customer churn index for a certain group (days after last 
      purchase / Group_Frequency); 
    - the group consumption stability (AVG((ABS(MEAN(purchase 
      interval) - purchase interval)) / Group_Frequency));
    - the actual margin for the group for a particular customer by 
      all transactions / by period / by number of transactions 
      (depends on data/retail_analitycs_config.tsv) (Group_Cost - 
      Group_Summ_Paid);
    - the share of transactions with a discount;
    - the minimum discount size for a group;
    - the average group discount size                                 */

DROP VIEW IF EXISTS groups;
CREATE VIEW groups AS
    SELECT 
        customer_id,
        group_id,
        group_transactions_count / general_transactions_count AS group_affinity_index,
        get_interval_between_dates(last_group_purchase_date, analysis_formation) / 
            group_frequency AS group_churn_rate,
        average_frequency_deviation / group_frequency AS group_stability_index,
        group_margin,
        discount_transactions_count / group_purchase AS group_discount_share,
        group_min_discount AS group_minimum_discount,
        group_average_discount
    FROM (
        SELECT 
            customer_id,
            group_id,
            NULLIF(COUNT(transaction_id) FILTER (WHERE 
                transaction_datetime <= last_group_purchase_date AND
                transaction_datetime >= first_group_purchase_date), 0)
                AS general_transactions_count,
            (COUNT(transaction_id) FILTER (WHERE
                purchased_group_id = group_id))::NUMERIC 
                AS group_transactions_count,
            MAX(analysis_formation) FILTER (WHERE 
                row_n = 1) AS analysis_formation,
            MAX(last_group_purchase_date) FILTER (WHERE 
                row_n = 1) AS last_group_purchase_date,
            NULLIF(MAX(group_frequency) FILTER (WHERE row_n = 1), 0) AS group_frequency,
            AVG(ABS(get_interval_between_dates(transaction_datetime, next_transaction_datetime) - 
                group_frequency)) FILTER (WHERE purchased_group_id = group_id)
                AS average_frequency_deviation,
            CASE
                WHEN get_calculation_method() = 'by all transactions' THEN
                    SUM(group_summ_paid - group_cost) FILTER (WHERE 
                        purchased_group_id = group_id)
                WHEN get_calculation_method() = 'by transactions count' THEN
                    SUM(group_summ_paid - group_cost) FILTER (WHERE 
                        purchased_group_id = group_id AND
                        transaction_number <= get_transactions_count())
                WHEN get_calculation_method() = 'by period' THEN
                    SUM(group_summ_paid - group_cost) FILTER (WHERE 
                        purchased_group_id = group_id AND
                        transaction_datetime > analysis_formation - get_days_from_analysis_formation())
                ELSE
                    NULL
                END AS group_margin,
            (COUNT(transaction_id) FILTER (WHERE
                purchased_group_id = group_id AND group_summ - group_summ_paid != 0)
                )::NUMERIC AS discount_transactions_count,
            NULLIF(MAX(group_purchase) FILTER (WHERE row_n = 1), 0) AS group_purchase,
            MAX(group_min_discount) FILTER (WHERE row_n = 1) AS group_min_discount,
            SUM(group_summ_paid) FILTER (WHERE purchased_group_id = group_id) / 
                NULLIF(SUM(group_summ) FILTER (WHERE purchased_group_id = group_id), 0)
                AS group_average_discount
        FROM (
            SELECT
                ph.customer_id,
                ph.transaction_id,
                ph.transaction_datetime,
                ph.group_id AS purchased_group_id,
                LAG(ph.transaction_datetime, -1) OVER purchase_intervals AS next_transaction_datetime,
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
                ROW_NUMBER() OVER group_margin_limit AS transaction_number,
                d.analysis_formation
            FROM purchase_history ph
            JOIN periods p ON ph.customer_id = p.customer_id
            CROSS JOIN (
                SELECT MAX(analysis_formation) AS analysis_formation
                FROM date_of_analysis_formation ) d
            WINDOW 
                purchase_intervals AS (
                    PARTITION BY ph.customer_id, ph.group_id, p.group_id 
                    ORDER BY ph.transaction_datetime),
                group_analysis AS (
                    PARTITION BY ph.customer_id, p.group_id 
                    ORDER BY ph.transaction_datetime),
                group_margin_limit AS (
                    PARTITION BY ph.customer_id, ph.group_id, p.group_id 
                    ORDER BY ph.transaction_datetime DESC)
        ) accumulation
        GROUP BY customer_id, group_id
    ) grouped_accumulation;

-- SELECT * FROM groups ORDER BY customer_id, group_id;

-- UPDATE retail_analitycs_config 
-- SET setting = 'by transactions count' 
-- WHERE name = 'groups_margin_calculation_method';
-- UPDATE retail_analitycs_config 
-- SET setting = '3' 
-- WHERE name = 'groups_margin_transactions_count';
-- SELECT * FROM retail_analitycs_config;

-- UPDATE retail_analitycs_config 
-- SET setting = 'by period' 
-- WHERE name = 'groups_margin_calculation_method';
-- UPDATE retail_analitycs_config 
-- SET setting = '100' 
-- WHERE name = 'groups_margin_days_from_analysis_formation';
