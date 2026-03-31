// modules/mod-guild-village/src/guild_village_bot.cpp

#include "ScriptMgr.h"
#include "Config.h"
#include "Player.h"
#include "Guild.h"
#include "DatabaseEnv.h"
#include "gv_common.h"
#include "Chat.h"
#include "StringFormat.h"
#include "Log.h"
#include "GameTime.h"

#if __has_include("../../mod-playerbots/src/Script/Playerbots.h")
#include "../../mod-playerbots/src/Script/Playerbots.h"
#define GV_HAS_PLAYERBOTS 1
#else
#define GV_HAS_PLAYERBOTS 0
#endif

#include <algorithm>
#include <optional>
#include <cstdint>

namespace GuildVillage
{
    // ------- Konfig: mapa vesnice a "bezpečné" fallback lokace -------
    static inline uint32 DefMap()
    {
        return sConfigMgr->GetOption<uint32>("GuildVillage.Default.Map", 37);
    }

    struct SafeLoc { uint32 map; float x, y, z, o; };

    static SafeLoc SafeAlliance()
    {
        SafeLoc d;
        d.map = sConfigMgr->GetOption<uint32>("GuildVillage.Safe.Alliance.Map", 0);         // Eastern Kingdoms
        d.x   = sConfigMgr->GetOption<float>("GuildVillage.Safe.Alliance.X", -8833.38f);    // Stormwind
        d.y   = sConfigMgr->GetOption<float>("GuildVillage.Safe.Alliance.Y",   628.62f);
        d.z   = sConfigMgr->GetOption<float>("GuildVillage.Safe.Alliance.Z",    94.00f);
        d.o   = sConfigMgr->GetOption<float>("GuildVillage.Safe.Alliance.O",     1.06f);
        return d;
    }

    static SafeLoc SafeHorde()
    {
        SafeLoc d;
        d.map = sConfigMgr->GetOption<uint32>("GuildVillage.Safe.Horde.Map", 1);            // Kalimdor
        d.x   = sConfigMgr->GetOption<float>("GuildVillage.Safe.Horde.X",   1629.85f);      // Orgrimmar
        d.y   = sConfigMgr->GetOption<float>("GuildVillage.Safe.Horde.Y",  -4373.64f);
        d.z   = sConfigMgr->GetOption<float>("GuildVillage.Safe.Horde.Z",    31.55f);
        d.o   = sConfigMgr->GetOption<float>("GuildVillage.Safe.Horde.O",     3.69f);
        return d;
    }

    // ------- Helpery -------
    static inline bool IsGMBypass(Player* p) { return p && p->IsGameMaster(); }
    static inline bool IsInVillageMap(Player* p) { return p && p->GetMapId() == DefMap(); }

    static inline bool BotVillageRoutingEnabled()
    {
        return sConfigMgr->GetOption<bool>(
            "GuildVillage.PlayerbotVillage.Enable", true);
    }

    static inline bool BotVillageDebug()
    {
        return sConfigMgr->GetOption<bool>(
            "GuildVillage.PlayerbotVillage.Debug", false);
    }

    static inline uint32 BotVillageTickSeconds()
    {
        return std::max<uint32>(
            sConfigMgr->GetOption<uint32>(
                "GuildVillage.PlayerbotVillage.TickSeconds", 30),
            5);
    }

    static inline uint32 BotVillageIntervalMinMinutes()
    {
        return sConfigMgr->GetOption<uint32>(
            "GuildVillage.PlayerbotVillage.IntervalMinMinutes", 30);
    }

    static inline uint32 BotVillageIntervalMaxMinutes()
    {
        return std::max<uint32>(
            BotVillageIntervalMinMinutes(),
            sConfigMgr->GetOption<uint32>(
                "GuildVillage.PlayerbotVillage.IntervalMaxMinutes", 60));
    }

    static inline uint32 BotVillageStayMinMinutes()
    {
        return sConfigMgr->GetOption<uint32>(
            "GuildVillage.PlayerbotVillage.StayMinMinutes", 10);
    }

