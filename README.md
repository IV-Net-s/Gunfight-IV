Gunfight (GTA IV)

A complete, ready-to-run Call of Duty-style Gunfight mode for GTA IV. Supports 1v1 to 4v4 matches, randomized loadouts, overtime objectives, stats, and Elo ratings.

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

Requires a client and server built with protocol v17.

Commands
Command	Description
/gf	Main menu
/queue [1v1/2v2/3v3/4v4]	Join a queue
/leave	Leave the queue
/stats [player]	View stats
/top	Leaderboard
/matches	Active matches
Tab	Scoreboard
Match Rules
Each match runs in an isolated instance.
Teams are balanced by Elo rating.
Randomized loadouts change every two rounds.
Each round lasts 40 seconds, with no respawns.
Overtime starts with a central flag. Hold it uncontested for 3 seconds to win.
If nobody captures it, the team with the most health wins.
First team to win 6 rounds takes the match.
Results, MVP, and Elo ratings are saved automatically.
Training

Use /train [easy/normal/hard/extreme] [challenge] or the training menu.

Stationary, moving, and armed targets.
Free practice or 60-second challenges.
Custom loadouts and arenas.
Tracks kills, headshots, accuracy, and personal records.
Stops automatically when a queued match starts.

Use /train stop to exit.

Arenas

Admins can edit arena positions in-game:

/gf_arena
/gf_arena middle center
/gf_arena middle a
/gf_arena middle b
/gf_arena middle flag
/gf_arena middle spectate
/gf_arena middle radius
/gf_arena middle cover:stockade


Changes are saved to data/arenas.json and override the default configuration.

Admins
/gf_force <mode> — Force-start a match.
/gf_end <id> — End a match.
/gf_arena — Edit arenas.
/gf_give <weapon> [player] — Give a weapon.

Requires group.gunfight.admin or server console access.

Anti-Cheat

The server validates hits based on player state, distance, damage, and fire rate. Repeated rejected hits can result in a kick.
