--
-- Created by IntelliJ IDEA.
-- User: kof
-- Date: 11/04/2019
-- Time: 18:36
--

local VERSION = 2.10
local MIN_RAID_PLAYERS = 10
local ADDON_NAME = "RaidLogger"
local FONT_NAME = "Fonts\\FRIZQT__.TTF"
local ADDON_PREFIX = "RaidLogger"
local WFCOMM_PREFIX_CREDIT = "WF_CREDIT"

-- local CORE_LEATHER_NAME = "Linen Cloth"
local CORE_LEATHER_NAME = "Core Leather"
local ACTIVE_RAID_TIMEOUT = 3600 * 12

local SPELL_TABLE = { [564] = 'WF3', [563] = 'WF2', [1783] = 'WF1' }

local TRACKED_INSTANCES = {
    [409] = "The Molten Core",
    [469] = "Blackwing Lair",
    [249] = "Onyxia's Lair",
    [531] = "Ahn'Qiraj",
    [533] = "Naxxramas",
    [309] = "Zul'Gurub",
    [509] = "Ruins of Ahn'Qiraj",
    [389] = "Ragefire Chasm",
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
    [20863] = "Clay Scarab",
    [20858] = "Stone Scarab",
    [20859] = "Gold Scarab",
    [20860] = "Silver Scarab",
    [20861] = "Bronze Scarab",
    [20862] = "Crystal Scarab",
    [20864] = "Bone Scarab",
    [20865] = "Ivory Scarab",
    [22373] = "Wartorn Leather Scrap",
    [22375] = "Wartorn Plate Scrap",
    [22374] = "Wartorn Chain Scrap",
    [22376] = "Wartorn Cloth Scrap",
    [20881] = "Idol of Strife",
    [20874] = "Idol of the Sun",
    [20882] = "Idol of War",
    [20875] = "Idol of Night",
    [20877] = "Idol of the Sage",
    [20878] = "Idol of Rebirth",
    [20876] = "Idol of Death",
    [20879] = "Idol of Life",
    [20725] = "Nexus Crystal",
    [16203] = "Greater Eternal Essence",
    [16204] = "Illusion Dust",
    [14344] = "Large Brilliant Shard",
    [22682] = "Frozen Rune",
}

local HIDDEN_ITEMS = {
    [18562] = "Elementium Ore",
}
-- copy IGNORED_ITEMS into HIDDEN_ITEMS
for k,v in pairs(IGNORED_ITEMS) do HIDDEN_ITEMS[k] = v end

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

local QUALITY_TEXT = {
    [0] = "Poor",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",    
    [5] = "Legendary",
}

local SYNC_LOOT = "loot"
local SYNC_COUNCIL = "council"
local SYNC_COUNCIL_WHO = "council?"
local SYNC_VOTE = "vote"
local SYNC_SUGGEST = "suggest"
local SYNC_PING = "ping"
local SYNC_PONG = "pong"
local SYNC_CHECK = "check"
local SYNC_CHECK_REPLY = "check-reply"
local SYNC_RESEND = "resend"
local SYNC_END = "end"

local SYNC_COOLDOWN_SECONDS = 60
local NEXT_SYNC_CHECK_MIN_SECONDS = 60
local NEXT_SYNC_CHECK_RANDOM_SECONDS = 60
local NEXT_SYNC_CHECK_SOON_MIN_SECONDS = 10
local NEXT_SYNC_CHECK_SOON_RANDOM_SECONDS = 10

local DROPDOWN_DISENCHANT_NAME = "-- Disenchant --"
local DROPDOWN_BANK_NAME = "-- Bank --"
local DROPDOWN_FFA_NAME = "-- FFA --"

local BUFF_CHECK_SECONDS = 60 

local lastBuffCheck = 0
local editRaid = nil 
local editRaidIndex = nil
local lastCouncilSync = 0
local votingEnabled = false 
local nextSyncCheck = 0
local lastSync = 0
local firstSyncMismatch = 0
local lootMismatchs = 0
local outOfSync = false
local syncingNow = false
local tradedItems = {}
local tradingWith = nil

RaidLoggerDelayedMessages = {}
RaidLoggerPendingLoot = {}

RaidLoggerStore = {
    raids = {},
    activeRaid = nil,
    players = {},
    qualityToLog = QUALITY_RARE,
}

RaidLogger = {}

local function questionOp(cond, trueValue, falseValue)
    if cond then 
        return trueValue
    end 
    return falseValue
end 

local function out(text, ...)
	print(" |cff0088ff{|cff00bbffRaidLogger|cff0088ff}|r "..text, ...)
end 

local function debug(text, ...)
    if RaidLoggerStore.debug then 
        print(" |cff0088ff{|cff00bbffRaidLogger|cff0088ff}|r |cff009999DEBUG|cff999999", text, ...)
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

local function getSelfPlayerName()
    return UnitName("player").."-"..GetRealmName()
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
    local name, _, _, _, _, _, _, mapID, _ = GetInstanceInfo()
    if TRACKED_INSTANCES[mapID] then return TRACKED_INSTANCES[mapID], mapID end
    return nil, nil
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

local function FixPlayerRealm(player)
    if not string.find(player, "-") then 
        return player.."-"..GetRealmName()
    end
    return player
end

