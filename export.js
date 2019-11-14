#!/usr/bin/env node
'use strict';

// Written by Kof

const
   MAX_RAID_OPTIONS = 20,
   USE_LAST_RAID = false,
   moment = require('moment'),
   colors = require('ansi-256-colors'),
   colorInfo = colors.fg.getRgb(0, 1, 4),
   colorWarning = colors.fg.getRgb(5, 5, 0),
   colorBrown = colors.fg.getRgb(4, 2, 1),
   colorGreen = colors.fg.getRgb(0, 3, 0),
   colorPurple = colors.fg.getRgb(3, 1, 2),
   colorBrightPurple = colors.fg.getRgb(3, 0, 4),
   colorDarkGray = colors.fg.getRgb(2, 2, 2),
   colorGray = colors.fg.getRgb(3, 3, 3),
   colorWhite = colors.fg.getRgb(4, 4, 4),
   colorInfoBright = colors.fg.getRgb(1, 2, 5),
   nocolor = colors.reset,
   qualityColor = {
      0: colors.fg.getRgb(3,3,3), // poor
      1: colors.fg.getRgb(5,5,5), // common
      2: colors.fg.getRgb(1,5,0), // uncommon
      3: colors.fg.getRgb(0,2,4), // rare
      4: colors.fg.getRgb(3,0,4), // epic
      5: colors.fg.getRgb(0,4,2), // legendary
   },
   classColor = {
      "Druid": colors.fg.getRgb(Math.round(5), Math.round(0.49*5), Math.round(0.04*5)),
      "Hunter": colors.fg.getRgb(Math.round(0.67*5), Math.round(0.83*5), Math.round(0.45*5)),
      "Mage": colors.fg.getRgb(Math.round(0.25*5), Math.round(0.78*5), Math.round(0.92*5)),
      "Paladin": colors.fg.getRgb(Math.round(0.96*5), Math.round(0.55*5), Math.round(0.73*5)),
      "Priest": colors.fg.getRgb(5, 5, 5),
      "Rogue": colors.fg.getRgb(5, Math.round(0.96*5), Math.round(0.41*5)),
      "Shaman": colors.fg.getRgb(0, Math.round(0.44*5), Math.round(0.87*5)),
      "Warlock": colors.fg.getRgb(Math.round(0.53*5), Math.round(0.53*5), Math.round(0.93*5)),
      "Warrior": colors.fg.getRgb(Math.round(0.78*5), Math.round(0.61*5), Math.round(0.43*5)),
   },
   inquirer = require("inquirer-async"),
   fs = require("fs"),
   path = require('path'),
   buffColor = {
      "Consumable": colorPurple,
      "Flask": colorBrightPurple,
      "World": colorBrown,
   };

