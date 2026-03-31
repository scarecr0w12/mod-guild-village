# mod-guild-village Enhanced

## Overview

`mod-guild-village` adds persistent guild-owned villages to AzerothCore. A guild can purchase a village, gain an isolated village phase, earn and spend village materials, unlock upgrades, run production, send expedition heroes, complete guild quests, use teleport networks, and interact with village-specific bosses and supporting systems.

This enhanced edition also includes:

- dedicated Guild Village file logging
- explicit configurable schema support
- cleaner persistence behavior and documentation
- improved troubleshooting guidance for restart and updater issues

## Core systems

The module currently includes:

- purchasable guild villages
- isolated phase ownership per guild
- configurable purchase price in gold and/or items
- upgrade catalogs and expansion unlocks
- teleport menus and personal teleport points
- daily and weekly guild quests
- guild material currency with optional caps
- passive production with upgradeable amount/speed ranks
- expedition hiring, missions, and loot bank
- PvP guild currency rewards
- optional AoE loot unlock
- village bosses with optional heroic toggles
- optional cleanup of villages owned by long-inactive guild masters
- optional playerbot visit routing with farm re-kicks for phased village mobs
- GM administration commands for creation, deletion, listing, and currency edits

## Persistence and where data is saved

Village ownership and village-specific state are stored in the schema configured by:

- `GuildVillage.Database.Name`

By default that schema is `customs`.

The most important persistence table is:

- `gv_guild` — one row per guild village ownership record

Other module tables store related village state, such as:

- `gv_currency`
- `gv_upgrades`
- `gv_guild_quests`
- `gv_teleport_player`
- `gv_teleport_back`
- `gv_production_*`
- `gv_expedition_*`
- `gv_loot`

World spawns created by the module are written into normal world tables such as `creature`, `gameobject`, and related respawn tables.

### Restart troubleshooting tip

If a guild can buy a village, play normally, and then appears to lose ownership after a restart, check these first:

1. the configured schema in `GuildVillage.Database.Name` still exists and is the one the module is using
2. the SQL user from `WorldDatabaseInfo` still has access to that schema
3. the tracking table `gv_updates` was not lost, reset, or recreated incorrectly
4. your startup logs in `GuildVillage.log` do not show schema/bootstrap/update failures

If the schema or updater-tracking state is reset, the module can behave like it is starting from a blank module database.

## Installation

### 1. Add the module

Place `mod-guild-village` in your `modules/` directory and rebuild your core.

### 2. Configure the module

Copy or merge:

- `conf/mod_guild_village.conf.dist`

Key options to review immediately:

- `GuildVillage.Locale`
- `GuildVillage.Database.Name`
- `GuildVillage.Database.AutoCreate`
- `GuildVillage.MaxVillages`
- `GuildVillage.Inactivity.CleanupDays`
- `GuildVillage.RequireGuildMasterForPurchase`
- `GuildVillage.HidePurchaseMenuForNonGM`
- `GuildVillage.PlayerbotVillage.Enable`
- `GuildVillage.PlayerbotVillage.FarmKickSeconds`

### 2.1 Playerbot village farming

When Playerbot support is present, the module can periodically send guild-owned
playerbots into their village and re-kick them toward farmable creature spawns.

The current behavior is intentionally module-side only:

- the module does not modify `mod-playerbots`
- visiting bots are teleported into their guild village phase
- if they idle at the central village hub, the module periodically relocates
	them to a random farmable creature spawn in that same phase
- the automated farm pool is restricted to the lighter non-elite village mobs,
	not the stronger elite 80+ combat packs

Useful options:

- `GuildVillage.PlayerbotVillage.Enable`
- `GuildVillage.PlayerbotVillage.TickSeconds`
- `GuildVillage.PlayerbotVillage.IntervalMinMinutes`
- `GuildVillage.PlayerbotVillage.IntervalMaxMinutes`
- `GuildVillage.PlayerbotVillage.StayMinMinutes`
- `GuildVillage.PlayerbotVillage.StayMaxMinutes`
- `GuildVillage.PlayerbotVillage.FarmKickSeconds`
- `GuildVillage.PlayerbotVillage.Debug`

