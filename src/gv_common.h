#pragma once

#include "Config.h"
#include "DataMap.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "StringFormat.h"

#include <algorithm>
#include <cctype>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_set>
#include <utility>

namespace GuildVillage
{
    namespace LogCategory
    {
        inline constexpr char const* Root = "guildvillage";
        inline constexpr char const* Purchase = "guildvillage.purchase";
        inline constexpr char const* Action = "guildvillage.action";
        inline constexpr char const* Trigger = "guildvillage.trigger";
        inline constexpr char const* Cleanup = "guildvillage.cleanup";
        inline constexpr char const* Command = "guildvillage.command";
        inline constexpr char const* Teleport = "guildvillage.teleport";
        inline constexpr char const* Upgrade = "guildvillage.upgrade";
        inline constexpr char const* GM = "guildvillage.gm";
        inline constexpr char const* Customs = "guildvillage.customs";
    }

    struct GVPhaseData : public DataMap::Base
    {
        uint32 phaseMask = 0;
    };

    inline bool IsSingleBitPhaseMask(uint32 phaseMask)
    {
        return phaseMask && !(phaseMask & (phaseMask - 1));
    }

    inline bool IsUsableVillagePhaseMask(uint32 phaseMask)
    {
        return IsSingleBitPhaseMask(phaseMask) && phaseMask != 1;
    }

    inline uint32 GuildVillagePhaseCapacity()
    {
        return 31;
    }

    inline std::optional<uint32> FindFreeVillagePhaseMask(std::unordered_set<uint32> const& usedMasks)
    {
        for (uint32 bit = 1; bit < 32; ++bit)
        {
            uint32 phaseMask = uint32(1) << bit;
            if (usedMasks.find(phaseMask) == usedMasks.end())
                return phaseMask;
        }

        return std::nullopt;
    }

    inline std::string DatabaseName()
    {
        std::string databaseName =
            sConfigMgr->GetOption<std::string>("GuildVillage.Database.Name", "customs");

        databaseName.erase(
            std::remove_if(databaseName.begin(), databaseName.end(),
                [](unsigned char ch) { return std::isspace(ch); }),
            databaseName.end());

        if (databaseName.empty())
            return "customs";

        return databaseName;
    }

    inline bool AutoCreateDatabase()
    {
        return sConfigMgr->GetOption<bool>("GuildVillage.Database.AutoCreate", false);
    }

    inline std::string QuoteIdentifier(std::string const& identifier)
    {
        std::string quoted;
        quoted.reserve(identifier.size() + 2);
        quoted.push_back('`');

        for (char ch : identifier)
        {
            if (ch == '`')
                quoted.push_back('`');

            quoted.push_back(ch);
        }

        quoted.push_back('`');
        return quoted;
    }

    inline std::string QuotedDatabaseName()
    {
        return QuoteIdentifier(DatabaseName());
    }

    inline std::string Table(std::string_view tableName)
    {
        return QuotedDatabaseName() + "." + QuoteIdentifier(std::string(tableName));
    }

}
