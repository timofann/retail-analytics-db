# RetailAnalytics v1.0

Retail analytics data upload, its simple analysis, statistics, customer segmentation and creation of personal offers.
The aim of the project is to create a database with knowledge of retailers' customers, and write the views and procedures needed to create personal offers.
                                                                                                                                                                                                                            |

#### Groups View

| **Field**                              | **System field name**       | **Format / possible values**     | **Description**                                                                                                                        |
|:--------------------------------------:|:---------------------------:|:--------------------------------:|:-----------------------------------------------------------------------------------------------------------------------------------:|
| Customer ID                            | Customer_ID                 | ---                              | ---                                                                                                                                 |
| Group ID                               | Group_ID                    | ---                              | ---                                                                                                                                 |
| Affinity index                         | Group_Affinity_Index        | Arabic numeral, decimal          | Customer affinity index for this group                                                                                 |
| Churn index                            | Group_Churn_Rate            | Arabic numeral, decimal          | Customer churn index for a specific group                                                                                          |
| Stability index                        | Group_Stability_Index       | Arabic numeral, decimal          | Indicator demonstrating the stability of the customer consumption of the group                                                                |
| Actual margin for the group            | Group_Margin                | Arabic numeral, decimal          | Indicator of the actual margin for the group for a particular customer                                                                       |
| Share of transactions with a discount  | Group_Discount_Share        | Arabic numeral, decimal          | Share of purchasing transactions of the group by a customer, within which the discount was applied (excluding the loyalty program bonuses) |
| Minimum size of the discount           | Group_Minimum_Discount      | Arabic numeral, decimal          | Minimum size of the group discount for the customer                                                                    |
| Average discount                       | Group_Average_Discount      | Arabic numeral, decimal          | Average size of the group discount for the customer                                                                                         |





## Part 3. Role model

Create roles in the *part3.sql* script and give them permissions as described below.

#### Administrator
The administrator has full permissions to edit and view any information, start and stop the processing.

#### Visitor
Only view information of all tables.

## Part 4. Forming personal offers aimed at the growth of the average check

Create a *part4.sql* script, in which you should add the following function.

### Write a function that determines offers that aimed at the growth of the average check
Function parameters:
- average check calculation method (1 - per period, 2 - per quantity)
- first and last dates of the period (for method 1)
- number of transactions (for method 2)
- coefficient of average check increase
- maximum churn index
- maximum share of transactions with a discount (in percent)
- allowable share of margin (in percent)

##### Offer condition determination

1.  **Choosing the method of calculating the average check.**
    There is an option to choose a method of calculating an average check - for a certain period of time or for a certain number of recent transactions. The calculation method *manually determined* by the user.

    1. The user selects the calculation method **by period**, and then specifies the first and last dates of the period for which you want to calculate the average check for the entire population of customers in the sample. Here, the last date of the specified period must be later than the first one, and the specified period must be within the total analyzed period. If the date is too early or too late, the system automatically substitutes the date of the beginning or the end of the analyzed period respectively. All transactions made by each specific customer during a given period are considered for the calculation.

    2. The user selects the calculation method **by the number of recent transactions**, and then manually specifies the number of transactions for which it is necessary to calculate the average check. To calculate the average check, we take the user-specified number of transactions, starting with the most recent one in reverse chronological order. In case any customer from the sample makes less than the specified number of transactions during the whole analyzed period, the available number of transactions is used for the analysis.

2.  **Determination of the average check.** For each customer, the current value of the average check is determined according to the method selected in step 1. This is done by dividing the total turnover of all transactions of a customer in the sample by the number of these transactions. The final value is saved in the table as the current value of the average check.

3.  **Determination of the target value of the average check.** The calculated value of the average check is multiplied by the coefficient set by the user. The received value is saved in the system as a target value of the average check of the customer and further is used to form the offer condition, which must be fulfilled by the customer to get the reward.

##### Reward determination

4.  **Determination of the group to form the reward.** A group that meets the following criteria in sequence is selected to form the reward:

    -  The affinity index of the group is the highest possible.

