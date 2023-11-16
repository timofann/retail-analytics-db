\connect -reuse-previous=on "dbname=retail_analytics user=retail_user"; 

CREATE FUNCTION get_personal_offers_aimed_at_cross_selling(
    IN number_of_groups INT,
    IN max_churn_index NUMERIC,
    IN max_consumption_stab_index NUMERIC,
    IN max_sku_share_percentage NUMERIC,
    IN allowable_margin_share_percentage NUMERIC
) RETURNS TABLE (
    customer_id BIGINT,
    sku_name VARCHAR,
    offer_discount_depth NUMERIC,
) AS $$
BEGIN
    -- query
    -- query
END; $$
LANGUAGE plpgsql;


WITH
-- Group selection
--–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
group_selection AS (
    SELECT *
    FROM (
        SELECT 
            gr.customer_id,
            gr.group_id,
            group_affinity_index,
            gr.group_churn_rate,
            gr.group_stability_index,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY group_id ASC) AS r
        FROM groups gr
        WHERE 
            group_churn_rate > 500
            AND
            group_stability_index < 0.90
        ORDER BY customer_id, group_affinity_index DESC
    ) rg
    WHERE rg.r <= 3
    LIMIT 20
)

SELECT DISTINCT ON (pm.customer_id, pm.group_id)
    pm.customer_id,
    pm.group_id,
    pm.store_id,
    pm.product_margin
    -- pm.max_margin
FROM (
    SELECT 
        gs.customer_id,
        gs.group_id,
        c.customer_primary_store AS store_id,
        (sp.sku_retail_price - sp.sku_purchase_price) AS product_margin
        -- max(sp.sku_retail_price - sp.sku_purchase_price) OVER (PARTITION BY pm.customer_id, pm.group_id) AS max_margin
    FROM group_selection gs
    JOIN customers c ON c.customer_id = gs.customer_id
    JOIN stores_products sp ON sp.store_id = c.customer_primary_store
) pm
ORDER BY pm.customer_id, pm.group_id, pm.store_id, pm.product_margin DESC;

-- Determination of SKU with maximum margin
--–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
-- Определение SKU с максимальной маржой. 
-- В каждой группе определяется SKU с максимальной маржой (в рублях).

-- Для этого, по основному магазину клиента 
-- из розничной цены товара (SKU_Retail_Price) 
-- вычитается его закупочная стоимость (SKU_Purchase_Price) 
-- для всех SKU данной группы, представленных в магазине, 

-- после чего выбирается одно SKU с максимальным значением указанной разницы.

-- Customers::Customer_Primary_Store
-- stores_products::SKU_Retail_Price
-- stores_products::SKU_Purchase_Price
