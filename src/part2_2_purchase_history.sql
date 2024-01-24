\connect -reuse-previous=on "dbname=retail_analytics user=retail_user";

/*  =====================  Purchase History View  ===================== 
    - stores the date when the transaction was made;
    - the ID of the group of related products to which the product 
      belongs;
    - group cost (SUM(SKU_Purchase_Price * SKU_Amount) by group);
    - group summ (SUM(SKU_Summ) by group);
    - group summ paid (SUM(SKU_Summ_Paid) by group)                    */

DROP VIEW IF EXISTS purchase_history;
CREATE OR REPLACE VIEW purchase_history AS
    SELECT 
        c.customer_id,
        t.transaction_id,
        t.transaction_datetime,
        p.group_id,
        SUM(s.sku_purchase_price * ch.sku_amount) AS group_cost,
        SUM(ch.sku_summ) AS group_summ,
        SUM(ch.sku_summ_paid) AS group_summ_paid
    FROM checks AS ch 
    LEFT JOIN transactions AS t ON ch.transaction_id = t.transaction_id
    LEFT JOIN cards AS c ON c.customer_card_id = t.customer_card_id
    LEFT JOIN product_grid AS p ON p.sku_id = ch.sku_id
    LEFT JOIN stores AS s ON s.sku_id = ch.sku_id AND s.transaction_store_id = t.transaction_store_id
    GROUP BY c.customer_id, t.transaction_id, p.group_id;

-- SELECT * FROM purchase_history ORDER BY customer_id, group_id;