local function ColorName(who)
    return (CLASS_COLOR[RaidLoggerStore.players[who] or "Unknown"] or CLASS_COLOR["Unknown"]) .. who .. "|r"
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
    err("                /rlog end")
    err(" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
end

local function ItemStringFromLink(itemLink) 
    local startIndex, _ = string.find(itemLink, "item")
    local _, endIndex = string.find(itemLink, "h%[")
    return string.sub(itemLink, startIndex, endIndex-3)
end 

local function ItemIdFromLink(itemLink) 
    local parts = {_G.string.split(":", itemLink)}
    return tonumber(parts[2])
end 

-- loot can be itemId
local function LogLoot(who, loot, quantity, ts, tradedTo, votes, status, lootid)
    -- local vStartIndex, vEndIndex, vLinkColor, vItemCode, vItemEnchantCode, vItemSubCode, vUnknownCode, vItemName = strfind(loot, "|c(%x+)|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[([^%]]+)%]|h|r");
    local itemName, itemLink, quality, _, _, itemType, _, _, _, _, vendorPrice = GetItemInfo(loot);
    who = FixPlayerRealm(who)

    if not itemLink then
        debug("Adding item to RaidLoggerPendingLoot - "..who..","..loot..","..quantity)
        tinsert(RaidLoggerPendingLoot, {who, loot, quantity or 1, ts, tradedTo, votes, status, lootid})
        return
    end 

    itemLink = normalizeLink(itemLink)
    local itemString = ItemStringFromLink(itemLink)
    local itemId = ItemIdFromLink(itemLink)
    lootid = lootid or (#RaidLoggerStore.activeRaid.loot + 1)

    if IGNORED_ITEMS[itemId] then 
        --debug("Ignoring loot (blacklist): " .. ColorName(who) .. " received " .. itemLink)
        return
    end 

    -- debug("Checking dup of - "..lootid..","..itemString)
    for i = #RaidLoggerStore.activeRaid.loot, 1, -1 do 
        local loggedItem = RaidLoggerStore.activeRaid.loot[i]
        -- debug("Checking dup with - "..loggedItem.lootid..","..loggedItem.itemString)
        if loggedItem.lootid == lootid then 
            if loggedItem.itemString == itemString then 
                debug("Found matching loot entry")
            else 
                out("|cffff0000Loot log isn't synced!")
            end
            return 
        end 
    end

    if who and itemName == CORE_LEATHER_NAME then 
        if not RaidLoggerStore.activeRaid.sands then RaidLoggerStore.activeRaid.sands = {} end 
        RaidLoggerStore.activeRaid.sands[who] = (RaidLoggerStore.activeRaid.sands[who] or 0) + 1
    end 

    if who and quality >= RaidLoggerStore.qualityToLog then
        out("Logged loot: " .. ColorName(who) .. " received " .. itemLink)
        local entry = {
            player = who,
            item = itemName,
            ts = ts or time(),
            link = itemLink,
            quality = quality,
            quantity = quantity,
            votes = votes or {},
            status = status or 0,
            lootid = lootid,
            itemString = itemString,
            tradedTo = tradedTo,

        }
        table.insert(RaidLoggerStore.activeRaid.loot, entry)
        RaidLogger_RaidWindow_LootTab:Refresh()

        if not ts then 
            local count = #RaidLoggerStore.activeRaid.loot
            RaidLogger:PostLootEntry(entry, count.."/"..count, 3, nil)
        end 
    else 
        --debug("Ignoring loot (quality): " .. ColorName(who) .. " received " .. itemLink)
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

function RaidLogger:ParseLootMessage(msg)
    -- debug("ParseLootMessage "..msg)
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

local function RaidLogger_Commands(msg)
    -- local _, _, cmd, arg1 = string.find(msg, "([%w]+)%s*(.*)$");
    local cmd, arg1 = _G.string.split(" ", msg)
    cmd = string.upper(cmd) 
    -- out("cmd '" .. cmd .. "'")
    if not cmd or #cmd == 0 then
        RaidLoggerStore.windowShown = not RaidLoggerStore.windowShown
        if RaidLoggerStore.windowShown then 
            RaidLogger:ChooseLastRaid()
            RaidLogger_RaidWindow:Refresh()
            RaidLogger_RaidWindow:Show()
        else 
            RaidLogger_RaidWindow:Hide()
        end 
    elseif  "S" == cmd or "START" == cmd then
        local zone = nil 
        if arg1 and #arg1 > 1 then 
            zone = string.sub(msg, #cmd + 2)
            debug("Custom zone '"..zone.."'")
        end 
        RaidLogger:UpdateRaid(zone)
    elseif  "H" == cmd or "HELP" == cmd then
        out("Commands: ")
        out("  |cFF00FF00/rlog|r - show UI")
        out("  |cFF00FF00/rlog |cFF00ff95a|cFF00FF00dd <player>|r - manually log an attended player.")
        out("  |cFF00FF00/rlog |cFF00ff95b|cFF00FF00ench <player>|r - log a benched player.")
        out("  |cFF00FF00/rlog |cFF00ff95q|cFF00FF00uality <1-5>|r - set minimum level of loot quality to log. ("..QUALITY_TEXT[RaidLoggerStore.qualityToLog]..")")
        out("  |cFF00FF00/rlog log <itemlink> <receiver>|r - manually add looted item.")
        out("  |cFF00FF00/rlog de|r - marks last distributed loot item as disenchanted.")
        out("  |cFF00FF00/rlog os|r - marks last distributed loot as an off-spec item.")
        out("  |cFF00FF00/rlog discard|r - discard current raid, do this to ignore current raid.")        
        out("  |cFF00FF00/rlog end|r - save and close raid, do this when raid ended.")
        out("  |cFF00FF00/rlog p|r - print active raid, if any.")
        out("  |cFF00FF00/rlog start|r - start logging a raid or update existing one.")
        out("  |cFF00FF00/rlog sand <channel>|r - print a list of players who picked [Hourglass Sand]. Channel can be raid/yell/guild or empty for say.")
        out("  |cFF00FF00/rlog ping|r - check who's on your sync channel.")
        out("  |cFF00FF00/rlog password <password>|r - sets sync channel. Leave <password> empty to print the password.")
        out("  |cFF00FF00/rlog resync <player>|r - requests for full loot re-sync from <player>, make sure he's in your sync channel.")
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
                    out("Incorrect usage of command, write |cff00ff00/rlog log [ITEM_LINK] [RECEIVER_NAME]")
                end 
            end				
        else 
            out("Incorrect usage of command, write |cff00ff00/rlog log [ITEM_LINK] [RECEIVER_NAME]")
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
    elseif  "PASSWORD" == cmd then
        if arg1 and string.len(arg1) > 0 then
            if string.len(arg1) > 6 then 
                return out("Password is too long! Max length is 6 characters.")
            end 
            RaidLoggerStore.sync = arg1 
            ReloadUI()
        else
            out("Current sync password: |cff00ff00" .. RaidLoggerStore.sync)
        end
    elseif  "CHECK" == cmd then
        lootMismatchs = 0
        RaidLogger:Post(0, nil, SYNC_CHECK, VERSION) 
    elseif  "TOTEMS" == cmd then
        RaidLogger:PrintTotemUptimeForLastRaid(arg1 and tonumber(arg1))
    elseif  "RESYNC" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLoggerStore.activeRaid.loot = {}
            lastSync = 0
            out("Requesting full item resync from "..arg1)
            RaidLogger:FullResync(arg1)
        else 
            err("Missing sync target! Write /rlog resync <PLAYER_NAME>")
        end 
    elseif  "RESEND" == cmd then
        if arg1 and string.len(arg1) > 0 then
            local entry = RaidLoggerStore.activeRaid.loot[tonumber(arg1)]
            local count = #RaidLoggerStore.activeRaid.loot
            RaidLogger:PostLootEntry(entry, count.."/"..count, 1, nil)
        else 
            err("Missing sync target! Write /rlog resync <PLAYER_NAME>")
        end 
    elseif  "PING" == cmd then 
        out("Sending PING query...")
        RaidLogger:Post(0, nil, SYNC_PING)
    elseif  "SAND" == cmd then 
        if not editRaid.sands then 
            out("No sands log in selected raid.")
            return 
        end 
        local sorted = {}
        for name in pairs(editRaid.sands) do table.insert(sorted, name) end
        if #sorted == 0 then 
            out("No sands were logged in selected raid.")
            return 
        end 
        table.sort(sorted)
        local output = "The following players have looted |cffffffff|Hitem:19183::::::::60:::::::|h[Hourglass Sand]|h|r: "
        for i = 1, #sorted do 
            local name = sorted[i]
            output = output .. name .. " x" .. editRaid.sands[name]
            if i < #sorted then output = output .. ", " end 
        end
        SendChatMessage(output, arg1)
    elseif  "CLEAR" == cmd then
        RaidLoggerStore.activeRaid.loot = {}
        RaidLogger_RaidWindow_LootTab:Refresh()
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
    elseif  "Q" == cmd or "QUALITY" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLoggerStore.qualityToLog = tonumber(arg1)
            out("Minimum quality to log changed to |cff00ff00"..QUALITY_TEXT[RaidLoggerStore.qualityToLog])
        else
            out("Current miniimum quality to log: |cff00ff00"..QUALITY_TEXT[RaidLoggerStore.qualityToLog])
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
        RaidLogger:DiscardRaid()
    elseif  "VERSION" == cmd or "V" == cmd then
        out("Version |cFFFFFF00" .. VERSION)
    elseif  "DEBUG" == cmd then
        RaidLoggerStore.debug = not RaidLoggerStore.debug
        out("Debug mode: " .. tostring(RaidLoggerStore.debug))
    elseif  "END" == cmd then
        out("Raid ended, saving.")
        RaidLogger:EndRaid()
        RaidLogger:Post(0, nil, SYNC_END)
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
        buffs = {},
        wf = {},
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
    nextSyncCheck = 1 -- check with other raiders if there's loot going on
end

function RaidLogger:DiscardRaid() 
    if RaidLoggerStore.activeRaid then
        out("Raid has been discarded.")
        RaidLoggerStore.activeRaid = nil
        RaidLogger:ChooseLastRaid()
        RaidLogger_RaidWindow:Refresh()
    else
        out("No active raid.")
    end
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
    player = FixPlayerRealm(player)
    if RaidLoggerStore.activeRaid.players[player] ~= STATE_ATTENDED then 
        out("Logging attendance for " .. ColorName(player))
        RaidLoggerStore.activeRaid.players[player] = STATE_ATTENDED
        RaidLogger_RaidWindow_PlayersTab:Refresh()
        RaidLogger_RaidWindow_LootTab:Refresh() -- refresh player list
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

function RaidLogger:UpdateRaid(forceZone)
    local raidSize = GetNumRaidMembers()

    if raidSize == 0 then
        out("Not in a raid!")
        return
    end

    -- out("Updating raid...")

    if not RaidLoggerStore.activeRaid then
        RaidLogger:StartRaid();
    end

    if forceZone and #forceZone > 2 then 
        RaidLoggerStore.activeRaid.zone = forceZone
        RaidLoggerStore.activeRaid.zoneid = "0"
    end 

    -- save zone
    if not RaidLoggerStore.activeRaid.zone then
        local zone, zoneId = InTrackedInstance()
        if zoneId then
            RaidLoggerStore.activeRaid.zone = zone
            RaidLoggerStore.activeRaid.zoneId = zoneId
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
            name = FixPlayerRealm(name)
            RaidLogger:LogAttended(name)
            RaidLoggerStore.players[name] = class
        end
    end

    -- out("Attendance updated.")
end

function RaidLogger:ChooseLastRaid()
    editRaidIndex = nil 
    if not RaidLoggerStore.activeRaid then 
        if RaidLoggerStore.raids and #RaidLoggerStore.raids > 0 then 
            editRaidIndex = #RaidLoggerStore.raids
            editRaid = RaidLoggerStore.raids[editRaidIndex]
        else 
            editRaid = nil 
        end 
    else 
        editRaid = RaidLoggerStore.activeRaid 
    end 
    if editRaid then 
        if not editRaid.players then editRaid.players = {} end 
    end 
end


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--   TRADE

function RaidLogger:OnTradeShow()
    -- reset list
    tradedItems = {}
    local name, realm = UnitName("npc")
    tradingWith = name.."-"..(realm or GetRealmName())
end

function RaidLogger:OnTradePlayerItemChanged(tradeSlotIndex)
    local ItemName, _, Quantity, _, Enchantment = GetTradePlayerItemInfo(tradeSlotIndex)
    if not ItemName then
        -- debug("Clearing slot "..tradeSlotIndex)
		tradedItems[tradeSlotIndex] = nil
		return
	end

    local itemLink = normalizeLink(GetTradePlayerItemLink(tradeSlotIndex))
    local itemString = ItemStringFromLink(itemLink)
    local found = nil
    local selfPlayerName = getSelfPlayerName();
    -- debug("itemLink "..itemLink)
    -- debug("itemString "..itemString)

    for i = #RaidLoggerStore.activeRaid.loot, 1, -1 do 
        local loggedItem = RaidLoggerStore.activeRaid.loot[i]
        -- debug("Checking dup with - "..loggedItem.lootid..","..loggedItem.itemString)
        if loggedItem.itemString == itemString and (not loggedItem.tradedTo or loggedItem.tradedTo == selfPlayerName) then 
            found = i
        end
    end
    if not found then 
        debug("Item "..itemLink.." on slot "..tradeSlotIndex.." is not in our list of logged loot!")
        tradedItems[tradeSlotIndex] = nil
        return 
    end 
        
    debug("Found trade of logged item #"..found..": ".. itemLink)
    tradedItems[tradeSlotIndex] = found
end

function RaidLogger:OnTradeAcceptUpdate()
    for i = 1, 6 do
        RaidLogger:OnTradePlayerItemChanged(i)
    end
end

function RaidLogger:OnUiInfoMessage(errorType, message) 
    -- debug("Trade UI message: "..message)
    -- debug("Trading with: "..tradingWith)
    if message == ERR_TRADE_COMPLETE and tradingWith then
        for k, i in pairs(tradedItems) do
            if i then 
                debug("Trade completed - changing item "..i.." to "..tradingWith)
                local loggedItem = RaidLoggerStore.activeRaid.loot[i]            
                loggedItem.tradedTo = tradingWith 
                local row = self:FindRow(loggedItem.lootid)
                RaidLogger_RaidWindow_LootTab:TradedToChanged(row, loggedItem)
                RaidLogger:Post(1, nil, SYNC_SUGGEST, loggedItem.lootid, loggedItem.itemString, loggedItem.tradedTo)
            end
        end
    end
end


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--   Totems tracking

local function IncreaseUptime(stats, reporter, shaman, totem, combatTime, uptime)
    if not uptime or uptime == "0" then return end
    if not stats[shaman] then
        stats[shaman] = {}
    end
    if not stats[shaman][reporter] then
        stats[shaman][reporter] = {}
    end
    if not stats[shaman][reporter][totem] then
        stats[shaman][reporter][totem] = {
            t = tonumber(combatTime),
            u = tonumber(uptime),
        }
    else
        stats[shaman][reporter][totem].t = stats[shaman][reporter][totem].t + tonumber(combatTime)
        stats[shaman][reporter][totem].u = stats[shaman][reporter][totem].u + tonumber(uptime)
    end
end

local function HandleTotemCreditMessage(combatTime, wfTime, shaman, strTime, agiTime, frTime, frrTime, gndTime, reporter, channel)
    debug('|c99ff9900'..channel..'|r', '|cff99ff00'..reporter..'|r', ''..combatTime, ''..wfTime, ''..shaman, strTime or '-', agiTime or '-', frTime or '-', frrTime or '-', gndTime or '-')
    if RaidLoggerStore.activeRaid and combatTime and combatTime ~= "0" then
        local totemStats = RaidLoggerStore.activeRaid.totemStats
        if not totemStats then
            RaidLoggerStore.activeRaid.totemStats = {}
            totemStats = RaidLoggerStore.activeRaid.totemStats
        end
        IncreaseUptime(totemStats, reporter, shaman, "wf", combatTime, wfTime)
        IncreaseUptime(totemStats, reporter, shaman, "str", combatTime, strTime)
        IncreaseUptime(totemStats, reporter, shaman, "agi", combatTime, agiTime)
        IncreaseUptime(totemStats, reporter, shaman, "fr", combatTime, frTime)
        IncreaseUptime(totemStats, reporter, shaman, "frr", combatTime, frrTime)
        IncreaseUptime(totemStats, reporter, shaman, "gnd", combatTime, gndTime)
    end
end

function RaidLogger:CalcAverageUptimePerShaman(stats)
    local shamanUptime = {}
    for shaman, reporters in pairs(stats) do
        local shamanStats = {}
        shamanUptime[shaman] = shamanStats
        local count = 0
        local maxCombatTime = 0
        for reporter, totems in pairs(reporters) do
            count = count + 1
            for totem, data in pairs(totems) do
                if not shamanStats[totem] then
                    shamanStats[totem] = {
                        t = 0,
                        u = 0,
                    }
                else
                    shamanStats[totem].t = shamanStats[totem].t + data.t
                    shamanStats[totem].u = shamanStats[totem].u + data.u
                end
                if shamanStats[totem].t > maxCombatTime then
                    maxCombatTime = shamanStats[totem].t
                end
            end
        end
        if count > 0 then
            for totem, data in pairs(shamanStats) do
                data.t = maxCombatTime / count
                data.u = data.u / count
            end
        end
    end
    return shamanUptime
end

local function UptimeText(uptimePercent, totem)
    local color = '|cff5599ff'
    if uptimePercent > 90 or totem and uptimePercent > 8 then
        color = '|cff00ff00'
    elseif uptimePercent > 80 or totem and uptimePercent > 4 then
        color = '|cffb9f542'
    elseif uptimePercent > 60 or totem and uptimePercent > 2 then
        color = '|cfff5ef42'
    elseif uptimePercent > 40 or totem and uptimePercent > 0 then
        color = '|cffff2222'
    end
    return color..tostring(uptimePercent)..'%|r'
end

local function UptimeTextSeconds(uptimeSec, combatTime, totem)
    local uptimePercent = 0
    if combatTime and combatTime > 0 then
        local p = uptimeSec / combatTime * 100
        if p > 10 then
            uptimePercent = math.floor(uptimeSec / combatTime * 100)
        else
            uptimePercent = math.floor(uptimeSec / combatTime * 1000) / 10
        end
    end
    return UptimeText(uptimePercent, totem)
end

function RaidLogger:PrintTotemUptimeForLastRaid(n)
    local raid = RaidLoggerStore.activeRaid
    if not raid then
        raid = RaidLoggerStore.raids[#RaidLoggerStore.raids - (n or 0)]
    end
    if not raid.totemStats then
        out("No totem stats available.")
        return
    end
    out("Totem uptime for " .. raid.date .. " (" .. raid.zone .. ")")
    local shamanUptime = RaidLogger:CalcAverageUptimePerShaman(raid.totemStats)
    local printOrder = { "wf", "str", "agi", "fr", "frr", "gnd" }
    for _, totem in pairs(printOrder) do
        out("  " .. string.upper(totem) .. ":")
        local stats = {}
        for shaman, shamanTotems in pairs(shamanUptime) do
            if shamanTotems[totem] and shamanTotems[totem].t > 0 then
                table.insert(stats, {
                    amount = math.floor(shamanTotems[totem].u / shamanTotems[totem].t * 10000),
                    shaman = shaman,
                })
            end
        end
        table.sort(stats, function(a, b)
            return a.amount > b.amount
        end)
        for _, obj in pairs(stats) do
            local data = shamanUptime[obj.shaman][totem]
            out("       " .. UptimeTextSeconds(data.u, data.t, totem) .. "  " .. obj.shaman)
        end
    end
end


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--   SYNC

function RaidLogger:OnAddonMessage(prefix, text, channel, sender, target)
    --debug("|cff99ff00"..prefix.."|r "..text)
    if RaidLoggerStore.sync and prefix == ADDON_PREFIX..RaidLoggerStore.sync then
        RaidLogger:OnSyncMessage(text, channel, sender, target)
    elseif prefix == WFCOMM_PREFIX_CREDIT then
        RaidLogger:OnWfMessage(text, channel, sender, target)
    end
end

function RaidLogger:OnWfMessage(text, channel, sender, target)
    local combatTime, wfTime, shaman, strTime, agiTime, frTime, frrTime, gndTime = strsplit(":", text)
    HandleTotemCreditMessage(combatTime, wfTime, shaman, strTime, agiTime, frTime, frrTime, gndTime, sender, channel)
end

function RaidLogger:OnSyncMessage(text, channel, sender, target)
    -- sender = removeRealmName(sender)
    if sender == getSelfPlayerName() then return end 
    local parts = splitCsv(text)
    debug("SYNC IN - ["..sender.."]: "..text)

    local function VerifyLoot(parts) 
        if not RaidLoggerStore.activeRaid then 
            out("Couldn't set vote, no active raid")
            return nil
        end 
        local lootid = tonumber(parts[2])
        local entry = self:FindEntry(lootid)
        if not entry then 
            out("|cffffff00Couldn't find loot "..lootid)
            nextSyncCheck = 1 -- sync now, if possible
            return nil
        end 
        if entry.itemString ~= parts[3] then 
            out("|cffffff00Wrong item found with id "..lootid..", expected "..parts[3].." but got "..entry.itemString)
            nextSyncCheck = 1 -- sync now, if possible
            return nil
        end 
        return entry 
    end 

    if parts[1] == SYNC_LOOT then 
        -- 2-receiver, 3-itemString, 4-quantity, 5-ts, 6-index, 7-tradedTo, 8-status, 9-votes
        if RaidLoggerStore.activeRaid then 
            local version = tonumber(parts[2])
            if not version then 
                debug("|cffff0000"..sender.." is using an old version, ignoring loot message")
                return 
            end 
            local t = time() - 10
            -- local zone = #parts >= 12 and parts[12]
            local _votes = parts[11]
            local status = tonumber(parts[10])
            local tradedTo = parts[9]
            local lootid = tonumber(parts[8])
            local ts = tonumber(parts[7])
            local quantity = tonumber(parts[6])
            local itemString = parts[5]
            local who = parts[4]
            local lootProgress = parts[3] -- 1/4  2/4  3/4  4/4 

            -- if zone and zone ~= RaidLoggerStore.activeRaid.zone then 
            --     return -- ignore loot reports from a different zone, it may have different loot count
            -- end 
    
            local lootCountBefore = #RaidLoggerStore.activeRaid.loot
            local shouldAdd = true
            for i = #RaidLoggerStore.activeRaid.loot, 1, -1 do 
                local loggedItem = RaidLoggerStore.activeRaid.loot[i]
                if loggedItem.itemString == itemString then 
                    shouldAdd = false 
                    debug("Found matching loot entry")
                    break -- found it
                end
            end
            if shouldAdd then 
                if tradedTo == "_" then tradedTo = nil end 
                local votes = {}
                if _votes and #_votes > 0 then 
                    local votesParts = {_G.string.split("|", _votes)}
                    for _, vote in ipairs(votesParts) do 
                        local voteParts = {_G.string.split("-", vote)}
                        votes[voteParts[1]] = tonumber(voteParts[2])
                    end 
                end 
                debug("SYNC LOOT who="..who.." itemString="..itemString.." quantity="..quantity.." ts="..ts.." tradedTo="..tostring(tradedTo).." lootid="..(lootid or "nil"))
                LogLoot(who, itemString, quantity, ts, tradedTo, votes, status, lootid)
            end 

            local progressParts = {_G.string.split("/", lootProgress)}
            if outOfSync and progressParts[1] == progressParts[2] then 
                syncingNow = false
                -- last item, using lootCountBefore because item may have been sent to query 
                -- and RaidLoggerStore.activeRaid.loot hasn't changed yet
                if lootCountBefore + 1 == tonumber(progressParts[2]) then 
                    outOfSync = false
                    lootMismatchs = 0
                    firstSyncMismatch = 0
                else 
                    err("Resync ended, but we still don't have the same number of items as "..sender)
                end 
            end 
        else 
            out("|cffffff00Received loot sync, but no active raid - ignoring")
        end 

    elseif parts[1] == SYNC_COUNCIL then 
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

    elseif parts[1] == SYNC_COUNCIL_WHO then 
        local currentCouncil = self:PackLootCouncil()
        if #currentCouncil > 0 then 
            self:AnnounceLootCouncil(currentCouncil)
        end 

    elseif parts[1] == SYNC_PING then 
        out("Received PING from "..sender)
        self:Post(0, sender, SYNC_PONG, VERSION)

    elseif parts[1] == SYNC_PONG then 
        out("Received PONG from |cff88ff00"..sender.."|r version |cff88ff00"..parts[2])

    elseif parts[1] == SYNC_VOTE then 
        local entry = VerifyLoot(parts)
        if not entry then return end 
        
        if entry.votes[sender] == tonumber(parts[4]) then return end -- vote already recorded

        entry.votes[sender] = tonumber(parts[4])
        local voteStr = "|cffff0000NO|r"
        if entry.votes[sender] == 1 then voteStr = "|cff00ff00YES|r" end 
        out(sender.." voted "..voteStr.." to give "..entry.link.." to "..entry.tradedTo)

        self:CheckVotes(entry)

    elseif parts[1] == SYNC_SUGGEST then 
        local entry = VerifyLoot(parts)
        if not entry then return end 

        if entry.tradedTo == parts[4] then return end -- tradeTo already recorded

        entry.tradedTo = parts[4]
        local row = self:FindRow(entry.lootid)
        RaidLogger_RaidWindow_LootTab:TradedToChanged(row, entry) 

        if entry.tradedTo == DROPDOWN_DISENCHANT_NAME then 
            out(sender.." suggests to disenchant "..entry.link)
        elseif entry.tradedTo == DROPDOWN_BANK_NAME then 
            out(sender.." suggests to send "..entry.link.." to guild bank")
        elseif entry.tradedTo == DROPDOWN_FFA_NAME then 
            out(sender.." suggests "..entry.link.." as Free for All")
        else 
            out(sender.." suggests to give "..entry.link.." to "..entry.tradedTo)
        end 

    elseif parts[1] == SYNC_CHECK then 
        if not parts[2] then 
            out("|cffffff00"..sender.." is using an old version of RaidLogger, this may lead to unexpected behaviour")
        else 
            local ver = tonumber(parts[2]) 
            if ver < VERSION then 
                out("|cffffff00"..sender.." is using an old version of RaidLogger ("..ver.."), this may lead to unexpected behaviour")
            elseif ver > VERSION then 
                out("|cffffff00You are using an old version of RaidLogger, this may lead to unexpected behaviour!")
            end 
        end 
        lootMismatchs = 0
        self:ScheduleSyncCheck() -- reset check timer
        if RaidLoggerStore.activeRaid and RaidLoggerStore.activeRaid.loot and not syncingNow then 
            self:Post(1, nil, SYNC_CHECK_REPLY, #RaidLoggerStore.activeRaid.loot, ""..RaidLoggerStore.activeRaid.zoneId or "")
        end 

    elseif parts[1] == SYNC_CHECK_REPLY then 
        local zoneId = parts[3]
        local lootCount = tonumber(parts[2])

        -- start a raid
        if not RaidLoggerStore.activeRaid or ""..RaidLoggerStore.activeRaid.zoneId ~= zoneId or syncingNow then 
            return 
        end

        if lootCount > #RaidLoggerStore.activeRaid.loot then  -- and time() - lastSync > SYNC_COOLDOWN_SECONDS
            lootMismatchs = lootMismatchs + 1
            -- someone else has more loot than us!
            if firstSyncMismatch == 0 then 
                -- check loot again in 10 sec to make sure it didn't just take time for loot msg to get to us
                firstSyncMismatch = time()
                self:ScheduleSyncCheckSoon()
                debug("Not in sync first time, will check again soon")
            else 
                outOfSync = true
                out("|cffff0000WARNING: You are not in sync! "..sender.." has "..lootCount.." items while you have only "..tostring(#RaidLoggerStore.activeRaid.loot)..". Write |cffffff00/rlog resync "..sender.."|cffff0000 to rebuild item list from "..sender)
            end 
        end 
    
    elseif parts[1] == SYNC_RESEND then 
        self:ResendLoot(sender)

    elseif parts[1] == SYNC_END then 
        if RaidLoggerStore.activeRaid then
            RaidLogger:EndRaid()
        end 
    end 
end 

function RaidLogger:FullResync(from)
    syncingNow = true 
    lastSync = time()
    RaidLoggerStore.activeRaid.loot = {}
    self:Post(0, from, SYNC_RESEND)
end 

function RaidLogger:ScheduleSyncCheck() 
    nextSyncCheck = time() + NEXT_SYNC_CHECK_MIN_SECONDS + math.random(NEXT_SYNC_CHECK_RANDOM_SECONDS)
end 

function RaidLogger:ScheduleSyncCheckSoon() 
    nextSyncCheck = time() + NEXT_SYNC_CHECK_SOON_MIN_SECONDS + math.random(NEXT_SYNC_CHECK_SOON_RANDOM_SECONDS)
end 

function RaidLogger:Post(delaySeconds, toWho, ...) 
    tinsert(RaidLoggerDelayedMessages, {
        ["time"] = time() + delaySeconds,
        ["msg"] = table.concat({...}, ","),
        ["to"] = toWho,
    })
end 

function RaidLogger:ResendLoot(sendTo, index)
    if index and string.len(index) > 0 then
        local entry = RaidLoggerStore.activeRaid.loot[tonumber(index)]
        RaidLogger:PostLootEntry(entry, index.."/"..#RaidLoggerStore.activeRaid.loot, 1, sendTo)
    else
        for i, entry in ipairs(RaidLoggerStore.activeRaid.loot) do 
            RaidLogger:PostLootEntry(entry, i.."/"..#RaidLoggerStore.activeRaid.loot, i, sendTo)
        end 
    end
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
        out("Loot "..entry.link.." |cff00ff00AGREED|r to be given to "..entry.tradedTo.." with "..sum.." / "..max.." votes.")
    elseif #veto > 0 then 
        entry.status = -1
    end 

    if editRaid and not editRaid.endTime then 
        -- update UI
        local row = self:FindRow(entry.lootid)
        RaidLogger_RaidWindow_LootTab:UpdateStatusImage(row, entry)
    end 
end 

function RaidLogger:FindRow(lootid)
    for _, row in ipairs(RaidLogger_RaidWindow_LootTab.rows) do 
        if row.entry.lootid == lootid then 
            return row 
        end 
    end 
end 

function RaidLogger:FindEntry(lootid)
    for _, entry in ipairs(RaidLoggerStore.activeRaid.loot) do 
        if entry.lootid == lootid then 
            return entry
        end 
    end 
end 

function RaidLogger:PostLootEntry(entry, lootProgress, delaySeconds, sendTo)
    -- if not RaidLoggerStore.activeRaid or not RaidLoggerStore.activeRaid.zone then return end 
    local votes = {}
    for name, vote in pairs(entry.votes) do 
        tinsert(votes, name.."-"..vote)
    end 
    RaidLogger:Post(delaySeconds, sendTo, SYNC_LOOT, VERSION, lootProgress, entry.player, entry.itemString, entry.quantity, entry.ts, entry.lootid, entry.tradedTo or "_", entry.status, table.concat(votes, "|"))
end 


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--   ADDON FRAME 

function RaidLoggerFrame:OnAddonLoaded()
    SLASH_RaidLogger1 = "/rlog"
    SlashCmdList["RaidLogger"] = RaidLogger_Commands
    out("Logs raid attendance into a file. Write |cFF00FF00/rlog help|r for a list of commands.")

    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_LootTab)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_PlayersTab)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_RaidsTab)

    -- saved variables loaded
    if Store and Store.raids and #Store.raids > 0 and (not RaidLoggerStore or not RaidLoggerStore.raids or #RaidLoggerStore.raids == 0) then 
        RaidLoggerStore = Store 
        Store = nil 
    end 
    if RaidLoggerStore and RaidLoggerStore.activeRaid then
        -- check for raid timeout 
        if time() - RaidLoggerStore.activeRaid.startTime > ACTIVE_RAID_TIMEOUT then 
            RaidLogger:EndRaid()
        else 
            LoggingCombat(true) -- resume combat logging
            EndRaidReminder()
        end 
    end

    -- migrate store
    if not RaidLoggerStore.qualityToLog then 
        RaidLoggerStore.qualityToLog = QUALITY_RARE;
    end 

    RaidLogger:ChooseLastRaid()
    RaidLogger_RaidWindow:Refresh()
    RaidLogger_RaidWindow_Buttons_LootTab:Clicked()
    if RaidLoggerStore.windowShown then 
        RaidLogger_RaidWindow:Show()
    else 
        RaidLogger_RaidWindow:Hide()
    end 

    if RaidLoggerStore.sync then 
        successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX..RaidLoggerStore.sync)
        if successfulRequest then 
            out("Registered for sync on "..RaidLoggerStore.sync)
            RaidLogger:Post(5, nil, SYNC_COUNCIL_WHO)
            nextSyncCheck = time() + 2
        else 
            printerr("Failed registering to message prefix!")
        end 
    end
end

function RaidLoggerFrame:OnUpdate()
    local now = time()
    if RaidLoggerStore and RaidLoggerStore.activeRaid and now - lastBuffCheck >= BUFF_CHECK_SECONDS then 
        -- out("checking buffs...")
        if not RaidLoggerStore.activeRaid.buffs then RaidLoggerStore.activeRaid.buffs = {} end 
        lastBuffCheck = now 
        RaidLogger_CheckBuffs(RaidLoggerStore.activeRaid.buffs)
    end 
    if RaidLoggerDelayedMessages and #RaidLoggerDelayedMessages and RaidLoggerStore.sync then 
        -- send message in queue
        newStack = {}
        for _, meta in ipairs(RaidLoggerDelayedMessages) do 
            if meta.time <= now then 
                if #meta.msg > 253 then 
                    err("Sync message is too long, skipping")
                else 
                    debug("SYNC OUT - "..meta.msg)
                    if meta.to then 
                        C_ChatInfo.SendAddonMessage(ADDON_PREFIX..RaidLoggerStore.sync, meta.msg, "WHISPER", meta.to)
                    else 
                        C_ChatInfo.SendAddonMessage(ADDON_PREFIX..RaidLoggerStore.sync, meta.msg, "RAID")
                    end 
                end 
            else 
                tinsert(newStack, meta)
            end
        end 
        RaidLoggerDelayedMessages = newStack
    end 
    if RaidLoggerPendingLoot and #RaidLoggerPendingLoot then 
        -- try to log loot again, last GetItemInfo query returned nil
        local params = RaidLoggerPendingLoot[1]
        table.remove(RaidLoggerPendingLoot, 1)
        if params then 
            LogLoot(params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8])
        end 
    end 
    if nextSyncCheck > 0 and now > nextSyncCheck and now - lastSync > SYNC_COOLDOWN_SECONDS then 
        RaidLogger:ScheduleSyncCheck() 
        if RaidLoggerStore.activeRaid and not syncingNow then 
            lootMismatchs = 0
            RaidLogger:Post(0, nil, SYNC_CHECK, VERSION) 
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
            RaidLogger:ParseLootMessage(arg1)
        end
    elseif event == "RAID_ROSTER_UPDATE" or event == "GROUP_ROSTER_UPDATE" or event == "ENCOUNTER_END" then
        if RaidLoggerStore and RaidLoggerStore.activeRaid then
            if GetNumRaidMembers() > 1 then
                RaidLogger:UpdateRaid()
            else
                EndRaidReminder();
            end
        else 
            -- every palyer that's added, check if raid has enough members to start logging
            if InTrackedInstance() and GetNumRaidMembers() >= MIN_RAID_PLAYERS then
                RaidLogger:UpdateRaid()
            end
        end
    elseif event == "CHAT_MSG_ADDON" then
        RaidLogger:OnAddonMessage(arg1, ...)
    elseif event == "UI_INFO_MESSAGE" then
        RaidLogger:OnUiInfoMessage(arg1, ...)
    elseif event == "TRADE_SHOW" and RaidLoggerStore.activeRaid then
        RaidLogger:OnTradeShow()
    elseif event == "TRADE_PLAYER_ITEM_CHANGED" and RaidLoggerStore.activeRaid then
        -- RaidLogger:OnTradePlayerItemChanged(arg1)
    elseif event == "TRADE_ACCEPT_UPDATE" and RaidLoggerStore.activeRaid then
        RaidLogger:OnTradeAcceptUpdate()
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
			btn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
            btn:SetBackdropBorderColor(0.1, 0.1, 0.1, 0.9)
			btn.label:SetTextColor(1, 1, 1, 1)
		else 
			btn:SetBackdropColor(0, 0, 0, 1)
            btn:SetBackdropBorderColor(0, 0, 0, 1)
			btn.label:SetTextColor(255/255, 238/255, 200/255, 1)
		end 
	else 
		if btn.selected then 
			btn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
            btn:SetBackdropBorderColor(0.1, 0.1, 0.1, 0.9)
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
	RaidLogger_QuestionDialog_Yes:SetScript("OnClick", function () 
		RaidLogger_QuestionDialog:Hide()
		onYes() 
	end)
	RaidLogger_QuestionDialog_No:SetScript("OnClick", function () 
		RaidLogger_QuestionDialog:Hide()
		if onNo then onNo() end 
	end)
	RaidLogger_QuestionDialog_Title_Text:SetText(titleText)
	RaidLogger_QuestionDialog_Question:SetText(questionText)
	RaidLogger_QuestionDialog_Yes:SetText(yesText or L["Yes"])
	RaidLogger_QuestionDialog_No:SetText(noText or L["No"])
	RaidLogger_QuestionDialog:Show()
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

local function SetButtonState(state, prefix, btn)
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
    row.statusImage:SetNormalTexture("Interface\\AddOns\\RaidLogger\\assets\\"..statusImage)
    row.statusFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(row.statusFrame, "ANCHOR_LEFT")
        GameTooltip:SetText(statusTooltip)
        GameTooltip:Show()
    end);
end 

function RaidLogger_RaidWindow_LootTab:TradedToChanged(row, entry) 
    entry.votes = {}
    entry.status = 0
    -- RaidLogger_RaidWindow_LootTab:Refresh()
    SetButtonState(0, "agree", row.yesButton)
    SetButtonState(0, "disagree", row.noButton)
    UIDropDownMenu_SetText(row.playerDropdown, entry.tradedTo)
    RaidLogger_RaidWindow_LootTab:UpdateStatusImage(row, entry)
    if votingEnabled then 
        row.yesButton:Show()
        row.noButton:Show()
    end 
end 

function RaidLogger_RaidWindow_LootTab:AddRow(players, entry, activeRaid) 
	self.visibleRows = self.visibleRows + 1

    local existingRow = self.rows[self.visibleRows]
    local row = existingRow or {};
    
    row.entry = entry 

	if not row.root then 
		row.root = CreateFrame("FRAME", nil, self.scrollContent, "BackdropTemplate");		
		-- row.root:SetWidth(self.scrollContent:GetWidth() - 20);
        row.root:SetHeight(27);
        row.root:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
        row.root:SetBackdropColor(0, 0, 0, 0.3)
		if #self.rows == 0 then 
			row.root:SetPoint("TOPLEFT", self.scrollContent, 0, -29);
			row.root:SetPoint("RIGHT", self, 0, 0);
		else 
			row.root:SetPoint("TOPLEFT", self.rows[#self.rows].root, "BOTTOMLEFT", 0, -2);
			row.root:SetPoint("TOPRIGHT", self.rows[#self.rows].root, "BOTTOMRIGHT", 0, -2);
		end 
	end     
    row.root:Show();

    local playerDropdownOffX = -24

    if not row.statusImage then 
        row.statusFrame = CreateFrame("FRAME", nil, row.root, "BackdropTemplate");
        row.statusFrame:SetSize(16, 16)
        row.statusFrame:SetPoint("LEFT", 46, 0)  
        row.statusFrame:SetScript("OnLeave", function(self)
            GameTooltip_Hide()
        end);	
        row.statusImage = CreateFrame("BUTTON", nil, row.statusFrame, "BackdropTemplate");
        row.statusImage:RegisterForClicks("AnyUp")
        row.statusImage:SetAllPoints(row.statusFrame)
    end 

    row.statusImage:SetScript("OnClick", function(self) 
        if entry.status == 1 then 
            local _, link = GetItemInfo(entry.link)
            SendChatMessage(link .. " --> " .. (entry.tradedTo or entry.player), "RAID_WARNING")
        end 
    end)

    if activeRaid then 
        playerDropdownOffX = -10
        if entry.tradedTo then 
            RaidLogger_RaidWindow_LootTab:UpdateStatusImage(row, entry)
        else 
            -- row.statusImage:SetNormalTexture(nil)
        end 
    else 
        -- row.statusImage:SetNormalTexture(nil)
        row.statusFrame:SetScript("OnEnter", nil)
    end 
    
    if not row.timeLabel then 
		row.timeLabel = row.root:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
		row.timeLabel:SetTextColor(0.8, 0.8, 0.8, 1)
		row.timeLabel:SetPoint("RIGHT", row.root, "LEFT", 40, 0)
		row.timeLabel:SetFont(FONT_NAME, 10)
    end 
    if entry.ts then 
        row.timeLabel:SetText(date("%H:%M", entry.ts));
    else 
        row.timeLabel:SetText("no time");
    end 

    if not row.playerDropdown then 
        row.playerDropdown = CreateFrame("Frame", "RaidLogger_RaidWindow_PlayerDropdown"..(self.visibleRows), row.root, "UIDropDownMenuTemplate")
        UIDropDownMenu_SetWidth(row.playerDropdown, 100) 
        UIDropDownMenu_JustifyText(row.playerDropdown, "LEFT")
    end 
    local function Dropdown_OnClick(self)
        entry.tradedTo = self.value 
        RaidLogger_RaidWindow_LootTab:TradedToChanged(row, entry)
        RaidLogger:Post(1, nil, SYNC_SUGGEST, entry.lootid, entry.itemString, entry.tradedTo)
    end
    UIDropDownMenu_Initialize(row.playerDropdown, function (frame, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        info.func = Dropdown_OnClick
        for _, name in ipairs(players) do 
            info.text, info.checked = name, name == (entry.tradedTo or entry.player)
            UIDropDownMenu_AddButton(info)
        end 
    end)
    row.playerDropdown:ClearAllPoints()
    row.playerDropdown:SetPoint("LEFT", row.statusImage, "RIGHT", playerDropdownOffX, -2)
    UIDropDownMenu_SetText(row.playerDropdown, entry.tradedTo or entry.player)

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
    SetButtonState(questionOp(vote == 1, 1, 0), "agree", row.yesButton)
    SetButtonState(questionOp(vote == 0, 1, 0), "disagree", row.noButton)
    row.yesButton:SetScript("OnClick", function(self) 
        SetButtonState(1, "agree", self)
        SetButtonState(0, "disagree", row.noButton)
        entry.votes[UnitName("player")] = 1
        RaidLogger:Post(1, nil, SYNC_VOTE, entry.lootid, entry.itemString, 1)
        RaidLogger:CheckVotes(entry)
    end)
    row.noButton:SetScript("OnClick", function(self) 
        SetButtonState(1, "disagree", self)
        SetButtonState(0, "agree", row.yesButton)
        entry.votes[UnitName("player")] = 0
        RaidLogger:Post(1, nil, SYNC_VOTE, entry.lootid, entry.itemString, 0)
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
            local _, link = GetItemInfo(entry.link)
			PlaceLinkInChatEditBox(link) -- paste in chat box
		elseif IsControlKeyDown() then
            local _, link = GetItemInfo(entry.link)
			DressUpItemLink(link) -- preview
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
        if editRaidIndex then 
            RaidLogger_EndRaidButton:Hide()
            RaidLogger_DiscardRaidButton:Hide()
        else
            RaidLogger_EndRaidButton:Show()
            RaidLogger_DiscardRaidButton:Show()
        end
    
        local title = (editRaid.zone or "??").." / "..editRaid.date
        if not editRaidIndex then 
            title = title.." (active)"
        end
        RaidLogger_RaidWindow_Title_Text:SetText(title)

        local currentFilter = RaidLoggerStore.displayLootFilter or QUALITY_EPIC
        UIDropDownMenu_Initialize(RaidLogger_DisplayLootFilter, function (frame, level, menuList)
            local info = UIDropDownMenu_CreateInfo()
            info.func = function (self) 
                RaidLoggerStore.displayLootFilter = self.value 
                RaidLogger_RaidWindow_LootTab:Refresh()
            end 
            for i = QUALITY_UNCOMMON, QUALITY_LEGENDARY do 
                info.text, info.checked, info.value = QUALITY_TEXT[i].."+", currentFilter == i, i
                UIDropDownMenu_AddButton(info)
            end 
        end)
        UIDropDownMenu_SetText(RaidLogger_DisplayLootFilter, QUALITY_TEXT[currentFilter])    

        local players = {}
        tinsert(players, DROPDOWN_DISENCHANT_NAME)
        tinsert(players, DROPDOWN_BANK_NAME)
        tinsert(players, DROPDOWN_FFA_NAME)
        for name, attStatus in pairs(editRaid.players or {}) do 
            tinsert(players, name)
        end 
        table.sort(players)

        local searchText = string.lower(RaidLogger_Loot_SearchBox:GetText())
        votingEnabled = not editRaid.endTime and RaidLoggerStore.council and RaidLoggerStore.council[UnitName("player")]

        for i = #editRaid.loot, 1, -1 do
            local entry = editRaid.loot[i]

            -- migrate old records
            if not entry.votes then entry.votes = {} end 
            if not entry.lootid then entry.lootid = i end 
            if not entry.itemString then entry.itemString = ItemStringFromLink(entry.link) end 

            local blueRecipe = entry.quality == QUALITY_RARE and (string.find(entry.item, "Recipe: ") == 1 or string.find(entry.item, "Formula: ") == 1 or string.find(entry.item, "Schematic: ") == 1)
            local epicItem = entry.quality >= (RaidLoggerStore.displayLootFilter or QUALITY_EPIC)
            local searchMatch = searchText == "" or string.find(string.lower(entry.item), searchText)
            -- local ignoredItem = tableTextLookup(IGNORED_ITEMS, entry.item)
            local hiddenItem = HIDDEN_ITEMS[ItemIdFromLink(entry.link)]
            if (epicItem or blueRecipe) and searchMatch and not hiddenItem then 
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
		row.root = CreateFrame("FRAME", nil, self.scrollContent, "BackdropTemplate");		
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
        for name, attStatus in pairs(editRaid.players or {}) do 
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
		row.root = CreateFrame("BUTTON", nil, self.scrollContent, "BackdropTemplate");		
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
    if not raidIndex then 
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

function RaidLogger_EndRaidButton:Clicked()
    RaidLogger:AskQuestion("End Raid", "Do you want to close this raid?", function()  
        RaidLogger:EndRaid()
    end, nil, "End", "Cancel") 
end 

function RaidLogger_DiscardRaidButton:Clicked()
    RaidLogger:AskQuestion("Discard Raid", "Do you want to discard this raid?", function()  
        RaidLogger:DiscardRaid() 
    end, nil, "Discard", "Cancel") 
end 
