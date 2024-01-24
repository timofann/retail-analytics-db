\connect -reuse-previous=on "dbname=retail_analytics user=retail_user";

/*  ========================  Customers View  ======================== 
    - stores the average check in rubles for the analyzed period;
    - High (10% of customers) / Medium (25% of customers) / Low 
      average check segment;
    - the customer visit frequency in the average number of days 
      between transactions;
    - Often (10% of customers) / Occasionally (25% of customers) / 
      Rarely transaction frequency segment;
    - number of days passed since the previous transaction date;
    - value of the customer churn rate (Customer_Inactive_Period / 
      Customer_Frequency);
    - High (> 5) / Medium (2 - 5) / Low (< 2) churn rate segment;
    - the number of the segment to which the customer belongs:

| **Segment** | **Average check** | **Frequency of purchases** | **Churn probability** |
|-------------|-------------------|----------------------------|-----------------------|
| 1           | Low               | Rarely                     | Low                   |
| 2           | Low               | Rarely                     | Medium                |
| 3           | Low               | Rarely                     | High                  |
| 4           | Low               | Occasionally               | Low                   |
| 5           | Low               | Occasionally               | Medium                |
| 6           | Low               | Occasionally               | High                  |
| 7           | Low               | Often                      | Low                   |
| 8           | Low               | Often                      | Medium                |
| 9           | Low               | Often                      | High                  |
| 10          | Medium            | Rarely                     | Low                   |
| 11          | Medium            | Rarely                     | Medium                |
| 12          | Medium            | Rarely                     | High                  |
| 13          | Medium            | Occasionally               | Low                   |
| 14          | Medium            | Occasionally               | Medium                |
| 15          | Medium            | Occasionally               | High                  |
| 16          | Medium            | Often                      | Low                   |
| 17          | Medium            | Often                      | Medium                |
| 18          | Medium            | Often                      | High                  |
| 19          | High              | Rarely                     | Low                   |
| 20          | High              | Rarely                     | Medium                |
| 21          | High              | Rarely                     | High                  |
| 22          | High              | Occasionally               | Low                   |
| 23          | High              | Occasionally               | Medium                |
| 24          | High              | Occasionally               | High                  |
| 25          | High              | Often                      | Low                   |
| 26          | High              | Often                      | Medium                |
| 27          | High              | Often                      | High                  |

*/

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
                cards.customer_id,
                COALESCE(AVG(t.transaction_summ::NUMERIC), 0.0) AS customer_average_check,
                get_interval_between_dates(
                    MIN(t.transaction_datetime), 
                    MAX(t.transaction_datetime)
                ) / COUNT(*) AS customer_frequency,
                get_interval_between_dates(
                    MAX(t.transaction_datetime), 
                    get_last_analysis_date()
                ) AS customer_inactive_period
            FROM cards
                LEFT JOIN transactions AS t ON cards.customer_card_id = t.customer_card_id
            GROUP BY cards.customer_id
        ),

        rank_table AS (
            SELECT
                customer_id,
                customer_average_check,
                (ROW_NUMBER() OVER (ORDER BY customer_average_check DESC))::NUMERIC / 
                    (SELECT COUNT(*) FROM transaction_info_table) AS rank_check,
                customer_frequency,
                (ROW_NUMBER() OVER (ORDER BY customer_frequency))::NUMERIC / 
                    (SELECT COUNT(*) FROM transaction_info_table) AS rank_frequency,
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
                    WHEN rank_frequency <= 0.1 THEN 'Often'
                    WHEN rank_frequency <= 0.35 THEN 'Occasionally'
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

-- SELECT * FROM customers ORDER BY customer_id;
