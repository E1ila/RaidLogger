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

## Uploading Attendance

After exiting WoW, you may upload the attendance log to your guild's website. For that, you first need to have Node.js framework and dependencies installed (see above).

From command prompt, run the upload script -

```commandline
node <ADDON_PATH>/upload.js <WEBSITE_API_ENDPOINT> 
```

For example, on Windows -

```commandline
node \WoW\Interface\AddOns\RaidLogger\upload.js http://myguild.com/api
```

Or on Mac -

```commandline
node /Applications/WoW/Interface/AddOns/RaidLogger/upload.js http://myguild.com/api
```

You can save this command into a script, so you won't have to type this all over again each time. Make sure to replace `WoW` with the actual path of your World of Warcraft directory and `YOURACCOUNT` with the directory name of your account.

You'll be then be shown with last 3 raids, after choosing one it'll print the list of attended and benched  players. You can then proceed to upload those to your website.

## Upload Protocol

Your guild's website would need to support the following REST API in order to be able to receive the log.

#### GET `/events`

Reads a list of events from the guild's website. 

You may return only events which haven't received attendance log, or some of them. It is advised to limit the number of returned events to no more than 10.

Response should be a JSON containing a list of events in the following format - 

```json
[
  {
    "name": "Blackwing Lair",
    "id": "1",
    "date": "2018-12-25",
    "logged": true
  },
  {
    "name": "Ahn'qiraj",
    "id": "2",
    "date": "2018-12-27",
    "logged": false
  },
  {
    "name": "Molten Core",
    "id": "3",
    "date": "2018-12-29",
    "logged": false
  }
]
```

* `name` - event name, use instance name if applicable.
* `id` - event ID.
* `date` - event date, in server time, SQL format.
* `logged` - boolean flag, has attendance been previously logged for this event. 

#### POST `/event`

Uploads attendance log for an event.

Input will be sent as JSON object within request body, in following format -

```json
{
  "id": "2",
  "zone": "Blackwing Lair",
  "datetime": "2018-12-20 21:30",
  "attended": [
    "playername1",
    "playername2",
    "playername3"
  ],
  "benched": [
    "playername4",
    "playername5"
  ],
  "loot": [
    {
      "player": "playername1",
      "item": "itemname",
      "datetime": "2018-12-20 22:15"
    }, {
      "player": "playername3",
      "item": "itemname2",
      "datetime": "2018-12-20 22:19"
    }
  ]
}
``` 

* `id` - event ID as previously provided by server.
* `zone` - instance name: Molten Core, Blackwing Lair, Anq'qiraj, Zul'Gurub, Ruins of Anq'quiraj, Naxxramas.
* `datetime` - time of raid start, server time, in SQL format.
* `attended` - list of attended players
* `benched` - list of benched players

