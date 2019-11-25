--
-- Created by IntelliJ IDEA.
-- User: kof
-- Date: 11/04/2019
-- Time: 18:36
--

local VERSION = 1.5
local MIN_RAID_PLAYERS = 10

local TRACKED_INSTANCES = {
    [1] = "The Molten Core",
    [2] = "Blackwing Lair",
    [3] = "Onyxia's Lair",
    [4] = "Zul'Gurub",
    [5] = "Ahn'Qiraj",
    [6] = "Ruins of Ahn'Qiraj",
    [7] = "Naxxramas",
    -- [8] = "Ragefire Chasm",
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

local COLOR_INSTANCE = "|cffff33ff"

local QUALITY_POOR = 0 -- gray
local QUALITY_COMMON = 1 -- white
local QUALITY_UNCOMMON = 2 -- green
local QUALITY_RARE = 3 -- blue
local QUALITY_EPIC = 4 -- purple
local QUALITY_LEGENDARY = 5 -- orange

local BUFF_CHECK_SECONDS = 60 

local lastBuffCheck = 0

RaidLoggerStore = {
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
        st = st .. CLASS_COLOR[RaidLoggerStore.players[name] or "Unknown"] .. name .. "|r "
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
    return CLASS_COLOR[RaidLoggerStore.players[who] or "Unknown"] .. who .. "|r"
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

    self:SetScript("OnEvent", function(self, event, ...) RaidLogger_OnEvent(event, ...) end)
    self:SetScript("OnUpdate", function(self, ...) RaidLogger_OnUpdate(...) end)

    SLASH_RaidLogger1 = "/rl"
    SlashCmdList["RaidLogger"] = RaidLogger_Main

    out("Logs raid attendance into a file. Write |cFF00FF00/rl help|r for a list of commands.")
end

function RaidLogger_OnUpdate()
    if RaidLoggerStore and RaidLoggerStore.activeRaid and time() - lastBuffCheck >= BUFF_CHECK_SECONDS then 
        -- out("checking buffs...")
        if not RaidLoggerStore.activeRaid.buffs then RaidLoggerStore.activeRaid.buffs = {} end 
        lastBuffCheck = time() 
        RaidLogger_CheckBuffs(RaidLoggerStore.activeRaid.buffs)
    end 
end 

function RaidLogger_OnEvent(event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "RaidLogger" then
            -- saved variables loaded
            if Store and Store.raids and #Store.raids > 0 and (not RaidLoggerStore or not RaidLoggerStore.raids or #RaidLoggerStore.raids == 0) then 
                RaidLoggerStore = Store 
                Store = nil 
            end 
            if RaidLoggerStore and RaidLoggerStore.activeRaid then
                LoggingCombat(true) -- resume combat logging
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
            if zone and RaidLoggerStore.activeRaid then
                RaidLogger_ParseLootMessage(arg1, zone)
            end
        elseif event == "RAID_ROSTER_UPDATE" or event == "GROUP_ROSTER_UPDATE" or event == "ENCOUNTER_END" then
            if RaidLoggerStore and RaidLoggerStore.activeRaid then
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
        table.insert(RaidLoggerStore.activeRaid.loot, {
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
        RaidLoggerStore.activeRaid.lootCount = RaidLoggerStore.activeRaid.lootCount + 1
    end
end

local LootMsgStrings = {
    _G.LOOT_ITEM_MULTIPLE,              -- %s receives loot: %sx%d.
    _G.LOOT_ITEM,                       -- %s receives loot: %s.
}
local LootSelfMsgStrings = {
	_G.LOOT_ITEM_SELF_MULTIPLE,         -- You receive loot: %sx%d.
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
        if not RaidLoggerStore.activeRaid then
            out("No active raid!")
        elseif RaidLoggerStore.activeRaid.lootCount == 0 then
            out("No loot logged!")
        else
            if RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].de then
                RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].de = 0
                out(RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].item .. "|r |cFFaaaa00unmarked|r as disenchanted")
            else
                RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].de = 1
                out(RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].item .. "|r marked as disenchanted")
            end
        end
    elseif  "OS" == cmd then
        if not RaidLoggerStore.activeRaid then
            out("No active raid!")
        elseif RaidLoggerStore.activeRaid.lootCount == 0 then
            out("No loot logged!")
        else
            if RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].os then
                RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].os = 0
                out(RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].item .. "|r |cFFaaaa00unmarked|r as an off-spec item")
            else
                RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].os = 1
                out(RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].item .. "|r marked as an off-spec item")
            end
        end
    elseif  "P" == cmd then
        if RaidLoggerStore.activeRaid then
            out("Raid started at " .. COLOR_INSTANCE .. RaidLoggerStore.activeRaid.date)
            if RaidLoggerStore.activeRaid.zone then
                out("Zone " .. COLOR_INSTANCE .. RaidLoggerStore.activeRaid.zone)
            end
            if RaidLoggerStore.activeRaid.attendedCount > 0 then
                out("Attended " .. ConcatPlayers(RaidLoggerStore.activeRaid.attended))
            else
                out("No players attended.")
            end
            if RaidLoggerStore.activeRaid.benchedCount > 0 then
                out("Benched " .. ConcatPlayers(RaidLoggerStore.activeRaid.benched))
            end
        else
            out("No active raid.")
        end
    elseif  "DISCARD" == cmd then
        if RaidLoggerStore.activeRaid then
            out("Raid has been discarded.")
            RaidLoggerStore.activeRaid = nil
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

    RaidLoggerStore.activeRaid = {
        date = date("%y-%m-%d %H:%M"),
        startTime = time(),
        attended = {},
        attendedCount = 0,
        benched = {},
        benchedCount = 0,
        zone = nil,
        loot = {},
        lootCount = 0,
        buffs = {}
    }
    if not RaidLoggerStore.players then
        RaidLoggerStore.players = {}
    end
    LoggingCombat(true) -- start combat logging
    out("Started a new raid.")
