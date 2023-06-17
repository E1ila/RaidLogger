local BUFFS = {
    ["23768"] = {
        name = "Sayge's Dark Fortune of Damage",
        desc = "DMF Damage",
        type = "World"
     },
     ["23736"] = {
        name = "Sayge's Dark Fortune of Agility",
        desc = "DMF Agility",
        type = "World"
     },
     ["23766"] = {
        name = "Sayge's Dark Fortune of Intelligence",
        desc = "DMF Intelligence",
        type = "World"
     },
     ["23735"] = {
        name = "Sayge's Dark Fortune of Strength",
        desc = "DMF Strength",
        type = "World",
     },
     ["23769"] = {
        name = "Sayge's Dark Fortune of Resistance",
        desc = "DMF Resistance",
        type = "World",
     },
     ["23737"] = {
        name = "Sayge's Dark Fortune of Stamina",
        desc = "DMF Stamina",
        type = "World"
     },
     ["23738"] = {
        name = "Sayge's Dark Fortune of Spirit",
        desc = "DMF Spirit",
        type = "World"
     },
     ["23767"] = {
        name = "Sayge's Dark Fortune of Armor",
        desc = "DMF Armor",
        type = "World"
     },
    ["10669"] = {
        name = "Strike of the Scorpok (25 agi)",
        desc = "Ground Scorpok Assay",
        type = "Consumable"
     },
     ["10667"] = {
        name = "Rage of Ages (25 str)",
        desc = "R.O.I.D.S.",
        type = "Consumable"
     },
     ["22888"] = {
        name = "Rallying Cry of the Dragonslayer",
        desc = "Dragonslayer",
        type = "World"
    },
    ["355363"] = {
        name = "Rallying Cry of the Dragonslayer", -- unbooned probably
        desc = "Dragonslayer",
        type = "World"
    },
    ["16609"] = {
        name = "Warchief's Blessing",
        desc = "Dragonslayer",
        type = "World"
    },
    ["355366"] = {
        name = "Warchief's Blessing", -- unbooned probably
        desc = "Dragonslayer",
        type = "World"
    },
    ["15366"] = {
        name = "Songflower Serenade",
        desc = "Songflower",
        type = "World",
    },
    ["22817"] = {
        name = "Fengus' Ferocity",
        desc = "DMT AP",
        type = "World",
    },
    ["22820"] = {
        name = "Slip'kik's Savvy",
        desc = "DMT Crit",
        type = "World",
    },
    ["22818"] = {
        name = "Mol'dar's Moxie",
        desc = "DMT Stamina",
        type = "World",
    },
    ["11364"] = {
        name = "Resistance",
        desc = "Magic Resistance Potion",
        type = "Consumable",
    },
    ["3593"] = {
        name = "Health II",
        desc = "Elixir of Fortitude",
        type = "Consumable",
    },
    ["3222"] = {
        name = "Regeneration (6 hp5)",
        desc = "Strong Troll's Blood Potion",
        type = "Consumable",
     },
     ["3223"] = {
        name = "Regeneration (12 hp5)",
        desc = "Mighty Troll's Blood Potion",
        type = "Consumable",
     },
     ["24361"] = {
        name = "Regeneration (20 hp5)",
        desc = "Major Troll's Blood Potion",
        type = "Consumable",
     },
     ["24363"] = {
        name = "Mana Regeneration (12 mp5)",
        desc = "Mageblood Potion",
        type = "Consumable",
     },
     ["17549"] = {
        name = "Greater Arcane Protection",
        desc = "Greater Arcane Protection Potion",
        type = "Consumable"
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
    ["24870"] = {
        name = "Well Fed (?? sta, ?? spi)",
        type = "Food",
    },
    ["19705"] = {
        name = "Well Fed (1 sta, 1 spi)",
        type = "Food",
    },
    ["19706"] = {
        name = "Well Fed (3 sta, 3 spi)",
        type = "Food",
    },
    ["19709"] = {
        name = "Well Fed (7 sta, 7 spi)",
        type = "Food",
    },
    ["19710"] = {
        name = "Well Fed (11 sta, 11 spi)",
        type = "Food",
    },
    ["19711"] = {
        name = "Well Fed (13 sta, 13 spi)",
        type = "Food",
    },
    ["25694"] = {
        name = "Well Fed (2 mp5)",
        type = "Food",
    },
    ["25941"] = {
        name = "Well Fed (5 mp5)",
        type = "Food",
    },
    ["18194"] = {
        name = "Mana Regeneration (7 mp5)",
        desc = "Nightfin Soup",
        type = "Food",
    },
    ["22730"] = {
        name = "Increased Intellect (9 int)",
        desc = "Runn Tum Tuber Surprise",
        type = "Food",
    },
    ["18192"] = {
        name = "Increased Agility (9 agi)",
        desc = "Grilled Squid",
        type = "Food",
    },
    ["24799"] = {
        name = "Well Fed (19 str)",
        desc = "Smoked Desert Dumpling",
        type = "Food",
    },
    ["22789"] = {
        name = "Gordok Green Grog (10 sta)",
        desc = "DMT beer",
        type = "Alcohol",
    },
    ["22790"] = {
        name = "Kreeg's Stout Beatdown (25 spi, -5 int)",
        desc = "DMT beer",
        type = "Alcohol",
    },
    ["25804"] = {
        name = "Rumsey Rum Black Label (15 sta)",
        desc = "Fishing",
        type = "Alcohol",
    },
    ["27721"] = {
        name = "Very Berry Cream (23 spell dmg)",
        desc = "Love Event",
        type = "Food",
    },
    ["27720"] = {
        name = "Buttermilk Delight (13 defense)",
        desc = "Love Event",
        type = "Food",
    },
    ["27723"] = {
        name = "Dark Desire (2% hit)",
        desc = "Love Event",
        type = "Food",
    },
    ["27722"] = {
        name = "Sweet Surprise (44 healing)",
        desc = "Love Event",
        type = "Food",
    },
    ["27669"] = {
        name = "Orgrimmar Gift of Friendship (30 agi)",
        desc = "Love Event",
        type = "Food",
    },
    ["27670"] = {
        name = "Thunder Bluff Gift of Friendship (30 sta)",
        desc = "Love Event",
        type = "Food",
    },
    ["27671"] = {
        name = "Undercity Gift of Friendship (30 int)",
        desc = "Love Event",
        type = "Food",
    },
    ["17038"] = {
        name = "Winterfall Firewater",
        desc = "Winterfall Firewater",
        type = "Consumable",
    },
}

local function FixPlayerRealm(player)
    if not string.find(player, "-") then 
        return player.."-"..GetRealmName()
    end
    return player
end

function RaidLogger_CheckBuffs(players)
    for i = 1, 40 do
        name, _, group = GetRaidRosterInfo(i)
        if name then
            name = FixPlayerRealm(name)
            if not players[name] then players[name] = {} end 
            RaidLogger_CheckUnitBuffs(players[name], "raid" .. i) 
            players[name]["present"] = (players[name]["present"] or 0) + 1
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
