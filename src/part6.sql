\connect -reuse-previous=on "dbname=retail_analytics user=retail_user"; 

-- TODO delete
DROP FUNCTION IF EXISTS round_discount CASCADE;
CREATE OR REPLACE FUNCTION round_discount(discount NUMERIC)
    RETURNS NUMERIC
AS $$
BEGIN
    RETURN ((FLOOR(discount / 5)) + (discount % 5 != 0)::INT) * 5.0;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_personal_offers_aimed_at_cross_selling CASCADE;

CREATE FUNCTION get_personal_offers_aimed_at_cross_selling(
    IN number_of_groups INT,
    IN max_churn_index NUMERIC,
    IN max_consumption_stab_index NUMERIC,
    IN max_sku_share_percentage NUMERIC,
    IN allowable_margin_share_percentage NUMERIC
) RETURNS TABLE (
    customer_id BIGINT,
    sku_name VARCHAR,
    offer_discount_depth NUMERIC
) AS $$
BEGIN
    RETURN QUERY (
        WITH

            group_selection AS (
                SELECT
                    rg.customer_id,
                    rg.group_id
                FROM (
                    SELECT 
                        gr.customer_id,
                        gr.group_id,
                        ROW_NUMBER() OVER (PARTITION BY gr.customer_id ORDER BY group_affinity_index DESC) AS r
                    FROM groups gr
                    WHERE 
                        group_churn_rate <= max_churn_index AND
                        group_churn_rate IS NOT NULL AND
                        group_stability_index < max_consumption_stab_index
                ) rg
                WHERE rg.r <= number_of_groups
            ),

            sku_with_max_margin AS (
                SELECT DISTINCT ON (pm.customer_id, pm.group_id)
                    pm.customer_id,
                    pm.group_id,
                    pm.store_id,
                    pm.sku_id,
                    pm.sku_retail_price,
                    pm.product_margin AS max_margin
                FROM (
                    SELECT 
                        gs.customer_id,
                        gs.group_id,
                        c.customer_primary_store AS store_id,
                        sp.sku_id,
                        sp.sku_retail_price,
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

            sku_transactions AS (
                SELECT
                    sk.sku_id,
                    COUNT (transaction_id) as transactions_count
                FROM (
                    SELECT 
                        sku_id
                    FROM sku_with_max_margin swmm
                    LEFT JOIN cards c ON c.customer_id = swmm.customer_id
                    GROUP BY sku_id
                ) sk
                JOIN checks c ON sk.sku_id = c.sku_id
                GROUP BY sk.sku_id
            ),

            group_transactions AS (
                SELECT
                    group_id,
                    COUNT(transaction_id) AS group_transactions_count
                FROM purchase_history
                GROUP BY group_id
            )

        SELECT
            swmm.customer_id,
            pr.sku_name,
            round_discount(p.group_min_discount) AS offer_discount_depth
        FROM sku_with_max_margin swmm
        LEFT JOIN products pr ON pr.sku_id = swmm.sku_id
        LEFT JOIN sku_transactions st ON swmm.sku_id = st.sku_id
        LEFT JOIN group_transactions gt ON swmm.group_id = gt.group_id
        LEFT JOIN periods p ON p.customer_id = swmm.customer_id AND p.group_id = swmm.group_id
        WHERE (st.transactions_count::NUMERIC / gt.group_transactions_count) < (max_sku_share_percentage / 100)
            AND round_discount(p.group_min_discount) >= (((allowable_margin_share_percentage / 100) * swmm.max_margin::NUMERIC) / swmm.sku_retail_price)
    );
END; $$
LANGUAGE plpgsql;


SELECT * FROM get_personal_offers_aimed_at_cross_selling(5, 3, 0.5, 100, 30)