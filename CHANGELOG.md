# Changelog

All notable documentation and maintenance updates for the enhanced `mod-guild-village` variant should be recorded here.

The format is intentionally simple and practical for module maintenance.

## Unreleased

### Added

- dedicated Guild Village file logging via `GuildVillage.log`
- structured logging categories for purchase, upgrade, teleport, command, GM, cleanup, trigger, and customs updater activity
- explicit configurable table qualification helper for module-owned schema tables
- refreshed root/module documentation for the enhanced edition
- a dedicated changelog for tracking module maintenance work

### Changed

- updated runtime SQL access to use the configured schema name explicitly instead of relying on hardcoded visible `customs.` references in live source queries
- improved customs updater logging to use the dedicated Guild Village logging categories
- clarified installation, persistence, schema, and restart troubleshooting guidance in the README files
- modernized the module’s landing documentation and compatibility notes for Playerbot-oriented environments

### Fixed

- corrected remaining hardcoded schema access paths so village-owned data follows `GuildVillage.Database.Name`
- improved observability around village purchase, teleport, cleanup, GM actions, and upgrade flows
- reduced the risk of confusing restart behavior caused by opaque schema handling

### Notes

- Primary village ownership is stored in `gv_guild` in the configured Guild Village schema.
- Older installations may still need the legacy migration in `data/sql/customs/archive/updates/014_important_update.sql` before relying on current automatic updater behavior.
- World content IDs used by the module remain reserved and should be checked before deployment on customized world databases.
