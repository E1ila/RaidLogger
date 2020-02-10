--
-- Created by IntelliJ IDEA.
-- User: kof
-- Date: 11/04/2019
-- Time: 18:36
--

local VERSION = 1.6
local MIN_RAID_PLAYERS = 2
local ADDON_NAME = "RaidLogger"
local FONT_NAME = "Fonts\\FRIZQT__.TTF"
local ADDON_PREFIX = "RaidLogger"

local TRACKED_INSTANCES = {
    [1] = "The Molten Core",
    [2] = "Blackwing Lair",
    [3] = "Onyxia's Lair",
    [4] = "Zul'Gurub",
    [5] = "Ahn'Qiraj",
    [6] = "Ruins of Ahn'Qiraj",
    [7] = "Naxxramas",
    [8] = "Ragefire Chasm",
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

local STATE_ATTENDED = "a"
local STATE_BENCHED = "b"
local STATE_NOSHOW = "n"
local STATE_LATE = "l"

local QUALITY_POOR = 0 -- gray
local QUALITY_COMMON = 1 -- white
local QUALITY_UNCOMMON = 2 -- green
local QUALITY_RARE = 3 -- blue
local QUALITY_EPIC = 4 -- purple
local QUALITY_LEGENDARY = 5 -- orange

local SYNC_LOOT = "loot"
local SYNC_COUNCIL = "council"
local SYNC_COUNCIL_WHO = "council?"
local SYNC_VOTE = "vote"
local SYNC_SUGGEST = "suggest"

local BUFF_CHECK_SECONDS = 60 

local lastBuffCheck = 0
local editRaid = nil 
local editRaidIndex = nil
local debugMode = true
local lastCouncilSync = 0

RaidLoggerDelayedMessages = {}
RaidLoggerPendingLoot = {}

RaidLoggerStore = {
    raids = {},
    activeRaid = nil,
    players = {},
}

RaidLogger = {}

local function questionOp(cond, trueValue, falseValue)
    if cond then 
        return trueValue
    end 
    return falseValue
end 

local function out(text)
	print(" |cff0088ff<|cff00bbffRaidLogger|cff0088ff>|r "..text)
end 

local function debug(text)
    if debugMode then 
        print(" |cff0088ff<|cff00bbffRaidLogger|cff0088ff>|r DEBUG "..text)
    end 
end 

local function err(text)
	out(""..text)
end 

local function normalizeLink(link)
	-- remove player level from item link
	local parts = {_G.string.split(":", link)}
	parts[10] = "_"
	return table.concat(parts, ":") 
end 

local function removeRealmName(playerRealmName) 
    local nameParts = {_G.string.split("-", playerRealmName)}
	return nameParts[1]
end 

local function splitCsv(text, sep) 
	local result = {}
	for word in string.gmatch(text, '([^,]+)') do 
		table.insert(result, word)
	end 
	return result 
end 

local function tableTextLookup(table, text)
    for _, value in ipairs(table) do
        if value == text then
            return true
        end
    end
    return false
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

local function PlaceLinkInChatEditBox(itemLink)
	-- Copy itemLink into ChatFrame
	local chatFrame = SELECTED_DOCK_FRAME
	local editbox = chatFrame.editBox
	if editbox then
		if editbox:HasFocus() then
			editbox:SetText(editbox:GetText()..itemLink);
		else
			editbox:SetFocus(true);
			editbox:SetText(itemLink);
		end
	end
end

local function AttStatusToString(status)
    if status == STATE_ATTENDED then return "Attended" end 
    if status == STATE_BENCHED then return "Benched" end
    if status == STATE_LATE then return "Late" end 
    if status == STATE_NOSHOW then return "No Show" end 
    return "??"..status
end 

local function AttStatusFromString(text)
    if text == "Attended" then return STATE_ATTENDED end
    if text == "Benched" then return STATE_BENCHED end
    if text == "Late" then return STATE_LATE end
    if text == "No Show" then return STATE_NOSHOW end
    return "??"
end 

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--   LOGGER LOGIC

local function InTrackedInstance()
    if not IsInInstance() then return nil end
    local zone = GetZoneText()
    if tableTextLookup(TRACKED_INSTANCES, zone) then return zone end
    return nil
end

local function ConcatPlayers(tab, filter) 
    local st = ""
    for name, state in pairs(tab) do
        if state == filter then 
            st = st .. CLASS_COLOR[RaidLoggerStore.players[name] or "Unknown"] .. name .. "|r "
        end 
    end 
    return st
end 

local function TitleCase(first, rest)
    return string.upper(first) .. string.lower(rest)
end

local function FixPlayerName(player)
    return TitleCase(string.sub(player, 1, 1), string.sub(player, 2))
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

-- loot can be itemId
local function LogLoot(who, loot, quantity, ts)
    -- local vStartIndex, vEndIndex, vLinkColor, vItemCode, vItemEnchantCode, vItemSubCode, vUnknownCode, vItemName = strfind(loot, "|c(%x+)|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[([^%]]+)%]|h|r");
    local itemName, itemLink, quality, _, _, itemType, _, _, _, _, vendorPrice = GetItemInfo(loot);

    if not itemLink then
        tinsert(RaidLoggerPendingLoot, {who, loot, quantity, ts})
        return
    end 

    itemLink = normalizeLink(itemLink)
    local startIndex, _ = string.find(itemLink, "item")
    local _, endIndex = string.find(itemLink, "h%[")
    local itemString = string.sub(itemLink, startIndex, endIndex-3)

    if who and quality >= QUALITY_UNCOMMON and not tableTextLookup(IGNORED_ITEMS, vItemName) then
        out("Logged loot: " .. ColorName(who) .. " received " .. itemLink)
        RaidLoggerStore.activeRaid.lootCount = RaidLoggerStore.activeRaid.lootCount + 1
        local entry = {
            player = who,
            item = itemName,
            ts = ts or time(),
            link = itemLink,
            quality = quality,
            quantity = quantity,
            de = 0,
            os = 0,
            bank = 0,
            votes = {},
            status = 0,
            idx = RaidLoggerStore.activeRaid.lootCount,
            itemString = itemString,
        }
        table.insert(RaidLoggerStore.activeRaid.loot, entry)
        RaidLogger_RaidWindow_LootTab:Refresh()

        if not ts then 
            RaidLogger:Post(1, nil, SYNC_LOOT, entry.player, entry.itemString, entry.quantity, entry.ts, entry.idx)
        end 
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

function RaidLogger:ParseLootMessage(msg, zone)
	for _, st in ipairs(LootMsgStrings) do
		local player, link, quantity = RaidLoggerDeformat(msg, st)
		if player and link then 
            LogLoot(player, link, (quantity or 1))
		end 
	end
	for _, st in ipairs(LootSelfMsgStrings) do
		local link, quantity = RaidLoggerDeformat(msg, st)
        if link then 
            local myName = UnitName("player")
            LogLoot(myName, link, (quantity or 1))
		end 
	end
end

function RaidLogger_Commands(msg)
    -- local _, _, cmd, arg1 = string.find(msg, "([%w]+)%s*(.*)$");
    local cmd, arg1 = _G.string.split(" ", msg)
    cmd = string.upper(cmd)
    -- out("cmd " .. cmd .. " / arg1 " .. arg1)
    if not cmd then
        RaidLogger:ChooseLastRaid()
        RaidLogger_RaidWindow:Refresh()
        RaidLogger_RaidWindow:Show()
    elseif  "S" == cmd or "START" == cmd then
        RaidLogger:UpdateRaid()
    elseif  "H" == cmd or "HELP" == cmd then
        out("Commands: ")
        out("  |cFF00FF00/rl|r - show UI")
        out("  |cFF00FF00/rl |cFF00ff95a|cFF00FF00dd <player>|r - manually log an attended player.")
        out("  |cFF00FF00/rl |cFF00ff95b|cFF00FF00ench <player>|r - log a benched player.")
        out("  |cFF00FF00/rl log <itemlink> <receiver>|r - manually add looted item.")
        out("  |cFF00FF00/rl de|r - marks last distributed loot item as disenchanted.")
        out("  |cFF00FF00/rl os|r - marks last distributed loot as an off-spec item.")
        out("  |cFF00FF00/rl discard|r - discard current raid, do this to ignore current raid.")        
        out("  |cFF00FF00/rl end|r - save and close raid, do this when raid ended.")
        out("  |cFF00FF00/rl p|r - print active raid, if any.")
        out("  |cFF00FF00/rl start|r - start logging a raid or update existing one.")
    elseif  "LOG" == cmd then
        if not RaidLoggerStore.activeRaid then 
            out("No active raid!")
            return 
        end 

        local startIndex, _ = string.find(arg1, "%|c");
        local _, endIndex = string.find(arg1, "%]%|h%|r");
        local itemLink = string.sub(arg1, startIndex, endIndex);	

        if itemLink and GetItemInfo(itemLink) then 
            if ((endIndex + 2 ) <= (#arg1)) then
                local player = string.sub(arg1, endIndex + 2, #arg1)
                if player then 
                    LogLoot(player, itemLink, 1)
                else 
                    out("Incorrect usage of command, write |cff00ff00/rl log [ITEM_LINK] [RECEIVER_NAME]")
                end 
            end				
        else 
            out("Incorrect usage of command, write |cff00ff00/rl log [ITEM_LINK] [RECEIVER_NAME]")
        end 
    elseif  "COUNCIL" == cmd then
        if arg1 and string.len(arg1) > 0 then
            if arg1 == "disable" then
                out("Loot council disabled.");
                RaidLoggerStore.council = nil 
            else 
                RaidLogger:SetLootCouncil(FixPlayerName(arg1))
            end 
        else
            err("Missing player name!")
        end
    elseif  "SYNC" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLoggerStore.sync = arg1 
            ReloadUI()
        else
            err("Missing sync password!")
        end
    elseif  "SEND" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLogger:Post(1, nil, arg1)
        else
            err("Missing sync test text!")
        end
    elseif  "RESEND" == cmd then
        if arg1 and string.len(arg1) > 0 then
            local entry = RaidLoggerStore.activeRaid.loot[tonumber(arg1)]
            RaidLogger:Post(1, nil, SYNC_LOOT, entry.player, entry.itemString, entry.quantity, entry.ts, entry.idx)
        else
            for i, entry in ipairs(RaidLoggerStore.activeRaid.loot) do 
                RaidLogger:Post(i, nil, SYNC_LOOT, entry.player, entry.itemString, entry.quantity, entry.ts, entry.idx)
            end 
        end
    elseif  "BENCH" == cmd or "B" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLogger:LogBenched(FixPlayerName(arg1))
        else
            err("Missing player name!")
        end
    elseif  "NOSHOW" == cmd or "NS" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLogger:LogNoShow(FixPlayerName(arg1))
        else
            err("Missing player name!")
        end
    elseif  "LATE" == cmd or "L" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLogger:LogLateShow(FixPlayerName(arg1))
        else
            err("Missing player name!")
        end
    elseif  "REMOVE" == cmd or "R" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLogger:RemoveFromLog(FixPlayerName(arg1))
        else
            err("Missing player name!")
        end
    elseif  "ADD" == cmd or "A" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLogger:LogAttended(FixPlayerName(arg1))
        else
            err("Missing player name!")
        end
    elseif  "DE" == cmd then
        if not RaidLoggerStore.activeRaid then
            out("No active raid!")
        elseif RaidLoggerStore.activeRaid.lootCount == 0 then
            out("No loot logged!")
        else
            if RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].de == 1 then
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
            if RaidLoggerStore.activeRaid.loot[RaidLoggerStore.activeRaid.lootCount].os == 1 then
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
            out("Attended " .. ConcatPlayers(RaidLoggerStore.activeRaid.players, STATE_ATTENDED))
            out("Benched " .. ConcatPlayers(RaidLoggerStore.activeRaid.players, STATE_BENCHED))
            out("No-show " .. ConcatPlayers(RaidLoggerStore.activeRaid.players, STATE_NOSHOW))
            out("Late " .. ConcatPlayers(RaidLoggerStore.activeRaid.players, STATE_LATE))
        else
            out("No active raid.")
        end
    elseif  "DISCARD" == cmd then
        if RaidLoggerStore.activeRaid then
            out("Raid has been discarded.")
            RaidLoggerStore.activeRaid = nil
            RaidLogger:ChooseLastRaid()
            RaidLogger_RaidWindow:Refresh()
        else
            out("No active raid.")
        end
    elseif  "VERSION" == cmd or "V" == cmd then
        out("Version |cFFFFFF00" .. VERSION)
    elseif  "END" == cmd then
        out("Raid ended, saving.")
        RaidLogger:EndRaid()
    end
end

function RaidLogger:StartRaid()
    -- flush previous raid
    RaidLogger:EndRaid()

    RaidLoggerStore.activeRaid = {
        date = date("%y-%m-%d %H:%M"),
        startTime = time(),
        players = {},
        zone = nil,
        loot = {},
        lootCount = 0,
        buffs = {},
    }
    if not RaidLoggerStore.players then
        RaidLoggerStore.players = {}
    end
    LoggingCombat(true) -- start combat logging
    out("Started a new raid.")

    local roster = {}
    for i=1,GetNumGuildMembers() do
        local name,rank,_,level,clas = GetGuildRosterInfo(i)
        if level >= 40 then 
            roster[name] = {level, clas, rank}
        end 
    end 
    RaidLoggerStore.guildRoster = roster
    RaidLogger:ChooseLastRaid()
    RaidLogger_RaidWindow:Refresh()
    RaidLogger_RaidWindow_Buttons_LootTab:Clicked()
end

function RaidLogger:EndRaid()
    if RaidLoggerStore.activeRaid then
        RaidLoggerStore.activeRaid.endTime = time()
        if not RaidLoggerStore.activeRaid.zone then
            RaidLoggerStore.activeRaid.zone = "Unknown"
        end
        table.insert(RaidLoggerStore.raids, RaidLoggerStore.activeRaid)
        out("Ended raid to " .. COLOR_INSTANCE .. RaidLoggerStore.activeRaid.zone)
    end
    RaidLoggerStore.activeRaid = nil
    LoggingCombat(false) -- stop combat logging
    RaidLogger:ChooseLastRaid()
    RaidLogger_RaidWindow:Refresh()
end

function RaidLogger:SetLootCouncil(player)
    if not RaidLoggerStore.council then 
        RaidLoggerStore.council = {}
    end 
    if RaidLoggerStore.council[player] then
        out("Removing " .. ColorName(player) .. " from loot council.")
        RaidLoggerStore.council[player] = nil 
    else 
        out("Adding " .. ColorName(player) .. " to loot council.")
        RaidLoggerStore.council[player] = true  
    end 
    self:AnnounceLootCouncil()
    RaidLogger_RaidWindow_LootTab:Refresh()
end

function RaidLogger:PackLootCouncil() 
    if not RaidLoggerStore.council then return "" end 
    local names = {}
    for name, _ in pairs(RaidLoggerStore.council) do 
        tinsert(names, name)
    end 
    table.sort(names)
    return table.concat(names, "|")
end 

function RaidLogger:AnnounceLootCouncil(packedCouncil) 
    RaidLogger:Post(0, nil, SYNC_COUNCIL, packedCouncil or self:PackLootCouncil())
end 

function RaidLogger:LogBenched(player)
    out("Logging bench for " .. ColorName(player))
    RaidLoggerStore.activeRaid.players[player] = STATE_BENCHED
    RaidLogger_RaidWindow_PlayersTab:Refresh()
end

function RaidLogger:LogAttended(player)
    if RaidLoggerStore.activeRaid.players[player] ~= STATE_ATTENDED then 
        out("Logging attendance for " .. ColorName(player))
        RaidLoggerStore.activeRaid.players[player] = STATE_ATTENDED
        RaidLogger_RaidWindow_PlayersTab:Refresh()
    end 
end

function RaidLogger:LogNoShow(player)
    out("Logging no-show for " .. ColorName(player))
    RaidLoggerStore.activeRaid.players[player] = STATE_NOSHOW
    RaidLogger_RaidWindow_PlayersTab:Refresh()
end

function RaidLogger:LogLateShow(player)
    out("Logging late show for " .. ColorName(player))
    RaidLoggerStore.activeRaid.players[player] = STATE_LATE
    RaidLogger_RaidWindow_PlayersTab:Refresh()
end

function RaidLogger:RemoveFromLog(player)
    out("Removing " .. ColorName(player) .. " from log")
    RaidLoggerStore.activeRaid.players[player] = nil 
    RaidLogger_RaidWindow_PlayersTab:Refresh()
end

function RaidLogger:UpdateRaid()
    local raidSize = GetNumRaidMembers()

    if raidSize == 0 then
        out("Not in a raid!")
        return
    end

    -- out("Updating raid...")

    if not RaidLoggerStore.activeRaid then
        RaidLogger:StartRaid();
    end

    -- save zone
    if not RaidLoggerStore.activeRaid.zone then
        local zone = InTrackedInstance()
        if zone then
            RaidLoggerStore.activeRaid.zone = zone
            RaidLogger_RaidWindow:Refresh()
            out("Zone: " .. COLOR_INSTANCE .. zone)
        else
            err("Zone " .. COLOR_INSTANCE .. GetZoneText() .. "|r couldn't be identified!")
        end
    end

    -- merge current player list with previous list
    for i = 1, raidSize do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
        if name then
            RaidLogger:LogAttended(name)
            RaidLoggerStore.players[name] = class
        end
    end

    -- out("Attendance updated.")
end

function RaidLogger:ChooseLastRaid()
    editRaidIndex = nil 
    if not RaidLoggerStore.activeRaid then 
        if #RaidLoggerStore.raids > 0 then 
            editRaidIndex = #RaidLoggerStore.raids
            editRaid = RaidLoggerStore.raids[editRaidIndex]
        else 
            editRaid = nil 
        end 
    else 
        editRaid = RaidLoggerStore.activeRaid 
    end 
end


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--   SYNC

function RaidLogger:OnAddonMessage(text, channel, sender, target)
    sender = removeRealmName(sender)
    if sender == UnitName("player") then return end 
    local parts = splitCsv(text)
    debug("SYNC IN - ["..sender.."]: "..text)

    local function VerifyLoot(parts) 
        if not RaidLoggerStore.activeRaid then 
            out("Couldn't set vote, no active raid")
            return false
        end 
        local idx = tonumber(parts[2])
        if #RaidLoggerStore.activeRaid.loot < idx then 
            out("Couldn't set vote, loot #"..idx.." is missing")
            return false
        end 
        local entry = RaidLoggerStore.activeRaid.loot[idx]
        if entry.itemString ~= parts[3] then 
            __p1 = entry.itemString
            __p2 = parts[3]
            out("Wrong item at index "..idx..", expected "..parts[3].." but got "..entry.itemString.." - ignoring vote")
            return false
        end 
        return true 
    end 

    if parts[1] == SYNC_LOOT then 
        -- 2-receiver, 3-itemString, 4-quantity, 5-ts, 6-index
        if RaidLoggerStore.activeRaid then 
            local t = time() - 10
            local idx = tonumber(parts[6])
            local ts = tonumber(parts[5])
            local quantity = tonumber(parts[4])
            local itemString = parts[3]
            local who = parts[2]

            local shouldAdd = true
            for i = #RaidLoggerStore.activeRaid.loot, 1, -1 do 
                local loggedItem = RaidLoggerStore.activeRaid.loot[i]
                if loggedItem.idx == idx then 
                    if loggedItem.itemId == itemId then 
                        shouldAdd = false 
                        debug("Found matching loot entry")
                        break -- found it
                    else 
                        shouldAdd = false 
                        out("Loot log isn't synced!")
                        break 
                    end
                end 
            end
            if shouldAdd then 
                debug("who="..who.." itemString="..itemString.." quantity="..quantity.." ts="..ts)
                LogLoot(who, itemString, quantity, ts)
            end 
        else 
            out("Received loot sync, but no active raid - ignoring")
        end 
    end 

    if parts[1] == SYNC_COUNCIL then 
        local currentCouncil = self:PackLootCouncil()
        if currentCouncil == parts[2] then return end -- council not changed

        if not parts[2] or #parts[2] == 0 then 
            RaidLoggerStore.council = nil 
            out("Received loot council disable from "..sender)
        else 
            RaidLoggerStore.council = {}
            local names = {_G.string.split("|", parts[2])}
            for _, name in pairs(names) do 
                RaidLoggerStore.council[name] = true 
            end 
            out("Received new loot council from "..sender..": "..parts[2])
            RaidLogger_RaidWindow_LootTab:Refresh()
        end 
    end

    if parts[1] == SYNC_COUNCIL_WHO then 
        local currentCouncil = self:PackLootCouncil()
        if #currentCouncil > 0 then 
            self:AnnounceLootCouncil(currentCouncil)
        end 
    end

    if parts[1] == SYNC_VOTE then 
        if not VerifyLoot(parts) then return end 
        
        if entry.votes[sender] == tonumber(parts[4]) then return end -- vote already recorded

        entry.votes[sender] = tonumber(parts[4])
        local voteStr = "|cffff0000NO|r"
        if entry.votes[sender] == 1 then voteStr = "|cff00ff00YES|r" end 
        out(sender.." voted "..voteStr.." to give "..entry.link.." to "..entry.tradedTo)

        self:CheckVotes(entry)
    end 

    if parts[1] == SYNC_SUGGEST then 
        if not VerifyLoot(parts) then return end 

        if entry.tradedTo == parts[4] then return end -- tradeTo already recorded

        entry.tradedTo = parts[4]
        local row = RaidLogger_RaidWindow_LootTab.rows[#RaidLogger_RaidWindow_LootTab.rows - entry.idx + 1]
        RaidLogger_RaidWindow_LootTab:TradedToChanged(row, entry) 
    end 
end 

function RaidLogger:Post(delaySeconds, toWho, ...) 
    tinsert(RaidLoggerDelayedMessages, {
        ["time"] = time() + delaySeconds,
        ["msg"] = table.concat({...}, ","),
        ["to"] = toWho,
    })
end 

function RaidLogger:CheckVotes(entry) 
    local raidPlayers = {}
    for i = 1, GetNumGroupMembers() do 
        if UnitIsConnected("raid"..i) then 
            local name = UnitName("raid"..i)
            raidPlayers[name] = true 
        end 
    end 

    local sum = 0
    local max = 0
    local veto = {}
    for name, enabled in pairs(RaidLoggerStore.council) do 
        if enabled and raidPlayers[name] then
            max = max + 1
            if entry.votes[name] == 1 then 
                sum = sum + 1
            elseif entry.votes[name] == 0 then 
                tinsert(veto, name)
            end 
        end 
    end 
    if sum > max then 
        out("Very strange, got more votes than max possible for "..entry.link)
    end 
    if sum >= max and entry.status ~= 1 then 
        entry.status = 1
        out("Loot "..entry.link.." AGREED to be given to "..entry.tradedTo.." with "..sum.." / "..max.." votes.")
    elseif #veto > 0 then 
        entry.status = -1
    end 

    if editRaid and not editRaid.endTime then 
        -- update UI
        local row = RaidLogger_RaidWindow_LootTab.rows[#RaidLogger_RaidWindow_LootTab.rows - entry.idx + 1]
        RaidLogger_RaidWindow_LootTab:UpdateStatusImage(row, entry)
    end 
end 


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--   ADDON FRAME 

function RaidLoggerFrame:OnAddonLoaded()
    SLASH_RaidLogger1 = "/rl"
    SlashCmdList["RaidLogger"] = RaidLogger_Commands
    out("Logs raid attendance into a file. Write |cFF00FF00/rl help|r for a list of commands.")

    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_LootTab)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_PlayersTab)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_RaidsTab)

    -- saved variables loaded
    if Store and Store.raids and #Store.raids > 0 and (not RaidLoggerStore or not RaidLoggerStore.raids or #RaidLoggerStore.raids == 0) then 
        RaidLoggerStore = Store 
        Store = nil 
    end 
    if RaidLoggerStore and RaidLoggerStore.activeRaid then
        LoggingCombat(true) -- resume combat logging
        EndRaidReminder()
    end
    RaidLogger:ChooseLastRaid()
    RaidLogger_RaidWindow:Refresh();
    RaidLogger_RaidWindow_Buttons_LootTab:Clicked()

    if RaidLoggerStore.sync then 
        successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX..RaidLoggerStore.sync)
        if successfulRequest then 
            out("Registered for sync on "..RaidLoggerStore.sync)
            RaidLogger:Post(5, nil, SYNC_COUNCIL_WHO)
        else 
            printerr("Failed registering to message prefix!")
        end 
    end 
end

function RaidLoggerFrame:OnUpdate()
    if RaidLoggerStore and RaidLoggerStore.activeRaid and time() - lastBuffCheck >= BUFF_CHECK_SECONDS then 
        -- out("checking buffs...")
        if not RaidLoggerStore.activeRaid.buffs then RaidLoggerStore.activeRaid.buffs = {} end 
        lastBuffCheck = time() 
        RaidLogger_CheckBuffs(RaidLoggerStore.activeRaid.buffs)
    end 
    if RaidLoggerDelayedMessages and #RaidLoggerDelayedMessages then 
        newStack = {}
        for _, meta in ipairs(RaidLoggerDelayedMessages) do 
            if meta.time <= time() then 
                debug("SYNC OUT - "..meta.msg)
                if meta.to then 
                    C_ChatInfo.SendAddonMessage(ADDON_PREFIX..RaidLoggerStore.sync, meta.msg, "WHISPER", meta.to)
                else 
                    C_ChatInfo.SendAddonMessage(ADDON_PREFIX..RaidLoggerStore.sync, meta.msg, "RAID")
                end 
            else 
                tinsert(newStack, meta)
            end
        end 
        RaidLoggerDelayedMessages = newStack
    end 
    if RaidLoggerPendingLoot and #RaidLoggerPendingLoot then 
        local params = RaidLoggerPendingLoot[1]
        table.remove(RaidLoggerPendingLoot, 1)
        if params then 
            LogLoot(params[1], params[2], params[3], params[4])
        end 
    end 
end 

function RaidLoggerFrame:OnEvent(event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then 
            self:OnAddonLoaded()
        end 
    elseif event == "RAID_INSTANCE_WELCOME" or event == "ZONE_CHANGED_NEW_AREA" then
        if InTrackedInstance() and GetNumRaidMembers() >= MIN_RAID_PLAYERS then
            RaidLogger:UpdateRaid()
        end
    elseif event == "CHAT_MSG_LOOT" then
        local zone = InTrackedInstance()
        if zone and RaidLoggerStore.activeRaid then
            RaidLogger:ParseLootMessage(arg1, zone)
        end
    elseif event == "RAID_ROSTER_UPDATE" or event == "GROUP_ROSTER_UPDATE" or event == "ENCOUNTER_END" then
        if RaidLoggerStore and RaidLoggerStore.activeRaid then
            if GetNumRaidMembers() > 1 then
                RaidLogger:UpdateRaid()
            else
                EndRaidReminder();
            end
        end
    elseif event == "CHAT_MSG_ADDON" and RaidLoggerStore.sync then
        if arg1 == ADDON_PREFIX..RaidLoggerStore.sync then 
            RaidLogger:OnAddonMessage(...)
        end 
    end
end



-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--   CURRENT RAID WINDOW

-- tabs ----------

function RaidLogger:SetTabBackdropColor(btn, hovering)
	if btn.disabled then 
		btn:SetBackdropColor(0.3, 0.3, 0.3, 0.1)
		-- btn:SetBackdropBorderColor(1, 1, 1, 0.08)
		btn.label:SetTextColor(0.8, 0.8, 0.8, 0.5)
	elseif hovering then 
		if btn.selected then 
			btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
            btn:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)
			btn.label:SetTextColor(1, 1, 1, 1)
		else 
			btn:SetBackdropColor(0, 0, 0, 1)
            btn:SetBackdropBorderColor(0, 0, 0, 1)
			btn.label:SetTextColor(255/255, 238/255, 200/255, 1)
		end 
	else 
		if btn.selected then 
			btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
            btn:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)
			btn.label:SetTextColor(1, 1, 1, 1)
		else 
			btn:SetBackdropColor(0, 0, 0, 1)
            btn:SetBackdropBorderColor(0, 0, 0, 1)
			btn.label:SetTextColor(0.8, 0.8, 0.8, 1)
		end 
	end 
