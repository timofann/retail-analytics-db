CREATE OR REPLACE FUNCTION get_last_analysis_date()
RETURNS timestamp
LANGUAGE plpgsql
AS
$$
BEGIN
  RETURN (SELECT max(analysis_formation) FROM date_of_analysis_formation);
END;
$$;

CREATE OR REPLACE FUNCTION get_interval_between_dates(init_date timestamptz, stop_date timestamptz)
RETURNS NUMERIC
LANGUAGE plpgsql
AS
$$
DECLARE
  date_interval INTERVAL := init_date - stop_date;
BEGIN
  RETURN ABS(date_part('day', date_interval)
  + date_part('hour', date_interval)/24
  + date_part('minute', date_interval)/(24*60)
  + date_part('second', date_interval)/(24*60*60));
END;
$$;



CREATE OR REPLACE VIEW Customers (
  Customer_ID,
  Customer_Average_Check,
  Customer_Average_Check_Segment,
  Customer_Frequency,
  Customer_Frequency_Segment,
  Customer_Inactive_Period,
  Customer_Churn_Rate,
  Customer_Churn_Segment)
  -- Customer_Segment
  -- Customer_Primary_Store)
AS (

WITH transaction_info_table AS (
SELECT
  cards.customer_id,
  AVG(t.transaction_summ::numeric) AS customer_average_check,
  get_interval_between_dates(MIN(t.transaction_datetime), MAX(t.transaction_datetime)) / COUNT(*)
  AS customer_frequency,
  get_interval_between_dates(MAX(t.transaction_datetime), get_last_analysis_date())
  AS customer_inactive_period
FROM personal_information
  JOIN cards ON personal_information.customer_id = cards.customer_id
  JOIN transactions as t ON cards.card_id = t.card_id
GROUP BY cards.customer_id),

rank_table AS (
SELECT
  customer_id,
  customer_average_check,
  CUME_DIST() OVER (ORDER BY customer_average_check) AS rank_check,
  customer_frequency,
  CUME_DIST() OVER (ORDER BY customer_frequency) AS rank_frequency,
  customer_inactive_period,
  customer_inactive_period / customer_frequency AS customer_churn_rate
FROM transaction_info_table),

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
    ELSE 'High' END AS customer_churn_segment
FROM rank_table)

SELECT
  t.customer_id,
  t.customer_average_check,
  t.customer_average_check_segment,
  t.customer_frequency,
  t.customer_frequency_segment,
  t.customer_inactive_period,
  t.customer_churn_rate,
  t.customer_churn_segment
FROM stat_segment t
ORDER BY t.customer_id
);  -- Customer view end
