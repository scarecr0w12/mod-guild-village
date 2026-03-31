// modules/mod-guild-village/src/boss/boss_thalor_the_lifebinder.cpp

#include "CreatureScript.h"
#include "Player.h"
#include "ScriptedCreature.h"
#include "SpellScript.h"
#include "Config.h"
#include "ObjectAccessor.h"
#include "GossipDef.h"
#include "SpellAuraEffects.h"
#include <algorithm>
#include <vector>
#include <chrono>
#include <limits>

// -------- Lokalizace (cs/en) --------
namespace GuildVillageLoc
{
    enum class Lang { CS, EN };

    static inline Lang LangOpt()
    {
        return Lang::EN;
    }

    static inline char const* T(char const* cs, char const* en)
    {
        return (LangOpt() == Lang::EN) ? en : cs;
    }
}

// -------- Přepínač obtížnosti --------
static inline bool ThalorHeroic()
{
    return sConfigMgr->GetOption<bool>("GuildVillage.Thalor.Heroic", false);
}

enum ThalorSpells : uint32
{
    SPELL_BERSERK           = 62555,
    SPELL_ENTANGLING_ROOTS  = 20699,
    SPELL_JUDGEMENT_WRATH   = 46033,
    SPELL_NATURE_BOMB       = 64587,
    SPELL_VENOM_BOLT        = 59839,
    SPELL_LIFEBLOOM_H       = 67959,
    SPELL_STORM_WAVE_H      = 63533 
};

enum ThalorEvents : uint32
{
    EVENT_ROOTS = 1,
    EVENT_WRATH,
    EVENT_NATURE_BOMB,
    EVENT_STORM_WAVE,
    EVENT_VENOM_TICK,
    EVENT_BERSERK
};

// --- Časy a parametry ---
static constexpr uint32 ROOTS_FIRST_MS        = 10000; // 10s po pullu
static constexpr uint32 WRATH_AFTER_ROOTS_MS  = 15000; // +15s od zapnutí Roots
static constexpr uint32 BOMB_AFTER_WRATH_MS   = 10000; // +10s od zapnutí Wrath
static constexpr uint32 ROOTS_AFTER_BOMB_MS   = 10000; // +10s po Nature Bomb (loop – Normal)

static constexpr uint32 STORM_AFTER_BOMB_MS   = 20000; // HEROIC: +20s po Nature Bomb

static constexpr uint32 VENOM_CAST_MS         = 1410;  // ~1.41s cast
static constexpr uint32 VENOM_TICK_MS         = 1000;  // zkusit cca každou 1s
static constexpr uint32 VENOM_SAFETY_BUFFER   = 300;   // rezerva, aby nepřetékalo do fáze

static constexpr float  MELEE_PICK_RANGE      = 5.0f;  // pro výběr 4 melee targetů
static constexpr float  ROOTS_RADIUS          = 30.0f; // dosah Roots
static constexpr float  MAX_LOS_RANGE         = 70.0f;
static constexpr float  STORM_MIN_DIST        = 9.0f;  // vzdálený cíl pro druhou vlnu

static constexpr uint32 TIMER_INF             = std::numeric_limits<uint32>::max();

struct boss_thalor_the_lifebinder : public ScriptedAI
{
    boss_thalor_the_lifebinder(Creature* c) : ScriptedAI(c) { }

    EventMap events;

    uint32 tRootsMs  = TIMER_INF;
    uint32 tWrathMs  = TIMER_INF;
    uint32 tBombMs   = TIMER_INF;
    uint32 tStormMs  = TIMER_INF;
	uint32 venomLockMs = 0;

    // -------- Hlášky --------
    void YellAggro()
    {
        me->Yell(GuildVillageLoc::T(
            "Kořeny se probouzí... Nechte se pohltit zelení!",
            "Roots awaken... Be swallowed by verdure!"
        ), LANG_UNIVERSAL, nullptr);
    }

