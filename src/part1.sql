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
    customer_id             BIGINT, -- one customer can own several cards
    CONSTRAINT customer_id_foreign_key
        FOREIGN KEY (customer_id) REFERENCES personal_information(customer_id)
);

/* Transactions Table */

DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
    transaction_id          BIGSERIAL PRIMARY KEY,
    customer_card_id        BIGINT,
    CONSTRAINT customer_card_id_foreign_key 
        FOREIGN KEY (customer_id) REFERENCES cards(customer_card_id)
    transaction_summ        NUMERIC, -- transaction sum in rubles (full purchase price excluding discounts)
    transaction_datetime    TIMESTAMPTZ, -- date and time when the transaction was made
    transaction_store_id, -- the store where the transaction was made
);

select typname, typlen from pg_type where typname ~ '^timestamp';