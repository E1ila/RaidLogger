--
-- Created by IntelliJ IDEA.
-- User: kof
-- Date: 11/04/2019
-- Time: 18:36
--

local VERSION = 0.1
local MIN_RAID_PLAYERS = 10

local TRACKED_INSTANCES = {
    [1] = "The Molten Core",
    [2] = "Blackwing Lair",
    [3] = "Onyxia's Lair",
    [4] = "Zul'Gurub",
    [5] = "Ahn'Qiraj",
    [6] = "Ruins of Ahn'Qiraj",
    [7] = "Naxxramas",
    -- [8] = "Ragefire Chasm"
}

local IGNORED_ITEMS = {
    [1] = "Elementium Ore",
}

local LOOT_OTHER_RECEIVES = "(.+) receives loot: (.+)."
local LOOT_YOU_RECEIVE = "You receive loot: (.+)."

local LOOT_COLOR_UNCOMMON = "ff1eff00"
local LOOT_COLOR_COMMON = "ffffffff"
local LOOT_COLOR_RARE = "ff0070dd"
local LOOT_COLOR_EPIC = "ffa335ee"
local LOOT_COLOR_LEGENDARY = "ffff8000"

Store = {
    raids = {},
    activeRaid = nil,
    players = {},
}

local function print(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

local function tableTextLookup(table, text)
    for _, value in ipairs(table) do
        if value == text then
            return true
        end
    end
    return false
end

local function InTrackedInstance()
    if not IsInInstance() then return nil end
    local zone = GetZoneText()
    if tableTextLookup(TRACKED_INSTANCES, zone) then return zone end
    return nil
end

-- checks if a value exists in a list
local function HasValue(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

-- removes a value from a list, if exists
local function RemoveValue(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            table.remove(tab, index)
            return true
        end
    end
    return false
end

local function TitleCase(first, rest)
    return string.upper(first) .. string.lower(rest)
end

local function FixPlayerName(player)
    return string.gsub(player, "(%a)([%w_']*)", TitleCase)
end

local function EndRaidReminder()
    print("|cFFFF962F RaidLogger |cFFFF0000 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
    print("|cFFFF962F RaidLogger |cFFFF0000    DO NOT FORGET TO END THE RAID !")
    print("|cFFFF962F RaidLogger |cFFFF0000                /rl end")
    print("|cFFFF962F RaidLogger |cFFFF0000 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
end

function RaidLogger_OnLoad()
    this:RegisterEvent("ADDON_LOADED");
    this:RegisterEvent("RAID_ROSTER_UPDATE");
    this:RegisterEvent("GROUP_ROSTER_UPDATE");
    this:RegisterEvent("ENCOUNTER_END");
    this:RegisterEvent("RAID_INSTANCE_WELCOME");
    this:RegisterEvent("ZONE_CHANGED_NEW_AREA");
    this:RegisterEvent("CHAT_MSG_LOOT");

    SLASH_RaidLogger1 = "/rl"
    SlashCmdList["RaidLogger"] = RaidLogger_Main

    print("|cFFFF962F RaidLogger |rLogs raid attendance into a file. Write |cFF00FF00/rl help|r for a list of commands.")
end

function RaidLogger_OnEvent(event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "RaidLogger" then
            -- saved variables loaded
            if Store and Store.activeRaid then
                EndRaidReminder()
            end
        end
        return
    else
        -- print("|cFFFF962F RaidLogger |c44FFFFFF"..event.." event")
        if event == "RAID_INSTANCE_WELCOME" or event == "ZONE_CHANGED_NEW_AREA" then
            if InTrackedInstance() and GetNumRaidMembers() >= MIN_RAID_PLAYERS then
                RaidLogger_UpdateRaid()
            end
        elseif event == "CHAT_MSG_LOOT" then
            local zone = InTrackedInstance()
            if zone and Store.activeRaid then
                RaidLogger_ParseLootMessage(arg1, zone)
            end
        elseif event == "RAID_ROSTER_UPDATE" or event == "GROUP_ROSTER_UPDATE" or event == "ENCOUNTER_END" then
            if Store and Store.activeRaid then
                if GetNumRaidMembers() > 1 then
                    RaidLogger_UpdateRaid()
                else
                    EndRaidReminder();
                end
            end
        end
    end
end

local function GetItemType(color)
    if color == LOOT_COLOR_UNCOMMON then
        return 'Uncommon' -- green
    elseif color == LOOT_COLOR_COMMON then
        return 'Common' -- white
    elseif color == LOOT_COLOR_EPIC then
        return 'Epic' -- purple
    elseif color == LOOT_COLOR_LEGENDARY then
        return 'Legendary' -- orange
    elseif color == LOOT_COLOR_RARE then
        return 'Rare' -- blue
    end
end

local function LogLoot(who, loot, zone)
    local vStartIndex, vEndIndex, vLinkColor, vItemCode, vItemEnchantCode, vItemSubCode, vUnknownCode, vItemName = strfind(loot, "|c(%x+)|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[([^%]]+)%]|h|r");

    if who and vLinkColor == LOOT_COLOR_EPIC and not tableTextLookup(IGNORED_ITEMS, vItemName) then
        print("|cFFFF962F RaidLogger |rLogged loot: |cFF00FF00" .. who .. "|r received |cFF00FF00" .. loot .. "|r at |cFF00FF00" .. zone .. "|r")
        table.insert(Store.activeRaid.loot, {
            player = who,
            item = vItemName,
            datetime = date("%y-%m-%d %H:%M"),
            zone = zone,
            itemcode = vItemCode,
            itemtype = GetItemType(vLinkColor),
            de = 0,
            os = 0,
        })
        Store.activeRaid.lootCount = Store.activeRaid.lootCount + 1
    end
end

function RaidLogger_ParseLootMessage(msg, zone)
    for who, loot in string.gfind(msg, LOOT_OTHER_RECEIVES) do
        LogLoot(who, loot, zone)
    end
    for loot in string.gfind(msg, LOOT_YOU_RECEIVE) do
        LogLoot(UnitName("player"), loot, zone)
    end
end

function RaidLogger_Main(msg)
    local _, _, cmd, arg1 = string.find(string.upper(msg), "([%w]+)%s*(.*)$");
    -- print("|cFFFF962F RaidLogger |rcmd " .. cmd .. " / arg1 " .. arg1)
    if not cmd then
        RaidLogger_UpdateRaid()
    elseif  "H" == cmd or "HELP" == cmd then
        print("|cFFFF962F RaidLogger |rCommands: ")
        print("|cFFFF962F RaidLogger |r  |cFF00FF00/rl|r - update raid attendance")
        print("|cFFFF962F RaidLogger |r  |cFF00FF00/rl add <player>|r - manually log an attended player.")
        print("|cFFFF962F RaidLogger |r  |cFF00FF00/rl bench <player>|r - log a benched player.")
        print("|cFFFF962F RaidLogger |r  |cFF00FF00/rl de|r - marks last distributed loot item as disenchanted.")
        print("|cFFFF962F RaidLogger |r  |cFF00FF00/rl os|r - marks last distributed loot as an off-spec item.")
        print("|cFFFF962F RaidLogger |r  |cFF00FF00/rl discard|r - discard current raid, do this to ignore current raid.")
        print("|cFFFF962F RaidLogger |r  |cFF00FF00/rl end|r - save and close raid, do this when raid ended.")
    elseif  "BENCH" == cmd or "B" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLogger_Bench(FixPlayerName(arg1))
        else
            print("|cFFFF962F RaidLogger |cFFFF0000Missing player name!")
        end
    elseif  "ADD" == cmd or "A" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLogger_Attend(FixPlayerName(arg1), true)
        else
            print("|cFFFF962F RaidLogger |cFFFF0000Missing player name!")
        end
    elseif  "DE" == cmd then
        if not Store.activeRaid then
            print("|cFFFF962F RaidLogger |rNo active raid!")
        elseif Store.activeRaid.lootCount == 0 then
            print("|cFFFF962F RaidLogger |rNo loot logged!")
        else
            if Store.activeRaid.loot[Store.activeRaid.lootCount].de then
                Store.activeRaid.loot[Store.activeRaid.lootCount].de = 0
                print("|cFFFF962F RaidLogger |r|cFF00FF00" .. Store.activeRaid.loot[Store.activeRaid.lootCount].item .. "|r |cFFaaaa00unmarked|r as disenchanted")
            else
                Store.activeRaid.loot[Store.activeRaid.lootCount].de = 1
                print("|cFFFF962F RaidLogger |r|cFF00FF00" .. Store.activeRaid.loot[Store.activeRaid.lootCount].item .. "|r marked as disenchanted")
            end
        end
    elseif  "OS" == cmd then
        if not Store.activeRaid then
            print("|cFFFF962F RaidLogger |rNo active raid!")
        elseif Store.activeRaid.lootCount == 0 then
            print("|cFFFF962F RaidLogger |rNo loot logged!")
        else
            if Store.activeRaid.loot[Store.activeRaid.lootCount].os then
                Store.activeRaid.loot[Store.activeRaid.lootCount].os = 0
                print("|cFFFF962F RaidLogger |r|cFF00FF00" .. Store.activeRaid.loot[Store.activeRaid.lootCount].item .. "|r |cFFaaaa00unmarked|r as an off-spec item")
            else
                Store.activeRaid.loot[Store.activeRaid.lootCount].os = 1
                print("|cFFFF962F RaidLogger |r|cFF00FF00" .. Store.activeRaid.loot[Store.activeRaid.lootCount].item .. "|r marked as an off-spec item")
            end
        end
    elseif  "P" == cmd then
        if Store.activeRaid then
            print("|cFFFF962F RaidLogger |rRaid startrf at |cFF00FF00" .. Store.activeRaid.date)
            if Store.activeRaid.zone then
                print("|cFFFF962F RaidLogger |rZone |cFF00FF00" .. Store.activeRaid.zone)
            end
            if Store.activeRaid.attendedCount > 0 then
                print("|cFFFF962F RaidLogger |rAttended |cFF00FF00" .. table.concat(Store.activeRaid.attended, " "))
            else
                print("|cFFFF962F RaidLogger |rNo players attended.")
            end
            if Store.activeRaid.benchedCount > 0 then
                print("|cFFFF962F RaidLogger |rBenched |cFF00FF00" .. table.concat(Store.activeRaid.benched, " "))
            end
        else
            print("|cFFFF962F RaidLogger |rNo active raid.")
        end
    elseif  "DISCARD" == cmd then
        if Store.activeRaid then
            print("|cFFFF962F RaidLogger |rRaid has been discarded.")
            Store.activeRaid = nil
        else
            print("|cFFFF962F RaidLogger |rNo active raid.")
        end
    elseif  "VERSION" == cmd or "V" == cmd then
        print("|cFFFF962F RaidLogger |rVersion |cFF00FF00" .. VERSION)
    elseif  "END" == cmd then
        print("|cFFFF962F RaidLogger |rRaid ended, saving.")
        RaidLogger_EndRaid()
    end
end

function RaidLogger_StartRaid()
    -- flush previous raid
    RaidLogger_EndRaid()

    Store.activeRaid = {
        date = date("%y-%m-%d %H:%M"),
        attended = {},
        attendedCount = 0,
        benched = {},
        benchedCount = 0,
        zone = nil,
        loot = {},
        lootCount = 0,
    }
    print("|cFFFF962F RaidLogger |cFF00FF00Started a new raid.")

    if not Store.players then
        Store.players = {}
    end
end

function RaidLogger_EndRaid()
    if Store.activeRaid then
        if not Store.activeRaid.zone then
            Store.activeRaid.zone = "Unknown"
        end
        table.insert(Store.raids, Store.activeRaid)
        print("|cFFFF962F RaidLogger |cFF00FF00Ended raid to |r" .. Store.activeRaid.zone .. "|cFF00FF00 with |r" .. Store.activeRaid.attendedCount .. "|cFF00FF00 participants.")
    end
    Store.activeRaid = nil
end

function RaidLogger_Bench(player)
    if not HasValue(Store.activeRaid.benched, player) then
        print("|cFFFF962F RaidLogger |rBenching |cFF4444FF" .. player)
        table.insert(Store.activeRaid.benched, player)
        Store.activeRaid.benchedCount = Store.activeRaid.benchedCount + 1;
    end
    -- remove attended player from benched
    if RemoveValue(Store.activeRaid.attended, player) then
        print("|cFFFF962F RaidLogger |rUnattending |cFF4444FF" .. player)
        Store.activeRaid.attendedCount = Store.activeRaid.attendedCount - 1;
    end
end

function RaidLogger_Attend(player, warnExists)
    if not HasValue(Store.activeRaid.attended, player) then
        print("|cFFFF962F RaidLogger |rAdding |cFF0000FF" .. player)
        table.insert(Store.activeRaid.attended, player)
        Store.activeRaid.attendedCount = Store.activeRaid.attendedCount + 1;
    elseif warnExists then
        print("|cFFFF962F RaidLogger |rIgnoring |cFF0000FF" .. player .. "|r, already logged")
    end
    -- remove attended player from benched
    if RemoveValue(Store.activeRaid.benched, player) then
        print("|cFFFF962F RaidLogger |rUnbenching |cFF0000FF" .. player)
        Store.activeRaid.benchedCount = Store.activeRaid.benchedCount - 1;
    end
end

function RaidLogger_UpdateRaid()
    local raidSize = GetNumRaidMembers()

    if raidSize == 0 then
        print("|cFFFF962F RaidLogger |rNot in a raid!")
        return
    end

    -- print("|cFFFF962F RaidLogger |rUpdating raid...")

    if not Store.activeRaid then
        RaidLogger_StartRaid();
    end

    -- save zone
    if not Store.activeRaid.zone then
        local zone = InTrackedInstance()
        if zone then
            Store.activeRaid.zone = zone
            print("|cFFFF962F RaidLogger |cFF00FF00Zone|cFF909090: " .. zone)
        else
            print("|cFFFF962F RaidLogger |cFFFF0000Zone |cFF00FF00" .. GetZoneText() .. "|r couldn't be identified!")
        end
    end

    -- merge current player list with previous list
    for i = 1, raidSize do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
        if name then
            RaidLogger_Attend(name)
        end
        Store.players[name] = class
    end

    -- print("|cFFFF962F RaidLogger |cFF00FF00Attendance updated.")
end
