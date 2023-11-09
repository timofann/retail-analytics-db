-- Get interval between dates
CREATE OR REPLACE FUNCTION get_interval_between_dates(
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


CREATE OR REPLACE FUNCTION form_personal_offer_by_customer_frequency(
    start_date TIMESTAMPTZ, 
    end_date TIMESTAMPTZ,
    added_number_of_transactions BIGINT,
    maximum_churn_index NUMERIC,
    maximum_discount_share NUMERIC,
    acceptable_margin_share NUMERIC
) RETURNS TABLE (
    Customer_Id INTEGER,
    Start_Date TIMESTAMP,
    End_Date TIMESTAMP,
    Required_Transactions_Count NUMERIC,
    Group_Name VARCHAR,
    Offer_Discount_Depth NUMERIC
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        customer.customer_id,
        start_date,
        end_date,
        ROUND(get_interval_between_dates(start_date, end_date) / customer.customer_frequency) + added_number_of_transactions,
        

    
END; $$


period = get_interval_between_dates(start_date, end_date);

current_frequensy = period / SELECT customer_frequency FROM VIEW Customers;

