\connect "dbname=retail_analytics user=retail_user";

DROP VIEW IF EXISTS purchase_history;
CREATE OR REPLACE VIEW purchase_history AS
    SELECT 
        c.customer_id,
        t.transaction_id,
        TO_CHAR(t.transaction_datetime, 'DD.MM.YYYY HH:MM:SS.0000000') AS transaction_datetime,
        p.group_id,
        SUM(sp.sku_purchase_price * ch.sku_amount) AS group_cost,
        SUM(ch.sku_summ) AS group_summ,
        SUM(ch.sku_summ_paid) AS group_summ_paid
    FROM transactions AS t
    INNER JOIN cards AS c ON c.card_id = t.card_id
    INNER JOIN checks AS ch ON ch.transaction_id = t.transaction_id
    INNER JOIN products AS p ON p.sku_id = ch.sku_id
    INNER JOIN stores_products AS sp ON sp.sku_id = ch.sku_id AND sp.store_id = t.store_id
    GROUP BY c.customer_id, t.transaction_id, p.group_id;


-- TEST
SELECT * FROM purchase_history ORDER BY customer_id ASC;
