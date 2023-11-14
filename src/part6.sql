\connect -reuse-previous=on "dbname=retail_analytics user=retail_user"; 

CREATE FUNCTION get_personal_offers_aimed_at_cross_selling(
    number_of_groups INT,
    max_churn_index NUMERIC,
    max_consumption_stab_index NUMERIC,
    max_sku_share NUMERIC,              -- (in percent)
    allowable_margin_share NUMERIC      -- (in percent)
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


WITH group_selection AS (
    SELECT * 
    FROM groups 
    WHERE group_churn_rate > 1000           -- 1000 - value for test
        AND group_stability_index < 0.70    -- 0.70 - value for test
    LIMIT 100
)

SELECT * FROM group_selection;
