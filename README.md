# Click Empire 🖱️

A complete Roblox clicker / incremental game. Click for cash, buy upgrades and
auto-clickers, then **rebirth** to reset with a permanent earnings multiplier.

**Features**

- 💰 Cash per click + passive income, with juicy floating numbers and sounds
- 🛒 9 upgrades that scale in cost the more you buy (all tunable in one file)
- ⭐ Rebirth system: reset cash & upgrades for a permanent earnings boost
- 💾 Progress saves automatically (DataStores, with retry + wipe protection)
- 🏆 Global top-10 "Top Earners" leaderboard on a physical board near spawn
- 🛡️ Server-authoritative: all cash, purchases, and click rates are validated
  on the server, so exploiters can't cheat
- 📱 Works on PC and mobile out of the box

## Getting it into Roblox Studio

### Option A — open the prebuilt file (easiest)

1. Download `ClickEmpire.rbxlx` from this repo.
2. Double-click it (or in Studio: **File → Open from File**).
3. Press **Play**. That's it.

### Option B — sync with Rojo (best if you'll keep editing code here)

[Rojo](https://rojo.space) live-syncs this folder into Studio.

1. Install the Rojo CLI ([instructions](https://rojo.space/docs/v7/getting-started/installation/))
   — or `aftman install` if you use [Aftman](https://github.com/LPGhatguy/aftman).
2. Install the **Rojo plugin** in Studio (the CLI can do it: `rojo plugin install`).
3. In this folder run: `rojo serve`
4. In Studio open any place, click the Rojo plugin button, then **Connect**.

You can also just build a place file yourself: `rojo build -o ClickEmpire.rbxlx`

### Option C — copy-paste by hand (no tools needed)

Create this layout in Studio's Explorer and paste each file's contents in.
The names must match exactly:

| File | Where in Studio | Instance type |
|---|---|---|
| `src/shared/Config.luau` | ReplicatedStorage → Folder `Shared` → `Config` | ModuleScript |
| `src/shared/Format.luau` | ReplicatedStorage → Folder `Shared` → `Format` | ModuleScript |
| `src/server/Main.server.luau` | ServerScriptService → Folder `Server` → `Main` | Script |
| `src/server/DataManager.luau` | ServerScriptService → Folder `Server` → `DataManager` | ModuleScript |
| `src/server/Leaderboard.luau` | ServerScriptService → Folder `Server` → `Leaderboard` | ModuleScript |
| `src/client/Main.client.luau` | StarterPlayer → StarterPlayerScripts → Folder `Client` → `Main` | LocalScript |
| `src/client/UI.luau` | StarterPlayer → StarterPlayerScripts → Folder `Client` → `UI` | ModuleScript |

## Making saving work (important!)

DataStores are off until you publish:

1. **File → Publish to Roblox** (give the game a name).
2. **Home → Game Settings → Security → Enable Studio Access to API Services → On.**

Until then the game runs fine but prints a warning and doesn't save progress.

## Tuning the game

Everything lives in `src/shared/Config.luau`:

- **Add an upgrade**: copy a line in `Config.Upgrades`, give it a unique `Id`.
  The shop builds itself from this list — no UI work needed.
- **Pacing**: `BaseCost` / `CostMult` control how fast costs grow; `Power` is
  what each purchase gives you.
- **Rebirth**: `Config.Rebirth` controls the cost curve and how big each
  permanent multiplier is.
- **Anti-autoclicker**: `MaxClicksPerSecond` caps how fast the server accepts
  clicks.

## How the code is organized

```
src/
  shared/   code both server & client use (game config, number formatting)
  server/   the source of truth: data, validation, saving, leaderboard
  client/   display only: builds the UI and asks the server to do things
```

The golden rule used throughout: **the client never decides anything that
matters**. It asks (`Click`, `BuyUpgrade`, `Rebirth` remotes) and the server
validates, updates the real state, and pushes it back (`StateChanged`).
