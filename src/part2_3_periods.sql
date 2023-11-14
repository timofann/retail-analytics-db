\connect -reuse-previous=on "dbname=retail_analytics user=retail_user";

DROP VIEW IF EXISTS periods;
CREATE VIEW periods AS
    WITH

        raw_data_for_periods AS (
            SELECT t.transaction_id, customer_id, group_id, sku_discount, sku_summ, transaction_datetime
            FROM checks
            LEFT JOIN transactions t ON checks.transaction_id = t.transaction_id
            LEFT JOIN products ON checks.sku_id = products.sku_id
            LEFT JOIN cards ON cards.card_id = t.card_id
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
        tc.group_purchase::NUMERIC,
        (EXTRACT(EPOCH FROM rd.last_group_purchase_date) - 
            EXTRACT(EPOCH FROM rd.first_group_purchase_date))::NUMERIC /
            tc.group_purchase AS group_frequency,
        COALESCE(rd.group_min_discount, 0)::NUMERIC AS group_min_discount
    FROM (
        SELECT
            customer_id,
            group_id,
            MIN(transaction_datetime) AS first_group_purchase_date,
            MAX(transaction_datetime) AS last_group_purchase_date,
            MIN(sku_discount / sku_summ) FILTER (
                WHERE sku_discount != 0 ) AS group_min_discount
        FROM raw_data_for_periods
        GROUP BY customer_id, group_id ) rd
    LEFT JOIN transactions_count tc ON tc.customer_id = rd.customer_id AND tc.group_id = rd.group_id;

-- SELECT * FROM periods;