const BUFFS = {
   "22888" : {
       "name": "Rallying Cry of the Dragonslayer",
       "desc": "Dragonslayer",
       "type": "World",
       "score": 5,
   },
   "15366" : {
       "name": "Songflower Serenade",
       "desc": "Songflower",
       "type": "World",
       "score": 5,
   },
   "22817" : {
       "name": "Fengus' Ferocity",
       "desc": "DMT AP",
       "type": "World",
       "score": 5,
       "ignore": ["Mage", "Warlock", "Shaman", "Priest"],
   },
   "22820" : {
       "name": "Slip'kik's Savvy",
       "desc": "DMT Crit",
       "type": "World",
       "score": 3,
   },
   "22818" : {
       "name": "Mol'dar's Moxie",
       "desc": "DMT Stamina",
       "type": "World",
       "score": 5,
   },
   "17549" : {
      "name": "Greater Arcane Protection",
      "desc": "Greater Arcane Protection Potion",
      "type": "Consumable",
      "score": 50,
      "onetime": true,
  },
   "17543" : {
       "name": "Greater Fire Protection",
       "desc": "Greater Fire Protection Potion",
       "type": "Consumable",
       "score": 100,
       "onetime": true,
   },
   "7233" : {
       "name": "Fire Protection",
       "type": "Consumable",
       "score": 50,
       "onetime": true,
   },
   "17548" : {
       "name": "Greater Shadow Protection",
       "desc": "Greater Shadow Protection Potion",
       "type": "Consumable",
       "score": 100,
       "onetime": true,
   },
   "7242" : {
       "name": "Shadow Protection",
       "desc": "Shadow Protection Potion",
       "type": "Consumable",
       "score": 50,
       "onetime": true,
   },
   "17546" : {
       "name": "Greater Nature Protection",
       "desc": "Greater Nature Protection Potion",
       "type": "Consumable",
       "score": 100,
       "onetime": true,
   },
   "7254" : {
       "name": "Nature Protection",
       "desc": "Nature Protection Potion",
       "type": "Consumable",
       "score": 50,
       "onetime": true,
   },
   "17544" : {
       "name": "Greater Frost Protection",
       "desc": "Greater Frost Protection Potion",
       "type": "Consumable",
       "score": 100,
       "onetime": true,
   },
   "7239" : {
       "name": "Frost Protection",
       "desc": "Frost Protection Potion",
       "type": "Consumable",
       "score": 50,
       "onetime": true,
   },
   "17539" : {
       "name": "Greater Arcane Elixir",
       "type": "Consumable",
       "score": 5,
       "ignore": ["Warrior", "Rogue", "Hunter"],
   },
   "11474" : {
       "name": "Elixir of Shadow Power",
       "type": "Consumable",
       "score": 5,
       "ignore": ["Mage", "Shaman"],
   },
   "17538" : {
       "name": "Elixir of the Mongoose",
       "type": "Consumable",
       "score": 5,
       "ignore": ["Mage", "Warlock", "Shaman", "Priest"],
   },
   "16326" : {
       "name": "Juju Ember",
       "desc": "Fire Res Juju",
       "type": "Consumable",
       "score": 20,
   },
   "16329" : {
       "name": "Juju Might",
       "desc": "Attack Power Juju",
       "type": "Consumable",
       "score": 20,
       "ignore": ["Mage", "Warlock", "Shaman", "Priest"],
   },
   "16323" : {
       "name": "Juju Power",
       "desc": "Strength Juju",
       "type": "Consumable",
       "score": 20,
       "ignore": ["Mage", "Warlock", "Shaman", "Priest"],
   },
   "16322" : {
       "name": "Juju Flurry",
       "desc": "Attack Speed Juju",
       "type": "Consumable",
       "score": 20,
       "ignore": ["Mage", "Warlock", "Shaman", "Priest"],
   },
   "16325" : {
       "name": "Juju Chill",
       "desc": "Frost Res Juju",
       "type": "Consumable",
       "score": 20,
   },
   "16321" : {
       "name": "Juju Escape",
       "desc": "Dodge Juju",
       "type": "Consumable",
       "score": 20,
       "ignore": ["Mage", "Warlock", "Shaman", "Priest"],
   },
   "17628" : {
       "name": "Supreme Power",
       "type": "Flask",
       "score": 20,
   },
   "17626" : {
       "name": "Flask of the Titans",
       "type": "Flask",
       "score": 20,
   },
   "17627" : {
       "name": "Distilled Wisdom",
       "type": "Flask",
       "score": 20,
   },
}

String.prototype.replaceAll = function(search, replacement) {
   let target = this;
   return target.split(search).join(replacement);
};

function playerColor(playerClass) {
   return classColor[playerClass] || colorInfo;
}

function sortPlayerByClass(classes) {
   return (a, b) => {
      const classa = classes[a], classb = classes[b];
      if (classa < classb)
         return -1;
      if (classa > classb)
         return 1;
      return 0;
   }
}

function printUsageAndExit() {
   console.log('USAGE: node export.js [EXPORT_PATH]');
   console.log('EXPORT_PATH = Where JSON output will be written');
   process.exit(1);
}

/**
 * Searches for a file, scans up or down the tree
 * @param dir starting directory
 * @param filename search file with this name
 * @param scanBackwards if false, drills down the tree; if true goes back (up)
 * @return {String} if stopWhenFound, returns a file. if not, returns array of files.
 */
