\connect "dbname=retail_analytics user=retail_user";

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
        offer_discount_depth    NUMERIC,
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
    RETURN (
        WITH
        transactions_mini AS (
            SELECT transaction_id, card_id, transaction_summ
            FROM transactions
            WHERE transaction_datetime BETWEEN first_date AND last_date
        ),
        required_average_check AS (
            SELECT
                customer_id,
                SUM(transaction_summ) / COUNT(transaction_id) * increasing_coeff AS required_check_measure
            FROM transactions_mini JOIN
                cards on transactions_mini.card_id = cards.card.id
            GROUP BY customer_id
        ),
        group_discounts AS (
            SELECT 
                customer_id,
                group_id,
                SUM(group_summ != group_summ_paid) / COUNT(transaction_id) AS discount_percentage,
                ((MIN((group_summ - group_summ_paid) * 100 / group_summ) - 1) // 5 + 1) * 5 AS min_group_discount
            FROM purchase_history
            GROUP BY customer_id, group_id
        ),
        groups_mini AS (
            SELECT customer_id, group_id, group_churn_rate, group_affinity_index, group_margin
            FROM groups
        ),
        allowable_groups AS (
            SELECT
                customer_id, group_id, group_affinity_index, min_group_discount AS offer_discount_depth
            FROM group_discounts d JOIN
                groups_mini g ON d.customer_id = g.customer_id AND d.group_id = g.group_id
            WHERE
                group_churn_rate < max_churn_index AND
                discount_percentage < discount_transactions_percentage AND
                group_margin * allowable_margin_percentage > min_group_discount
            GROUP BY customer_id
        ),
        best_results AS (
            SELECT customer_id, group_name, offer_discount_depth
            FROM allowable_groups g JOIN
                sku_groups s ON g.group_id = s.group_id
            WHERE group_affinity_index = MAX(group_affinity_index)
            GROUP BY customer_id
        )
    SELECT c.customer_id, required_check_measure, group_name, offer_discount_depth
    FROM required_average_check c LEFT JOIN
        best_results r ON r.customer_id = c.customer_id
    );
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_offers_to_increase_the_average_check(
    INT, BIGINT, NUMERIC, NUMERIC, NUMERIC, NUMERIC) CASCADE;
CREATE FUNCTION get_offers_to_increase_the_average_check(
    method increasing_the_average_check_method,
    number_of_transactions BIGINT,
    increasing_coeff NUMERIC,
    max_churn_index NUMERIC,
    discount_transactions_percentage NUMERIC,
    allowable_margin_percentage NUMERIC )
    RETURNS TABLE (
        customer_id             BIGINT,
        required_check_measure  NUMERIC,
        group_name              VARCHAR,
        offer_discount_depth    NUMERIC,
    )
AS $$
BEGIN
    IF calculation_method != 1 AND calculation_method != 2 THEN
        RAISE 'The calculation_method should be set to 1 (per period) or 2 (per transactions quantity)';
    ELSIF calculation_method = 1 THEN
        RAISE 'The calculation_method is set to 1 so you need to set up first_date and last_date of period';
    END IF;
    RETURN (
        WITH
        rowed_transaction_customer AS (
            SELECT
                transaction_id,
                transaction_summ,
                customer_id,
                ROW_NUMBER(*) OVER (PARTITION BY customer_id ORDER BY transaction_datetime DESC) AS row_n
            FROM transactions t JOIN 
                cards c ON t.card_id = c.card_id;
        ),
        required_average_check AS (
            SELECT
                customer_id,
                SUM(transaction_summ) / COUNT(transaction_id) * increasing_coeff AS required_check_measure
            FROM rowed_transaction_customer
            WHERE row_n <= number_of_transactions
            GROUP BY customer_id
        ),
        group_discounts AS (
            SELECT
                customer_id,
                group_id,
                SUM(group_summ != group_summ_paid) / COUNT(transaction_id) AS discount_percentage,
                ((MIN((group_summ - group_summ_paid) * 100 / group_summ) - 1) // 5 + 1) * 5 AS min_group_discount
            FROM purchase_history
            GROUP BY customer_id, group_id
        ),
        groups_mini AS (
            SELECT customer_id, group_id, group_churn_rate, group_affinity_index, group_margin
            FROM groups
        ),
        allowable_groups AS (
            SELECT
                customer_id, group_id, group_affinity_index, min_group_discount AS offer_discount_depth
            FROM group_discounts d JOIN
                groups_mini g ON d.customer_id = g.customer_id AND d.group_id = g.group_id
            WHERE
                group_churn_rate < max_churn_index AND
                discount_percentage < discount_transactions_percentage AND
                group_margin * allowable_margin_percentage > min_group_discount
            GROUP BY customer_id
        ),
        best_results AS (
            SELECT customer_id, group_name, offer_discount_depth
            FROM allowable_groups g JOIN
                sku_groups s ON g.group_id = s.group_id
            WHERE group_affinity_index = MAX(group_affinity_index)
            GROUP BY customer_id
        )
    SELECT c.customer_id, required_check_measure, group_name, offer_discount_depth
    FROM required_average_check c LEFT JOIN
        best_results r ON r.customer_id = c.customer_id
    );
END; $$
LANGUAGE plpgsql;