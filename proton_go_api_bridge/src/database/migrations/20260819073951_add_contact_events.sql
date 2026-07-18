-- +goose Up
-- create "contact_events" table
CREATE TABLE `contact_events` (
  `id` varchar NULL,
  `contact_id` text NOT NULL,
  `action` integer NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `chk_contact_events_action` CHECK (action IN (1, 2))
);

-- +goose Down
-- reverse: create "contact_events" table
DROP TABLE `contact_events`;