function searchRecursive(dir, filename, scanBackwards) {
   let files = fs.readdirSync(dir);
   for (let i = 0; i < files.length; i++) {
      let file = path.resolve(dir, files[i]);
      let stat = fs.statSync(file);
      if (path.basename(file).toLowerCase() === filename.toLowerCase())
         return file;
      if (!scanBackwards && stat.isDirectory()) {
         file = searchRecursive(file, filename, scanBackwards);
         if (file)
            return file;
      }
   }
   if (scanBackwards) {
      const nextDir = path.join(dir, '..');
      if (nextDir !== dir)
         return searchRecursive(path.join(dir, '..'), filename, scanBackwards);
   }
   return null;
}

function parseLua(lua) {
   let json = lua;
   json = json.replaceAll('\t["', '\t"');
   json = json.replaceAll('"] = ', '": ');
   json = json.replaceAll('\t[', '\t"');
   json = json.replaceAll('\tnil, --', '\tnull, --');
   json = json.replaceAll('\t', "");
   json = json.replaceAll('\r', "");

   let firstVar = true;
   const lines = json.split('\n');
   for (let i = 0; i < lines.length; i++) {
      if (lines[i].indexOf(' = {') !== -1) {
         lines[i] = `${firstVar ? '"' : ', "'}${lines[i].replace(' = {', '": {')}`
         firstVar = false;
      }
      if (lines[i].indexOf(' = nil') !== -1) {
         lines[i] = `${firstVar ? '"' : ', "'}${lines[i].replace(' = nil', '": null')}`
         firstVar = false;
      }
   }
   json = lines.join('');

   // convert arrays
   let arrayIndex = 0;
   let pos = json.indexOf(', -- [')
   while (pos !== -1) {
      if (json[pos-1] === '}') {
         let j = pos - 2, count = 1;
         while (count) {
            if (json[j] == '}')
               count++;
            if (json[j] == '{')
               count--;
            j--;
         }
         j++;
         json = json.substr(0, j) + `"${(arrayIndex++) + 1}": ` + json.substr(j, pos - j + 1) + json.substr(json.indexOf(']', pos) + 1);
      } else {
         let j = pos - 1;
         while (json[j] !== '{' && json[j] !== ',')
            j--;
         j++;
         json = json.substr(0, j) + `"${(arrayIndex++) + 1}": ` + json.substr(j, pos - j) + ',' + json.substr(json.indexOf(']', pos) + 1);
      }
      pos = json.indexOf(', -- [');
   }
   // lines[i] = lines[i].indexOf(', -- [') === -1 ? lines[i] : `"${i + 1}": ` + lines[i].split(', -- [')[0] + ',';

   json = json.replaceAll(',}', '}');
   json = '{' + json + '}';


   return JSON.parse(json);
}

function readRaids(lua) {
   let raids, classes;
   let luaContent = fs.readFileSync(lua).toString('utf8');
   luaContent = luaContent.replace("Store = nil", "")
   try {
      // convert LUA format to JSON format
      let store = parseLua(luaContent)["RaidLoggerStore"];

      const dateCompare = (left, right) => left.date.localeCompare(right.date);
      raids = Object.values(store['raids']).sort(dateCompare).reverse();
      classes = store['players'] || {};

      if (raids.length > MAX_RAID_OPTIONS)
         raids.splice(MAX_RAID_OPTIONS);

      raids.forEach(raid => {
         raid['attended'] = Object.values(raid['attended']);
         raid['benched'] = Object.values(raid['benched']);
      });
   } catch (e) {
      console.error(`Failed parsing LUA file: ${e.message}`);
      console.log(luaContent);
      process.exit(1);
   }

   if (!raids || !raids.length) {
      console.log(`No raids found.`);
      process.exit(1);
   }
   return {raids, classes};
}

function getBuffString(playerClass, buffs) {
   let strings = [];
   let asArr = [];
   let score = 0;
   Object.keys(buffs).forEach(spellId => {
      let minutes = buffs[spellId];
      if (!BUFFS[spellId].ignore || BUFFS[spellId].ignore.indexOf(playerClass) == -1)
         score += (BUFFS[spellId].onetime ? BUFFS[spellId].score : BUFFS[spellId].score * minutes);
      asArr.push({spellId, minutes});
   });
   let text = ` ${colorWhite}${(''+score).padStart(6, ' ')}  ` + asArr
      .sort((a, b) => b.minutes - a.minutes)
      .map(buff => `${buffColor[BUFFS[buff.spellId].type]}${BUFFS[buff.spellId].name} ${colorGray}${buff.minutes}m`)
      .join(`${colorDarkGray}, `);
   return {score, text};
}

