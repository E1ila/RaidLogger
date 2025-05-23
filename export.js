#!/usr/bin/env node
'use strict';

// Written by Kof

const
   MAX_RAID_OPTIONS = 40,
   ZONE_SHORT_NAME = {
      "Onyxia's Lair": "Onyxia",
      "The Molten Core": "MC",
      "Blackwing Lair": "BWL",
      "Zul'Gurub": "ZG",
      "Ahn'Qiraj": "AQ40",
      "Ruins of Ahn'Qiraj": "AQ20",
      "Naxxramas": "Naxx",
   },
   moment = require('moment'),
   colors = require('ansi-256-colors'),
   program = require('commander'),
   request = require('async-request'),
   Promise = require('bluebird'),
   lineReader = require('line-reader'),
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
   // console.log(`scanning ${dir} ...`);
   for (let i = 0; i < files.length; i++) {
      let file = path.resolve(dir, files[i]);
      try {
         let stat = fs.statSync(file);
         if (path.basename(file).toLowerCase() === filename.toLowerCase())
            return file;
         if (!scanBackwards && stat.isDirectory()) {
            file = searchRecursive(file, filename, scanBackwards);
            if (file)
               return file;
         }
      } catch (e) { }
   }
   if (scanBackwards) {
      const nextDir = path.join(dir, '..');
      if (nextDir !== dir)
         return searchRecursive(path.join(dir, '..'), filename, scanBackwards);
   }
   return null;
}

let arrayIndex = 0;

function parseLua2(lua) {
   let json = lua.substring(lua.indexOf('RaidLoggerStore = ') + 'RaidLoggerStore = '.length); // remove RaidLoggerStore =
   json = json.replace(/\["([\p{L}\w-]+)"\] = /gu, '"$1": ');
   json = json.replace(/\r\n[{]\r\n/g, (s, args) => {
      return `\r\n"ARR-${(''+arrayIndex++).padStart(6, '0')}": {\r\n`;
   });
   const guildRosterTag = '"guildRoster": {';
   let pos = json.indexOf(guildRosterTag);
   if (pos !== -1) {
      let pos2 = json.lastIndexOf('},');
      let mid = json.substring(pos + guildRosterTag.length, pos2);
      // convert LUA arrays to JSON arrays
      mid = mid.replace(/{/g, '[').replace(/}/g, ']');
      json =
         json.substring(0, pos + guildRosterTag.length) +
         mid +
         json.substring(pos2);
   }
   // remove /r/n
   json = json.replace(/\r\n/g, '');
   json = json.replace(/,}/g, '}');
   json = json.replace(/,]/g, ']');
   return JSON.parse(json);
}

function fixPlayerMap(map, defaultRealm) {
   if (defaultRealm) {
      for (let name in map) {
         if (name.indexOf('-') === -1) {
            map[name + '-' + defaultRealm] = map[name];
            delete map[name];
         }
      }
   }
}