    void YellRoots()
    {
        me->Yell(GuildVillageLoc::T(
            "Půda vás spoutá trním!",
            "The soil binds you in thorns!"
        ), LANG_UNIVERSAL, nullptr);
    }

    void YellWrath()
    {
        me->Yell(GuildVillageLoc::T(
            "Hněv přírody skosí vaše kroky!",
            "Nature’s wrath severs your stride!"
        ), LANG_UNIVERSAL, nullptr);
    }

    void YellBomb()
    {
        me->Yell(GuildVillageLoc::T(
            "Živoucí výboj vás očistí... nebo zlomí!",
            "A living surge will cleanse... or break you!"
        ), LANG_UNIVERSAL, nullptr);
    }
	
	void YellStormWave()
    {
        me->Yell(GuildVillageLoc::T(
            "Vlna života vás smete!",
            "A surge of life will sweep you away!"
        ), LANG_UNIVERSAL, nullptr);
    }

    void YellBerserk()
    {
        me->Yell(GuildVillageLoc::T(
            "Míza plane! Les řve!",
            "Sap ignites! The forest roars!"
        ), LANG_UNIVERSAL, nullptr);
    }

    void YellDeath()
    {
        me->Yell(GuildVillageLoc::T(
            "Listy... tiší šum...",
            "Leaves... grow still..."
        ), LANG_UNIVERSAL, nullptr);
    }

    // -------- Utility: sběr hráčů --------
    void CollectPlayers(std::vector<Player*>& out, float radius = MAX_LOS_RANGE)
    {
        out.clear();
        Map* currentMap = me->GetMap();
        if (currentMap)
        {
            for (auto const& playerRef : currentMap->GetPlayers())
            {
                Player* player = playerRef.GetSource();
                if (player)
                {
                    if (!player->IsAlive())
                        continue;
                    if (!me->IsWithinDistInMap(player, radius))
                        continue;
                    if (!me->IsWithinLOSInMap(player))
                        continue;
                    out.push_back(player);
                }
            }
        }
    }

    Player* RandomPlayer(float radius = MAX_LOS_RANGE)
    {
        std::vector<Player*> players;
        CollectPlayers(players, radius);
        if (players.empty())
            return nullptr;
        uint32 playerIndex = urand(0u, (uint32)players.size() - 1u);
        return players[playerIndex];
    }

    void PickUpToFourMelee(std::vector<Player*>& out)
    {
        out.clear();
        std::vector<Player*> meleeCandidates;
        CollectPlayers(meleeCandidates, MELEE_PICK_RANGE + 1.0f);

        std::sort(meleeCandidates.begin(), meleeCandidates.end(), [this](Player* leftPlayer, Player* rightPlayer)
        {
            return me->GetDistance(leftPlayer) < me->GetDistance(rightPlayer);
        });

        for (Player* meleePlayer : meleeCandidates)
        {
            if (me->GetDistance(meleePlayer) <= MELEE_PICK_RANGE)
                out.push_back(meleePlayer);
            if (out.size() >= 4)
                break;
        }
    }

    Player* PickDistantTarget(float minDist = STORM_MIN_DIST, float maxDist = MAX_LOS_RANGE)
    {
        std::vector<Player*> distantCandidates;
        CollectPlayers(distantCandidates, maxDist);
        std::vector<Player*> distantPlayers;
        for (Player* player : distantCandidates)
        {
            if (me->GetDistance(player) >= minDist)
                distantPlayers.push_back(player);
        }
        if (distantPlayers.empty())
            return nullptr;
        uint32 targetIndex = urand(0u, (uint32)distantPlayers.size() - 1u);
        return distantPlayers[targetIndex];
    }