async function main() {
   // console.log(process.argv.length);
   try {
      const exportPath = process.argv.length < 3 ? '.' : process.argv[2];

      let wtfFile = searchRecursive(__dirname, 'WTF', 1);
      if (!wtfFile) {
         console.error(`Couldn't find WoW root folder! Make sure to run this file somewhere within your WoW folder, or one of its sub-folders`);
         process.exit(1);
      }

      let luaFile = searchRecursive(wtfFile, 'RaidLogger.lua', 0);
      if (!luaFile) {
         console.error(`Couldn't find RaidLogger.lua output file! It should be under SavedVariables after finishing a raid with /rl end`);
         process.exit(1);
      }
      console.log(`\nUsing ${colorWarning}${luaFile}${nocolor}`);

      const backupFilename = `backup-${moment().format('YYYYMMDDHHmmss')}.lua`;
      fs.copyFileSync(luaFile, path.join(exportPath, backupFilename))

      const {raids, classes} = readRaids(luaFile);
      let answerIndex = 0

      if (!USE_LAST_RAID) {
         let raidOptions = raids.map(o => `${o['date']} / ${o['zone']} / ${o['attendedCount']} participants, ${o['benchedCount']} benched`);
         raidOptions.push('Cancel');

         console.log('');
         let answers = await inquirer.promptAsync([{
            type: 'list',
            name: 'action',
            message: 'Choose a raid:',
            choices: raidOptions
         }]);
         answerIndex = raidOptions.indexOf(answers['action']);

         if (answerIndex === raidOptions.length - 1)
            process.exit(0);
      }

      const raid = raids[answerIndex];

      let attendedPlayers = raid['attended']
         .sort(sortPlayerByClass(classes))
         .map(p => ({p, buffs: getBuffString(classes[p], raid.buffs[p])}))
         .sort((a, b) => b.buffs.score - a.buffs.score)
         .map(o => `  ${playerColor(classes[o.p])}${o.p.padEnd(12, ' ')}${nocolor} ${o.buffs.text}`)
         .join('\n  ');
         // .forEach(p => playerByClass[classes[p]] = (playerByClass[classes[p]] || []).concat(`${playerColor(classes[p])}${p}`));
      // const playersGroupedByClass =
      //    Object.values(playerByClass)
      //       .map(players => players.join(", "))
      //       .join('\n  ');

      console.log(`\nParticipants:\n  ${attendedPlayers}${nocolor}\n`);
      if (raid['benched'] && raid['benched'].length)
         console.log(`Benched:${colorInfo}\n  ${raid['benched'].join('\n  ')}${nocolor}\n`);
      console.log(`Loot:\n  ${Object.values(raid['loot'] || {}).map(o => {
         if (o['de'])
            return `${colorGreen}Disenchanted ${qualityColor[o['quality']]}[${o['item']}]${nocolor}`;
         else 
            return `${playerColor(classes[o['player']])}${o['player']} ${colorGreen}received ${qualityColor[o['quality']]}[${o['item']}]${nocolor}`; 
      }).join('\n  ')}${nocolor}\n`);

      const raidDateParts = raid['date'].split(' ')[0].split('-');
      console.log(`\nPlayer,Item,Date\n${Object
         .values(raid['loot'] || {})
         .filter(o => !o['de'] && o['quality'] >= 4)
         .map(o => `${o['player']},${o['item']},${raidDateParts[1]}/${raidDateParts[2]}/${raidDateParts[0]}`)
         .join('\n')}${nocolor}\n`);

      let answers = await inquirer.promptAsync([{
         type: 'list',
         name: 'action',
         message: 'Proceed with export?',
         choices: ['Stop', 'Export to JSON']
      }]);

      if (answers['action'] === 'Export to JSON') {
         const filename = `${raid['date'].replace(' ', '').replaceAll('-', '').replace(':', '')}_${raid['zone'].replaceAll(' ', '')}.json`;
         fs.writeFileSync(path.join(exportPath, filename), JSON.stringify(raid));
      }

   } catch (e) {
      console.error(`Exception: ${e.stack}`);
   }
}

main();
