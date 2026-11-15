# Insane 2 - Achievements (rules extracted from the game)

Sources: `GameData/Achievements.lua`, `scripts/profile.lua` (decompiled from `data/gamedata.pak`)
and the `i2.exe` routines that increment the statistics.

## How the game grants achievements on PC

1. The C++ code increments profile statistics (`Profile:StatAdd`).
2. `Profile:OnStatChange` (Lua) checks the condition and calls `Profile:UnlockAchievement("ACHIEV_...")`.
3. On PC, `UnlockAchievement` calls `Steam_UnlockAchievement(steamId)`.

The console command `unlockAchievement` is the **Xbox 360** path (queue by `xlastId`) and
**does not send anything to Steam on PC**. The PC equivalent (Lua console) is:

```lua
Profile:UnlockAchievement("ACHIEV_XXX", true)
```

## Online achievements (confirmed in the code)

| Steam | Internal name | Real condition in the code | With bots? |
|---|---|---|---|
| Hello! | `ACHIEV_HI` | Start of any level with the multiplayer flag on (stat `achiev_hi`) | Yes |
| For Ages | `ACHIEV_LONGTIME` | Stat `game_time_multiplayer` >= 7200 s (2 h accumulated) | Yes |
| Step to Fame | `ACHIEV_STEPTOFAME` | Stat `gameplay_win_multiplayer` >= 25 | Yes |
| Very good Car | `ACHIEV_FAVORITECAR` | Stat `gameplay_win_mp_Vehicle_<car>` >= 10 (same car) | Yes |
| Love of Diversity | `ACHIEV_JOYDIVERSITY` | >= 1 MP win in each mode: Offroad_Race, Knockout_Race, Chase_Flag, Pathfinder, Gate_Hunt, Mark_Gate, Jamboree, Capture_Flag, Return_Flag, Greed | Yes |
| I know the Route | `ACHIEV_PATHFINDER` | >= 1 MP win on each of the 20 maps (us1-5, nz1-5, ke1-5, aq1-5) | Yes |
| Bots are harder | `ACHIEV_HARDMODE` | When you win, the **8 human slots (0 to 7)** must be in status 4 (`PS_ACTIVE`). Bots use slots 8+ (`isBot = slot >= 8`) | **No** (needs 8 game copies, tested and working) |
| Ram Ram | `ACHIEV_MEETHEADON` | Head-on crash in split screen (stat `splitscreen_frontal_crash`) | No server needed |

Notes:
- "Win" = the local slot finishes 1st in a match with the multiplayer flag on.
- Hosting counts: the rule does not distinguish host from client.

## `sv_gameMode` values (`scripts/ai/constants.lua`)

| Value | Mode | Option (cvar) | Values accepted by the UI |
|---|---|---|---|
| 1 | OFFROAD_RACE | `sv_lapCount` | 2, 3, 4, 5 |
| 5 | PATHFINDER | `sv_maxGates` | 15, 20, 25, 30 |
| 6 | GATE_HUNT | `sv_maxGates` | 15, 20, 25, 30 |
| 7 | MARK_GATE | `sv_maxScoreMarkGate` | 150, 200, 350, 500 |
| 8 | JAMBOREE | `sv_maxScoreJamboree` | 5, 7, 10, 15 |
| 9 | CAPTURE_FLAG | `sv_maxScoreCaptureFlag` | 75, 100, 150, 200 |
| 10 | RETURN_FLAG | `sv_maxScoreReturnFlag` | 50, 75, 100, 150 |
| 11 | CHASE_FLAG | `sv_maxScoreChaseFlag` | 50, 100, 150, 200 |
| 12 | GREED | `sv_maxScoreGreed` | 50, 75, 100, 125 |
| 14 | KNOCKOUT_RACE | `sv_knockoutTime` | 25, 30, 35, 40 |

Modes that do not count for "Love of Diversity": REVERSI (2), DESTRUCTION_ZONE (3), INSANE (4), TIME_ATTACK (13).

## Full list (47 on Steam)

| Steam | Internal name |
|---|---|
| Shiny! | `ACHIEV_FIRSTGOLD` |
| Step to Peak | `ACHIEV_CUP` |
| Hard work | `ACHIEV_CHAMPIONSHIP` |
| I'm the Boss | `ACHIEV_FULLGAME` |
| Rally Master | `ACHIEV_RALLYST` |
| Pathfinder (2400 in Gates) | `ACHIEV_HUNTER` |
| Unstoppable | `ACHIEV_CARRIER` |
| Pretender | `ACHIEV_GOLDCHAMPION1` |
| World celebrity | `ACHIEV_GOLDCHAMPION2` |
| Best mechanic | `ACHIEV_GOLDCHAMPION3` |
| Live legend | `ACHIEV_GOLDCHAMPION4` |
| Experimenter | `ACHIEV_EXPEREMENTALIST` |
| Mechanic | `ACHIEV_MECHANIC` |
| Dust of the Roads | `ACHIEV_ROADDUST` |
| Traveller | `ACHIEV_TRAVELLER` |
| Catch me | `ACHIEV_CATCHME` |
| Hunter | `ACHIEV_GREEDY` |
| Optimizer | `ACHIEV_OPTIMIZER` |
| Frisky | `ACHIEV_IMPOSIBLE` |
| My! | `ACHIEV_MY` |
| Cautious | `ACHIEV_CAREFUL` |
| Don't come to me! | `ACHIEV_NOWAY` |
| Speed Lust | `ACHIEV_CRAVINGSPEED` |
| Snatch | `ACHIEV_GOLDDIGGER` |
| I've tried | `ACHIEV_WILLVICTORY` |
| What is inside? | `ACHIEV_WHATINSIDE` |
| Orbital Velocity | `ACHIEV_SUPERSPEED` |
| New Record | `ACHIEV_LONGJUMP` |
| Where is my wings? | `ACHIEV_FLY` |
| Hello! | `ACHIEV_HI` |
| Bots are harder | `ACHIEV_HARDMODE` |
| For Ages | `ACHIEV_LONGTIME` |
| Step to Fame | `ACHIEV_STEPTOFAME` |
| Very good Car | `ACHIEV_FAVORITECAR` |
| Love of Diversity | `ACHIEV_JOYDIVERSITY` |
| I know the Route | `ACHIEV_PATHFINDER` |
| Ram Ram | `ACHIEV_MEETHEADON` |
| Buggy | `ACHIEV_BUGGY` |
| SUV | `ACHIEV_SUV` |
| Trucks | `ACHIEV_TRUCKS` |
| Pickups | `ACHIEV_PICKUP` |
| Extreme | `ACHIEV_EXTREME` |
| Prototype | `ACHIEV_PROTOTYPE` |
| Eurasia | `ACHIEV_NZ` |
| North America | `ACHIEV_US` |
| Africa | `ACHIEV_KE` |
| Antarctic | `ACHIEV_AQ` |