- The churn index for this group should not exceed the value set by the user. If the churn index exceeds the set value, the next group by the affinity index is used;

    - The share of transactions with a discount for this group is less than the value set by the user. If the selected group exceeds the set value, the next group by the affinity index that also meets the churn criterion is used. 

5.  **Determination of the maximum allowable size of a discount for the reward.**

The user manually determines the share of margin (in percent) that is allowed to be used to provide a reward for the group. The final value of the maximum allowable discount is calculated by multiplying the set value by the average customer margin for the group.

6.  **Determination of the discount size**. The value obtained at step 5 is compared to the minimum discount that was fixed for the customer for the given group, rounded up in increments of 5%. If the minimum discount after rounding is less than the value obtained at step 5, it is set as a discount for the group within the offer for the customer. Otherwise, this group is excluded from consideration, and to form an offer for the customer the process is repeated, starting with step 4 (the next appropriate group according to the described criteria is used).

Function output:

| **Field**                      | **System field name**      | **Format / possible values**                | **Description**                                                                               |
|--------------------------------|-----------------------------|--------------------------------------------|----------------------------------------------------------------------------------------------|
| Customer ID                    | Customer_ID                 |                                            |                                                                                               |
| Average check target value     | Required_Check_Measure      | Arabic numeral (decimal)                   | Target value of the average check required to receive a reward                               |
| Offer group                    | Group_Name                  |                                            | The name of the offer group, for which the reward is accrued when the condition is met.   |
| Maximum discount depth         | Offer_Discount_Depth        | Arabic numeral (decimal), percent          | The maximum possible discount for the offer                                                   |


## Part 5. Forming personal offers aimed at increasing the frequency of visits

Create a *part5.sql* script and add the following function to it.

### Write a function that determines offers aimed at increasing the frequency of visits
Function parameters:
- first and last dates of the period
- added number of transactions
- maximum churn index
- maximum share of transactions with a discount (in percent)
- allowable margin share (in percent)

##### Offer condition determination

1. **Period determination**.
   The user manually sets the period of validity of the developing offer, specifying its start and end dates.