end 

function RaidLogger_RaidWindow_Buttons_PlayersTab:Clicked()
	if self.disabled then return end 
    self.selected = true
    RaidLogger_RaidWindow_Buttons_LootTab.selected = false 
    RaidLogger_RaidWindow_Buttons_RaidsTab.selected = false 
    RaidLogger:SetTabBackdropColor(self, true)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_LootTab, false)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_RaidsTab, false)
    RaidLogger_RaidWindow:SwitchTabs("players")
end 

function RaidLogger_RaidWindow_Buttons_LootTab:Clicked()
	if self.disabled then return end 
    self.selected = true
    RaidLogger_RaidWindow_Buttons_PlayersTab.selected = false 
    RaidLogger_RaidWindow_Buttons_RaidsTab.selected = false 
    RaidLogger:SetTabBackdropColor(self, true)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_PlayersTab, false)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_RaidsTab, false)
    RaidLogger_RaidWindow:SwitchTabs("loot")
end 

function RaidLogger_RaidWindow_Buttons_RaidsTab:Clicked()
	if self.disabled then return end 
    self.selected = true
    RaidLogger_RaidWindow_Buttons_PlayersTab.selected = false 
    RaidLogger_RaidWindow_Buttons_LootTab.selected = false 
    RaidLogger:SetTabBackdropColor(self, true)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_PlayersTab, false)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_LootTab, false)
    RaidLogger_RaidWindow:SwitchTabs("raids")
