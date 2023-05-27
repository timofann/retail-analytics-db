/* Personal Information Table */

DROP TABLE IF EXISTS personal_information;
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
        CHECK has_phone_format(customer_primary_phone, 
            'personal_information', 'customer_primary_phone')
);

/* Cards Table */

DROP TABLE IF EXISTS cards;
CREATE TABLE cards (
    customer_card_id        BIGINT NOT NULL PRIMARY KEY,
    customer_id             BIGINT,
    CONSTRAINT customer_id_foreign_key_constraint 
        FOREIGN KEY (customer_id) REFERENCES personal_information(customer_id)
);

/* SKU group Table */

DROP TABLE IF EXISTS sku_group;
CREATE TABLE sku_group (
    group_id                BIGSERIAL NOT NULL PRIMARY KEY,
    group_name              VARCHAR NOT NULL
);

/* Product grid Table */

DROP TABLE IF EXISTS product_grid;
CREATE TABLE product_grid (
    sku_id                  BIGSERIAL PRIMARY KEY,
    sku_name                VARCHAR NOT NULL,
    group_id
);
