Gunfight (GTA IV)

A complete, ready-to-run Call of Duty-style Gunfight mode for GTA IV. Supports 1v1 to 4v4 matches, randomized loadouts, overtime objectives, player stats, and Elo ratings.

File Structure
sdk/gunfight/
server.ini
resources/[gunfight]/
gunfight/
config.lua — Main configuration
lib/
weapons.lua — Weapon definitions
util.lua — Utility functions
server/
main.lua — Lobby, queues, commands, and anti-cheat
match.lua — Match flow, rounds, overtime, and results
queue.lua — Matchmaking and team balancing
arenas.lua — Arena management
stats.lua — Player stats and Elo ratings
client/
main.lua — Match controls and client logic
ui/ — HUD, killfeed, scoreboard, results, and menus
data/ — Saved stats and arena configurations
gunfight_loading/ — Loading screen
Installation

Launch the server using:

AXDK.exe --data "C:\path\to\axora\sdk\gunfight"


Alternatively, select sdk/gunfight through the Server Manager using Add Existing Folder.

Requirement: Both client and server must use protocol v17.

Commands
Command	Description
/gf	Open the main menu
/queue [1v1/2v2/3v3/4v4]	Join a match queue
/leave	Leave the queue
/stats [player]	View player statistics
/top	View the leaderboard
/matches	View active matches
Tab	Open the scoreboard
Match Rules
Matchmaking: Each match runs in an isolated instance with Elo-balanced teams.
Loadouts: Randomized weapons change every two rounds.
Round duration: 40 seconds, with no respawns.
Overtime: A flag spawns in the center. Hold it uncontested for 3 seconds to win.
Timeout: The team with the most remaining health wins.
Victory condition: First team to win 6 rounds.
Results: Stats, MVP, and Elo ratings are saved automatically.
Arena boundaries: Players receive a warning before taking damage for leaving the arena.
Training

Start training through /gf or use:

/train [easy/normal/hard/extreme] [challenge]
/train stop


Features:

Stationary, moving, and armed targets.
Free practice and 60-second challenges.
Custom loadouts and arenas.
Kill, headshot, accuracy, and personal record tracking.
Automatic shutdown when a queued match starts.

Training records are saved with player statistics.

Arena Editor

Admins can configure arena positions directly in-game.

/gf_arena
/gf_arena middle center
/gf_arena middle a reset
/gf_arena middle a
/gf_arena middle b
/gf_arena middle flag
/gf_arena middle spectate
/gf_arena middle radius
/gf_arena middle cover:stockade


Arena changes are saved to data/arenas.json and override the default configuration.

Unknown arenas can be created automatically. Arena names are case-insensitive, and partial names are supported.

Admin Commands
Command	Description
/gf_force <mode>	Force-start a match
/gf_end <id>	End a match
/gf_arena	Manage arenas
/gf_give <weapon> [player]	Give a weapon

Permissions: Requires group.gunfight.admin or server console access. Admin accounts can also be configured in config.admins.

Anti-Cheat

The server validates hits based on player state, distance, damage, and fire rate. Invalid hits are rejected before damage is applied. Players who exceed the configured rejected-hit limit within 10 seconds can be kicked automatically.

Configuration

The main config.lua file controls:

Match modes and round durations.
Weapons and loadouts.
Arenas, teams, and spawn positions.
Elo ratings and matchmaking.
Training settings.
Anti-cheat limits.
Admin permissions.

Player statistics and arena changes are stored in the data/ directory.