    static inline uint32 BotVillageStayMaxMinutes()
    {
        return std::max<uint32>(
            BotVillageStayMinMinutes(),
            sConfigMgr->GetOption<uint32>(
                "GuildVillage.PlayerbotVillage.StayMaxMinutes", 20));
    }

    static inline uint32 BotVillageFarmKickSeconds()
    {
        return std::max<uint32>(
            sConfigMgr->GetOption<uint32>(
                "GuildVillage.PlayerbotVillage.FarmKickSeconds", 90),
            15);
    }

    static inline time_t Now()
    {
        return GameTime::GetGameTime().count();
    }

    static inline uint32 RandomMinutesInRange(uint32 minMinutes, uint32 maxMinutes)
    {
        return urand(minMinutes, maxMinutes);
    }

    struct VillageTeleportDest
    {
        uint32 map = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        float o = 0.0f;
        uint32 phaseMask = 0;
    };

    struct BotVillageVisitData : public DataMap::Base
    {
        time_t nextEvaluationAt = 0;
        time_t nextVillageVisitAt = 0;
        time_t villageVisitEndsAt = 0;
        time_t nextFarmKickAt = 0;
        bool villageVisitActive = false;
        bool hasReturnPoint = false;
        uint32 lastGuildId = 0;

        uint32 returnMap = 0;
        float returnX = 0.0f;
        float returnY = 0.0f;
        float returnZ = 0.0f;
        float returnO = 0.0f;
    };

    struct VillageFarmDest
    {
        uint32 entry = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        float o = 0.0f;
    };

    // Má hráč guildu, která má záznam v customs.gv_guild?
    static bool HasGuildVillage(Player* p)
    {
        if (!p) return false;
        Guild* g = p->GetGuild();
        if (!g) return false;

        if (QueryResult r = WorldDatabase.Query(
            "SELECT 1 FROM {} WHERE guild={}", Table("gv_guild"), g->GetId()))
            return true;
        return false;
    }

    static uint32 LoadGuildVillagePhase(Player* p)
    {
        if (!p || !p->GetGuild())
            return 0;

        if (QueryResult r = WorldDatabase.Query(
            "SELECT phase FROM {} WHERE guild={}",
            Table("gv_guild"), p->GetGuildId()))
            return (*r)[0].Get<uint32>();

        return 0;
    }

    static bool LoadPersonalVillageTp(Player* player, VillageTeleportDest& dest)
    {
        if (!player || !player->GetGuild())
            return false;

        if (QueryResult res = WorldDatabase.Query(
            "SELECT map, positionx, positiony, positionz, orientation, phase "
            "FROM {} WHERE player={} AND guild={} LIMIT 1",
            Table("gv_teleport_player"), player->GetGUID().GetCounter(), player->GetGuildId()))
        {
            Field* f = res->Fetch();
            dest.map = f[0].Get<uint32>();
            dest.x = f[1].Get<float>();
            dest.y = f[2].Get<float>();
            dest.z = f[3].Get<float>();
            dest.o = f[4].Get<float>();
            dest.phaseMask = f[5].Get<uint32>();
            return dest.map == DefMap() && dest.phaseMask != 0;
        }

        return false;
    }

    static bool LoadVillageDestination(Player* player, VillageTeleportDest& dest)
    {
        if (!player || !player->GetGuild())
            return false;

        if (LoadPersonalVillageTp(player, dest))
            return true;

        dest.map = DefMap();
        dest.x = sConfigMgr->GetOption<float>(
            "GuildVillage.Default.X", 1026.7292f);
        dest.y = sConfigMgr->GetOption<float>(
            "GuildVillage.Default.Y", 289.9494f);
        dest.z = sConfigMgr->GetOption<float>(
            "GuildVillage.Default.Z", 332.66083f);
        dest.o = sConfigMgr->GetOption<float>(
            "GuildVillage.Default.O", 3.4305837f);
        dest.phaseMask = LoadGuildVillagePhase(player);

        return dest.phaseMask != 0;
    }

