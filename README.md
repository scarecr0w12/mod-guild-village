# mod-guild-village Enhanced

`mod-guild-village` adds persistent, upgradeable guild settlements to AzerothCore with village ownership, custom currencies, upgrades, transport, quests, bosses, expeditions, production, PvP rewards, and optional playerbot routing.

This repository copy is being maintained as an **Enhanced** version focused on:

- cleaner documentation
- better operational visibility through dedicated logging
- configurable schema support via `GuildVillage.Database.Name`
- safer persistence and startup/update behavior
- continued compatibility work for Playerbot-oriented setups

## Start here

- Full documentation: [`README_EN.md`](README_EN.md)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Legacy pointer: [`README_CS.md`](README_CS.md)

## Quick facts

- Purchase steward entry: `987454`
- Spawn it manually with: `.npc add 987454`
- Main village ownership is stored in the configured schema table `gv_guild`
- Default schema name: `customs`
- Dedicated module log file: `env/dist/logs/GuildVillage.log`

## Feature snapshot

- purchasable guild villages with isolated phase ownership
- configurable village materials and upgrade trees
- teleporter and personal teleport support
- daily and weekly guild quests
- passive production system
- expedition heroes, missions, and loot bank
- village bosses and optional heroic switches
- battleground and optional world PvP rewards
- AoE loot unlock tied to village ownership
- GM utilities for creation, deletion, listing, and currency adjustment
- optional playerbot village visit routing

## Recommended extras

- Addon: [Guild Village Helper (3.3.5a)](https://github.com/BeardBear33/Guild-Village-Helper-3.3.5a)
- Client map patch: [Worldmap fix-mod guild village](https://github.com/BeardBear33/Worldmap_fix-mod-guild-village)

## Compatibility notes

The module is actively used in Playerbot-style environments and has dedicated playerbot hooks/configuration. Review [`README_EN.md`](README_EN.md) before installing it on a production server, especially if you use:

- non-default database/schema names
- custom world ID ranges
- automated SQL deployment
- Playerbot branches or heavily customized cores

## Current enhanced focus

Recent maintenance work has concentrated on:

- explicit configurable table qualification instead of hardcoded `customs.` usage
- dedicated Guild Village logging categories for purchase, upgrade, teleport, GM, cleanup, trigger, and customs updater activity
- clearer persistence and restart troubleshooting guidance
- documentation cleanup and packaging

## License

This module is licensed under the [GNU Affero General Public License v3.0](LICENSE).