end 


-- Question dialog

function RaidLogger:AskQuestion(titleText, questionText, onYes, onNo, yesText, noText) 
	FarmLog_QuestionDialog_Yes:SetScript("OnClick", function () 
		FarmLog_QuestionDialog:Hide()
		onYes() 
	end)
	FarmLog_QuestionDialog_No:SetScript("OnClick", function () 
		FarmLog_QuestionDialog:Hide()
		if onNo then onNo() end 
	end)
	FarmLog_QuestionDialog_Title_Text:SetText(titleText)
	FarmLog_QuestionDialog_Question:SetText(questionText)
	FarmLog_QuestionDialog_Yes:SetText(yesText or L["Yes"])
	FarmLog_QuestionDialog_No:SetText(noText or L["No"])
	FarmLog_QuestionDialog:Show()
end 


-- rows & tabs ----------

local function HideRowsBeyond(j, container)
	local n = #container.rows;
	if j <= n then 
		for i = j, n do
			container.rows[i].root:Hide()
		end
	end 
end

function setButtonState(state, prefix, btn)
    local texture = "Interface\\AddOns\\RaidLogger\\assets\\"..prefix.."-"
    if state == 1 then 
        texture = texture .. "on"
    else 
        texture = texture .. "off"
    end     
    btn:SetNormalTexture(texture)
    btn:SetPushedTexture(texture)
    btn:SetHighlightTexture(texture)    