function readRaids(lua, defaultRealm) {
   let raids, classes, roster;
   let luaContent = fs.readFileSync(lua).toString('utf8');
   luaContent = luaContent.replace("Store = nil", "")
   try {
      // convert LUA format to JSON format
      let store = parseLua2(luaContent);

      const dateCompare = (left, right) => left.date.localeCompare(right.date);
      raids = Object.values(store['raids']).sort(dateCompare).reverse();
      classes = store['players'] || {};
      roster = store['guildRoster'];

      if (raids.length > MAX_RAID_OPTIONS)
         raids.splice(MAX_RAID_OPTIONS);

      raids.forEach(raid => {
      fixPlayerMap(raid.buffs, defaultRealm);
      fixPlayerMap(raid.players, defaultRealm);
         raid['loot'] = Object.values(raid['loot']).map(loot => {
            if (defaultRealm && loot.player.indexOf('-') === -1)
               loot.player += '-' + defaultRealm;
            return loot;
         });
      });

      fixPlayerMap(classes, defaultRealm);
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
         if (spellId != "present") // minutes of attendance
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
   console.log(`Using LUA ${colorWarning}${luaFile}${nocolor}`);

   return luaFile;
}

function findLogFile(required) {
   let logsDir = searchRecursive(__dirname, 'Logs', 1);
   if (!logsDir) {
      if (!required) return;
      console.error(`Couldn't find WoW Logs folder! Make sure to run this file somewhere within your WoW folder, or one of its sub-folders`);
      process.exit(1);
   }

   let logFile = searchRecursive(logsDir, 'WoWCombatLog.txt', 0);
   if (!logFile) {
      if (!required) return;
      console.error(`Couldn't find Logs/WoWCombatLog.txt file! It should be under Logs after logging out.`);
      return null;
   }
   console.log(`Found log file ${colorWarning}${logFile}${nocolor}`);

   return logFile;
}

function backup(backupPath, sourceFile, postfix, ext) {
   if (!backupPath) return;
   const backupFile = path.join(backupPath, `${postfix}-${moment().format('YYYYMMDDHHmmss')}.${ext}`);
   console.log(`Backing up ${sourceFile} ==> ${backupFile}`);
   fs.copyFileSync(sourceFile, backupFile);
}

function raidName(o) {
   return `${o['date']} / ${o['zone']}`;
}

function filterPlayers(players, filter) {
   return Object.keys(players).map(name => players[name] === filter ? name : null).filter(name => !!name);
}

function handleServerResponse(response, debugObj) {
   if (response.statusCode === 200) {
      const responseContent = JSON.parse(response.body);
      if (responseContent.error) {
         if (responseContent.errorCode === 1) {
            console.warn(responseContent.error);
         } else {
            console.error(responseContent.error);
            if (debugObj)
               console.debug(JSON.stringify(debugObj));
         }
      }
      else if (responseContent.ok)
         return true;
   } else {
      console.error("Unexpected HTTP status: " + response.statusCode);
      console.error("Response body: " + response.body);
      if (debugObj)
         console.debug(JSON.stringify(debugObj));
   }
}

async function browseLua(exportPath, luaFile, useLastRaid) {
   try {
      if (!luaFile)
         luaFile = findLuaFile()

      const { raids, classes } = readRaids(luaFile);
      let raidOptions = raids.map(o => raidName(o));
      let answerIndex = 0; // raidOptions.indexOf('19-10-23 22:46 / The Molten Core');

      if (!useLastRaid) {
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

      // console.log(JSON.stringify(raid));
      let attendedPlayers = [];
      if (raid['attended'])
         attendedPlayers = Object.values(raid['attended']).sort(sortPlayerByClass(classes));
      else if (raid['players'])
         attendedPlayers = filterPlayers(raid['players'], 'a').sort(sortPlayerByClass(classes));

      if (raid.buffs) {
         attendedPlayers = attendedPlayers
            .filter(p => raid.buffs[p])
            .map(p => ({ p, buffs: raid.buffs && raid.buffs[p] && getBuffString(classes[p], raid.buffs[p]) }))
            .sort((a, b) => (b.buffs && b.buffs.score || 0) - (a.buffs && a.buffs.score || 0))
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
      else if (raid['players']) {
         console.log(`Benched:${colorInfo}\n  ${filterPlayers(raid['players'], 'b').join('\n  ')}${nocolor}\n`);
         console.log(`No show:${colorInfo}\n  ${filterPlayers(raid['players'], 'n').join('\n  ')}${nocolor}\n`);
         console.log(`Late:${colorInfo}\n  ${filterPlayers(raid['players'], 'l').join('\n  ')}${nocolor}\n`);
      }

      console.log(`Loot:\n  ${Object.values(raid['loot'] || {}).map(o => {
         if (o['de'])
            return `${colorGreen}Disenchanted ${qualityColor[o['quality']]}[${o['item']}]${nocolor}`;
         else
            return `${playerColor(classes[o['tradedTo'] || o['player']])}${o['tradedTo'] || o['player']} ${colorGreen}received ${qualityColor[o['quality']]}[${o['item']}]${nocolor}`;
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

async function uploadRaids(apiEndpoint, luaFile, backupPath, logs, vod, gear, retainlog, choose, combatlogsPath, defaultRealm, useLastRaid, zoneFilter) {
   try {
      if (!luaFile)
         luaFile = findLuaFile()

      const payload = readRaids(luaFile, defaultRealm);
      let first = true;
      let raids;

      if (choose) {
         let raidOptions = payload.raids.map((o, index) => ({name: raidName(o), index, zone: o.zone}));
         raidOptions = raidOptions.filter(o => !zoneFilter || ZONE_SHORT_NAME[o.zone] === zoneFilter);
         raidOptions.push({name: 'Cancel'});

         if (useLastRaid) {
            raids = [payload.raids[0]];
         } else {
            console.log('');
            const choices = raidOptions.map(o => o.name);
            let answers = await inquirer.promptAsync([{
               type: 'list',
               name: 'action',
               message: 'Choose a raid:',
               choices,
            }]);
            let answerIndex = choices.indexOf(answers['action']);
            console.log('');

            if (answerIndex === raidOptions.length - 1)
               process.exit(0);

            raids = [payload.raids[raidOptions[answerIndex].index]];
         }
      } else
         raids = payload.raids.sort((a, b) => a['date'].localeCompare(b['date']));

      backup(backupPath, luaFile, "raids", "lua");

      for (let raid of raids) {
         // fix local time
         if (!raid.startTime)
            raid.startTime = (+moment(raid.date, 'YY-MM-DD HH:mm:ss')) / 1000;

         console.log(`Uploading raid ${raidName(raid)} to ${apiEndpoint + "/raid"}...`);
         try {
            const response = await request(apiEndpoint + "/raid", {
               method: 'POST',
               data: {
                  logs,
				  vod,
                  raid,
                  classes: first ? payload.classes : null,
                  roster: first ? payload.roster : null,
               },
            });
            first = false;
            handleServerResponse(response);
         } catch (e) {
            console.error(`Failed uploading raid: ${e.stack}`);
            return;
         }
      }

      if (gear && raids.length)
         await uploadGear(apiEndpoint, luaFile, backupPath, retainlog, payload.classes, raids[0], combatlogsPath);
   } catch (e) {
      console.error(`Failed uploading raid: ${e.stack}`);
   }
}

async function uploadGear(apiEndpoint, luaFile, backupPath, retainlog, classes, raidInfo, combatlogsPath) {
   try {
      const logFile = combatlogsPath || findLogFile(true);

      if (!logFile)
         return;

      if (!classes) {
         if (!luaFile)
            luaFile = findLuaFile()
         const payload = readRaids(luaFile);
         classes = payload.classes;
      }
   
      const extraInfo = raidInfo ? `-${ZONE_SHORT_NAME[raidInfo.zone] || raidInfo.zone}` : "";
      backup(backupPath, logFile, "combatlog" + extraInfo, "txt");

      const { players, playerGear } = await parseCombatLog(logFile);

      const gear = {};
      for (let guid of Object.keys(players)) {
         const name = players[guid]; //.split("-")[0];
         gear[name] = {class: classes[name], gear: playerGear[guid]};
      }

      console.log(`Uploading gear...`);

      const response = await request(apiEndpoint + "/gear", {
         method: 'POST',
         data: gear,
      });
      const ok = handleServerResponse(response);

      if (ok && !retainlog && !combatlogsPath) {
         console.log(`Deleting combat log...`);
         fs.unlinkSync(logFile);
      }

   } catch (e) {
      console.error(`Failed uploading combat logs: ${e.stack}`);
   }
}

function clCreateIter(line) {
   return {line, pos: 0};
}

function clNextVar(iter, skipCount) {
   for (let i = 0; i < (skipCount || 0); i++)
      clNextVar(iter);
   let value = "";
   let pos = iter.line.indexOf(",", iter.pos + 1);
   if (pos !== -1) {
      const value = iter.line.substr(iter.pos + 1, pos - iter.pos - 1);
      iter.pos = pos;
      return value;
   }
   iter.pos = iter.line.length;
   return null;
}

async function parseCombatLog(logFile) {
   const players = {};
   const playerGear = {};

   console.log('Parsing combat log...');

   const COMBATANT_INFO = "COMBATANT_INFO";
   const SPELL_AURA_APPLIED = "SPELL_AURA_APPLIED";

   var eachLine = Promise.promisify(lineReader.eachLine);
   let missing = 0;
   await eachLine(logFile, (line) => {
      if (line.length > 100 && line.substr(line.indexOf("  ") + 2, COMBATANT_INFO.length) === COMBATANT_INFO) {
         const iter = clCreateIter(line);
         const playerGUID = clNextVar(iter, 1);
         if (!playerGear[playerGUID])
            missing++;
         playerGear[playerGUID] = iter.line.substr(iter.pos + 1);
      }
      if (missing && line.length > 100 && line.substr(line.indexOf("  ") + 2, SPELL_AURA_APPLIED.length) === SPELL_AURA_APPLIED) {
         const iter = clCreateIter(line);
         const playerGUID = clNextVar(iter, 1);
         const playerName = clNextVar(iter);
         if (!players[playerGUID] && playerGear[playerGUID]) {
            players[playerGUID] = playerName.replace(/"/g, "");
            missing--;
         }
      }
   })

   console.log('Finished parsing combat log.');
   return {players, playerGear};
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
         data: { buffs },
      });
      handleServerResponse(response);
   } catch (e) {
      console.error(`Exception: ${e.stack}`);
   }
}

async function main() {
   program
      .command('browse')
      .description('Browse raids in LUA')
      .option("--lua <file>", "Full path to RaidLogger.lua saved vadiables")
      .option("-e, --export <exportPath>", "Path to export data", ".")
      .option("--last", "Use last raid instead of letting user choose")
      .action(async function (options) {
         await browseLua(options['exportPath'], options['lua'], options['last']);
         console.log('Done.');
      });

   program
      .command('upload <what> <url>')
      .description('Uploads data to guild\'s website\n  <what>   raid / raids / buffs / gear\n  <url>    website API endpoint URL')
      .option('--backup <path>', 'Back up files to this directory')
      .option('--gear', 'Parse and upload gear from WoWCombatLog.txt, will also backup/delete it')
      .option('--retainlog', 'Do not delete combat log')
      .option('--logs <url>', 'Link to raid logs')
      .option('--vod <url>', 'Link to raid video')
      .option("-z, --zone <name>", "Filter only specific zone: Naxx/BWL/MC/AQ40/AQ20/ZG")
      .option('-c, --combatlogs <url>', 'Location of combat logs')
      .option('--realm <name>', 'Default realm to use for unrealmed player names', 'Firemaw')
      .option("-l, --lua <file>", "Full path to RaidLogger.lua saved vadiables")
      .option("--last", "Use last raid instead of letting user choose")
      .action(async function (what, apiurl, options) {
         if (what === "raid")
            await uploadRaids(apiurl, options.lua, options.backup, options.logs, options.vod, options.gear, options.retainlog, true, options.combatlogs, options.realm, options['last'], options['zone']);
         else if (what === "raids")
            await uploadRaids(apiurl, options.lua, options.backup, options.logs, options.vod, options.gear, options.retainlog, false, options.combatlogs, options.realm, options['last'], options['zone']);
         else if (what === "buffs")
            await uploadBuffs(apiurl);
         else if (what === "gear")
            await uploadGear(apiurl, options.lua, options.backup, options.retainlog, undefined, undefined, options.combatlogs);
         console.log('Done.');
      });

   program.parse(process.argv);

   // if (program.args.length === 0)
   // program.help();
}

main();