end

function RaidLogger_EndRaid()
    if RaidLoggerStore.activeRaid then
        RaidLoggerStore.activeRaid.endTime = time()
        if not RaidLoggerStore.activeRaid.zone then
            RaidLoggerStore.activeRaid.zone = "Unknown"
        end
        table.insert(RaidLoggerStore.raids, RaidLoggerStore.activeRaid)
        out("Ended raid to " .. COLOR_INSTANCE .. RaidLoggerStore.activeRaid.zone .. "|r with " .. COLOR_INSTANCE .. RaidLoggerStore.activeRaid.attendedCount .. "|r participants.")
    end
    RaidLoggerStore.activeRaid = nil
    LoggingCombat(false) -- stop combat logging
end

function RaidLogger_Bench(player)
    if not HasValue(RaidLoggerStore.activeRaid.benched, player) then
        out("Benching " .. ColorName(player))
        table.insert(RaidLoggerStore.activeRaid.benched, player)
        RaidLoggerStore.activeRaid.benchedCount = RaidLoggerStore.activeRaid.benchedCount + 1;
    end
    -- remove attended player from benched
    if RemoveValue(RaidLoggerStore.activeRaid.attended, player) then
        out("Unattending " .. ColorName(player))
        RaidLoggerStore.activeRaid.attendedCount = RaidLoggerStore.activeRaid.attendedCount - 1;
    end
end

function RaidLogger_Attend(player, warnExists)
    if not HasValue(RaidLoggerStore.activeRaid.attended, player) then
        out("Adding " .. ColorName(player))
        table.insert(RaidLoggerStore.activeRaid.attended, player)
        RaidLoggerStore.activeRaid.attendedCount = RaidLoggerStore.activeRaid.attendedCount + 1;
    elseif warnExists then
        out("Ignoring " .. ColorName(player) .. ", already logged")
    end
    -- remove attended player from benched
    if RemoveValue(RaidLoggerStore.activeRaid.benched, player) then
        out("Unbenching " .. ColorName(player))
        RaidLoggerStore.activeRaid.benchedCount = RaidLoggerStore.activeRaid.benchedCount - 1;
    end
end

function RaidLogger_UpdateRaid()
    local raidSize = GetNumRaidMembers()

    if raidSize == 0 then
        out("Not in a raid!")
        return
    end

    -- out("Updating raid...")

    if not RaidLoggerStore.activeRaid then
        RaidLogger_StartRaid();
    end

    -- save zone
    if not RaidLoggerStore.activeRaid.zone then
        local zone = InTrackedInstance()
        if zone then
            RaidLoggerStore.activeRaid.zone = zone
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
        RaidLoggerStore.players[name] = class
    end

    -- out("Attendance updated.")
end