    void MaybeApplyLifebloomHeroic()
    {
        if (!ThalorHeroic())
            return;

        Aura* lifebloomAura = me->GetAura(SPELL_LIFEBLOOM_H);
        if (lifebloomAura)
        {
            uint8 currentStacks = lifebloomAura->GetStackAmount();
            if (currentStacks < 3)
                lifebloomAura->SetStackAmount(currentStacks + 1);
            lifebloomAura->SetDuration(6000);
            lifebloomAura->SetMaxDuration(6000);
        }
        else
        {
            me->AddAura(SPELL_LIFEBLOOM_H, me);
            Aura* appliedLifebloomAura = me->GetAura(SPELL_LIFEBLOOM_H);
            if (appliedLifebloomAura)
            {
                appliedLifebloomAura->SetDuration(6000);
                appliedLifebloomAura->SetMaxDuration(6000);
                appliedLifebloomAura->SetStackAmount(1);
            }
        }
    }

    void Reset() override
    {
        events.Reset();
        me->RemoveAllAuras();
        me->SetReactState(REACT_AGGRESSIVE);
		venomLockMs = 0;

        tRootsMs = tWrathMs = tBombMs = tStormMs = TIMER_INF;
    }

    void JustReachedHome() override
    {
        me->setActive(false);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        me->setActive(true);
        me->CallForHelp(175.0f);
        YellAggro();

        events.ScheduleEvent(EVENT_ROOTS, std::chrono::milliseconds(ROOTS_FIRST_MS));
        tRootsMs = ROOTS_FIRST_MS;

        events.ScheduleEvent(EVENT_VENOM_TICK, std::chrono::milliseconds(VENOM_TICK_MS));

        events.ScheduleEvent(EVENT_BERSERK, std::chrono::minutes(5));
    }

    void JustDied(Unit* /*killer*/) override
    {
        YellDeath();
    }

    // -------- Jednotlivé akce --------
    void DoEntanglingRoots()
    {
        YellRoots();
        me->CastSpell(me, SPELL_ENTANGLING_ROOTS, true);

        MaybeApplyLifebloomHeroic();
    }

    void DoJudgementOfWrath()
    {
        YellWrath();

        std::vector<Player*> targets;
        PickUpToFourMelee(targets);

        if (targets.empty())
        {
            Unit* currentVictim = me->GetVictim();
            if (currentVictim)
                if (me->GetDistance(currentVictim) <= MELEE_PICK_RANGE + 1.0f)
                    me->CastSpell(currentVictim, SPELL_JUDGEMENT_WRATH, false);
        }
        else
        {
            for (Player* targetPlayer : targets)
                me->CastSpell(targetPlayer, SPELL_JUDGEMENT_WRATH, false);
        }

        MaybeApplyLifebloomHeroic();
    }

    void DoNatureBomb()
    {
        YellBomb();
        me->CastSpell(me, SPELL_NATURE_BOMB, true);

        MaybeApplyLifebloomHeroic();
    }

    void DoStormWaveHeroic()
    {
        if (!ThalorHeroic())
            return;
		
		YellStormWave();

        me->CastSpell(me, SPELL_STORM_WAVE_H, true);

        Player* distantTarget = PickDistantTarget(STORM_MIN_DIST, MAX_LOS_RANGE);
        if (distantTarget)
            me->CastSpell(distantTarget, SPELL_STORM_WAVE_H, false);
        else
            me->CastSpell(me, SPELL_STORM_WAVE_H, true);
    }

    void TryCastVenomBolt()
    {
        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        uint32 nextMajor = std::min(std::min(tRootsMs, tWrathMs), std::min(tBombMs, tStormMs));

        if (nextMajor <= (VENOM_CAST_MS + VENOM_SAFETY_BUFFER))
            return;

        Player* venomTarget = RandomPlayer(MAX_LOS_RANGE);
        if (venomTarget)
        {
            venomLockMs = VENOM_CAST_MS + 1000;
            me->CastSpell(venomTarget, SPELL_VENOM_BOLT, false);
        }
    }

    static void DecTimer(uint32& timer, uint32 diff)
    {
        if (timer == TIMER_INF)
            return;

        if (diff >= timer)
            timer = 0;
        else
            timer -= diff;
    }