end 

function RaidLogger_RaidWindow:Refresh()
    RaidLogger_RaidWindow_LootTab:Refresh()
    RaidLogger_RaidWindow_PlayersTab:Refresh()
    RaidLogger_RaidWindow_RaidsTab:Refresh()
end 

function RaidLogger_RaidWindow:SwitchTabs(tab)
    self.tab = tab
    if self.tab == "loot" then 
        RaidLogger_RaidWindow_LootTab:Show()
    else 
        RaidLogger_RaidWindow_LootTab:Hide()
    end 
    if self.tab == "players" then 
        RaidLogger_RaidWindow_PlayersTab:Show()
    else 
        RaidLogger_RaidWindow_PlayersTab:Hide()
    end 
    if self.tab == "raids" then 
        RaidLogger_RaidWindow_RaidsTab:Show()
    else 
        RaidLogger_RaidWindow_RaidsTab:Hide()
    end 
end 

-- loot tab ----------

function RaidLogger_RaidWindow_LootTab:UpdateStatusImage(row, entry)
    local statusImage = "question"
    local statusTooltip = "Undecided"
    if entry.status == 1 then 
        statusImage = "check"
        statusTooltip = "Approved"
    elseif entry.status == -1 then 
        statusImage = "cross"
        statusTooltip = "Denied"
    end 
    row.statusImage:SetTexture("Interface\\AddOns\\RaidLogger\\assets\\"..statusImage)
    row.statusFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(row.statusFrame, "ANCHOR_LEFT")
        GameTooltip:SetText(statusTooltip)
        GameTooltip:Show()
    end);
