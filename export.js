#!/usr/bin/env node
'use strict';

// Written by Kof

const
   MAX_RAID_OPTIONS = 20,
   USE_LAST_RAID = false,
   moment = require('moment'),
   colors = require('ansi-256-colors'),
   program = require('commander'),
   request = require('async-request'),
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
      0: colors.fg.getRgb(3, 3, 3), // poor
      1: colors.fg.getRgb(5, 5, 5), // common
      2: colors.fg.getRgb(1, 5, 0), // uncommon
      3: colors.fg.getRgb(0, 2, 4), // rare
      4: colors.fg.getRgb(3, 0, 4), // epic
      5: colors.fg.getRgb(0, 4, 2), // legendary
   },
   classColor = {
      "Druid": colors.fg.getRgb(Math.round(5), Math.round(0.49 * 5), Math.round(0.04 * 5)),
      "Hunter": colors.fg.getRgb(Math.round(0.67 * 5), Math.round(0.83 * 5), Math.round(0.45 * 5)),
      "Mage": colors.fg.getRgb(Math.round(0.25 * 5), Math.round(0.78 * 5), Math.round(0.92 * 5)),
      "Paladin": colors.fg.getRgb(Math.round(0.96 * 5), Math.round(0.55 * 5), Math.round(0.73 * 5)),
      "Priest": colors.fg.getRgb(5, 5, 5),
      "Rogue": colors.fg.getRgb(5, Math.round(0.96 * 5), Math.round(0.41 * 5)),
      "Shaman": colors.fg.getRgb(0, Math.round(0.44 * 5), Math.round(0.87 * 5)),
      "Warlock": colors.fg.getRgb(Math.round(0.53 * 5), Math.round(0.53 * 5), Math.round(0.93 * 5)),
      "Warrior": colors.fg.getRgb(Math.round(0.78 * 5), Math.round(0.61 * 5), Math.round(0.43 * 5)),
   },
   inquirer = require("inquirer-async"),
   fs = require("fs"),
   path = require('path'),
   buffColor = {
      "Consumable": colorPurple,
      "Flask": colorBrightPurple,
      "World": colorBrown,
      "Food": colorPurple,
      "Alcohol": colorPurple,
   },
   BUFFS = require('./buffs');