    // -------- Update --------
    void UpdateAI(uint32 diff) override
    {
        if (!UpdateVictim())
            return;

        DecTimer(tRootsMs, diff);
        DecTimer(tWrathMs, diff);
        DecTimer(tBombMs, diff);
        DecTimer(tStormMs, diff);
        DecTimer(venomLockMs, diff);

        events.Update(diff);

        uint32 ev;
        while ((ev = events.ExecuteEvent()))
        {
            switch (ev)
            {
                case EVENT_ROOTS:
                {
                    if (me->HasUnitState(UNIT_STATE_CASTING))
                    {
                        events.ScheduleEvent(EVENT_ROOTS, std::chrono::milliseconds(200));
                        tRootsMs = 200;
                        break;
                    }

                    DoEntanglingRoots();

                    events.ScheduleEvent(EVENT_WRATH, std::chrono::milliseconds(WRATH_AFTER_ROOTS_MS));
                    tRootsMs = TIMER_INF;
                    tWrathMs = WRATH_AFTER_ROOTS_MS;
                    break;
                }

                case EVENT_WRATH:
                {
                    if (me->HasUnitState(UNIT_STATE_CASTING))
                    {
                        events.ScheduleEvent(EVENT_WRATH, std::chrono::milliseconds(200));
                        tWrathMs = 200;
                        break;
                    }

                    DoJudgementOfWrath();

                    events.ScheduleEvent(EVENT_NATURE_BOMB, std::chrono::milliseconds(BOMB_AFTER_WRATH_MS));
                    tWrathMs = TIMER_INF;
                    tBombMs  = BOMB_AFTER_WRATH_MS;
                    break;
                }

                case EVENT_NATURE_BOMB:
                {
                    if (me->HasUnitState(UNIT_STATE_CASTING))
                    {
                        events.ScheduleEvent(EVENT_NATURE_BOMB, std::chrono::milliseconds(200));
                        tBombMs = 200;
                        break;
                    }

                    DoNatureBomb();

                    if (ThalorHeroic())
                    {
                        events.ScheduleEvent(EVENT_STORM_WAVE, std::chrono::milliseconds(STORM_AFTER_BOMB_MS));
                        tBombMs  = TIMER_INF;
                        tStormMs = STORM_AFTER_BOMB_MS;
                        tRootsMs = TIMER_INF;
                    }
                    else
                    {
                        events.ScheduleEvent(EVENT_ROOTS, std::chrono::milliseconds(ROOTS_AFTER_BOMB_MS));
                        tBombMs  = TIMER_INF;
                        tRootsMs = ROOTS_AFTER_BOMB_MS;
                    }
                    break;
                }

                case EVENT_STORM_WAVE:
                {
                    if (!ThalorHeroic())
                        break;

                    if (me->HasUnitState(UNIT_STATE_CASTING))
                    {
                        events.ScheduleEvent(EVENT_STORM_WAVE, std::chrono::milliseconds(200));
                        tStormMs = 200;
                        break;
                    }

                    DoStormWaveHeroic();

                    events.ScheduleEvent(EVENT_ROOTS, std::chrono::milliseconds(0));
                    tStormMs = TIMER_INF;
                    tRootsMs = 0;
                    break;
                }

				case EVENT_VENOM_TICK:
				{
					if (venomLockMs == 0)
						TryCastVenomBolt();
				
					events.ScheduleEvent(EVENT_VENOM_TICK, std::chrono::milliseconds(VENOM_TICK_MS));
					break;
				}

                case EVENT_BERSERK:
                {
                    YellBerserk();
                    me->CastSpell(me, SPELL_BERSERK, true);
                    break;
                }
            }
        }

        if (!me->HasUnitState(UNIT_STATE_CASTING))
            DoMeleeAttackIfReady();
    }
};

// ============================
// Registrace
// ============================
void RegisterGuildVillageThalor()
{
    RegisterCreatureAI(boss_thalor_the_lifebinder);
}
