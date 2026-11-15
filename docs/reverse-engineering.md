# How it works (reverse engineering notes)

Everything here was found by reading `i2.exe` (Steam release build 60, Mar 17 2012) with a
disassembler and by decompiling the game's Lua scripts. No game file was modified.

## 1. The `.pak` format (TPAK v4)

Loader routine at `0x430BB0` in `i2.exe`. Implemented in [`tools/tpak_extract.py`](../tools/tpak_extract.py).

| Field | Description |
|---|---|
| `"TPAK"`, `u32 version (4)`, `u32 reserved`, `u32 count` | Header (16 bytes) |
| `u32 check` | Obfuscated: `(~check) >> 2 == 4` |
| `u32 names_size`, `u32 names_csize`, `bytes` | Name block, zlib. **First dword XOR `count`** |
| align 4 | |
| `u32[count]` | Sorted index |
| `u32 n`, `u32[n]` | Chunk table (big files split in zlib chunks) |
| `u32 table_size`, `u32 table_csize`, `bytes` | File table, zlib. **First dword XOR `(table_csize + count)`** |
| align 4 | Data starts here |

- File names: `u32 length` + bytes + `\0`. Byte `j` of name `i` is XORed with
  `2*(length + j) + (length % 5) + i`.
- File table entry (28 bytes): `usize, csize, chunk_index (-1 = single block), offset, name_offset, ?, ?`.
- `usize == csize` means stored; otherwise zlib (single block or chunks of `(usize, csize)` pairs).
- Scripts inside are **Lua 5.1 bytecode**; [unluac](https://sourceforge.net/projects/unluac/) decompiles them.

## 2. Hidden command line options

| Option | Effect |
|---|---|
| `-dev` | Enables the in-game console (without it, `toggleConsole` does nothing) and runs `developer.cfg` |
| `-multiCopies` | Skips the single-instance mutex (`Can not run another copy of %s!`) |
| `-concmd "<cmds>"` | Runs console commands at startup (too early for `connect`) |
| `-safe` | Skips the user config |

Config execution order: `config.cfg` -> `developer.cfg` (only with `-dev`) ->
`Documents\My Games\insane2\user_config.cfg` (skipped with `-safe`) -> `autoexec.cfg` (always).

All copies of the game share `Documents\My Games\insane2\user_config.cfg`, and the game
rewrites it when it closes (the last copy to close wins).

## 3. The console runs Lua

The text typed in the console is executed as Lua (`[string "console_string"]`), so `scriptRun`
does not exist there. Console commands are called with `sys.concmd("...")`. Inside `.cfg`
files it is the opposite: lines are console commands and `scriptRun '<lua>'` runs Lua.

## 4. Servers

| How | Function | Steam authentication |
|---|---|---|
| Menu > Multiplayer > Create server | `Steam_ServerStart(false, "mp_lobby")` | Yes: a second copy on the same account gets **"Authorization error"** (`STEAM_AUTH_FAILED = 18`) |
| Console `sv_start [map]` (default `mp_lobby`) | Own UDP/WinSock server | No: extra copies on the same account can join with `connect 127.0.0.1` |

- `sv_numBots` / `sv_maxPlayers`; the lobby option "Bots" only has `Forbidden` (0) and `Allowed` (`network.MAX_PLAYERS` = 8) and overwrites the cvar.
- The lobby "Start" button requires at least one *ready* human besides the server
  (`MpServerLobbyWnd:HasReadyPlayers`). Bots are not in that table. The button then just runs
  `map '<sv_nextLevel>'`, so `UI.MpServerLobbyWnd:StartMpGame()` in the console starts the match alone.
- Human slots are 0..7, bots are 8+ (`isBot = slot >= 8`). Player status: `PS_NONE 0`,
  `PS_CONNECTED 1`, `PS_MAP_LOAD 2`, `PS_SPECTATOR 3`, `PS_ACTIVE 4`.

## 5. Achievement flow

See [achievements.md](achievements.md). On a win (`0x60A640`) the game increments
`gameplay_win_multiplayer`, `gameplay_win_mp_level_<map>`, `gameplay_win_mp_<mode>`,
`gameplay_win_mp_Vehicle_<car>` and, if all 8 human slots are `PS_ACTIVE`, `achiev_hardmode`.
On level start in multiplayer it increments `achiev_hi`.
