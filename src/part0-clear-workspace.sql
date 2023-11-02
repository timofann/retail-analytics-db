DROP USER IF EXISTS test_visitor;

DROP DATABASE retail_analytics WITH (FORCE);
DROP USER IF EXISTS retail_user;

-- REVOKE ALL PRIVILEGES ON
--     personal_information,
--     cards,
--     sku_groups,
--     products,
--     stores,
--     stores_products,
--     transactions,
--     checks,
--     date_of_analysis_formation
-- FROM administrator;
DROP ROLE administrator;

-- REVOKE ALL PRIVILEGES ON
--     personal_information,
--     cards,
--     sku_groups,
--     products,
--     stores,
--     stores_products,
--     transactions,
--     checks,
--     date_of_analysis_formation
-- FROM visitor;
DROP ROLE visitor;