2. **Determination of the current frequency of customer visits in the specified period.**
   The start date is subtracted from the end date of the specified period, after which the received value is divided by the average intensity of customer transactions (`Customer_Frequency` of the [Customers Table](#customers-view)). The final result is saved as the base intensity of customer transactions during the specified period.

3. **Determination of the reward transaction.**
   The system determines the serial number of the transaction within the specified period, for which the reward should be accrued. For this, the value obtained at step 2 is rounded according to arithmetic rules to an integer, and then the number of transactions specified by the user is added to it. The final value is the target number of transactions that the customer must make to receive the reward.

##### Reward determination

4.  **Determination of the group to form the reward.** A group that meets the following criteria in sequence is selected to form the reward:

    -  The affinity index of the group is the highest possible.

    -  The churn index for this group should not exceed the value set by the user. If the churn rate exceeds the set value, the next group according to the affinity index is selected;

    -  The share of transactions with a discount for this group is less than the user-defined value. If the selected group exceeds the set value, the next group is selected according to the affinity index, which also meets the churn criterion.

5.  **Determination of the maximum allowable discount for the reward.** The user manually determines the share of margin (in percent) that is allowed to be used to provide a reward for the group. The final value of the maximum allowable discount is calculated by multiplying the set value by the average customer margin for the group.

6.  **Determination of the discount size**. The value obtained at step 5 is compared to the minimum discount that was fixed for the customer for the given group, rounded up in increments of 5%. If the minimum discount after rounding is less than the value obtained at step 5, it is set as a discount for the group within the offer for the customer. Otherwise, this group is excluded from consideration, and to form an offer for the customer the process is repeated, starting with step 4 (the next appropriate group according to the described criteria is used).

Function output:

| **Field**                     | **System field name**       | **Format / possible values**      | **Description**
|-------------------------------|-----------------------------|-----------------------------------|--------------------------------------------------------------------------------------------|
| Customer ID                   | Customer_ID                 |                                   |                                                                                            |
| Period start date             | Start_Date                  | yyyy-mm-dd hh:mm:ss.0000000       | The start date of the period during which transactions must be made
| Period end date               | End_Date                    | yyyy-mm-dd hh:mm:ss.0000000       | The end date of the period during which transactions must be made                 |
| Target number of transactions | Required_Transactions_Count | Arabic numeral (decimal)          | Serial number of the transaction to which the reward is accrued                         |
| Offer group                   | Group_Name                  |                                   | The name of the offer group, to which the reward is accrued when the condition is met. |
| Maximum discount depth        | Offer_Discount_Depth        | Arabic numeral (decimal), percent | The maximum possible discount for the offer                                        |


## Part 6. Forming personal offers aimed at cross-selling

Create a *part6.sql* script and add the following function to it.

### Write a function that determines offers aimed at cross-selling (margin growth)
Function parameters:
- number of groups
- maximum churn index
- maximum consumption stability index
- maximum SKU share (in percent)
- allowable margin share (in percent)

Offers aimed at margin growth due to cross-sales involve switching the customer to the highest margin SKU within the demanded group.

1.  **Group selection.** To form offers aimed at margin growth due to cross-sales, several groups  with the maximum affinity index (the number is *set* by the user) are selected for each customer and meet the following conditions:

    1. The churn index for the group is not more than the value set by the user.

    2. The consumption stability index is less than the value set by the user.

2.  **Determination of SKU with maximum margin.** SKU with the maximum margin is determined in each group (in rubles).This is done by subtracting the purchase price (`SKU_Purchase_Price`) from retail price of the product (`SKU_Retail_Price`)  for all SKUs of the group represented in the primary store, and then selecting one SKU with the maximum value of the specified difference.

3.  **Determination of the SKU share in a group.** The share of transactions where the analyzed SKU is present is determined. This is done by dividing the number of transactions containing this SKU by the number of transactions containing the group as a whole (for the analyzed period). SKU is used to form an offer only if the resulting value does not exceed the value set by the user.

4.  **Determination of the margin share for discount calculation.** The user *manually determines* the margin share (in percent) that is allowable to be used to provide rewards for SKU (a single value is set for the whole set of customers).

5.  **Discount calculation.** The value *set* by the user at step 4 is multiplied by the difference between the retail (`SKU_Retail_Price`) and purchase (`SKU_Purchase_Price`) prices, and the resulting value is divided by the retail SKU price (`SKU_Retail_Price`). All prices are for the customer's main store. If the resulting value is equal to or greater than the minimum user discount for the analyzed group rounded up in increments of 5%, the minimum discount for the group rounded up in increments of 5% is set as a discount for the given SKU for the customer. Otherwise, no offer is formed for the customer for this group.

Function output:

| **Field**              | **System field name** | **Format / possible values**       | **Description**                                                |
|------------------------|-----------------------|------------------------------------|-----------------------------------------------------------------------------------------|
| Customer ID            | Customer_ID           |                                    |                                                       |
| SKU offers             | SKU_Name              |                                    | The name of the SKU offer, to which the reward is accrued when the condition is met. |
| Maximum discount depth | Offer_Discount_Depth  | Arabic numeral (decimal), percent  | The maximum possible discount for the offer                                    |


## Chapter IV

Chuck had been staring at the screen for hours and couldn't figure it out. A certain "AID" department disappears from the statements as fast as appears, literally in the blink of an eye.
All expenses are written off for the development of smart vacuum cleaners, something only the household department has been doing for a long time. Yes, there was a new SP-21 model released at the same time, but still what is this: an innocent typo in the name or an opportune moment? The question that will haunt Chuck in the near future...


💡 [Tap here](https://forms.yandex.ru/cloud/641820bf5d2a060d5d1b2b40/) **to leave your feedback on the project**. Product Team really tries to make your educational experience better.
