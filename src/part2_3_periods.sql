\connect -reuse-previous=on "dbname=retail_analytics user=retail_user";

/*  =========================  Periods View  ========================= 
    - stores the ID of the group of related products to which the 
      product belongs;
    - the last group purchase by the customer;
    - the number of transactions with the analyzed group;
    - the group purchases frequency ((Last_Group_Purchase_Date - 
      First_Group_Purchase_Date) / Group_Purchase);
    - the minimum discount for a group. If there is no discount on 
      all SKUs of the group, the value 0 is specified                  */

DROP VIEW IF EXISTS periods CASCADE;
CREATE VIEW periods AS
    WITH

        raw_data_for_periods AS (
            SELECT t.transaction_id, customer_id, group_id, sku_discount, sku_summ, transaction_datetime
            FROM checks
            LEFT JOIN transactions t ON checks.transaction_id = t.transaction_id
            LEFT JOIN product_grid p ON checks.sku_id = p.sku_id
            LEFT JOIN cards ON cards.customer_card_id = t.customer_card_id
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
        (get_interval_between_dates(rd.first_group_purchase_date, rd.last_group_purchase_date) + 1) / 
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

-- SELECT * FROM periods ORDER BY customer_id, group_id;
