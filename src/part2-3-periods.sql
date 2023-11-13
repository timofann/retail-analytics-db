\connect -reuse-previous=on "dbname=retail_analytics user=retail_user";

DROP VIEW IF EXISTS periods;

CREATE OR REPLACE VIEW periods AS
    WITH
    raw_data_for_periods AS (
        SELECT t.transaction_id, customer_id, group_id, sku_discount, sku_summ, transaction_datetime
        FROM checks JOIN
            transactions t ON checks.transaction_id = t.transaction_id JOIN
            products ON checks.sku_id = products.sku_id JOIN
            cards ON cards.card_id = t.card_id
    ),
    transactions_count AS (
        SELECT
            customer_id,
            group_id,
            COUNT(transaction_id) AS group_purchase
        FROM purchase_history
        GROUP BY customer_id, group_id
    )
    SELECT
        rd.customer_id,
        rd.group_id,
        rd.first_group_purchase_date,
        rd.last_group_purchase_date, 
        tc.group_purchase,
        (rd.last_group_purchase_date::DATE - rd.first_group_purchase_date::DATE + 1)::NUMERIC / tc.group_purchase AS group_frequency,
        group_min_discount
    FROM (
        SELECT
            customer_id,
            group_id,
            MIN(transaction_datetime) AS first_group_purchase_date,
            MAX(transaction_datetime) AS last_group_purchase_date,
            MIN(sku_discount / sku_summ) AS group_min_discount
        FROM raw_data_for_periods
        GROUP BY customer_id, group_id) rd
    JOIN transactions_count tc ON tc.customer_id = rd.customer_id AND tc.group_id = rd.group_id;
