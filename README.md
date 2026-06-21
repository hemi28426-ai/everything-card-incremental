# Everything Card Incremental 🃏

A Roblox incremental where **every card is a real Roblox account**. Roll the
gacha and the game picks a random user id out of the entire id space, scans
the actual account, and grades it into a card. The rarer the account, the
bigger your coin boost. Walk the upgrade tree, roll faster, multi-roll,
automate it, and chase the legends.

## How a roll works

1. The server picks a random real user id (weighted across id ranges, with a
   tiny chance to hit the **legends pool** — Roblox, builderman, Hazem, ...).
2. The account is scanned for rarity signals:
   - **Engine signals (always work):** low/round user ids, short clean
     usernames, the verified badge, and whatever the account is *wearing*
     right now — worn avatars are public even with a private inventory,
     which is how a Dominus gets caught on a locked-down account.
   - **Deep scan via proxy (optional):** collectible value (RAP) for the
     robux tiers, account age, Roblox Admin/Veteran badges. Needs
     *Allow HTTP Requests* (Game Settings → Security). Without it the game
     silently uses engine signals only — rolls never break.
3. The card gets a tier and a coin boost. Equip your best cards to earn
   faster, sell dupes, buy tree upgrades.

| Tier | How you get it |
|---|---|
| Common | the endless sea of random accounts |
| Uncommon | younger-but-real accounts, clean names, dressed avatars |
| Rare | owns collectibles, verified, OG/round ids, rare usernames, 15y+ accounts |
| Legendary | 100K+ RAP, a worn Dominus, or id ≤ 10000 |
| Mythic | 1M+ RAP, Roblox Admin badge, or multiple Dominus |
| God | the legends list (editable in Config) |
| Secret | roll the `Roblox` account itself. SYSTEM ERROR. |

Rolls are kept instant by a prefetch buffer (the server scans accounts ahead
of time) and a **global shared pool**: every Rare+ account any server ever
discovers is saved and shared across all servers. Players who join your game
get scanned too, growing the pool for everyone. In offline Studio the game
auto-switches to stub cards so you can still test everything.

## The upgrade tree (38 pads)

Physical pads with glowing paths, generated from one table in Config:

- **Rolling (purple, west):** Roll Speed I–V, Multi-Roll x2/x3/x5, Auto-Roller,
  Auto Speed I–III, Auto Multi-Roll
- **Luck (green, north):** Luck I–V, Fresh Scans I–II, God Hunter
- **Economy (gold, east):** Coins I–V, +1 Equip Slot ×4, Dupe Value I–III,
  Offline Earnings
- **Endgame (magenta, south):** four ∞ repeatable upgrades with compounding
  costs — no level cap

Walk to a pad and press the prompt to buy. Costs/levels show on per-player
billboards.

## Getting it into Roblox Studio

### Option A — open the prebuilt file (easiest)

Download `EverythingCards.rbxlx`, open it in Studio, press **Play**.

### Option B — sync with Rojo

1. Install the [Rojo](https://rojo.space) CLI (or `aftman install`).
2. Install the Studio plugin: `rojo plugin install`
3. Run `rojo serve`, then connect from the plugin in Studio.

Or build a fresh place file: `rojo build -o EverythingCards.rbxlx`

### Option C — copy-paste by hand

| File | Where in Studio | Instance type |
|---|---|---|
| `src/shared/Config.luau` | ReplicatedStorage → Folder `Shared` → `Config` | ModuleScript |
| `src/shared/Format.luau` | ReplicatedStorage → Folder `Shared` → `Format` | ModuleScript |
| `src/server/Main.server.luau` | ServerScriptService → Folder `Server` → `Main` | Script |
| `src/server/DataManager.luau` | ServerScriptService → Folder `Server` → `DataManager` | ModuleScript |
| `src/server/Scanner.luau` | ServerScriptService → Folder `Server` → `Scanner` | ModuleScript |
| `src/server/CardPool.luau` | ServerScriptService → Folder `Server` → `CardPool` | ModuleScript |
| `src/server/TreeBuilder.luau` | ServerScriptService → Folder `Server` → `TreeBuilder` | ModuleScript |
| `src/server/Leaderboard.luau` | ServerScriptService → Folder `Server` → `Leaderboard` | ModuleScript |
| `src/client/Main.client.luau` | StarterPlayer → StarterPlayerScripts → Folder `Client` → `Main` | LocalScript |
| `src/client/UI.luau` | StarterPlayer → StarterPlayerScripts → Folder `Client` → `UI` | ModuleScript |
| `src/client/Cards.luau` | StarterPlayer → StarterPlayerScripts → Folder `Client` → `Cards` | ModuleScript |

## Switches to flip after publishing

1. **File → Publish to Roblox** (free).
2. **Game Settings → Security → Enable Studio Access to API Services** —
   turns on saving, the shared card pool, and the leaderboard.
3. **Game Settings → Security → Allow HTTP Requests** — turns on deep scans
   (RAP robux tiers, account age, admin badges). Optional but recommended.

## Tuning

Everything lives in `src/shared/Config.luau`:

- `Config.Tiers` — names, colors, boosts, dupe sell values
- `Config.Legends` — add any famous username; resolved to ids at startup
- `Config.Tree` — every upgrade pad (cost, effect, position, prerequisite);
  add a line and the world + billboards build themselves
- `Config.Roll` — cooldowns, luck/god chances, buffer size, id-space size

## Honesty notes

- "Has bought robux" is private data with no API — the robux tiers use
  collectible value (RAP) instead, which is the standard public wealth proxy.
- Only public profile data is used (usernames, avatars, public inventories
  via official endpoints / a public proxy mirror).
- The deep scan depends on the free RoProxy mirror; if it's ever down, the
  game degrades to engine-only scans automatically.
