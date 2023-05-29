DROP TABLE IF EXISTS personal_information CASCADE;
DROP TABLE IF EXISTS cards CASCADE;
DROP TABLE IF EXISTS sku_groups CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS stores CASCADE;
DROP TABLE IF EXISTS stores_products CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS checks CASCADE;
DROP TABLE IF EXISTS date_of_analysis_formation CASCADE;


/*  ===  Personal Information Table  ===
    - stores information about customers;
    - uses unique key for identification  */

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
    customer_primary_email  VARCHAR NOT NULL,
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
    customer_primary_phone  VARCHAR NOT NULL,
    CONSTRAINT customer_primary_phone_format
        CHECK (has_phone_format(customer_primary_phone, 
            'personal_information', 'customer_primary_phone'))
);

/*  ============  Cards Table  ===========
    - stores unique card id and its owner;
    - one customer can own several cards  */

CREATE TABLE cards (
    card_id                 BIGSERIAL PRIMARY KEY,
    customer_id             BIGINT,
    CONSTRAINT customer_id_foreign_key
        FOREIGN KEY (customer_id) REFERENCES personal_information(customer_id)
);

/*  ========  SKU Group Table  ======== 
    - stores unique groups of the
      similar products and their names  */

CREATE TABLE sku_groups (
    group_id                BIGSERIAL PRIMARY KEY,
    group_name              VARCHAR NOT NULL
);

/*  ================  Products Table  ================
    - stores possible unique products and their names;
    - stores the group that each product belongs to  */

CREATE TABLE products (
    sku_id                  BIGSERIAL PRIMARY KEY,
    sku_name                VARCHAR NOT NULL,
    group_id                BIGINT,
    CONSTRAINT group_id_foreign_key
        FOREIGN KEY (group_id) REFERENCES sku_group(group_id)
);

/*  ===========  Stores Table  ===========
    - stores unique shops and their names  */

CREATE TABLE stores (
    store_id                BIGSERIAL PRIMARY KEY,
    store_name              VARCHAR NOT NULL
);

/*  ==============  Stores-Products Table  ==============
    - stores unique pair certain store - certain product;
    - purchasing price of the product for the store;
    - the sale price of the product excluding discounts  */

CREATE TABLE stores_products (
    store_id                BIGINT,
    CONSTRAINT store_id
        FOREIGN KEY (store_id) REFERENCES stores(store_id),
    sku_id                  BIGINT,
    CONSTRAINT sku_id_foreign_key
        FOREIGN KEY (sku_id) REFERENCES product_grid(sku_id),
    sku_purchase_price      NUMERIC,
    sku_retail_price        NUMERIC,
    CONSTRAINT store_primary_key 
        PRIMARY KEY (store_id, sku_id)
);

/*  ============  Transactions Table  ============ 
    - stores unique money transfers/transactions;
    - customer card that was used to make it;
    - transaction sum in rubles (full purchase 
      price excluding discounts);
    - date and time when the transaction was made;
    - the store where the transaction was made     */

CREATE TABLE transactions (
    transaction_id          BIGSERIAL PRIMARY KEY,
    card_id                 BIGINT,
    CONSTRAINT card_id_foreign_key 
        FOREIGN KEY (card_id) REFERENCES cards(card_id),
    transaction_summ        NUMERIC,
    transaction_datetime    TIMESTAMPTZ,
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
    transaction_id          BIGINT, -- transaction ID is specified for all products in the check
    CONSTRAINT transaction_id_foreign_key 
        FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    sku_id                  BIGINT,
    CONSTRAINT sku_id_foreign_key 
        FOREIGN KEY (sku_id) REFERENCES product_grid(sku_id),
    sku_amount              BIGINT,
    sku_summ                NUMERIC,
    sku_summ_paid           NUMERIC,
    sku_discount            NUMERIC,
    CONSTRAINT check_primary_key 
        PRIMARY KEY (transaction_id, sku_id)
);

/* ===  Date of analysis formation Table  === */

CREATE TABLE date_of_analysis_formation (
    analysis_formation      TIMESTAMP
);