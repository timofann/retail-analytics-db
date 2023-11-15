\connect -reuse-previous=on "dbname=retail_analytics user=retail_user";

CREATE OR REPLACE FUNCTION round_discount(discount NUMERIC)
    RETURNS NUMERIC
AS $$
BEGIN
    RETURN ((FLOOR(discount / 5)) + (discount % 5 != 0)::INT) * 5.0;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_offers_to_increase_the_average_check(
    INT, DATE, DATE, NUMERIC, NUMERIC, NUMERIC, NUMERIC) CASCADE;
CREATE FUNCTION get_offers_to_increase_the_average_check(
    calculation_method INT,
    first_date DATE,
    last_date DATE,
    increasing_coeff NUMERIC,
    max_churn_index NUMERIC,
    discount_transactions_percentage NUMERIC,
    allowable_margin_percentage NUMERIC )
    RETURNS TABLE (
        customer_id             BIGINT,
        required_check_measure  NUMERIC,
        group_name              VARCHAR,
        offer_discount_depth    NUMERIC
    )
AS $$
BEGIN
    IF calculation_method != 1 AND calculation_method != 2 THEN
        RAISE 'The calculation_method should be set to 1 (per period) or 2 (per transactions quantity)';
    ELSIF calculation_method = 2 THEN
        RAISE 'The calculation_method is set to 2 so you need to set up number_of_transactions';
    ELSIF last_date <= first_date THEN
        RAISE 'The last date of the specified period must be later than the first one';
    END IF;
    RETURN QUERY (
        WITH

            required_average_check AS (
                SELECT
                    c.customer_id,
                    SUM(t.transaction_summ) / COUNT(t.transaction_id) * increasing_coeff
                        AS required_check_measure
                FROM (
                    SELECT transaction_id, customer_card_id, transaction_summ
                    FROM transactions 
                    WHERE transaction_datetime BETWEEN first_date AND last_date ) t
                LEFT JOIN cards c on t.customer_card_id = c.customer_card_id
                GROUP BY c.customer_id
            ),

            allowable_groups AS (
                SELECT
                    g.customer_id,
                    g.group_id,
                    round_discount(g.group_minimum_discount * 100) AS offer_discount_depth,
                    ROW_NUMBER() OVER affinity_window AS rating
                FROM groups g
                WHERE
                    group_churn_rate <= max_churn_index AND
                    group_churn_rate IS NOT NULL AND
                    group_discount_share < (discount_transactions_percentage / 100) AND
                    group_margin > (round_discount(group_minimum_discount * 100)) / allowable_margin_percentage
                WINDOW 
                    affinity_window AS (
                        PARTITION BY g.customer_id
                        ORDER BY g.group_affinity_index DESC, g.group_minimum_discount DESC )
            )

        SELECT i.customer_id, c.required_check_measure, s.group_name, g.offer_discount_depth
        FROM personal_information i
        LEFT JOIN required_average_check c ON i.customer_id = c.customer_id
        LEFT JOIN (
            SELECT * FROM allowable_groups WHERE rating = 1 ) g 
            ON i.customer_id = g.customer_id
        LEFT JOIN sku_group s ON g.group_id = s.group_id );
END; $$
LANGUAGE plpgsql;

-- SELECT * FROM get_offers_to_increase_the_average_check(1, '21.12.2021', '21.12.2022', 1.5, 1000, 101, 1.2);

DROP FUNCTION IF EXISTS get_offers_to_increase_the_average_check(
    INT, BIGINT, NUMERIC, NUMERIC, NUMERIC, NUMERIC) CASCADE;
CREATE FUNCTION get_offers_to_increase_the_average_check(
    calculation_method INT,
    number_of_transactions BIGINT,
    increasing_coeff NUMERIC,
    max_churn_index NUMERIC,
    discount_transactions_percentage NUMERIC,
    allowable_margin_percentage NUMERIC )
    RETURNS TABLE (
        customer_id             BIGINT,
        required_check_measure  NUMERIC,
        group_name              VARCHAR,
        offer_discount_depth    NUMERIC
    )
AS $$
BEGIN
    IF calculation_method != 1 AND calculation_method != 2 THEN
        RAISE 'The calculation_method should be set to 1 (per period) or 2 (per transactions quantity)';
    ELSIF calculation_method = 1 THEN
        RAISE 'The calculation_method is set to 1 so you need to set up first_date and last_date of period';
    END IF;
    RETURN QUERY (
        WITH

            rowed_transaction_customer AS (
                SELECT
                    t.transaction_id,
                    t.transaction_summ,
                    c.customer_id,
                    ROW_NUMBER() OVER transactions_chronological_windiow AS row_n
                FROM transactions t
                LEFT JOIN cards c ON t.customer_card_id = c.customer_card_id
                WINDOW transactions_chronological_windiow AS (
                    PARTITION BY c.customer_id ORDER BY t.transaction_datetime DESC )
            ),

            required_average_check AS (
                SELECT
                    t.customer_id,
                    SUM(t.transaction_summ) / COUNT(t.transaction_id) * increasing_coeff
                        AS required_check_measure
                FROM rowed_transaction_customer t
                WHERE t.row_n <= number_of_transactions
                GROUP BY t.customer_id
            ),

            allowable_groups AS (
                SELECT
                    g.customer_id,
                    g.group_id,
                    round_discount(g.group_minimum_discount * 100) AS offer_discount_depth,
                    ROW_NUMBER() OVER affinity_window AS rating
                FROM groups g
                WHERE
                    group_churn_rate <= max_churn_index AND
                    group_churn_rate IS NOT NULL AND
                    group_discount_share < (discount_transactions_percentage / 100) AND
                    group_margin > (round_discount(group_minimum_discount * 100)) / allowable_margin_percentage
                WINDOW 
                    affinity_window AS (
                        PARTITION BY g.customer_id
                        ORDER BY g.group_affinity_index DESC, g.group_minimum_discount DESC )
            )

        SELECT i.customer_id, c.required_check_measure, s.group_name, g.offer_discount_depth
        FROM personal_information i
        LEFT JOIN required_average_check c ON i.customer_id = c.customer_id
        LEFT JOIN (
            SELECT * FROM allowable_groups WHERE rating = 1 ) g 
            ON i.customer_id = g.customer_id
        LEFT JOIN sku_group s ON g.group_id = s.group_id );
END; $$
LANGUAGE plpgsql;

-- SELECT * FROM get_offers_to_increase_the_average_check(2, 5, 1.5, 1000, 101, 1.2);