    static void TeleportToSafeCity(Player* p)
    {
        if (!p) return;
        SafeLoc loc = (p->GetTeamId() == TEAM_ALLIANCE) ? SafeAlliance() : SafeHorde();
        p->TeleportTo(loc.map, loc.x, loc.y, loc.z, loc.o);
    }

    static void ScheduleNextVillageVisit(BotVillageVisitData* state, time_t now)
    {
        if (!state)
            return;

        state->nextVillageVisitAt = now + static_cast<time_t>(
            RandomMinutesInRange(
                BotVillageIntervalMinMinutes(),
                BotVillageIntervalMaxMinutes()) * MINUTE);
    }

    static void ScheduleVillageStay(BotVillageVisitData* state, time_t now)
    {
        if (!state)
            return;

        state->villageVisitEndsAt = now + static_cast<time_t>(
            RandomMinutesInRange(
                BotVillageStayMinMinutes(),
                BotVillageStayMaxMinutes()) * MINUTE);
    }

    static void ResetBotVillageVisit(
        BotVillageVisitData* state, time_t now, uint32 guildId = 0)
    {
        if (!state)
            return;

        state->villageVisitActive = false;
        state->villageVisitEndsAt = 0;
        state->nextFarmKickAt = 0;
        state->hasReturnPoint = false;
        state->lastGuildId = guildId;
        ScheduleNextVillageVisit(state, now);
    }

    static void SaveVillageReturnPoint(Player* player, BotVillageVisitData* state)
    {
        if (!player || !state)
            return;

        state->hasReturnPoint = true;
        state->returnMap = player->GetMapId();
        state->returnX = player->GetPositionX();
        state->returnY = player->GetPositionY();
        state->returnZ = player->GetPositionZ();
        state->returnO = player->GetOrientation();
    }

    static void ClearVillagePhase(Player* player)
    {
        if (!player)
            return;

        player->CustomData.GetDefault<GVPhaseData>("gv_phase")->phaseMask = 0;
    }

    static bool TeleportToVillage(Player* player, VillageTeleportDest const& dest)
    {
        if (!player || !dest.phaseMask)
            return false;

        player->CustomData.GetDefault<GVPhaseData>("gv_phase")->phaseMask =
            dest.phaseMask;
        player->SetPhaseMask(dest.phaseMask, true);
        return player->TeleportTo(dest.map, dest.x, dest.y, dest.z, dest.o);
    }

    static bool TeleportOutOfVillage(Player* player, BotVillageVisitData* state)
    {
        if (!player)
            return false;

        ClearVillagePhase(player);

        if (state && state->hasReturnPoint && state->returnMap != DefMap())
        {
            return player->TeleportTo(
                state->returnMap,
                state->returnX,
                state->returnY,
                state->returnZ,
                state->returnO);
        }

        TeleportToSafeCity(player);
        return true;
    }

    static bool IsBotVillageBlocked(Player* player)
    {
        if (!player)
            return true;

        if (!player->IsAlive() || player->IsInCombat() ||
            player->IsBeingTeleported() || player->InBattleground() ||
            player->InArena())
            return true;

        if (Map* map = player->GetMap())
            if (map->IsDungeon())
                return true;

        return false;
    }

    static bool LoadRandomVillageFarmDestination(
        Player* player, VillageFarmDest& dest)
    {
        if (!player)
            return false;

        uint32 phaseMask = player->GetPhaseMask();
        if (!IsUsableVillagePhaseMask(phaseMask))
            phaseMask = LoadGuildVillagePhase(player);

        if (!IsUsableVillagePhaseMask(phaseMask))
            return false;

        // Keep playerbots on the lighter village wildlife/resource packs.
        // The 987402-987410 set contains the stronger elite camp mobs and is
        // too punishing for solo village visits.
        static char const* farmEntriesSql =
            "987412,987413,987414,987415,987416,987418,987419,987420,"
            "987421";

        if (QueryResult res = WorldDatabase.Query(
            "SELECT id1, position_x, position_y, position_z, orientation "
            "FROM creature WHERE map={} AND phaseMask={} AND id1 IN ({}) "
            "ORDER BY RAND() LIMIT 1",
            DefMap(), phaseMask, farmEntriesSql))
        {
            Field* fields = res->Fetch();
            dest.entry = fields[0].Get<uint32>();
            dest.x = fields[1].Get<float>();
            dest.y = fields[2].Get<float>();
            dest.z = fields[3].Get<float>();
            dest.o = fields[4].Get<float>();
            return true;
        }

        return false;
    }

#if GV_HAS_PLAYERBOTS
    static bool IsPlayerbot(Player* player)
    {
        return player && GET_PLAYERBOT_AI(player);
    }

