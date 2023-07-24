CREATE OR REPLACE FUNCTION get_last_analysis_date()
RETURNS timestamp
LANGUAGE plpgsql
AS
$$
BEGIN
  RETURN (SELECT max(analysis_formation) FROM date_of_analysis_formation);
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


WITH help_table AS (
SELECT
  cards.customer_id
FROM personal_information
  JOIN cards ON personal_information.customer_id = cards.customer_id
  JOIN transactions ON cards.card_id = transactions.card_id
GROUP BY cards.customer_id)








FROM personal_information;

SELECT
  cards.customer_id,
  AVG(transactions.transaction_summ::numeric)
FROM personal_information
  JOIN cards ON personal_information.customer_id = cards.customer_id
  JOIN transactions ON cards.card_id = transactions.card_id
GROUP BY cards.customer_id
