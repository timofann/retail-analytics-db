CALL drop_tables();

/*                 ===  Personal Information Table  ===
                   - stores information about customers;
                   - uses unique key for identification                */

CREATE TABLE personal_information (
    customer_id             BIGSERIAL PRIMARY KEY,
    customer_name           VARCHAR NOT NULL,
    CONSTRAINT customer_name_latin_letters_spaces_dashes 
        CHECK (contains_only_latin_letters_spaces_dashes(customer_name, 
            'personal_information', 'customer_name')),
    CONSTRAINT customer_name_capitalized_latin_letter
        CHECK (starts_with_capitalised_latin_letter(customer_name, 
            'personal_information', 'customer_name')),
    customer_surname        VARCHAR NOT NULL,
    CONSTRAINT customer_surname_latin_letters_spaces_dashes 
        CHECK (contains_only_latin_letters_spaces_dashes(customer_surname, 
            'personal_information', 'customer_surname')),
    CONSTRAINT customer_surname_capitalized_latin_letter
        CHECK (starts_with_capitalised_latin_letter(customer_surname, 
            'personal_information', 'customer_surname')),
    customer_primary_email  VARCHAR NOT NULL UNIQUE,
    CONSTRAINT customer_primary_email_email_format 
        CHECK (has_email_format(customer_primary_email, 
            'personal_information', 'customer_primary_email')),
    CONSTRAINT customer_primary_email_login 
        CHECK (has_correct_login(customer_primary_email, 
            'personal_information', 'customer_primary_email')),
    CONSTRAINT customer_primary_email_nleveldomain 
        CHECK (has_correct_nleveldomain(customer_primary_email, 
            'personal_information', 'customer_primary_email')),
    CONSTRAINT customer_primary_email_firstleveldomain  
        CHECK (has_correct_firstleveldomain(customer_primary_email, 
            'personal_information', 'customer_primary_email')),
    customer_primary_phone  VARCHAR NOT NULL UNIQUE,
    CONSTRAINT customer_primary_phone_format
        CHECK (has_phone_format(customer_primary_phone, 
            'personal_information', 'customer_primary_phone'))
);

/*                ============  Cards Table  ===========
                  - stores unique card id and its owner;
                  - one customer can own several cards                 */

CREATE TABLE cards (
    card_id                 BIGSERIAL PRIMARY KEY,
    customer_id             BIGINT,
    CONSTRAINT customer_id_foreign_key
        FOREIGN KEY (customer_id) REFERENCES personal_information(customer_id)
);

/*                 ========  SKU Group Table  ========
                   - stores unique groups of the
                     similar products and their names                  */

CREATE TABLE sku_groups (
    group_id                BIGSERIAL PRIMARY KEY,
    group_name              VARCHAR NOT NULL UNIQUE
);

/*         ================  Products Table  ================      
           - stores possible unique products and their names;      
           - stores the group that each product belongs to             */

CREATE TABLE products (
    sku_id                  BIGSERIAL PRIMARY KEY,
    sku_name                VARCHAR NOT NULL,
    group_id                BIGINT,
    CONSTRAINT group_id_foreign_key
        FOREIGN KEY (group_id) REFERENCES sku_groups(group_id)
);

/*                ===========  Stores Table  ===========
                  - stores unique shops and their names                */

CREATE TABLE stores (
    store_id                BIGSERIAL PRIMARY KEY,
    store_name              VARCHAR NOT NULL
);

/*         ==============  Stores-Products Table  ==============
           - stores unique pair certain store - certain product;
           - purchasing price of the product for the store;
           - the sale price of the product excluding discounts         */

CREATE TABLE stores_products (
    store_id                BIGINT,
    CONSTRAINT store_id
        FOREIGN KEY (store_id) REFERENCES stores(store_id),
    sku_id                  BIGINT,
    CONSTRAINT sku_id_foreign_key
        FOREIGN KEY (sku_id) REFERENCES products(sku_id),
    sku_purchase_price      NUMERIC,
    sku_retail_price        NUMERIC,
    CONSTRAINT nonnegative_money_stores_products
        CHECK (sku_purchase_price > 0.0 AND
               sku_retail_price > 0.0),
    CONSTRAINT store_primary_key 
        PRIMARY KEY (store_id, sku_id)
);

/*           ============  Transactions Table  ============ 
             - stores unique money transfers/transactions;
             - customer card that was used to make it;
             - transaction sum in rubles (full purchase 
               price excluding discounts);
             - date and time when the transaction was made;
             - the store where the transaction was made               */

CREATE TABLE transactions (
    transaction_id          BIGSERIAL PRIMARY KEY,
    card_id                 BIGINT,
    CONSTRAINT card_id_foreign_key 
        FOREIGN KEY (card_id) REFERENCES cards(card_id),
    transaction_summ        NUMERIC,
    CONSTRAINT transaction_summ_is_positive
        CHECK (transaction_summ > 0.0),
    transaction_datetime    TIMESTAMP,
    store_id                BIGINT,
    CONSTRAINT store_id_foreign_key
        FOREIGN KEY (store_id) REFERENCES stores(store_id)
);

/*  =========================  Checks Table  ========================= 
    - stores full information about product that customer spent money
      to due one certain transaction (one sku_id cant appear twice);
    - the quantity of the purchased product;
    - the purchase amount of the actual volume of this product in 
      rubles (full price without discounts and bonuses);
    - the amount actually paid for the product;
    - the size of the discount granted for the product in rubles      */

CREATE TABLE checks (
    transaction_id          BIGINT,
    CONSTRAINT transaction_id_foreign_key 
        FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    sku_id                  BIGINT,
    CONSTRAINT sku_id_foreign_key 
        FOREIGN KEY (sku_id) REFERENCES products(sku_id),
    sku_amount              NUMERIC,
    CONSTRAINT sku_amount_is_positive
        CHECK (sku_amount > 0.0),
    sku_summ                NUMERIC,
    sku_summ_paid           NUMERIC,
    sku_discount            NUMERIC,
    CONSTRAINT nonnegative_money
        CHECK (sku_summ >= 0.0 AND
               sku_summ_paid >= 0.0 AND
               sku_discount >= 0.0),
    CONSTRAINT check_primary_key 
        PRIMARY KEY (transaction_id, sku_id)
);

/*             ===  Date of analysis formation Table  ===             */

CREATE TABLE date_of_analysis_formation (
    analysis_formation      TIMESTAMP
);

/*                         === DATA EXPORT ===                        */

INSERT INTO personal_information VALUES (DEFAULT, 'My', 'Regree', 'regree@student.21-school.ru', '+79288903035');
SELECT * FROM personal_information;
SELECT * FROM retail_analitycs_config;
CALL export_to_csv('personal_information');
CALL export_to_tsv('personal_information');

/*                         === DATA IMPORT ===                        */

CALL truncate_tables();

CALL import_from_csv('personal_information');
CALL import_from_csv('cards');
CALL import_from_csv('sku_groups');
CALL import_from_csv('products');
CALL import_from_csv('stores');
CALL import_from_csv('stores_products');
CALL import_from_csv('transactions');
CALL import_from_csv('checks');
CALL import_from_csv('date_of_analysis_formation');

CALL import_default_dataset_mini();
CALL import_default_dataset();
CALL import_custom_dataset();

SELECT * FROM personal_information;
SELECT * FROM cards;
SELECT * FROM sku_groups;
SELECT * FROM products;
SELECT * FROM stores;
SELECT * FROM stores_products;
SELECT * FROM transactions;
SELECT * FROM checks;
SELECT * FROM date_of_analysis_formation;