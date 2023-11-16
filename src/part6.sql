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
    ),
    -- Determination of SKU with maximum margin
    --–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    sku_with_max_margin AS (
        SELECT DISTINCT ON (pm.customer_id, pm.group_id)
            pm.customer_id,
            pm.group_id,
            pm.store_id,
            pm.sku_id,
            pm.product_margin AS max_margin
        FROM (
            SELECT 
                gs.customer_id,
                gs.group_id,
                c.customer_primary_store AS store_id,
                sp.sku_id,
                (sp.sku_retail_price - sp.sku_purchase_price) AS product_margin
            FROM group_selection gs
            JOIN customers c ON c.customer_id = gs.customer_id
            JOIN stores_products sp ON sp.store_id = c.customer_primary_store
        ) pm
        ORDER BY 
            pm.customer_id, 
            pm.group_id, 
            pm.store_id, 
            pm.product_margin DESC
    ),
    -- SKU share in a group
    --–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    -- Определяется доля транзакций, в которых присутствует анализируемое SKU. 
    
    -- Для этого количество транзакций, содержащих данный SKU, 
    -- делится на количество транзакций, содержащих группу в целом
    
    -- SKU используется для формирования предложения только в том случае,
    -- если получившееся значение не превышает заданного пользователем значения.
    sku_share_in_a_group AS (
        SELECT 
            *
        FROM checks ch
        LEFT JOIN transactions t ON t.transaction_id = ch.transaction_id
        LEFT JOIN cards c ON t.card_id = c.card_id
        LEFT JOIN sku_with_max_margin swmm ON c.customer_id = swmm.customer_id
            AND ch.sku_id = swmm.sku_id
        
        -- JOIN transactions t
        -- -- WHERE swmm.customer_id = 16
        -- LIMIT 100
    )

SELECT * FROM sku_share_in_a_group;

SELECT * FROM checks;
SELECT * FROM transactions;
SELECT * FROM cards;