end 

function RaidLogger_RaidWindow_LootTab:TradedToChanged(row, entry) 
    entry.votes = {}
    entry.status = 0
    entry.de = 0
    entry.os = 0
    UIDropDownMenu_SetText(row.playerDropdown, self.value)
    RaidLogger_RaidWindow_LootTab:UpdateStatusImage(row, entry)
    if votingEnabled then 
        row.yesButton:Show()
        row.noButton:Show()
    end 
end 

function RaidLogger_RaidWindow_LootTab:AddRow(players, entry, activeRaid, votingEnabled) 
	self.visibleRows = self.visibleRows + 1

    local existingRow = self.rows[self.visibleRows]
	local row = existingRow or {};

	if not row.root then 
		row.root = CreateFrame("FRAME", nil, self.scrollContent);		
		-- row.root:SetWidth(self.scrollContent:GetWidth() - 20);
        row.root:SetHeight(27);
        row.root:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
        row.root:SetBackdropColor(0, 0, 0, 0.3)
		if #self.rows == 0 then 
			row.root:SetPoint("TOPLEFT", self.scrollContent, 0, -25);
			row.root:SetPoint("RIGHT", self, 0, 0);
		else 
			row.root:SetPoint("TOPLEFT", self.rows[#self.rows].root, "BOTTOMLEFT", 0, -2);
			row.root:SetPoint("TOPRIGHT", self.rows[#self.rows].root, "BOTTOMRIGHT", 0, -2);
		end 
	end     
    row.root:Show();

    local playerDropdownOffX = -24

    if not row.statusImage then 
        row.statusFrame = CreateFrame("FRAME", nil, row.root);
        row.statusFrame:SetSize(16, 16)
        row.statusFrame:SetPoint("LEFT", 46, 0)  
        row.statusFrame:SetScript("OnLeave", function(self)
            GameTooltip_Hide();
        end);	
        row.statusImage = row.root:CreateTexture();
        row.statusImage:SetAllPoints(row.statusFrame)
    end 

    if activeRaid then 
        playerDropdownOffX = -10
        if entry.tradedTo then 
            RaidLogger_RaidWindow_LootTab:UpdateStatusImage(row, entry)
        else 
            row.statusImage:SetTexture(nil)
        end 
    else 
        row.statusImage:SetTexture(nil)
        row.statusFrame:SetScript("OnEnter", nil)
    end 
    
    if not row.timeLabel then 
		row.timeLabel = row.root:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
		row.timeLabel:SetTextColor(0.8, 0.8, 0.8, 1)
		row.timeLabel:SetPoint("RIGHT", row.root, "LEFT", 40, 0)
		row.timeLabel:SetFont(FONT_NAME, 10)
	end 
	row.timeLabel:SetText(date("%H:%M", entry.ts));

    if not row.playerDropdown then 
        row.playerDropdown = CreateFrame("Frame", "RaidLogger_RaidWindow_PlayerDropdown"..(self.visibleRows), row.root, "UIDropDownMenuTemplate")
        UIDropDownMenu_SetWidth(row.playerDropdown, 100) 
        UIDropDownMenu_JustifyText(row.playerDropdown, "LEFT")
    end 
    local function Dropdown_OnClick(self)
        entry.tradedTo = self.value 
        RaidLogger_RaidWindow_LootTab:TradedToChanged(row, entry)
        RaidLogger:Post(1, nil, SYNC_SUGGEST, entry.idx, entry.itemString, entry.tradedTo)
    end
    UIDropDownMenu_Initialize(row.playerDropdown, function (frame, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        info.func = Dropdown_OnClick
        for _, name in ipairs(players) do 
            info.text, info.checked = name, name == entry.tradedTo
            UIDropDownMenu_AddButton(info)
        end 
    end)
    row.playerDropdown:ClearAllPoints()
    row.playerDropdown:SetPoint("LEFT", row.statusImage, "RIGHT", playerDropdownOffX, -2)
    UIDropDownMenu_SetText(row.playerDropdown, entry.tradedTo or "")

	if not row.label then 
		row.labelFrame = CreateFrame("FRAME", nil, row.root);		
        -- row.labelFrame:SetPoint("RIGHT", row.root, "RIGHT", -10, 0)
		row.label = row.labelFrame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
		row.label:SetTextColor(0.8, 0.8, 0.8, 1)
		row.label:SetPoint("TOPLEFT", row.playerDropdown, "TOPRIGHT", -7, 0)
        row.label:SetPoint("BOTTOMLEFT", row.playerDropdown, "BOTTOMRIGHT", -7, 3)
        row.label:SetJustifyV("MIDDLE");
		row.label:SetFont(FONT_NAME, 10)

        row.labelFrame:SetPoint("TOPLEFT", row.label)
        row.labelFrame:SetPoint("BOTTOMLEFT", row.label)
        row.labelFrame:SetPoint("RIGHT", row.label)
	end 
    row.label:SetText(entry.link);
    
    if not row.yesButton then 
        row.yesButton = CreateFrame("BUTTON", nil, row.root);
        row.yesButton:SetSize(16, 16)
        row.yesButton:SetPoint("RIGHT", -8, 0)
        row.yesButton:RegisterForClicks("AnyUp")
    end 
    if not row.noButton then 
        row.noButton = CreateFrame("BUTTON", nil, row.root);
        row.noButton:SetSize(16, 16)
        row.noButton:SetPoint("RIGHT", row.yesButton, "LEFT", -8, 0)
        row.noButton:RegisterForClicks("AnyUp")
    end 
    local vote = entry.votes[UnitName("player")] 
    setButtonState(questionOp(vote == 1, 1, 0), "agree", row.yesButton)
    setButtonState(questionOp(vote == 0, 1, 0), "disagree", row.noButton)
    row.yesButton:SetScript("OnClick", function(self) 
        setButtonState(1, "agree", self)
        setButtonState(0, "disagree", row.noButton)
        entry.votes[UnitName("player")] = 1
        RaidLogger:Post(1, nil, SYNC_VOTE, entry.idx, entry.itemString, 1)
        RaidLogger:CheckVotes(entry)
    end)
    row.noButton:SetScript("OnClick", function(self) 
        setButtonState(1, "disagree", self)
        setButtonState(0, "agree", row.yesButton)
        entry.votes[UnitName("player")] = 0
        RaidLogger:Post(1, nil, SYNC_VOTE, entry.idx, entry.itemString, 0)
        RaidLogger:CheckVotes(entry)
    end)

    if votingEnabled and entry.tradedTo then 
        row.yesButton:Show()
        row.noButton:Show()
    else 
        row.yesButton:Hide()
        row.noButton:Hide()
    end 

    row.labelFrame:SetScript("OnEnter", function(self)
		-- self:SetBackdropColor(0.8, 0.8, 0.8, 0.6)
        GameTooltip:SetOwner(row.label, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(entry.link)
        GameTooltip:Show()
	end);
    
    row.labelFrame:SetScript("OnLeave", function(self)
        GameTooltip_Hide();
        -- row.root:SetBackdropColor(1, 1, 1, 0.2)
    end);	

    row.labelFrame:SetScript("OnMouseUp", function(self, ...)
		if IsShiftKeyDown() then
			PlaceLinkInChatEditBox(entry.link) -- paste in chat box
		elseif IsControlKeyDown() then
			DressUpItemLink(entry.link) -- preview
		end
    end);
    
	if not existingRow then 
		tinsert(self.rows, row);
	end 

	return row
end 

function RaidLogger_RaidWindow_LootTab:Refresh()
    self.visibleRows = 0
    
    if editRaid then 
        local title = (editRaid.zone or "??").." / "..editRaid.date
        if not editRaid.endTime then 
            title = title.." (active)"
        end
        RaidLogger_RaidWindow_Title_Text:SetText(title)

        local players = {}
        tinsert(players, "-- Disenchant --")
        tinsert(players, "-- Bank --")
        for name, attStatus in pairs(editRaid.players) do 
            if attStatus == "a" then tinsert(players, name) end 
        end 
        table.sort(players)

        local searchText = string.lower(RaidLogger_Loot_SearchBox:GetText())
        local votingEnabled = not editRaid.endTime and RaidLoggerStore.council and RaidLoggerStore.council[UnitName("player")]

        for i = #editRaid.loot, 1, -1 do
            local entry = editRaid.loot[i]
            local blueRecipe = entry.quality == 3 and (string.find(entry.item, "Recipe: ") == 1 or string.find(entry.item, "Formula: ") == 1 or string.find(entry.item, "Schematic: ") == 1);
            local epicItem = entry.quality >= 0
            local searchMatch = searchText == "" or string.find(string.lower(entry.item), searchText)
            if (epicItem or blueRecipe) and searchMatch then 
                self:AddRow(players, entry, not editRaid.endTime, votingEnabled)
            end 
        end
    end

    HideRowsBeyond(self.visibleRows + 1, self)
end


-- players tab ----------

function RaidLogger_RaidWindow_PlayersTab:AddRow(player, status) 
	self.visibleRows = self.visibleRows + 1

    local existingRow = self.rows[self.visibleRows]
	local row = existingRow or {};

	if not row.root then 
		row.root = CreateFrame("FRAME", nil, self.scrollContent);		
		-- row.root:SetWidth(self.scrollContent:GetWidth() - 20);
        row.root:SetHeight(28);
        row.root:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
        row.root:SetBackdropColor(0, 0, 0, 0.3)
		if #self.rows == 0 then 
			row.root:SetPoint("TOPLEFT", self.scrollContent, 0, -25);
			row.root:SetPoint("RIGHT", self, 0, 0);
		else 
			row.root:SetPoint("TOPLEFT", self.rows[#self.rows].root, "BOTTOMLEFT", 0, -2);
			row.root:SetPoint("TOPRIGHT", self.rows[#self.rows].root, "BOTTOMRIGHT", 0, -2);
		end 
	end     
    row.root:Show();

    if not row.statusDropdown then 
        local function Dropdown_OnClick(self)
            editRaid.players[player] = AttStatusFromString(self.value)
            -- out("Setting attendance status of "..player.." to "..editRaid.players[player])
            UIDropDownMenu_SetText(row.statusDropdown, self.value)
        end
        row.statusDropdown = CreateFrame("Frame", "RaidLogger_RaidWindow_PlayersTab_StatusDropdown"..(self.visibleRows), row.root, "UIDropDownMenuTemplate")
        row.statusDropdown:SetPoint("LEFT", row.root, "LEFT", 13, -2)
        UIDropDownMenu_SetWidth(row.statusDropdown, 100) 
        UIDropDownMenu_JustifyText(row.statusDropdown, "LEFT")
        UIDropDownMenu_Initialize(row.statusDropdown, function (frame, level, menuList)
            local info = UIDropDownMenu_CreateInfo()
            info.func = Dropdown_OnClick
            info.text, info.checked = "Attended", STATE_ATTENDED == status
            UIDropDownMenu_AddButton(info)
            info.text, info.checked = "Benched", STATE_BENCHED == status
            UIDropDownMenu_AddButton(info)
        end)
    end 
    UIDropDownMenu_SetText(row.statusDropdown, AttStatusToString(status))    
        
    if not row.deleteButton then 
        row.deleteButton = CreateFrame("BUTTON", nil, row.root);
        row.deleteButton:SetSize(16, 16)
        row.deleteButton:SetPoint("LEFT", 7, 0)
        row.deleteButton:RegisterForClicks("AnyUp")
        row.deleteButton:SetNormalTexture("Interface\\AddOns\\RaidLogger\\assets\\delete")
        row.deleteButton:SetPushedTexture("Interface\\AddOns\\RaidLogger\\assets\\delete")
        row.deleteButton:SetHighlightTexture("Interface\\AddOns\\RaidLogger\\assets\\delete")
    end 
    row.deleteButton:SetScript("OnClick", function() 
        RaidLogger:AskQuestion("Remove Player", "Do you want to remove "..player.."\nfrom attendance list?", function()  
            editRaid.players[player] = nil 
            self:Refresh()
        end, nil, "Remove", "Cancel") 
    end)

    if not row.label then 
		row.label = row.root:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
		row.label:SetPoint("LEFT", row.statusDropdown, "RIGHT", -4, 2)
        row.label:SetJustifyV("MIDDLE");
		row.label:SetFont(FONT_NAME, 10)
    end 
    local rPerc, gPerc, bPerc, argbHex = GetClassColor(strupper(RaidLoggerStore.players[player] or "PRIEST"))
    row.label:SetTextColor(rPerc, gPerc, bPerc, 1)
    row.label:SetText(player);

	if not existingRow then 
		tinsert(self.rows, row);
	end 

	return row
end 

function RaidLogger_RaidWindow_PlayersTab:Refresh()
    self.visibleRows = 0
    
    if editRaid then 
        local players = {}
        for name, attStatus in pairs(editRaid.players) do 
            tinsert(players, name)
        end 
        table.sort(players)

        local searchText = string.lower(RaidLogger_Players_SearchBox:GetText())

        for _, name in ipairs(players) do
            local searchMatch = searchText == "" or string.find(string.lower(name), searchText)
            if searchMatch then 
                self:AddRow(name, editRaid.players[name])
            end 
        end
    end 

    HideRowsBeyond(self.visibleRows + 1, self)
end




-- raids tab ----------

function RaidLogger_RaidWindow_RaidsTab:AddRow(raid, raidIndex) 
	self.visibleRows = self.visibleRows + 1

    local existingRow = self.rows[self.visibleRows]
	local row = existingRow or {};

	if not row.root then 
		row.root = CreateFrame("BUTTON", nil, self.scrollContent);		
		-- row.root:SetWidth(self.scrollContent:GetWidth() - 20);
        row.root:SetHeight(28);
        row.root:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
        row.root:SetBackdropColor(0, 0, 0, 0.3)
        row.root:RegisterForClicks("AnyUp")
        row.root:SetScript("OnEnter", function(self)
            row.root:SetBackdropColor(0.5, 0.5, 0.5, 0.3)
        end);
        
        row.root:SetScript("OnLeave", function(self)
            row.root:SetBackdropColor(0, 0, 0, 0.3)
        end);	
		if #self.rows == 0 then 
			row.root:SetPoint("TOPLEFT", self.scrollContent, 0, -25);
			row.root:SetPoint("RIGHT", self, 0, 0);
		else 
			row.root:SetPoint("TOPLEFT", self.rows[#self.rows].root, "BOTTOMLEFT", 0, -2);
			row.root:SetPoint("TOPRIGHT", self.rows[#self.rows].root, "BOTTOMRIGHT", 0, -2);
		end 
	end     
    row.root:SetScript("OnClick", function() 
        editRaid = raid 
        editRaidIndex = raidIndex
        RaidLogger_RaidWindow:Refresh()
        RaidLogger_RaidWindow_Buttons_LootTab:Clicked()
    end)
    row.root:Show();
        
    if not row.deleteButton then 
        row.deleteButton = CreateFrame("BUTTON", nil, row.root);
        row.deleteButton:SetSize(16, 16)
        row.deleteButton:SetPoint("LEFT", 7, 0)
        row.deleteButton:RegisterForClicks("AnyUp")
        row.deleteButton:SetNormalTexture("Interface\\AddOns\\RaidLogger\\assets\\delete")
        row.deleteButton:SetPushedTexture("Interface\\AddOns\\RaidLogger\\assets\\delete")
        row.deleteButton:SetHighlightTexture("Interface\\AddOns\\RaidLogger\\assets\\delete")
    end 
    row.deleteButton:SetScript("OnClick", function() 
        local question = "Do you want to delete this raid?"
        if not editRaid.endTime then 
            question = "Do you want to discard active raid?"
        end 
        RaidLogger:AskQuestion("Delete Raid", question, function()  
            if not editRaid.endTime then 
                out("Raid has been discarded.")
                RaidLoggerStore.activeRaid = nil
            else
                table.remove(RaidLoggerStore.raids, editRaidIndex)
            end 
            RaidLogger:ChooseLastRaid()
            RaidLogger_RaidWindow:Refresh()
        end, nil, "Remove", "Cancel") 
    end)

    if not row.dateLabel then 
		row.dateLabel = row.root:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
		row.dateLabel:SetPoint("LEFT", row.deleteButton, "RIGHT", 10, 0)
        row.dateLabel:SetJustifyV("MIDDLE");
		row.dateLabel:SetFont(FONT_NAME, 10)
    end 
    row.dateLabel:SetText(raid.date);

    if not row.zoneLabel then 
		row.zoneLabel = row.root:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
		row.zoneLabel:SetPoint("LEFT", row.deleteButton, "RIGHT", 100, 0)
        row.zoneLabel:SetJustifyV("MIDDLE");
		row.zoneLabel:SetFont(FONT_NAME, 10)
    end 
    local text = raid.zone or ""
    if not raid.endTime then 
        text = text .. " (active)"
    end 
    row.zoneLabel:SetText(text);

	if not existingRow then 
		tinsert(self.rows, row);
	end 

	return row
end 

function RaidLogger_RaidWindow_RaidsTab:Refresh()
    self.visibleRows = 0

    if RaidLoggerStore.activeRaid then 
        self:AddRow(RaidLoggerStore.activeRaid)
    end 
    
    for i = #RaidLoggerStore.raids, 1, -1 do
        local raid = RaidLoggerStore.raids[i]
        self:AddRow(raid, i)
    end

    HideRowsBeyond(self.visibleRows + 1, self)
end
