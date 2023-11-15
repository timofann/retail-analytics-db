\connect -reuse-previous=on "dbname=retail_analytics user=retail_user"; 

/*                           === NEW ROLES ===                         */

CREATE ROLE administrator SUPERUSER;
GRANT ALL PRIVILEGES ON
    personal_information,
    cards,
    sku_group,
    product_grid,
    unique_stores,
    stores,
    transactions,
    checks,
    date_of_analysis_formation,
    customers,
    purchase_history,
    periods,
    groups
TO administrator;
GRANT USAGE, SELECT ON SEQUENCE 
    personal_information_customer_id_seq,
    cards_card_id_seq,
    product_grid_sku_id_seq,
    sku_group_group_id_seq,
    unique_stores_store_id_seq,
    transactions_transaction_id_seq
TO administrator;

CREATE ROLE visitor;
GRANT SELECT ON
    personal_information,
    cards,
    sku_group,
    product_grid,
    unique_stores,
    stores,
    transactions,
    checks,
    date_of_analysis_formation,
    customers,
    purchase_history,
    periods,
    groups
TO visitor;

/*                             === TEST ===                            */

SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'administrator' AND table_schema = 'public';

SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'visitor' AND table_schema = 'public';

SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'PUBLIC' AND table_schema = 'public';

-- CREATE USER test_visitor;

-- GRANT visitor TO test_visitor;

-- SELECT grantee.rolname as grantee, member.rolname as member, grantor.rolname as grantor
--     FROM pg_catalog.pg_auth_members auth
--     LEFT JOIN pg_catalog.pg_roles grantee ON grantee.oid = roleid
--     LEFT JOIN pg_catalog.pg_roles member ON member.oid = member
--     LEFT JOIN pg_catalog.pg_roles grantor ON grantor.oid = grantor;
-- \du;

-- \connect -reuse-previous=on "dbname=retail_analytics user=test_visitor";
-- INSERT INTO personal_information VALUES (DEFAULT, 'My', 'Regree', 'regree@student.21-school.ru', '+79288903035');
-- SELECT * FROM personal_information;

-- \connect -reuse-previous=on "dbname=retail_analytics user=retail_user"; 
-- REVOKE visitor FROM test_visitor;
-- GRANT administrator TO test_visitor;

-- SELECT grantee.rolname as grantee, member.rolname as member, grantor.rolname as grantor
--     FROM pg_catalog.pg_auth_members auth
--     LEFT JOIN pg_catalog.pg_roles grantee ON grantee.oid = roleid
--     LEFT JOIN pg_catalog.pg_roles member ON member.oid = member
--     LEFT JOIN pg_catalog.pg_roles grantor ON grantor.oid = grantor;
-- \du;

-- \connect -reuse-previous=on "dbname=retail_analytics user=test_visitor";
-- INSERT INTO personal_information VALUES (DEFAULT, 'My', 'Regree', 'regree@student.21-school.ru', '+79288903035');
-- SELECT * FROM personal_information;

-- \connect -reuse-previous=on "dbname=retail_analytics user=retail_user"; 
-- REVOKE administrator FROM test_visitor;
-- DELETE FROM personal_information WHERE customer_primary_email = 'regree@student.21-school.ru';
