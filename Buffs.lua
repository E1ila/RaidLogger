local BUFFS = {
    ["22888"] = {
        name = "Rallying Cry of the Dragonslayer",
        desc = "Dragonslayer",
        type = "World"
    },
    ["15366"] = {
        name = "Songflower Serenade",
        desc = "Songflower",
        type = "World"
    },
    ["22817"] = {
        name = "Fengus' Ferocity",
        desc = "DMT AP",
        type = "World"
    },
    ["22820"] = {
        name = "Slip'kik's Savvy",
        desc = "DMT Crit",
        type = "World"
    },
    ["22818"] = {
        name = "Mol'dar's Moxie",
        desc = "DMT Stamina",
        type = "World"
    },
    ["17543"] = {
        name = "Greater Fire Protection",
        desc = "Greater Fire Protection Potion",
        type = "Consumable"
    },
    ["7233"] = {
        name = "Fire Protection",
        type = "Consumable"
    },
    ["17548"] = {
        name = "Greater Shadow Protection",
        desc = "Greater Shadow Protection Potion",
        type = "Consumable"
    },
    ["7242"] = {
        name = "Shadow Protection",
        desc = "Shadow Protection Potion",
        type = "Consumable"
    },
    ["17546"] = {
        name = "Greater Nature Protection",
        desc = "Greater Nature Protection Potion",
        type = "Consumable"
    },
    ["7254"] = {
        name = "Nature Protection",
        desc = "Nature Protection Potion",
        type = "Consumable"
    },
    ["17544"] = {
        name = "Greater Frost Protection",
        desc = "Greater Frost Protection Potion",
        type = "Consumable"
    },
    ["7239"] = {
        name = "Frost Protection",
        desc = "Frost Protection Potion",
        type = "Consumable"
    },
    ["17539"] = {
        name = "Greater Arcane Elixir",
        type = "Consumable",
    },
    ["11474"] = {
        name = "Elixir of Shadow Power",
        type = "Consumable",
    },
    ["17538"] = {
        name = "Elixir of the Mongoose",
        type = "Consumable",
    },
    ["11405"] = {
        name = "Elixir of the Giants",
        type = "Consumable",
    },
    ["16326"] = {
        name = "Juju Ember",
        desc = "Fire Res Juju",
        type = "Consumable",
    },
    ["16329"] = {
        name = "Juju Might",
        desc = "Attack Power Juju",
        type = "Consumable",
    },
    ["16323"] = {
        name = "Juju Power",
        desc = "Strength Juju",
        type = "Consumable",
    },
    ["16322"] = {
        name = "Juju Flurry",
        desc = "Attack Speed Juju",
        type = "Consumable",
    },
    ["16325"] = {
        name = "Juju Chill",
        desc = "Frost Res Juju",
        type = "Consumable",
    },
    ["16321"] = {
        name = "Juju Escape",
        desc = "Dodge Juju",
        type = "Consumable",
    },
    ["17628"] = {
        name = "Supreme Power",
        type = "Flask",
    },
    ["17626"] = {
        name = "Flask of the Titans",
        type = "Flask",
    },
    ["17627"] = {
        name = "Distilled Wisdom",
        type = "Flask",
    },
}

function RaidLogger_CheckBuffs(players)
    for i = 1, 40 do
        name, _, group = GetRaidRosterInfo(i)
        if name then
            if not players[name] then players[name] = {} end 
            RaidLogger_CheckUnitBuffs(players[name], "raid" .. i) 
        end
    end
    return players
end

function RaidLogger_CheckUnitBuffs(player, unit)
    for i = 1, 40 do
        local buffName, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, i)
        if spellId then 
            -- using string because our lua parser having hard time dealing with number keys
            spellId = tostring(spellId)
            local trackedBuff = BUFFS[spellId]
            -- print(" |cff0088ff<|cff00bbffRaidLogger|cff0088ff>|r player "..i.." has "..buffName.." "..tostring(trackedBuff))
            if trackedBuff then 
                player[spellId] = (player[spellId] or 0) + 1 
            end 
        end 
    end
end
