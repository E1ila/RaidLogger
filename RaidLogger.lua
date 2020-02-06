--
-- Created by IntelliJ IDEA.
-- User: kof
-- Date: 11/04/2019
-- Time: 18:36
--

local VERSION = 1.6
local MIN_RAID_PLAYERS = 10
local ADDON_NAME = "RaidLogger"
local FONT_NAME = "Fonts\\FRIZQT__.TTF"

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

local BUFF_CHECK_SECONDS = 60 

local lastBuffCheck = 0
local editRaid = nil 

RaidLoggerStore = {
    raids = {},
    activeRaid = nil,
    players = {},
}

RaidLogger = {}

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

local function LogLoot(who, loot, quantity, zone)
    -- local vStartIndex, vEndIndex, vLinkColor, vItemCode, vItemEnchantCode, vItemSubCode, vUnknownCode, vItemName = strfind(loot, "|c(%x+)|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[([^%]]+)%]|h|r");
	local itemName, _, quality, _, _, itemType, _, _, _, _, vendorPrice = GetItemInfo(loot);

    if who and quality >= QUALITY_UNCOMMON and not tableTextLookup(IGNORED_ITEMS, vItemName) then
        out("Logged loot: " .. ColorName(who) .. " received " .. loot .. " at " .. COLOR_INSTANCE .. zone .. "|r")
        table.insert(RaidLoggerStore.activeRaid.loot, {
            player = who,
            item = itemName,
            ts = time(),
            link = loot,
            quality = quality,
            quantity = quantity,
            de = 0,
            os = 0,
            votes = {},
            status = 0,
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

function RaidLogger:ParseLootMessage(msg, zone)
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

function RaidLogger_Commands(msg)
    local _, _, cmd, arg1 = string.find(string.upper(msg), "([%w]+)%s*(.*)$");
    -- out("cmd " .. cmd .. " / arg1 " .. arg1)
    if not cmd then
        RaidLogger:ChooseLastRaid()
        RaidLogger_RaidWindow_LootTab:Refresh()
        RaidLogger_RaidWindow:Show()
    elseif  "S" == cmd or "START" == cmd then
        RaidLogger:UpdateRaid()
    elseif  "H" == cmd or "HELP" == cmd then
        out("Commands: ")
        out("  |cFF00FF00/rl|r - show UI")
        out("  |cFF00FF00/rl |cFF00ff95a|cFF00FF00dd <player>|r - manually log an attended player.")
        out("  |cFF00FF00/rl |cFF00ff95b|cFF00FF00ench <player>|r - log a benched player.")
        out("  |cFF00FF00/rl de|r - marks last distributed loot item as disenchanted.")
        out("  |cFF00FF00/rl os|r - marks last distributed loot as an off-spec item.")
        out("  |cFF00FF00/rl discard|r - discard current raid, do this to ignore current raid.")        
        out("  |cFF00FF00/rl end|r - save and close raid, do this when raid ended.")
        out("  |cFF00FF00/rl p|r - print active raid, if any.")
        out("  |cFF00FF00/rl |cFF00ff95start|r - start logging a raid or update existing one.")
    elseif  "counsil" == cmd then
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
    elseif  "sync" == cmd then
        if arg1 and string.len(arg1) > 0 then
            RaidLoggerStore.sync = arg1 
        else
            err("Missing sync password!")
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
            RaidLogger:LogAttend(FixPlayerName(arg1))
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
end

function RaidLogger:SetLootCouncil(player)
    if RaidLoggerStore.council[player] then
        out("Removing " .. ColorName(player) .. " from loot council.")
        RaidLoggerStore.council[player] = nil 
    else 
        out("Adding " .. ColorName(player) .. " to loot council.")
        RaidLoggerStore.council[player] = true  
    end 
end

function RaidLogger:LogBenched(player)
    out("Logging bench for " .. ColorName(player))
    RaidLoggerStore.activeRaid.players[player] = STATE_BENCHED
end

function RaidLogger:LogAttended(player)
    if RaidLoggerStore.activeRaid.players[player] ~= STATE_ATTENDED then 
        out("Logging attendance for " .. ColorName(player))
        RaidLoggerStore.activeRaid.players[player] = STATE_ATTENDED
    end 
end

function RaidLogger:LogNoShow(player)
    out("Logging no-show for " .. ColorName(player))
    RaidLoggerStore.activeRaid.players[player] = STATE_NOSHOW
end

function RaidLogger:LogLateShow(player)
    out("Logging late show for " .. ColorName(player))
    RaidLoggerStore.activeRaid.players[player] = STATE_LATE
end

function RaidLogger:RemoveFromLog(player)
    out("Removing " .. ColorName(player) .. " from log")
    RaidLoggerStore.activeRaid.players[player] = nil 
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
    -- editRaid = RaidLoggerStore.activeRaid or RaidLoggerStore.raids[#RaidLoggerStore.raids]
    editRaid = RaidLoggerStore.activeRaid or RaidLoggerStore.raids[#RaidLoggerStore.raids-1]
end


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--   ADDON FRAME 

function RaidLoggerFrame:OnAddonLoaded()
    SLASH_RaidLogger1 = "/rl"
    SlashCmdList["RaidLogger"] = RaidLogger_Commands
    out("Logs raid attendance into a file. Write |cFF00FF00/rl help|r for a list of commands.")

    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_LootTab)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_ParticipantsTab)
end

function RaidLoggerFrame:OnUpdate()
    if RaidLoggerStore and RaidLoggerStore.activeRaid and time() - lastBuffCheck >= BUFF_CHECK_SECONDS then 
        -- out("checking buffs...")
        if not RaidLoggerStore.activeRaid.buffs then RaidLoggerStore.activeRaid.buffs = {} end 
        lastBuffCheck = time() 
        RaidLogger_CheckBuffs(RaidLoggerStore.activeRaid.buffs)
    end 
end 

function RaidLoggerFrame:OnEvent(event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then 
            self:OnAddonLoaded()
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
            RaidLogger_RaidWindow_LootTab:Refresh()
        end 
    else
        -- out("|c44FFFFFF"..event.." event")
        if event == "RAID_INSTANCE_WELCOME" or event == "ZONE_CHANGED_NEW_AREA" then
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

function RaidLogger_RaidWindow_Buttons_ParticipantsTab:Clicked(clickedButton)
	if self.disabled then return end 
    self.selected = true
    RaidLogger_RaidWindow_Buttons_LootTab.selected = false 
    RaidLogger:SetTabBackdropColor(self, true)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_LootTab, false)
end 

function RaidLogger_RaidWindow_Buttons_LootTab:Clicked(clickedButton)
	if self.disabled then return end 
    self.selected = true
    RaidLogger_RaidWindow_Buttons_ParticipantsTab.selected = false 
    RaidLogger:SetTabBackdropColor(self, true)
    RaidLogger:SetTabBackdropColor(RaidLogger_RaidWindow_Buttons_ParticipantsTab, false)
end 

-- rows ----------

local function HideRowsBeyond(j, container)
	local n = #container.rows;
	if j <= n then 
		for i = j, n do
			container.rows[i].root:Hide()
		end
	end 
end

function RaidLogger_RaidWindow_LootTab:AddRow(players, entry, activeRaid) 
	self.visibleRows = self.visibleRows + 1

    local existingRow = self.rows[self.visibleRows]
	local row = existingRow or {};

	if not row.root then 
		row.root = CreateFrame("FRAME", nil, self.scrollContent);		
		-- row.root:SetWidth(self.scrollContent:GetWidth() - 20);
        row.root:SetHeight(28);
        row.root:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
        row.root:SetBackdropColor(0, 0, 0, 0.6)
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
        row.statusFrame:SetPoint("LEFT", 40, 0)  
        row.statusFrame:SetScript("OnLeave", function(self)
            GameTooltip_Hide();
        end);	
        row.statusImage = row.root:CreateTexture();
        row.statusImage:SetAllPoints(row.statusFrame)
    end 
    if activeRaid then 
        playerDropdownOffX = -10
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
        local function Dropdown_OnClick(self)
            entry.tradedTo = self.value 
            entry.votes = {}
            entry.status = 0
            entry.de = 0
            entry.os = 0
            UIDropDownMenu_SetText(row.playerDropdown, self.value)
        end
        row.playerDropdown = CreateFrame("Frame", "RaidLogger_RaidWindow_PlayerDropdown"..(self.visibleRows), row.root, "UIDropDownMenuTemplate")
        UIDropDownMenu_SetWidth(row.playerDropdown, 100) 
        UIDropDownMenu_JustifyText(row.playerDropdown, "LEFT")
        UIDropDownMenu_Initialize(row.playerDropdown, function (frame, level, menuList)
            local info = UIDropDownMenu_CreateInfo()
            info.func = Dropdown_OnClick
            for _, name in ipairs(players) do 
                info.text, info.checked = name, name == (entry.tradedTo or entry.player)
                UIDropDownMenu_AddButton(info)
            end 
        end)
        row.playerDropdown:Show()    
    end 
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
		row.label:SetFont(FONT_NAME, 12)

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
        row.yesButton:SetNormalTexture("Interface\\AddOns\\RaidLogger\\assets\\agree")
        row.yesButton:SetPushedTexture("Interface\\AddOns\\RaidLogger\\assets\\agree")
        row.yesButton:SetHighlightTexture("Interface\\AddOns\\RaidLogger\\assets\\agree")
        row.yesButton:SetScript("OnClick", function(self) out("yes") end)
    end 

    if not row.noButton then 
        row.noButton = CreateFrame("BUTTON", nil, row.root);
        row.noButton:SetSize(16, 16)
        row.noButton:SetPoint("RIGHT", row.yesButton, "LEFT", -8, 0)
        row.noButton:RegisterForClicks("AnyUp")
        row.noButton:SetNormalTexture("Interface\\AddOns\\RaidLogger\\assets\\disagree")
        row.noButton:SetPushedTexture("Interface\\AddOns\\RaidLogger\\assets\\disagree")
        row.noButton:SetHighlightTexture("Interface\\AddOns\\RaidLogger\\assets\\disagree")
        row.noButton:SetScript("OnClick", function(self) out("no") end)
	end 

    if activeRaid then 
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

    row.root:SetScript("OnMouseUp", function(self, ...)
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
        local title = editRaid.zone.." / "..editRaid.date
        if not editRaid.endTime then 
            title = title.." (active)"
        end
        RaidLogger_RaidWindow_Title_Text:SetText(title)

        local players = {}
        for name, attStatus in pairs(editRaid.players) do 
            if attStatus == "a" then tinsert(players, name) end 
        end 
        table.sort(players)

        for i = #editRaid.loot, 1, -1 do
            local entry = editRaid.loot[i]
            if entry.quality >= 4 or (entry.quality == 3 and (string.find(entry.item, "Recipe: ") == 1 or string.find(entry.item, "Formula: ") == 1 or string.find(entry.item, "Schematic: ") == 1)) then 
                RaidLogger_RaidWindow_LootTab:AddRow(players, entry)
            end 
        end
    end

    HideRowsBeyond(self.visibleRows + 1, self)
end

