-- DROP VIEW IF EXISTS periods;
-- CREATE OR REPLACE VIEW periods AS
    SELECT 
        ph.customer_id,
        ph.group_id,
        min(ph.transaction_datetime) 
            AS First_Group_Purchase_Date,
        max(ph.transaction_datetime) 
            AS Last_Group_Purchase_Date,
        count(ph.transaction_id) 
            AS Group_Purchase,
        ((EXTRACT(DAY FROM (max(ph.transaction_datetime) - min(ph.transaction_datetime))) + 1) / count(ph.transaction_id)) 
            AS Group_Frequency,
        ('-') 
            AS Group_Min_Discount
    FROM purchase_history AS ph
    -- INNER JOIN checks AS ch ON ch.transaction_id = ph.transaction_id
    GROUP BY ph.customer_id, ph.group_id;


SELECT 
    c.transaction_id,
    MIN(c.sku_discount),
    p.group_id
FROM checks as c
JOIN products AS p ON p.sku_id = c.sku_id
GROUP BY c.transaction_id, p.group_id


-- TEST
SELECT * FROM periods;

-- show table columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'periods';

-- tables and views
SELECT * FROM purchase_history;
SELECT * FROM transactions;
SELECT * FROM cards;
SELECT * FROM personal_information;
SELECT * FROM checks;
SELECT * FROM products;
SELECT * FROM stores_products WHERE ;