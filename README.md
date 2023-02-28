# RaidLogger

Tracks raid attendance, loot distribution with loot council support.

## Installation

* Put the RaidLogger directory under your `Interface/Addons` directory, remove `-master` suffix if you downloaded ZIP from GitHub.

If you're going to use the export script (see below), also follow steps described under _Exporting Raid_

## Usage 

When entering a high-end vanilla instance (MC, BWL, ZG, AQ20, AQ40, Naxx) a new raid will be automatically start being logged.

Every time a player joins the raid, his attendance will be automatically logged. 

Loot distributed will be automatically logged as well when picked.
![loot log](https://octodex.github.com/E1ila/RaidLogger/imgs/loot-row.png)

When raid is over, type `/rlog end` to close and save the raid. For help and a full list of commands, type `/rlog h` or `/rlog help`.

#### Loot council

There are two way of working with this addon, your Master Looter can either send loot to the rightful receiver, or all loot can be picked up by one person, decided on the go and traded to the final receiver.

If you're distributing loot directly to the receiver, there's nothing special needed to be done, it'll track everything automatically, you can skip this section.

To work with others, they have to install the addon as well, then everyone who's using it should write `/rlog password <SYNC_PASSWORD>`, everyone should use the same password to be able to sync.

To determine who's able to vote for loot, write `/rlog council <PLAYER_NAME>` for each council member. This will be synced to other members in your sync channel so only one person needs to do it.

Loot council members will be see extra controls near each loot row and will be able to vote -
![loot log](https://octodex.github.com/E1ila/RaidLogger/imgs/loot-row-council.png)
if all council agrees, a green check will appear indicating this received has been approved -
![loot log](https://octodex.github.com/E1ila/RaidLogger/imgs/loot-row-agree.png)
if even one council member disagrees, a red cross will appear -
![loot log](https://octodex.github.com/E1ila/RaidLogger/imgs/loot-row-disagree.png)


## Exporting Raid

#### Prerequisites

As a one-time step, you need to do the following -

* Install [Node.js](https://nodejs.org) framework.
* Open a terminal and go to the RaidLogger addon folder, for example `cd \WoW\Interface\AddOns\RaidLogger`.
* Install library dependencies using command `npm i`. 

#### Uploading

**Do not forget to `/rlog end` or you won't see the raid on the list**

After exiting WoW, you may upload the attendance log to your guild's website.

From command prompt, run the upload script -

```commandline
node export.js upload raid <WEBSITE_API_URL> --backup <BACKUP_PATH> --gear --logs <WCL_PARSE_URL>
```

For example, on Windows -

```commandline
node \WoW\Interface\AddOns\RaidLogger\export.js upload raid https://myguild.com/api/SECRETKEY --backup c:\logs-backup --gear --logs https://classic.warcraftlogs.com/reports/Z9n1PdXK3vgL6mBQ/ 
```

Or on Mac -

```commandline
node /Applications/WoW/Interface/AddOns/RaidLogger/export.js upload raid https://myguild.com/api/SECRETKEY --backup ~/logs-backup --gear --logs https://classic.warcraftlogs.com/reports/Z9n1PdXK3vgL6mBQ/ 
```

You can save this command into a script, so you won't have to type this all over again each time. Make sure to replace `WoW` with the actual path of your World of Warcraft directory.

You'll be then be shown with last 10 raids, after choosing one it'll upload it to the website.

Write `node export.js upload --help` for a detailed list of commands and what each parameter does -
```
Usage: export upload [options] <what> <url>

Uploads data to guild's website
  <what>   raids / buffs
  <url>    website API endpoint URL

Options:
  --backup <path>         Back up files to this directory
  --gear                  Parse and upload gear from WoWCombatLog.txt, will also backup/delete it
  --retainlog             Do not delete combat log
  --logs <url>            Link to raid logs
  -c, --combatlogs <url>  Location of combat logs
  -h, --help              output usage information
```



### MIT License
Copyright 2019 https://github.com/E1ila

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
