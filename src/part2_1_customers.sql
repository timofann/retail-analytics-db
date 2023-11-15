\connect -reuse-previous=on "dbname=retail_analytics user=retail_user";

DROP FUNCTION IF EXISTS get_last_analysis_date CASCADE;
CREATE FUNCTION get_last_analysis_date()
RETURNS TIMESTAMP
AS $$ 
BEGIN
    RETURN (
        SELECT max(analysis_formation) 
        FROM date_of_analysis_formation
    );
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_interval_between_dates CASCADE;
CREATE FUNCTION get_interval_between_dates(
    init_date TIMESTAMPTZ, 
    stop_date TIMESTAMPTZ
) RETURNS NUMERIC 
AS $$
DECLARE
    date_interval INTERVAL := init_date - stop_date;
BEGIN
    RETURN ABS(date_part('day', date_interval)
        + date_part('hour', date_interval)/24
        + date_part('minute', date_interval)/(24*60)
        + date_part('second', date_interval)/(24*60*60));
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_primary_store_id CASCADE;
CREATE FUNCTION get_primary_store_id(
    target_customer_id BIGINT
) RETURNS BIGINT 
AS $$
BEGIN
    RETURN (
        WITH
        
            stat_stores AS (
                SELECT
                    t.transaction_store_id,
                    COUNT(*) OVER w1 AS visits_count,
                    MAX(t.transaction_datetime) OVER w1 AS last_visit_date,
                    ROW_NUMBER() OVER w2 AS store_rank
                FROM personal_information p
                    JOIN cards c ON p.customer_id = c.customer_id
                    JOIN transactions t ON c.customer_card_id = t.customer_card_id
                WHERE t.transaction_datetime <= get_last_analysis_date()
                    AND p.customer_id = target_customer_id
                WINDOW w1 AS (PARTITION BY t.transaction_store_id),
                    w2 AS (ORDER BY t.transaction_datetime DESC)
            ),

            get_popular_store AS (
                SELECT DISTINCT
                    FIRST_VALUE(transaction_store_id) OVER (
                        ORDER BY visits_count DESC, last_visit_date DESC)
                        AS popular_store_id
                FROM stat_stores
            ),

            get_last_store AS (
                SELECT DISTINCT
                    MAX(transaction_store_id) AS last_store_id,
                    MAX(transaction_store_id) = MIN(transaction_store_id) AS is_last_store
                FROM stat_stores
                WHERE store_rank <= 3
            )

        SELECT CASE
            WHEN (SELECT is_last_store FROM get_last_store)
            THEN (SELECT last_store_id FROM get_last_store)
            ELSE (SELECT popular_store_id FROM get_popular_store)
            END AS customer_primary_store_id
    );
END; $$
LANGUAGE plpgsql;

DROP VIEW IF EXISTS customers CASCADE;
CREATE VIEW customers AS
    WITH

        transaction_info_table AS (
            SELECT
                personal_information.customer_id,
                COALESCE(AVG(t.transaction_summ::NUMERIC), 0.0) AS customer_average_check,
                get_interval_between_dates(
                    MIN(t.transaction_datetime), 
                    MAX(t.transaction_datetime)
                ) / COUNT(*) AS customer_frequency,
                get_interval_between_dates(
                    MAX(t.transaction_datetime), 
                    get_last_analysis_date()
                ) AS customer_inactive_period
            FROM personal_information
                LEFT JOIN cards ON personal_information.customer_id = cards.customer_id
                LEFT JOIN transactions AS t ON cards.customer_card_id = t.customer_card_id
            GROUP BY personal_information.customer_id
        ),

        rank_table AS (
            SELECT
                customer_id,
                customer_average_check,
                (ROW_NUMBER() OVER (ORDER BY customer_average_check DESC))::NUMERIC / 
                    (SELECT COUNT(*) FROM personal_information) AS rank_check,
                customer_frequency,
                (ROW_NUMBER() OVER (ORDER BY customer_frequency DESC))::NUMERIC / 
                    (SELECT COUNT(*) FROM personal_information) AS rank_frequency,
                customer_inactive_period,
                customer_inactive_period / customer_frequency AS customer_churn_rate
            FROM transaction_info_table
        ),

        stat_segment AS (
            SELECT
                customer_id,
                customer_average_check,
                customer_frequency,
                customer_inactive_period,
                customer_churn_rate,
                CASE
                    WHEN rank_check <= 0.1 THEN 'High'
                    WHEN rank_check <= 0.35 THEN 'Medium'
                    ELSE 'Low' END AS customer_average_check_segment,
                CASE
                    WHEN rank_frequency > 0.9 THEN 'Often'
                    WHEN rank_frequency > 0.65 THEN 'Occasionally'
                    ELSE 'Rarely' END AS customer_frequency_segment,
                CASE
                    WHEN customer_churn_rate <= 2 THEN 'Low'
                    WHEN customer_churn_rate <= 5 THEN 'Medium'
                    WHEN customer_churn_rate IS NULL THEN 'High'
                    ELSE 'High' END AS customer_churn_segment
            FROM rank_table
        )

    SELECT
        t.customer_id,
        t.customer_average_check,
        t.customer_average_check_segment,
        t.customer_frequency,
        t.customer_frequency_segment,
        t.customer_inactive_period,
        t.customer_churn_rate,
        t.customer_churn_segment,
        CASE customer_average_check_segment
            WHEN 'Low' THEN 0
            WHEN 'Medium' THEN 9
            ELSE 18 END
        + CASE customer_frequency_segment
            WHEN 'Rarely' THEN 0
            WHEN 'Occasionally' THEN 3
            ELSE 6 END
        + CASE customer_churn_segment
            WHEN 'Low' THEN 1
            WHEN 'Medium' THEN 2
            ELSE 3 END AS customer_segment,
        get_primary_store_id(t.customer_id) AS customer_primary_store
    FROM stat_segment t
    ORDER BY t.customer_id;

-- SELECT * FROM customers;