String.prototype.replaceAll = function (search, replacement) {
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
      if (json[pos - 1] === '}') {
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
   let raids, classes, roster;
   let luaContent = fs.readFileSync(lua).toString('utf8');
   luaContent = luaContent.replace("Store = nil", "")
   try {
      // convert LUA format to JSON format
      let store = parseLua(luaContent)["RaidLoggerStore"];

      const dateCompare = (left, right) => left.date.localeCompare(right.date);
      raids = Object.values(store['raids']).sort(dateCompare).reverse();
      classes = store['players'] || {};
      roster = store['guildRoster'];

      if (raids.length > MAX_RAID_OPTIONS)
         raids.splice(MAX_RAID_OPTIONS);

      raids.forEach(raid => {
         raid['attended'] = Object.values(raid['attended']);
         raid['benched'] = Object.values(raid['benched']);
         raid['loot'] = Object.values(raid['loot']);
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
   return { raids, classes, roster };
}

function getBuffString(playerClass, buffs) {
   let strings = []
   let asArr = []
   let score = 0
   Object.keys(buffs).forEach(spellId => {
      let minutes = buffs[spellId]
      if (!BUFFS[spellId]) {
         console.error(`Missing buff info for spell ID ${spellId}`);
      } else {
         if (!BUFFS[spellId].ignore || BUFFS[spellId].ignore.indexOf(playerClass) == -1)
            score += (BUFFS[spellId].onetime ? BUFFS[spellId].score : BUFFS[spellId].score * minutes);
         asArr.push({ spellId, minutes });
      }
   });
   let text = ` ${colorWhite}${('' + score).padStart(6, ' ')}  ` + asArr
      .sort((a, b) => b.minutes - a.minutes)
      .map(buff => `${buffColor[BUFFS[buff.spellId].type]}${BUFFS[buff.spellId].name} ${colorGray}${buff.minutes}m`)
      .join(`${colorDarkGray}, `);
   return { score, text };
}

function findLuaFile() {
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

   return luaFile;
}

function backup(exportPath) {
   const backupFilename = `backup-${moment().format('YYYYMMDDHHmmss')}.lua`;
   fs.copyFileSync(luaFile, path.join(exportPath, backupFilename))
}

function raidName(o) {
   return `${o['date']} / ${o['zone']} / ${o['attendedCount']} participants, ${o['benchedCount']} benched`;
}

async function browseLua(exportPath) {
   try {
      let luaFile = findLuaFile()
      // backup()

      const { raids, classes } = readRaids(luaFile);
      let answerIndex = 0

      if (!USE_LAST_RAID) {
         let raidOptions = raids.map(o => raidName(o));
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

      let attendedPlayers = raid['attended'].sort(sortPlayerByClass(classes));
      if (raid.buffs) {
         attendedPlayers = attendedPlayers
            .map(p => ({ p, buffs: raid.buffs && getBuffString(classes[p], raid.buffs[p]) }))
            .sort((a, b) => b.buffs.score - a.buffs.score)
            .map(o => `  ${playerColor(classes[o.p])}${o.p.padEnd(12, ' ')}${nocolor} ${o.buffs.text}`)
            .join('\n  ');
         console.log(`\nParticipants:\n  ${attendedPlayers}${nocolor}\n`);
      } else {
         let playerByClass = {};
         attendedPlayers = attendedPlayers
            .forEach(p => playerByClass[classes[p]] = (playerByClass[classes[p]] || []).concat(`${playerColor(classes[p])}${p}`));
         const playersGroupedByClass =
            Object.values(playerByClass)
               .map(players => players.join(", "))
               .join('\n  ');
         console.log(`\nParticipants:\n  ${playersGroupedByClass}${nocolor}\n`);
      }
      // .forEach(p => playerByClass[classes[p]] = (playerByClass[classes[p]] || []).concat(`${playerColor(classes[p])}${p}`));
      // const playersGroupedByClass =
      //    Object.values(playerByClass)
      //       .map(players => players.join(", "))
      //       .join('\n  ');

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

async function uploadRaids(apiEndpoint, logs, choose) {
   try {
      let luaFile = findLuaFile()
      const payload = readRaids(luaFile);
      let first = true;
      let raids;

      if (choose) {
         let raidOptions = payload.raids.map(o => raidName(o));
         raidOptions.push('Cancel');

         console.log('');
         let answers = await inquirer.promptAsync([{
            type: 'list',
            name: 'action',
            message: 'Choose a raid:',
            choices: raidOptions
         }]);
         let answerIndex = raidOptions.indexOf(answers['action']);
         console.log('');

         if (answerIndex === raidOptions.length - 1)
            process.exit(0);

            raids = [payload.raids[answerIndex]];
      } else 
         raids = payload.raids.sort((a, b) => a['date'].localeCompare(b['date']));

      for (let raid of raids) {
         // fix local time
         if (!raid.startTime)
            raid.startTime = (+moment(raid.date, 'YY-MM-DD HH:mm:ss')) / 1000;

         console.log(`Uploading raid ${raidName(raid)} to ${apiEndpoint + "/raid"}...`)
         const response = await request(apiEndpoint + "/raid", {
            method: 'POST',
            data: {
               logs,
               raid, 
               classes: first ? payload.classes : null,
               roster: first ? payload.roster : null,
            },
         });   
         first = false;
         if (response.statusCode === 200) {
            const responseContent = JSON.parse(response.body);
            if (responseContent.error) {
               if (responseContent.errorCode === 1) {
                  console.warn(responseContent.error);
               } else {
                  console.error(responseContent.error);
                  console.debug(JSON.stringify(raid));
               }
            }
         } else {
            console.error("Unexpected HTTP status: " + response.statusCode);
            console.error("Response body: " + response.body);
            console.debug(JSON.stringify(raid));
         }
      }
   } catch (e) {
      console.error(`Exception: ${e.stack}`);
   }
}


async function uploadBuffs(apiEndpoint) {
   try {
      console.log(`Uploading buffs...`)
      const buffs = Object.keys(BUFFS).map(spellId => ({
         spellId, 
         desc: BUFFS[spellId].desc, 
         name: BUFFS[spellId].name, 
         score: BUFFS[spellId].score, 
         type: BUFFS[spellId].type, 
         onetime: BUFFS[spellId].onetime ? 1 : 0, 
         ignore: (BUFFS[spellId].ignore || []).join(','),
         imageUrl: BUFFS[spellId].imageUrl,
      }));
      const response = await request(apiEndpoint + "/buffs", {
         method: 'POST',
         data: {buffs},
      });   
      if (response.statusCode === 200) {
         const responseContent = JSON.parse(response.body);
         if (responseContent.error) {
            console.error(responseContent.error);
            // console.debug(JSON.stringify(BUFFS));
         }
      } else {
         console.error("Unexpected HTTP status: " + response.statusCode);
         // console.debug(JSON.stringify(BUFFS));
      }
   } catch (e) {
      console.error(`Exception: ${e.stack}`);
   }
}

async function main() {
   program
      .command('browse')
      .description('Browse raids in LUA')
      .option("-e, --export <exportPath>", "Path to export data", ".")
      .action(async function (options) {
         await browseLua(options['exportPath']);
         console.log('Done.');
      });

   program
      .command('upload <what> <url>')
      .description('Uploads data to guild\'s website\n  <what>   raids / buffs\n  <url>    website API endpoint URL')
      .option('--logs <url>', 'Link to raid logs')
      .action(async function (what, apiurl, options) {
         if (what === "raid") 
            await uploadRaids(apiurl, options.logs, true);
         else if (what === "raids") 
            await uploadRaids(apiurl, options.logs);
         else if (what === "buffs") 
            await uploadBuffs(apiurl);
         console.log('Done.');
      });

   program.parse(process.argv);

   // if (program.args.length === 0)
      // program.help();
}

main();
