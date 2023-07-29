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
  Customer_Churn_Segment,
  Customer_Segment,
  Customer_Primary_Store)
AS

WITH average_check_table AS (
SELECT
  cards.customer_id,
  AVG(transactions.transaction_summ::numeric) AS customer_average_check
FROM personal_information
  JOIN cards ON personal_information.customer_id = cards.customer_id
  JOIN transactions ON cards.card_id = transactions.card_id
GROUP BY cards.customer_id),

WITH transaction_info_table AS (
SELECT
  cards.customer_id,
  get_interval_between_dates(MIN(transactions.transaction_datetime), MAX(transactions.transaction_datetime)) / COUNT(*) AS customer_frequency,
  get_interval_between_dates(MAX(transactions.transaction_datetime), get_last_analysis_date()) AS customer_inactive_period
FROM personal_information
  JOIN cards ON personal_information.customer_id = cards.customer_id
  JOIN transactions ON cards.card_id = transactions.card_id
GROUP BY cards.customer_id),

difference_between_dates



  -- CUME_DIST() OVER (ORDER BY customer_average_check) AS check_range


FROM personal_information;


SELECT
  cards.customer_id
FROM personal_information
  JOIN cards ON personal_information.customer_id = cards.customer_id
  JOIN transactions ON cards.card_id = transactions.card_id
GROUP BY cards.customer_id

