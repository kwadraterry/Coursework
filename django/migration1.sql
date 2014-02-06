CREATE TABLE ACC (id integer, account integer, website integer);
INSERT INTO ACC(id,website,account) SELECT id,website_id,account_id FROM yandex_accounts_subscriptions;


ALTER TABLE yandex_accounts_subscriptions
    DROP COLUMN account_id,
    DROP COLUMN website_id,
    DROP COLUMN sorting_order,
    DROP COLUMN last_changed,
    DROP COLUMN last_changed0;