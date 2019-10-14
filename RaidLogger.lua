--
-- Created by IntelliJ IDEA.
-- User: kof
-- Date: 11/04/2019
-- Time: 18:36
--

local VERSION = 0.1
local MIN_RAID_PLAYERS = 1

local TRACKED_INSTANCES = {
    [1] = "The Molten Core",
    [2] = "Blackwing Lair",
    [3] = "Onyxia's Lair",
    [4] = "Zul'Gurub",
    [5] = "Ahn'Qiraj",
    [6] = "Ruins of Ahn'Qiraj",
    [7] = "Naxxramas",
    [8] = "Ragefire Chasm"
}

local CLASS_COLOR = {
    ["Druid"] = "|cffFF7D0A",
    ["Hunter"] = "|cffA9D271",
    ["Mage"] = "|cff40C7EB",
    ["Paladin"] = "|cffF58CBA",
    ["Priest"] = "|cffFFFFFF",
    ["Rogue"] = "|cffFFF569",
    ["Shaman"] = "|cff0070DE",
    ["Warlock"] = "|cff8787ED",
    ["Warrior"] = "|cffC79C6E",
    ["Unknown"] = "|cff888888",
}

local IGNORED_ITEMS = {
    -- [1] = "Elementium Ore",
}

local LOOT_OTHER_RECEIVES = "(.+) receives loot: (.+)."
local LOOT_YOU_RECEIVE = "You receive loot: (.+)."

local COLOR_INSTANCE = "|cffff33ff"

local QUALITY_POOR = 0 -- gray
local QUALITY_COMMON = 1 -- white
local QUALITY_UNCOMMON = 2 -- green
local QUALITY_RARE = 3 -- blue
local QUALITY_EPIC = 4 -- purple
local QUALITY_LEGENDARY = 5 -- orange

Store = {
    raids = {},
    activeRaid = nil,
    players = {},
}

local function out(text)
	print(" |cff0088ff<|cff00bbffRaidLogger|cff0088ff>|r "..text)
end 

local function err(text)
	out(""..text)
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

local function ConcatPlayers(tab) 
    local st = ""
    for _, name in ipairs(tab) do
        st = st .. CLASS_COLOR[Store.players[name] or "Unknown"] .. name .. "|r "
    end 
    return st
end 

local function TitleCase(first, rest)
    return string.upper(first) .. string.lower(rest)
end

local function FixPlayerName(player)
    return string.gsub(player, "(%a)([%w_']*)", TitleCase)
end

local function ColorName(who)
    return CLASS_COLOR[Store.players[who] or "Unknown"] .. who .. "|r"
end 

local function GetNumRaidMembers() 
    local count = 0
    for i = 1, MAX_RAID_MEMBERS do 
        name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
        if name then 
            count = count + 1 
        end 
    end 
    return count 
end 

