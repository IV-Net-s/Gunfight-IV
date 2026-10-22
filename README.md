Gunfight (GTA IV)

A complete, ready-to-run Call of Duty-style Gunfight mode for GTA IV, supporting 1v1 to 4v4, randomized loadouts, overtime objectives, player stats, and Elo ratings.

File Structure
sdk/gunfight/
├── server.ini
└── resources/[gunfight]/
    ├── gunfight/
    │   ├── config.lua
    │   ├── lib/
    │   ├── server/
    │   ├── client/
    │   ├── ui/
    │   └── data/
    └── gunfight_loading/

Installation

Launch the server with:

AXDK.exe --data "C:\path\to\axora\sdk\gunfight"


Requirement: Client and server must use protocol v17.

Commands
Command	Description
/gf	Open the main menu
/queue [1v1/2v2/3v3/4v4]	Join a match queue
/leave	Leave the queue
/stats [player]	View player stats
/top	View the leaderboard
/matches	View active matches
Tab	Open the scoreboard
Match Rules
Matchmaking: Separate instances with teams balanced by Elo.
Loadouts: Randomized weapons, changing every two rounds.
Round duration: 40 seconds, with no respawns.
Overtime: Capture the central flag and hold it uncontested for 3 seconds.
Timeout: The team with the most health wins.
Victory: First team to win 6 rounds.
Results: Stats, MVP, and Elo ratings are saved automatically.
Training

Start training through /gf or use:

/train [easy/normal/hard/extreme] [challenge]
/train stop


Features include:

Stationary, moving, and armed targets.
Free practice and 60-second challenges.
Custom loadouts and arenas.
Kill, headshot, accuracy, and personal record tracking.
Automatic shutdown when a queued match begins.
Arena Editor

Admins can configure arenas directly in-game.

/gf_arena
/gf_arena middle center
/gf_arena middle a
/gf_arena middle b
/gf_arena middle flag
/gf_arena middle spectate
/gf_arena middle radius
/gf_arena middle cover:stockade


Arena changes are saved to data/arenas.json and override the default configuration.

Admin Commands
Command	Description
/gf_force <mode>	Force-start a match
/gf_end <id>	End a match
/gf_arena	Manage arenas
/gf_give <weapon> [player]	Give a weapon

Permissions: Requires group.gunfight.admin or server console access.

Anti-Cheat

The server validates hits using player state, distance, damage, and fire rate. Players who exceed the configured rejected-hit limit can be kicked automatically.
