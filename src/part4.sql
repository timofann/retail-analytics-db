\connect -reuse-previous=on "dbname=retail_analytics user=retail_user";

DROP FUNCTION IF EXISTS get_offers_to_increase_the_average_check(
    INT, DATE, DATE, NUMERIC, NUMERIC, NUMERIC, NUMERIC) CASCADE;
CREATE FUNCTION get_offers_to_increase_the_average_check(
    calculation_method INT,
    first_date TIMESTAMP,
    last_date TIMESTAMP,
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
                LEFT JOIN (
                    SELECT ph.customer_id, ph.group_id, AVG((group_summ_paid - group_cost) / group_cost) AS avg_group_margin
                    FROM purchase_history ph
                    GROUP BY ph.customer_id, ph.group_id ) ph
                    ON ph.customer_id = g.customer_id AND ph.group_id = g.group_id
                WHERE
                    group_churn_rate <= max_churn_index AND
                    group_churn_rate IS NOT NULL AND
                    group_discount_share < (discount_transactions_percentage / 100) AND
                    avg_group_margin > (round_discount(group_minimum_discount * 100)) / allowable_margin_percentage
                WINDOW 
                    affinity_window AS (
                        PARTITION BY g.customer_id
                        ORDER BY g.group_affinity_index DESC, g.group_minimum_discount DESC )
            )

        SELECT c.customer_id, c.required_check_measure, s.group_name, g.offer_discount_depth
        FROM required_average_check c
        JOIN (
            SELECT * FROM allowable_groups WHERE rating = 1 ) g 
            ON c.customer_id = g.customer_id
        LEFT JOIN sku_group s ON g.group_id = s.group_id
        WHERE g.offer_discount_depth != 0 );
END; $$
LANGUAGE plpgsql;

-- SELECT * FROM get_offers_to_increase_the_average_check(1, '21.12.2020 00:00:00', '21.12.2022 00:00:00', 1.5, 3, 70, 30);

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
                    (SUM(t.transaction_summ) / COUNT(t.transaction_id)) * increasing_coeff
                        AS required_check_measure
                FROM rowed_transaction_customer t
                WHERE t.row_n <= number_of_transactions
                GROUP BY t.customer_id
            ),
        
            allowable_groups AS (
                SELECT
                    g.customer_id,
                    g.group_id,
                    group_churn_rate,
                    round_discount(g.group_minimum_discount * 100) AS offer_discount_depth,
                    ROW_NUMBER() OVER affinity_window AS rating
                FROM groups g
                LEFT JOIN (
                    SELECT ph.customer_id, ph.group_id, AVG((group_summ_paid - group_cost) / group_cost) AS avg_group_margin
                    FROM purchase_history ph
                    GROUP BY ph.customer_id, ph.group_id ) ph
                    ON ph.customer_id = g.customer_id AND ph.group_id = g.group_id
                WHERE
                    group_churn_rate <= max_churn_index AND
                    group_churn_rate IS NOT NULL AND
                    group_discount_share < (discount_transactions_percentage / 100) AND
                    avg_group_margin > (round_discount(group_minimum_discount * 100)) / allowable_margin_percentage
                WINDOW 
                    affinity_window AS (
                        PARTITION BY g.customer_id
                        ORDER BY g.group_affinity_index DESC, g.group_minimum_discount DESC )
            )
        
        SELECT c.customer_id, c.required_check_measure, s.group_name, g.offer_discount_depth
            FROM required_average_check c
            JOIN (
                SELECT * FROM allowable_groups WHERE rating = 1 ) g 
                ON c.customer_id = g.customer_id
            LEFT JOIN sku_group s ON g.group_id = s.group_id
            WHERE g.offer_discount_depth != 0 );
END; $$
LANGUAGE plpgsql;

-- SELECT * FROM get_offers_to_increase_the_average_check(2, 100, 1.15, 3, 70, 30);