local function EndRaidReminder()
    err(" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
    err("    DO NOT FORGET TO END THE RAID !")
    err("                /rl end")
    err(" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
end

function RaidLogger_OnLoad(self)
    self:RegisterEvent("ADDON_LOADED");
    self:RegisterEvent("RAID_ROSTER_UPDATE");
    self:RegisterEvent("GROUP_ROSTER_UPDATE");
    self:RegisterEvent("ENCOUNTER_END");
    self:RegisterEvent("RAID_INSTANCE_WELCOME");
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
    self:RegisterEvent("CHAT_MSG_LOOT");

    self:SetScript("OnEvent", function(self, event, ...) RaidLogger_OnEvent(event, ...) end);

    SLASH_RaidLogger1 = "/rl"
    SlashCmdList["RaidLogger"] = RaidLogger_Main

    out("Logs raid attendance into a file. Write |cFF00FF00/rl help|r for a list of commands.")
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
        -- out("|c44FFFFFF"..event.." event")
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

local function LogLoot(who, loot, quantity, zone)
    -- local vStartIndex, vEndIndex, vLinkColor, vItemCode, vItemEnchantCode, vItemSubCode, vUnknownCode, vItemName = strfind(loot, "|c(%x+)|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[([^%]]+)%]|h|r");
	local itemName, _, quality, _, _, itemType, _, _, _, _, vendorPrice = GetItemInfo(loot);

    if who and quality >= QUALITY_UNCOMMON and not tableTextLookup(IGNORED_ITEMS, vItemName) then
        out("Logged loot: " .. ColorName(who) .. " received " .. loot .. " at " .. COLOR_INSTANCE .. zone .. "|r")
        table.insert(Store.activeRaid.loot, {
            player = who,
            item = itemName,
            datetime = date("%y-%m-%d %H:%M"),
            zone = zone,
            link = loot,
            quality = quality,
            quantity = quantity,
            de = 0,
            os = 0,
        })
        Store.activeRaid.lootCount = Store.activeRaid.lootCount + 1
    end
end

local LootMsgStrings = {
    _G.LOOT_ITEM_MULTIPLE,              -- %s receives loot: %sx%d.
    _G.LOOT_ITEM,                       -- %s receives loot: %s.
}
local LootSelfMsgStrings = {
    _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE,  -- You receive item: %sx%d.
	_G.LOOT_ITEM_SELF_MULTIPLE,         -- You receive loot: %sx%d.
	_G.LOOT_ITEM_PUSHED_SELF,           -- You receive item: %s.
	_G.LOOT_ITEM_SELF,                  -- You receive loot: %s.
}

function RaidLogger_ParseLootMessage(msg, zone)
	for _, st in ipairs(LootMsgStrings) do
		local player, link, quantity = RaidLoggerDeformat(msg, st)
		if player and link then 
            LogLoot(player, link, (quantity or 1), zone)
		end 
	end
	for _, st in ipairs(LootSelfMsgStrings) do
		local link, quantity = RaidLoggerDeformat(msg, st)
        if link then 
            local myName = UnitName("player")
            LogLoot(myName, link, (quantity or 1), zone)
		end 
	end
end

function RaidLogger_Main(msg)
    local _, _, cmd, arg1 = string.find(string.upper(msg), "([%w]+)%s*(.*)$");
    -- out("cmd " .. cmd .. " / arg1 " .. arg1)
    if not cmd then
        RaidLogger_UpdateRaid()
    elseif  "H" == cmd or "HELP" == cmd then
        out("Commands: ")
        out("  |cFF00FF00/rl|r - update raid attendance")
        out("  |cFF00FF00/rl add <player>|r - manually log an attended player.")
        out("  |cFF00FF00/rl bench <player>|r - log a benched player.")
        out("  |cFF00FF00/rl de|r - marks last distributed loot item as disenchanted.")
        out("  |cFF00FF00/rl os|r - marks last distributed loot as an off-spec item.")
        out("  |cFF00FF00/rl discard|r - discard current raid, do this to ignore current raid.")        
        out("  |cFF00FF00/rl end|r - save and close raid, do this when raid ended.")
        out("  |cFF00FF00/rl p|r - print active raid, if any.")
    elseif  "BENCH" == cmd or "B" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLogger_Bench(FixPlayerName(arg1))
        else
            err("Missing player name!")
        end
    elseif  "ADD" == cmd or "A" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLogger_Attend(FixPlayerName(arg1), true)
        else
            err("Missing player name!")
        end
    elseif  "DE" == cmd then
        if not Store.activeRaid then
            out("No active raid!")
        elseif Store.activeRaid.lootCount == 0 then
            out("No loot logged!")
        else
            if Store.activeRaid.loot[Store.activeRaid.lootCount].de then
                Store.activeRaid.loot[Store.activeRaid.lootCount].de = 0
                out(Store.activeRaid.loot[Store.activeRaid.lootCount].item .. "|r |cFFaaaa00unmarked|r as disenchanted")
            else
                Store.activeRaid.loot[Store.activeRaid.lootCount].de = 1
                out(Store.activeRaid.loot[Store.activeRaid.lootCount].item .. "|r marked as disenchanted")
            end
        end
    elseif  "OS" == cmd then
        if not Store.activeRaid then
            out("No active raid!")
        elseif Store.activeRaid.lootCount == 0 then
            out("No loot logged!")
        else
            if Store.activeRaid.loot[Store.activeRaid.lootCount].os then
                Store.activeRaid.loot[Store.activeRaid.lootCount].os = 0
                out(Store.activeRaid.loot[Store.activeRaid.lootCount].item .. "|r |cFFaaaa00unmarked|r as an off-spec item")
            else
                Store.activeRaid.loot[Store.activeRaid.lootCount].os = 1
                out(Store.activeRaid.loot[Store.activeRaid.lootCount].item .. "|r marked as an off-spec item")
            end
        end
    elseif  "P" == cmd then
        if Store.activeRaid then
            out("Raid started at " .. COLOR_INSTANCE .. Store.activeRaid.date)
            if Store.activeRaid.zone then
                out("Zone " .. COLOR_INSTANCE .. Store.activeRaid.zone)
            end
            if Store.activeRaid.attendedCount > 0 then
                out("Attended " .. ConcatPlayers(Store.activeRaid.attended))
            else
                out("No players attended.")
            end
            if Store.activeRaid.benchedCount > 0 then
                out("Benched " .. ConcatPlayers(Store.activeRaid.benched))
            end
        else
            out("No active raid.")
        end
    elseif  "DISCARD" == cmd then
        if Store.activeRaid then
            out("Raid has been discarded.")
            Store.activeRaid = nil
        else
            out("No active raid.")
        end
    elseif  "VERSION" == cmd or "V" == cmd then
        out("Version |cFFFFFF00" .. VERSION)
    elseif  "END" == cmd then
        out("Raid ended, saving.")
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
    out("Started a new raid.")

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
        out("Ended raid to " .. COLOR_INSTANCE .. Store.activeRaid.zone .. "|r with " .. COLOR_INSTANCE .. Store.activeRaid.attendedCount .. "|r participants.")
    end
    Store.activeRaid = nil
end

function RaidLogger_Bench(player)
    if not HasValue(Store.activeRaid.benched, player) then
        out("Benching " .. ColorName(player))
        table.insert(Store.activeRaid.benched, player)
        Store.activeRaid.benchedCount = Store.activeRaid.benchedCount + 1;
    end
    -- remove attended player from benched
    if RemoveValue(Store.activeRaid.attended, player) then
        out("Unattending " .. ColorName(player))
        Store.activeRaid.attendedCount = Store.activeRaid.attendedCount - 1;
    end
end

function RaidLogger_Attend(player, warnExists)
    if not HasValue(Store.activeRaid.attended, player) then
        out("Adding " .. ColorName(player))
        table.insert(Store.activeRaid.attended, player)
        Store.activeRaid.attendedCount = Store.activeRaid.attendedCount + 1;
    elseif warnExists then
        out("Ignoring " .. ColorName(player) .. ", already logged")
    end
    -- remove attended player from benched
    if RemoveValue(Store.activeRaid.benched, player) then
        out("Unbenching " .. ColorName(player))
        Store.activeRaid.benchedCount = Store.activeRaid.benchedCount - 1;
    end
end

function RaidLogger_UpdateRaid()
    local raidSize = GetNumRaidMembers()

    if raidSize == 0 then
        out("Not in a raid!")
        return
    end

    -- out("Updating raid...")

    if not Store.activeRaid then
        RaidLogger_StartRaid();
    end

    -- save zone
    if not Store.activeRaid.zone then
        local zone = InTrackedInstance()
        if zone then
            Store.activeRaid.zone = zone
            out("Zone: " .. COLOR_INSTANCE .. zone)
        else
            err("Zone " .. COLOR_INSTANCE .. GetZoneText() .. "|r couldn't be identified!")
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

    -- out("Attendance updated.")
end