### 3. Prepare the village schema

By default the module expects an existing `customs` schema and does **not** auto-create it unless:

- `GuildVillage.Database.AutoCreate = 1`

For the customs updater to work, the database user from `WorldDatabaseInfo` must have access to the configured schema.

Example for the default schema name:

```sql
GRANT CREATE ON *.* TO 'acore'@'127.0.0.1';
CREATE DATABASE customs CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON customs.* TO 'acore'@'127.0.0.1';
FLUSH PRIVILEGES;
```

If you use a different schema name, change `GuildVillage.Database.Name` and grant access to that schema instead.

### 4. SQL layout

The module ships SQL in these locations:

- `data/sql/world/base/`
- `data/sql/world/updates/`
- `data/sql/customs/base/`
- `data/sql/customs/updates/`

If you installed an older pre-enhanced copy, also review:

- `data/sql/customs/archive/updates/014_important_update.sql`

That legacy migration is important for older installs that need the updater tracking table path brought forward before relying on current automatic updates.

## Logging and diagnostics

The enhanced version writes to its own file log:

- `env/dist/logs/GuildVillage.log`

Default config:

```ini
Appender.GuildVillage = 2,5,7,GuildVillage.log,a
Logger.guildvillage = 4,GuildVillage
```

Useful categories include:

- `guildvillage.purchase`
- `guildvillage.upgrade`
- `guildvillage.teleport`
- `guildvillage.command`
- `guildvillage.gm`
- `guildvillage.cleanup`
- `guildvillage.trigger`
- `guildvillage.customs`

Recommended troubleshooting levels:

- `4` = info/default
- `5` = debug
- `6` = trace

When debugging purchase or restart issues, review the log for:

- purchase acceptance/denial
- cleanup triggers
- teleports and village phase activity
- customs/bootstrap updater messages

## Reserved world IDs

The module uses fixed entries in these tables:

- `gameobject_template`
- `creature_template`
- `creature_template_model`
- `game_graveyard`
- `graveyard_zone`
- `fishing_loot_template`
- `points_of_interest`

Make sure these ranges are free in `acore_world`:

- Gameobjects: `990203`, `990204`
- Creatures: `987400`–`987430`, `987440`–`987454`
- Points of interest: `1200`–`1250`
- Graveyard entry: `2000`

The village steward / purchase NPC entry is:

- `987454`

Manual spawn example:

```text
.npc add 987454
```

If any required IDs are already in use on your server, move the module to a free range in both SQL and source before deployment.

## Operational notes

- The module now resolves village schema tables using the configured schema name rather than relying on hardcoded visible `customs.` references in live runtime queries.
- `gv_creature_template` and `gv_gameobject_template` can define layout content that is installed when a guild village is created.
- The customs updater keeps its own tracking table via `gv_updates` inside the configured schema.
- Cleanup features can remove villages for guild masters who remain offline past the configured threshold, so set `GuildVillage.Inactivity.CleanupDays` carefully.

## Compatibility

This module is commonly used in Playerbot-oriented environments and contains playerbot-specific village visit configuration.

Before production rollout, verify behavior against your exact stack, especially if you use:

- AzerothCore Playerbot branches
- `mod-playerbots`
- custom world ID ranges
- existing `customs`-style schemas shared with other modules

For Playerbot-heavy servers, test at least these village cases after updates:

- bots entering and leaving map `37` on schedule
- bots receiving the correct guild phase inside the village
- bots farming only the intended non-elite village creature pool
- bots returning safely after the configured stay window

## Recommended extras

- Addon: [Guild Village Helper (3.3.5a)](https://github.com/BeardBear33/Guild-Village-Helper-3.3.5a)
- Client map patch: [Worldmap fix-mod guild village](https://github.com/BeardBear33/Worldmap_fix-mod-guild-village)

## Additional references

- Module overview: [`README.md`](README.md)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Legacy pointer: [`README_CS.md`](README_CS.md)