    static void TriggerVillageRpg(Player* player);

    static void LogBotVillageEvent(
        Player* player, char const* action, time_t when)
    {
        if (!BotVillageDebug() || !player)
            return;

        LOG_INFO(
            "modules",
            "GV: Playerbot {} {} (guildId={}, active={}, nextVisitAt={}, visitEndsAt={})",
            player->GetName(), action, player->GetGuildId(),
            player->CustomData.GetDefault<BotVillageVisitData>("gv_bot_village")
                ->villageVisitActive,
            player->CustomData.GetDefault<BotVillageVisitData>("gv_bot_village")
                ->nextVillageVisitAt,
            player->CustomData.GetDefault<BotVillageVisitData>("gv_bot_village")
                ->villageVisitEndsAt);
        (void)when;
    }

    static void TriggerVillageFarmKick(
        Player* player, BotVillageVisitData* state, bool force = false)
    {
        if (!player || !state)
            return;

        time_t now = Now();
        if (!force && state->nextFarmKickAt && now < state->nextFarmKickAt)
            return;

        state->nextFarmKickAt = now + BotVillageFarmKickSeconds();

        PlayerbotAI* botAI = GET_PLAYERBOT_AI(player);
        if (!botAI || !IsInVillageMap(player) || IsBotVillageBlocked(player))
            return;

        VillageFarmDest dest;
        if (!LoadRandomVillageFarmDestination(player, dest))
            return;

        if (!player->TeleportTo(DefMap(), dest.x, dest.y, dest.z, dest.o))
            return;

        botAI->DoSpecificAction("attack anything", Event(), true);
        TriggerVillageRpg(player);

        if (BotVillageDebug())
        {
            LOG_INFO(
                "modules",
                "GV: Playerbot {} farm kick -> mob {} at map {} ({}, {}, {})",
                player->GetName(), dest.entry, DefMap(), dest.x, dest.y,
                dest.z);
        }
    }

    static void TriggerVillageRpg(Player* player)
    {
        PlayerbotAI* botAI = GET_PLAYERBOT_AI(player);
        if (!botAI)
            return;

        if (botAI->HasStrategy("new rpg", BOT_STATE_NON_COMBAT))
            botAI->DoSpecificAction("new rpg go grind", Event(), true);

        if (botAI->HasStrategy("rpg", BOT_STATE_NON_COMBAT))
            botAI->DoSpecificAction("rpg", Event(), true);
    }

