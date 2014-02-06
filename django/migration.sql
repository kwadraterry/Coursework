ALTER TABLE yandex_accounts_subscriptions
ADD COLUMN
sorting_order
INT
DEFAULT 0;
ALTER TABLE yandex_accounts_subscriptions
ADD COLUMN last_changed
timestamp with time zone;
WITH q
AS
(
  SELECT yandex_subscriptions.id, quantity.common_quantity AS common_quantity, yandex_accounts_subscriptions.id AS y_a_s
  FROM yandex_accounts_subscriptions
    JOIN yandex_subscriptions ON yandex_subscriptions.id=yandex_accounts_subscriptions.yandex_subscription_id
    LEFT JOIN (SELECT * FROM yandex_wordstat WHERE
      (yandex_wordstat.timestamp, yandex_wordstat.yandex_subscription_id) IN
        (SELECT max(yandex_wordstat.timestamp), yandex_wordstat.yandex_subscription_id FROM yandex_wordstat
         GROUP BY yandex_wordstat.yandex_subscription_id)) quantity
    ON quantity.yandex_subscription_id=yandex_subscriptions.id
)
UPDATE yandex_accounts_subscriptions
SET sorting_order = -q.common_quantity
FROM q
WHERE yandex_accounts_subscriptions.id = q.y_a_s;
UPDATE yandex_accounts_subscriptions SET last_changed = now();
