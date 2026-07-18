-- +goose Up
-- create "contacts" table
CREATE TABLE `contacts` (
  `id` text NULL,
  `updated_at` datetime NULL,
  `synced_at` datetime NULL,
  `search_fields` text NULL,
  `decrypted_v_card` text NULL,
  `is_favorite` numeric NULL DEFAULT false,
  `email_ids` json NULL,
  `groups` json NULL,
  PRIMARY KEY (`id`)
);
-- create "contact_cards" table
CREATE TABLE `contact_cards` (
  `id` integer NULL PRIMARY KEY AUTOINCREMENT,
  `created_at` datetime NULL,
  `updated_at` datetime NULL,
  `contact_id` text NULL,
  `card_type` integer NULL,
  `server_data` text NULL,
  `decrypted_data` text NULL,
  `server_signature` text NULL,
  `key_ring_id` text NULL,
  CONSTRAINT `fk_contacts_cards` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON UPDATE NO ACTION ON DELETE CASCADE
);
-- create index "idx_contact_cards_contact_id" to table: "contact_cards"
CREATE INDEX `idx_contact_cards_contact_id` ON `contact_cards` (`contact_id`);
-- create "sync_states" table
CREATE TABLE `sync_states` (
  `id` integer NULL PRIMARY KEY AUTOINCREMENT,
  `created_at` datetime NULL,
  `updated_at` datetime NULL,
  `full_sync_done` numeric NULL,
  `last_event_id` text NULL,
  `last_sync_at` datetime NULL,
  `last_error` text NULL
);

-- +goose Down
-- reverse: create "sync_states" table
DROP TABLE `sync_states`;
-- reverse: create index "idx_contact_cards_contact_id" to table: "contact_cards"
DROP INDEX `idx_contact_cards_contact_id`;
-- reverse: create "contact_cards" table
DROP TABLE `contact_cards`;
-- reverse: create "contacts" table
DROP TABLE `contacts`;