    static void HandlePlayerbotVillageRouting(Player* player)
    {
        if (!GV_HAS_PLAYERBOTS || !BotVillageRoutingEnabled() || !player ||
            IsGMBypass(player) || !IsPlayerbot(player))
            return;

        BotVillageVisitData* state =
            player->CustomData.GetDefault<BotVillageVisitData>(
                "gv_bot_village");
        time_t now = Now();

        if (state->nextEvaluationAt && now < state->nextEvaluationAt)
            return;

        state->nextEvaluationAt = now + BotVillageTickSeconds();

        Guild* guild = player->GetGuild();
        uint32 guildId = guild ? guild->GetId() : 0;
        bool hasVillage = HasGuildVillage(player);

        if (!guildId || !hasVillage)
        {
            if (state->villageVisitActive)
                ResetBotVillageVisit(state, now, guildId);
            else if (!state->nextVillageVisitAt)
                ScheduleNextVillageVisit(state, now);
            return;
        }

        if (state->lastGuildId != guildId)
            ResetBotVillageVisit(state, now, guildId);

        if (state->villageVisitActive)
        {
            if (!IsInVillageMap(player))
            {
                ResetBotVillageVisit(state, now, guildId);
                LogBotVillageEvent(player, "left village early", now);
                return;
            }

            if (state->villageVisitEndsAt && now >= state->villageVisitEndsAt &&
                !IsBotVillageBlocked(player))
            {
                if (TeleportOutOfVillage(player, state))
                {
                    ResetBotVillageVisit(state, now, guildId);
                    LogBotVillageEvent(player, "returned from village", now);
                }
            }

            if (!IsBotVillageBlocked(player))
                TriggerVillageFarmKick(player, state);

            return;
        }

        if (IsInVillageMap(player))
        {
            ScheduleNextVillageVisit(state, now);
            return;
        }

        if (!state->nextVillageVisitAt)
            ScheduleNextVillageVisit(state, now);

        if (now < state->nextVillageVisitAt || IsBotVillageBlocked(player))
            return;

        VillageTeleportDest dest;
        if (!LoadVillageDestination(player, dest))
        {
            ScheduleNextVillageVisit(state, now);
            return;
        }

        SaveVillageReturnPoint(player, state);

        if (!TeleportToVillage(player, dest))
        {
            state->hasReturnPoint = false;
            ScheduleNextVillageVisit(state, now);
            return;
        }

        state->villageVisitActive = true;
        state->lastGuildId = guildId;
        ScheduleVillageStay(state, now);
        state->nextFarmKickAt = 0;
        TriggerVillageRpg(player);
        TriggerVillageFarmKick(player, state, true);
        LogBotVillageEvent(player, "entered village", now);
    }
#endif

    static void Enforce(Player* p)
    {
        if (!p || IsGMBypass(p))
            return;

        // Cizinec (nebo hráč bez guildy) nemá co dělat v mapě vesnice
        if (IsInVillageMap(p) && !HasGuildVillage(p))
        {
            if (BotVillageRoutingEnabled())
                ResetBotVillageVisit(
                    p->CustomData.GetDefault<BotVillageVisitData>(
                        "gv_bot_village"),
                    Now());
            TeleportToSafeCity(p);
        }
    }

    class guild_village_BotGuard : public PlayerScript
    {
    public:
        guild_village_BotGuard() : PlayerScript("guild_village_BotGuard") { }

        // Před jakýmkoli teleportem – bloknout cílovou vesnici cizincům
        [[nodiscard]] bool OnPlayerBeforeTeleport(Player* player, uint32 mapId, float /*x*/, float /*y*/, float /*z*/, float /*orientation*/, uint32 /*options*/, Unit* /*target*/) override
        {
            if (!player || IsGMBypass(player))
                return true;

            if (mapId == DefMap() && !HasGuildVillage(player))
            {
                TeleportToSafeCity(player);
                return false; // zrušit původní teleport do vesnice
            }
            return true;
        }

		void OnPlayerLogin(Player* player) override
		{
			if (!player || IsGMBypass(player)) return;
			Enforce(player); // pokud se probudil rovnou ve vesnici a není „oprávněný“, poslat pryč
		}
		
		void OnPlayerMapChanged(Player* player) override
		{
			if (!player || IsGMBypass(player)) return;
			Enforce(player); // po jakémkoli teleportu na jinou mapu
		}
		
		void OnPlayerUpdateZone(Player* player, uint32 /*newZone*/, uint32 /*newArea*/) override
		{
			if (!player || IsGMBypass(player)) return;
			Enforce(player); // přesun v rámci mapy mezi zónami
		}

        void OnPlayerUpdate(Player* player, uint32 /*p_time*/) override
        {
            if (!player || IsGMBypass(player)) return;
            Enforce(player);
#if GV_HAS_PLAYERBOTS
            HandlePlayerbotVillageRouting(player);
#endif
        }
    };
} // namespace GuildVillage

// ------- Registrace pro loader.cpp -------
void RegisterGuildVillageBot()
{
    new GuildVillage::guild_village_BotGuard();
}
