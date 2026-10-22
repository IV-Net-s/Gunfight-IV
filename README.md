# Gunfight (GTA IV)

A complete, ready-to-run Call of Duty-style **Gunfight** mode for GTA IV, featuring 1v1 to 4v4 matches, randomized loadouts, overtime objectives, player stats, and Elo ratings.

## Installation

Launch the server using:

```bash
AXDK.exe --data "C:\path\to\axora\sdk\gunfight"
```

Alternatively, use **Add Existing Folder** in the Server Manager and select `sdk/gunfight`.

> [!IMPORTANT]
> Both client and server must use **protocol v17**.

## Project Structure

```
sdk/gunfight/
├── server.ini                  # Server configuration
└── resources/
    └── [gunfight]/
        ├── gunfight/
        │   ├── config.lua      # Main settings
        │   ├── lib/            # Weapon definitions and utilities
        │   ├── server/         # Matchmaking, match logic, arenas, stats, and anti-cheat
        │   ├── client/         # Client-side gameplay
        │   ├── ui/             # HUD, killfeed, scoreboard, results, and menus
        │   └── data/           # Saved statistics and arena configurations
        └── gunfight_loading/   # Loading screen
```

## Commands

| Command | Description |
|---|---|
| `/gf` | Open the main menu |
| `/queue [1v1/2v2/3v3/4v4]` | Join a match queue |
| `/leave` | Leave the queue |
| `/stats [player]` | View player statistics |
| `/top` | View the leaderboard |
| `/matches` | View active matches |
| `Tab` | Open the scoreboard |

## Match Rules

- Supports **1v1**, **2v2**, **3v3**, and **4v4**.
- Teams are balanced by Elo rating.
- Randomized loadouts change every two rounds.
- Each round lasts **40 seconds** with no respawns.
- Overtime starts with a central flag. Hold it uncontested for **3 seconds** to win.
- If nobody captures the flag, the team with the most health wins.
- The first team to win **6 rounds** takes the match.
- Stats, MVP, and Elo ratings are saved automatically.

Each match runs independently, allowing multiple matches at the same time.

## Training

Start training from the `/gf` menu or use:

```
/train [easy/normal/hard/extreme] [challenge]
/train stop
```

- Stationary, moving, and armed targets.
- Free practice or 60-second challenges.
- Custom loadouts and arenas.
- Kill, headshot, accuracy, and personal record tracking.
- Training stops automatically when a queued match begins.

## Arena Editor

Admins can configure arena positions in-game:

```
/gf_arena
/gf_arena middle center
/gf_arena middle a reset
/gf_arena middle a
/gf_arena middle b
/gf_arena middle flag
/gf_arena middle spectate
/gf_arena middle radius
/gf_arena middle cover:stockade
```

Arena changes are saved in `data/arenas.json` and override the default configuration. Unknown arenas can be created automatically.

## Admin Commands

| Command | Description |
|---|---|
| `/gf_force <mode>` | Force-start a match |
| `/gf_end <id>` | End a match |
| `/gf_arena` | Manage arenas |
| `/gf_give <weapon> [player]` | Give a weapon |

Admin access requires `group.gunfight.admin`. Admin accounts can also be configured in `config.admins`. The server console always has full permissions.

## Anti-Cheat

The server validates hits using player state, distance, damage, and fire rate. Invalid hits are rejected, and players who exceed the configured rejection limit within **10 seconds** can be kicked automatically.

## Configuration and Data

The main `config.lua` file controls game modes, round durations, loadouts, arenas, teams, Elo ratings, training, and anti-cheat settings.

Player statistics and arena configurations are saved in the `data/` directory.
