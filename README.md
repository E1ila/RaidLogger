# RaidLogger
Tracks raid attendance and benched players.

## Installation

Put the RaidLogger directory under your Interface/Addons directory.

If you're going to use the upload script (see below), also follow these steps:

* Install [Node.js](https://nodejs.org) framework.
* Open a terminal and go to the RaidLogger addon folder, for example `cd \WoW\Interface\AddOns\RaidLogger`.
* Install library dependencies using command `npm i`. 

## Usage 
When entering a high-end vanilla instance (MC, BWL, ZG, AQ20, AQ40, Naxx) a new raid will be automatically start being logged.

Every time a player joins the raid, his attendance will be automatically logged.

You can log benched players by typing `/rl bench <PLAYER_NAME>`, he won't be logged as attended, but on a separate benched list.

When raid is over, type `/rl end` to close and save the raid. For help and a full list of commands, type `/rl h` or `/rl help`.

## Exporting Raid

After exiting WoW, you may upload the attendance log to your guild's website. For that, you first need to have Node.js framework and dependencies installed (see above).

From command prompt, run the upload script -

```commandline
node <ADDON_PATH>/export.js <OUTPUT_PATH> 
```

For example, on Windows -

```commandline
node \WoW\Interface\AddOns\RaidLogger\export.js C:\raid_loot
```

Or on Mac -

```commandline
node /Applications/WoW/Interface/AddOns/RaidLogger/export.js ~/raid_loot
```

You can save this command into a script, so you won't have to type this all over again each time. Make sure to replace `WoW` with the actual path of your World of Warcraft directory and `YOURACCOUNT` with the directory name of your account.

You'll be then be shown with last 3 raids, after choosing one it'll print the list of attended and benched  players. You can then proceed to upload those to your website.
