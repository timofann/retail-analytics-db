\connect -reuse-previous=on "dbname=retail_analytics user=retail_user"; 

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
                    g.customer_id,
                    group_id,
                    group_minimum_discount,
                    row_number() OVER (PARTITION BY g.customer_id ORDER BY group_stability_index DESC) as rn
                FROM groups g
                WHERE group_churn_rate <= max_churn_index 
                    AND group_stability_index <= max_consumption_stab_index
            ),

            sku_with_max_margin AS (
                SELECT
                    *
                FROM (
                    SELECT 
                        st.transaction_store_id AS store_id, 
                        st.sku_id, 
                        pg.group_id, 
                        pg.sku_name,
                        (st.sku_retail_price - st.sku_purchase_price) / st.sku_retail_price * allowable_margin_share_percentage AS margin_share,
                        row_number() OVER (PARTITION BY transaction_store_id, pg.group_id ORDER BY (st.sku_retail_price - st.sku_purchase_price) DESC) AS rn
                    FROM stores st
                    LEFT JOIN product_grid pg on st.sku_id = pg.sku_id
                ) t
                WHERE rn = 1
            ),

            sku_group_share AS (
                SELECT * FROM (
                    SELECT DISTINCT
                        t1.customer_id,
                        t1.sku_id,
                        t1.group_id,
                        t1.sku_name,
                        (SELECT COUNT(*) FROM (SELECT DISTINCT UNNEST(transactions_sku_arr)) sku)::NUMERIC /
                        (SELECT COUNT(*) FROM (SELECT DISTINCT UNNEST(transactions_group_arr)) grp) AS sku_group_share
                    FROM (
                        SELECT
                            ctgs.customer_id,
                            ctgs.sku_id,
                            ctgs.group_id,
                            pg.sku_name,
                            ARRAY_AGG(ctgs.transaction_id) OVER (PARTITION BY ctgs.group_id) transactions_group_arr,
                            ARRAY_AGG(ctgs.transaction_id) OVER (PARTITION BY ctgs.sku_id) transactions_sku_arr
                        FROM (
                            SELECT DISTINCT 
                                ph.customer_id, 
                                ph.transaction_id, 
                                ph.group_id, 
                                c.sku_id
                            FROM purchase_history ph
                            JOIN checks c ON c.transaction_id = ph.transaction_id
                        ) AS ctgs
                        LEFT JOIN checks ch ON ch.transaction_id = ctgs.transaction_id
                        JOIN product_grid pg ON pg.sku_id = ch.sku_id AND ctgs.group_id = pg.group_id
                    ) AS t1
                ) AS t2
                WHERE sku_group_share::NUMERIC <= max_sku_share_percentage / 100 
            )

        SELECT
            c.customer_id,
            sgs.sku_name,
            round_discount(p.group_min_discount) AS offer_discount_depth
        FROM group_selection gs
        JOIN customers c ON c.customer_id = gs.customer_id
        JOIN sku_with_max_margin swmm ON c.customer_primary_store = swmm.store_id AND gs.group_id = swmm.group_id
        JOIN sku_group_share sgs 
            ON c.customer_id = sgs.customer_id 
            AND swmm.group_id = sgs.group_id 
            AND swmm.sku_id = sgs.sku_id
        LEFT JOIN periods p 
            ON p.customer_id = c.customer_id 
            AND p.group_id = swmm.group_id
        WHERE margin_share >= round_discount(p.group_min_discount)
    );
END; $$
LANGUAGE plpgsql;

-- SELECT * FROM get_personal_offers_aimed_at_cross_selling(5, 3, 0.5, 100, 30);


-- number of groups                         - 5
-- maximum churn index                      - 3
-- maximum consumption stability index      - 0.5
-- maximum SKU share                        - 100
-- allowable margin share                   - 30,

-- returns the following data.
--      5   "Kerton Бензин АИ-95 Поездка"        15
--      11  "Heipz GmbH Ручка шариковая Ромашка" 5


