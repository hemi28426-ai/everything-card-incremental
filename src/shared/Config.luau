-- Everything Card Incremental — all game tuning in one file.
-- Tiers, the legends list, the upgrade trees, roll pacing: edit freely.
--
-- Layout of the world (all built at runtime by TreeBuilder):
--   * HUB (centre, round): the COIN trees. One short trunk that SPLITS into the
--     Path of Greed (money) and the Path of Luck (rare odds). Bought with COINS;
--     these reset on rebirth, so you re-climb them each run (faster every time as
--     your permanent rebirth tree grows).
--   * GOLD / yellow island (north): the REBIRTH tree. Bought with TOKENS. One
--     root that splits into five organic branches and boosts EVERYTHING. Permanent.
--   * GREEN island (south): the AUTOMATION tree. Bought with TOKENS. Permanent.
--   * SHOP (west): the imported store — a cashier you can talk to and five items
--     (RAM sticks, two flasks, a speed coil, a lucky block). Bought with COINS.

local Config = {}

Config.GameName = "Everything Card Incremental"

-- ===== Cards / tiers =======================================================
-- Order matters: index = rarity rank (higher = rarer).
Config.Tiers = {
	{ Name = "Common", Color = Color3.fromRGB(160, 165, 180), Boost = 1, SellValue = 5 },
	{ Name = "Uncommon", Color = Color3.fromRGB(95, 205, 120), Boost = 4, SellValue = 25 },
	{ Name = "Rare", Color = Color3.fromRGB(80, 150, 255), Boost = 15, SellValue = 150 },
	{ Name = "Epic", Color = Color3.fromRGB(170, 90, 255), Boost = 45, SellValue = 700 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 160, 50), Boost = 120, SellValue = 3000 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 80, 140), Boost = 500, SellValue = 30000 },
	{ Name = "Ancient", Color = Color3.fromRGB(60, 210, 200), Boost = 2200, SellValue = 200000 },
	{ Name = "God", Color = Color3.fromRGB(255, 215, 60), Boost = 9000, SellValue = 1500000 },
	{ Name = "Divine", Color = Color3.fromRGB(225, 205, 255), Boost = 40000, SellValue = 15000000 },
	{ Name = "Secret", Color = Color3.fromRGB(255, 40, 60), Boost = 200000, SellValue = 250000000 },
}
Config.TierByName = {}
for index, tier in Config.Tiers do
	tier.Index = index
	Config.TierByName[tier.Name] = tier
end

-- Famous accounts. Usernames get resolved to user ids at server startup, so
-- you can add anyone here; KnownId is just a fallback if resolution fails.
Config.Legends = {
	{ Username = "Roblox", KnownId = 1, Tier = "Secret", Flavor = "You rolled the corporate mainframe. Reality is collapsing." },
	{ Username = "DavidBaszucki", Tier = "Divine", Flavor = "The CEO of imagination itself." },
	{ Username = "builderman", KnownId = 156, Tier = "God", Flavor = "The original architect. Check your messages." },
	{ Username = "Shedletsky", KnownId = 261, Tier = "God", Flavor = "Sword fights on the heights, forever." },
	{ Username = "Hazem", Tier = "God", Flavor = "PLS DONATE. The clout is immeasurable." },
}

-- ===== Rolling =============================================================
Config.Roll = {
	BaseCooldown = 1.5, -- seconds between MANUAL rolls (clicking the TV)
	MinCooldown = 0.2,
	AutoInterval = 3.0, -- auto-roll fires this often (NOT affected by roll speed)
	AutoIntervalFast = 1.5, -- with the FAST AUTO gamepass (2x faster, permanent)
	BaseLuckChance = 0.02,
	MaxLuckChance = 0.75,
	BaseGodChance = 1 / 5000, -- chance a roll hits the legends list
	BaseFreshInterval = 4.0, -- seconds between background account scans
	MaxUserId = 8_500_000_000, -- rough top of the current id space
	BufferTarget = 40, -- scanned cards kept ready per server (bigger = smoother)
}

-- Manual roll-speed upgrade (bought with coins right on the TV). Each level
-- shaves the manual cooldown; cost compounds. The level CAP starts at 20 and is
-- raised by the shop's RAM sticks (+1 each, up to +20 → 40) and a couple of
-- rebirth speed upgrades.
Config.RollSpeed = {
	BaseCost = 50,
	CostMult = 1.6,
	CooldownFactor = 0.9, -- cooldown *= 0.9 per level
	MaxLevel = 20, -- base cap; RAM sticks + rebirth speed nodes raise it
}

function Config.GetRollSpeedCost(level)
	return math.floor(Config.RollSpeed.BaseCost * Config.RollSpeed.CostMult ^ level)
end

-- Gamepasses (set these to your real gamepass ids on the Creator Dashboard).
Config.Gamepass = {
	FastAuto = 1875970080, -- "FAST auto roll" — makes auto-roll near-instant
}

-- Random ids are weighted by account era. A purely uniform 1-in-8.5B pick would
-- make Legendaries literally one-in-a-billion (almost every real account is a
-- "common nobody"), so — like any gacha — older/lower ids (which grade higher)
-- are made rarer-but-reachable. Each bracket lines up with a rarity floor:
-- roughly Common 70% / Uncommon 20% / Rare 7% / Epic 2.5% / Legendary 0.5%.
Config.IdRanges = {
	{ Min = 100_000_000, Max = Config.Roll.MaxUserId, Weight = 70 }, -- Common
	{ Min = 1_000_000, Max = 100_000_000, Weight = 20 }, -- Uncommon
	{ Min = 100_000, Max = 1_000_000, Weight = 7 }, -- Rare
	{ Min = 10_000, Max = 100_000, Weight = 2.5 }, -- Epic
	{ Min = 1, Max = 10_000, Weight = 0.5 }, -- Legendary
}

Config.Economy = {
	BaseRate = 1, -- coins per second before any cards
	BaseEquipSlots = 3,
	OfflineCapHours = 8,
	OfflineFraction = 0.5, -- offline earnings run at half speed
	BaseWalkSpeed = 16, -- default Roblox walk speed (the speed flask scales this)
}

-- The backpack caps how many UNIQUE cards you can hold (dupes stack free).
-- Upgrades are bought with ROLLS, not coins, and cost 45% more each time.
Config.Backpack = {
	BaseCapacity = 20,
	CapacityPerUpgrade = 5,
	BaseCost = 30,
	CostMult = 1.45,
}

function Config.GetBackpackCapacity(level)
	return Config.Backpack.BaseCapacity + Config.Backpack.CapacityPerUpgrade * level
end

function Config.GetBackpackCost(level)
	return math.floor(Config.Backpack.BaseCost * Config.Backpack.CostMult ^ level)
end

-- ===== Rebirth =============================================================
-- Rebirth needs a Legendary+ card and at least BaseCoins banked. Tokens scale
-- as the fourth root of coins, so: 100M = 100 tokens, 1T = 1,000 tokens,
-- 10Q = 10,000 tokens. Rebirthing wipes coins, the HUB coin trees, and every
-- card below Mythic (Legendaries included). Mythic+, backpack, rolls, the
-- rebirth tree, the automation tree, and shop purchases all stay.
Config.Rebirth = {
	BaseCoins = 10000, -- minimum coins banked before a rebirth pays out
	KeepTier = "Mythic", -- cards at/above this survive (Legendary Keeper lowers it)
}

function Config.GetRebirthTokens(coins)
	if coins < Config.Rebirth.BaseCoins then
		return 0
	end
	return math.floor(coins ^ 0.25)
end

-- coins needed to have one more token than `tokens` (inverse of the formula)
function Config.GetCoinsForTokens(tokens)
	return math.max(Config.Rebirth.BaseCoins, math.floor((tokens + 1) ^ 4))
end

Config.AutosaveInterval = 60
Config.LeaderboardRefreshInterval = 60
Config.LeaderboardSize = 10

-- ===== layout helpers ======================================================
-- Small turtle/arc helpers so the tree coordinates stay readable. Positions are
-- {x, z} on the flat world; y is fixed by the builder.

-- An arc of `n` points around (cx, cz): angle sweeps from startDeg by stepDeg
-- each step, radius from startR by stepR each step.
local function arc(cx, cz, startDeg, stepDeg, startR, stepR, n)
	local pts = {}
	for i = 1, n do
		local d = math.rad(startDeg + stepDeg * (i - 1))
		local r = startR + stepR * (i - 1)
		pts[i] = { cx + math.cos(d) * r, cz + math.sin(d) * r }
	end
	return pts
end

-- ===== HUB coin trees (Greed + Luck) =======================================
-- On the central hub. Bought with COINS, stored in data.Upgrades, and WIPED on
-- rebirth. A short shared trunk splits at "fork" into two ~10-node arms: Greed
-- (money, pricier, the balanced long game) and Luck (rare odds, cheaper).
local HUB = {}
local function hnode(def)
	def.IsRebirth = false
	def.Area = "hub"
	table.insert(HUB, def)
end

-- shared trunk (a mix of money + luck, climbs straight north from the centre)
hnode({ Id = "seed", Name = "First Profits", Desc = "x1.5 ALL coin earnings", Branch = "Trunk", Pos = { 0, 14 }, Cost = 100 })
hnode({ Id = "clover", Name = "Four-Leaf Clover", Desc = "+5% rare-tier chance", Branch = "Trunk", Pos = { 0, 26 }, Cost = 400, Requires = "seed" })
hnode({ Id = "vault", Name = "First Vault", Desc = "x2 ALL coin earnings", Branch = "Trunk", Pos = { 0, 38 }, Cost = 1500, Requires = "clover" })
hnode({ Id = "fork", Name = "The Fork", Desc = "+1 equip slot — then choose your path", Branch = "Trunk", Pos = { 0, 48 }, Cost = 4000, Requires = "vault" })

-- Path of GREED — sweeps down the EAST side of the hub. Pricey but balanced;
-- meant to be ground out once your rebirth tree is strong.
do
	local g = arc(0, 0, 64, -9, 52, 1.6, 10)
	local defs = {
		{ Id = "greed1", Name = "Greedy Hands", Desc = "x2 ALL coin earnings", Cost = 12000 },
		{ Id = "greed2", Name = "Coin Magnet", Desc = "+100% dupe & sell value", Cost = 30000 },
		{ Id = "greed3", Name = "Compound Interest", Desc = "x1.5 ALL coin earnings", Cost = 80000 },
		{ Id = "greed4", Name = "Tax Haven", Desc = "+2 equip slots", Cost = 200000 },
		{ Id = "greed5", Name = "Big Pockets", Desc = "+40 backpack capacity", Cost = 450000 },
		{ Id = "greed6", Name = "Market Boom", Desc = "x2 ALL coin earnings", Cost = 1_000_000 },
		{ Id = "greed7", Name = "Monopoly", Desc = "x1.5 coins & +50% sell value", Cost = 2_500_000 },
		{ Id = "greed8", Name = "Gold Rush", Desc = "x2 ALL coin earnings", Cost = 6_000_000 },
		{ Id = "greed9", Name = "Empire", Desc = "+3 equip slots", Cost = 15_000_000 },
		{ Id = "greed10", Name = "Midas Touch", Desc = "x3 ALL coin earnings", Cost = 40_000_000 },
	}
	for i, d in defs do
		d.Branch = "Greed"
		d.Pos = g[i]
		d.Requires = if i == 1 then "fork" else defs[i - 1].Id
		hnode(d)
	end
end

-- Path of LUCK — sweeps down the WEST side. Cheaper; all about rare odds.
do
	local l = arc(0, 0, 116, 9, 52, 1.6, 10)
	local defs = {
		{ Id = "luck1", Name = "Rabbit's Foot", Desc = "+8% rare-tier chance", Cost = 8000 },
		{ Id = "luck2", Name = "Wishbone", Desc = "+8% rare-tier chance", Cost = 20000 },
		{ Id = "luck3", Name = "Horseshoe", Desc = "x2 legend chance", Cost = 45000 },
		{ Id = "luck4", Name = "Shooting Star", Desc = "+10% rare-tier chance", Cost = 110000 },
		{ Id = "luck5", Name = "Lucky Streak", Desc = "Every 7th roll is Rare or better", Cost = 250000 },
		{ Id = "luck6", Name = "Fortune's Favor", Desc = "+12% rare-tier chance", Cost = 600000 },
		{ Id = "luck7", Name = "Black Cat", Desc = "x2 legend chance", Cost = 1_400_000 },
		{ Id = "luck8", Name = "Cosmic Dice", Desc = "+15% rare-tier chance", Cost = 3_500_000 },
		{ Id = "luck9", Name = "Jackpot", Desc = "x3 legend chance", Cost = 9_000_000 },
		{ Id = "luck10", Name = "Destiny", Desc = "+20% rare-tier chance", Cost = 22_000_000 },
	}
	for i, d in defs do
		d.Branch = "Luck"
		d.Pos = l[i]
		d.Requires = if i == 1 then "fork" else defs[i - 1].Id
		hnode(d)
	end
end

Config.Tree = HUB -- the hub coin trees live in the old "Tree" slot (coins)

-- ===== REBIRTH tree (gold / yellow island, tokens) =========================
-- One root that SPLITS into five organic branches (with one short offshoot that
-- dead-ends, for that hand-grown look). Bought with Rebirth Tokens; permanent.
-- Island is centred to the NORTH; coords here are absolute world {x, z}.
local R = {}
local function rnode(def)
	def.IsRebirth = true
	def.Branch = def.Branch or "Rebirth"
	def.Area = "gold"
	table.insert(R, def)
end

-- root (the one repeatable node; cost rockets 20x/level so it isn't spammed)
rnode({ Id = "core", Name = "Rebirth Core", Desc = "x2 ALL coin earnings, forever (cost 20x each level)", Pos = { 0, 150 }, Cost = 1, CostMult = 20, MaxLevel = nil })

-- Wealth branch (due north) + a short offshoot that ends
rnode({ Id = "rw1", Name = "Old Money", Desc = "x2 ALL coin earnings", Pos = { 0, 166 }, Cost = 3, Requires = "core" })
rnode({ Id = "rw2", Name = "Dynasty", Desc = "+200% dupe & sell value", Pos = { 0, 184 }, Cost = 6, Requires = "rw1" })
rnode({ Id = "rw3", Name = "Fortune 500", Desc = "x3 ALL coin earnings", Pos = { 0, 202 }, Cost = 14, Requires = "rw2" })
rnode({ Id = "rw4", Name = "Trust Fund", Desc = "+50K starting coins after rebirth", Pos = { 0, 220 }, Cost = 18, Requires = "rw3" })
rnode({ Id = "rw5", Name = "Dream Profits", Desc = "Offline earnings: full rate, 24h cap", Pos = { 16, 216 }, Cost = 20, Requires = "rw3" })

-- Luck branch (north-east)
rnode({ Id = "rl1", Name = "Eternal Luck", Desc = "+15% rare-tier chance", Branch = "RLuck", Pos = { 13, 164 }, Cost = 4, Requires = "core" })
rnode({ Id = "rl2", Name = "God Magnet", Desc = "x3 legend chance", Branch = "RLuck", Pos = { 25, 178 }, Cost = 7, Requires = "rl1" })
rnode({ Id = "rl3", Name = "Cosmic Favor", Desc = "+15% rare-tier chance", Branch = "RLuck", Pos = { 35, 194 }, Cost = 12, Requires = "rl2" })
rnode({ Id = "rl4", Name = "Pantheon", Desc = "x3 legend chance AGAIN", Branch = "RLuck", Pos = { 43, 210 }, Cost = 20, Requires = "rl3" })

-- Speed branch (north-west) — the rebirth speed nodes raise the Roll-Speed cap
rnode({ Id = "rs1", Name = "Time Lord", Desc = "Manual roll cooldown x0.6", Branch = "RSpeed", Pos = { -13, 164 }, Cost = 4, Requires = "core" })
rnode({ Id = "rs2", Name = "Overclock", Desc = "+2 max Roll-Speed levels", Branch = "RSpeed", Pos = { -25, 178 }, Cost = 8, Requires = "rs1" })
rnode({ Id = "rs3", Name = "Scanner Overdrive", Desc = "Fresh accounts found 2x faster", Branch = "RSpeed", Pos = { -35, 194 }, Cost = 6, Requires = "rs2" })
rnode({ Id = "rs4", Name = "Light Speed", Desc = "+2 max Roll-Speed levels", Branch = "RSpeed", Pos = { -43, 210 }, Cost = 14, Requires = "rs3" })

-- Capacity branch (east)
rnode({ Id = "rc1", Name = "Deep Pockets", Desc = "+1 equip slot", Branch = "RCap", Pos = { 20, 156 }, Cost = 5, Requires = "core" })
rnode({ Id = "rc2", Name = "Bottomless Bag", Desc = "+40 backpack capacity", Branch = "RCap", Pos = { 38, 162 }, Cost = 6, Requires = "rc1" })
rnode({ Id = "rc3", Name = "Hoarder", Desc = "+1 equip slot", Branch = "RCap", Pos = { 53, 172 }, Cost = 12, Requires = "rc2" })
rnode({ Id = "rc4", Name = "Vault Lord", Desc = "+2 equip slots", Branch = "RCap", Pos = { 62, 186 }, Cost = 22, Requires = "rc3" })

-- Meta branch (west) — tokens & keeping cards through rebirth
rnode({ Id = "rm1", Name = "Token Tithe", Desc = "+2 tokens from every rebirth", Branch = "RMeta", Pos = { -20, 156 }, Cost = 6, Requires = "core" })
rnode({ Id = "rm2", Name = "Legendary Keeper", Desc = "Legendary cards survive rebirth", Branch = "RMeta", Pos = { -38, 162 }, Cost = 10, Requires = "rm1" })
rnode({ Id = "rm3", Name = "Token Hoarder", Desc = "+3 tokens from every rebirth", Branch = "RMeta", Pos = { -53, 172 }, Cost = 18, Requires = "rm2" })

Config.RebirthTree = R

-- ===== AUTOMATION tree (green island, tokens) ==============================
-- The root (autocore) UNLOCKS auto-roll the moment you buy it (no separate "Buy
-- Automation" anymore). Everything else hangs off it. Bought with Tokens;
-- permanent. Island is centred to the SOUTH; coords are absolute world {x, z}.
local A = {}
local function anode(def)
	def.IsRebirth = true
	def.Branch = "Automation"
	def.Area = "green"
	-- every automation node except the root needs the root bought first
	def.IsAutomation = def.Id ~= "autocore"
	table.insert(A, def)
end

anode({ Id = "autocore", Name = "Automaton Core", Desc = "Unlocks AUTO-ROLL on the TV (root)", Pos = { 0, -150 }, Cost = 8, MaxLevel = 1 })

-- equip / sell line (west arm)
anode({ Id = "autoequip", Name = "Auto Equip", Desc = "Always keeps your best cards equipped", Pos = { -18, -162 }, Cost = 6, Requires = "autocore" })
anode({ Id = "autosell", Name = "Auto Liquidate", Desc = "Auto-sells duplicate cards for coins", Pos = { -30, -178 }, Cost = 8, Requires = "autoequip" })
anode({ Id = "smartsell", Name = "Smart Seller", Desc = "Also auto-sells the rarities you toggled off", Pos = { -42, -196 }, Cost = 12, Requires = "autosell" })

-- auto-roll speed line (east arm)
anode({ Id = "overclock1", Name = "Overclock I", Desc = "Auto-roll 25% faster", Pos = { 18, -162 }, Cost = 6, Requires = "autocore" })
anode({ Id = "overclock2", Name = "Overclock II", Desc = "Auto-roll 30% faster again", Pos = { 30, -178 }, Cost = 10, Requires = "overclock1" })
anode({ Id = "overclock3", Name = "Overclock III", Desc = "Auto-roll 40% faster again", Pos = { 42, -196 }, Cost = 16, Requires = "overclock2" })

-- rebirth automation (centre arm)
anode({ Id = "autorebirth", Name = "Auto Rebirth", Desc = "Rebirths automatically when worth it", Pos = { 0, -172 }, Cost = 25, Requires = "autocore" })

Config.AutomationTree = A

-- ===== Bridges =============================================================
-- You build a grey bridge to reach each area, one part at a time, with coins.
-- The price climbs, then jumps 10x at the halfway part to make the second half a
-- real goal. The Shop bridge is the longest (50 parts) but cheapest per part.
Config.Bridges = {
	gold = { Parts = 12, BaseCost = 120, Mult = 1.14 },
	green = { Parts = 18, BaseCost = 600, Mult = 1.16 },
	shop = { Parts = 50, BaseCost = 50, Mult = 1.08, TenXAtHalf = true },
}

function Config.GetBridgeCost(which, partsBuilt)
	local b = Config.Bridges[which]
	if not b then
		return math.huge
	end
	local cost = b.BaseCost * b.Mult ^ partsBuilt
	if b.TenXAtHalf and partsBuilt >= math.floor(b.Parts / 2) then
		cost *= 10 -- the shop bridge's second half costs 10x more
	end
	return math.floor(cost)
end

-- ===== Shop (imported store, west) =========================================
-- The five items from the uploaded place. Bought with COINS via a proximity
-- prompt on each physical item. RAM sticks level up (raising the roll-speed cap);
-- the lucky block is a repeatable consumable; the rest are one-time unlocks.
Config.Shop = {
	{ Id = "rams", ItemName = "Rams", Name = "RAM Sticks", Desc = "+1 max Roll-Speed level (cap 20 → 40)", Cost = 2500, Mult = 1.55, MaxLevel = 20 },
	{ Id = "speedcoil", ItemName = "SpeedCoil", Name = "Speed Coil", Desc = "A coil tool: +16 walk speed while held", Cost = 9000, Mult = 1, MaxLevel = 1 },
	{ Id = "flask3", ItemName = "Flask3", Name = "Speed Flask", Desc = "+50% walk speed, permanently", Cost = 18000, Mult = 1, MaxLevel = 1 },
	{ Id = "luckyblock", ItemName = "Lucky Block", Name = "Lucky Block", Desc = "Open a guaranteed Mythic+ card (with bonus value)", Cost = 60000, Mult = 1.35 },
	{ Id = "flask2", ItemName = "Flask2withlid", Name = "Legendary Flask", Desc = "Rolls SKIP Common→Epic — only Legendary+!", Cost = 750000, Mult = 1, MaxLevel = 1 },
}
Config.ShopById = {}
for _, item in Config.Shop do
	Config.ShopById[item.Id] = item
end

function Config.GetShopCost(item, level)
	return math.floor(item.Cost * item.Mult ^ level)
end

-- the lucky block grants a random tier in this (inclusive) range, weighted toward
-- the low end, with a value multiplier on top
Config.LuckyBlock = { MinTier = "Mythic", MaxTier = "Divine", ValueMult = 1.6 }

Config.NodeById = {}
local function indexTree(tree)
	for _, treeNode in tree do
		if treeNode.MaxLevel == nil and treeNode.CostMult == nil then
			treeNode.MaxLevel = 1 -- plain nodes are one-time purchases
		end
		Config.NodeById[treeNode.Id] = treeNode
	end
end
indexTree(Config.Tree)
indexTree(Config.RebirthTree)
indexTree(Config.AutomationTree)

Config.BranchColors = {
	Trunk = Color3.fromRGB(205, 195, 160),
	Greed = Color3.fromRGB(255, 200, 70),
	Luck = Color3.fromRGB(95, 210, 125),
	Rebirth = Color3.fromRGB(255, 215, 60),
	RLuck = Color3.fromRGB(120, 230, 150),
	RSpeed = Color3.fromRGB(120, 190, 255),
	RCap = Color3.fromRGB(235, 170, 95),
	RMeta = Color3.fromRGB(220, 150, 255),
	Automation = Color3.fromRGB(100, 200, 140),
}

function Config.GetNodeCost(treeNode, level)
	return math.floor(treeNode.Cost * (treeNode.CostMult or 1) ^ level)
end

-- Turns a player's data (rebirth tree, hub coin trees, roll-speed level, shop
-- purchases) into effective stats. Pass the whole data table.
function Config.ComputeStats(data)
	data = data or {}
	local rebirthUpgrades = data.RebirthUpgrades or {}
	local coinUpgrades = data.Upgrades or {}
	local rollSpeedLevel = data.RollSpeedLevel or 0
	local shopUpgrades = data.ShopUpgrades or {}

	local stats = {
		RollCooldown = Config.Roll.BaseCooldown,
		LuckChance = Config.Roll.BaseLuckChance,
		GodChance = Config.Roll.BaseGodChance,
		FreshInterval = Config.Roll.BaseFreshInterval,
		CoinMult = 1,
		EquipSlots = Config.Economy.BaseEquipSlots,
		DupeMult = 1,
		BackpackBonus = 0,
		OfflineUnlocked = false,
		OfflineFraction = Config.Economy.OfflineFraction,
		OfflineCapHours = Config.Economy.OfflineCapHours,
		StartCoins = 0,
		BonusTokens = 0,
		KeepLegendary = false,
		LuckySevens = false,
		MaxRollSpeedLevel = Config.RollSpeed.MaxLevel,
		WalkSpeedMult = 1,
		HasSpeedCoil = false,
		RarityFloor = nil, -- e.g. "Legendary": every roll graded up to at least this
		AutoSpeedMult = 1, -- multiplies the (non-fast) auto-roll interval
		-- automation island
		AutoCore = false,
		AutoEquipUnlocked = false,
		AutoSellUnlocked = false,
		SmartSellUnlocked = false,
		AutoRebirthUnlocked = false,
	}

	local function rLevel(id)
		return rebirthUpgrades[id] or 0
	end
	local function cLevel(id)
		return coinUpgrades[id] or 0
	end
	local function sLevel(id)
		return shopUpgrades[id] or 0
	end

	-- ----- HUB coin trees (reset each rebirth) -----
	-- trunk
	if cLevel("seed") > 0 then stats.CoinMult *= 1.5 end
	stats.LuckChance += 0.05 * cLevel("clover")
	if cLevel("vault") > 0 then stats.CoinMult *= 2 end
	stats.EquipSlots += cLevel("fork")
	-- greed (money)
	if cLevel("greed1") > 0 then stats.CoinMult *= 2 end
	stats.DupeMult += 1 * cLevel("greed2")
	if cLevel("greed3") > 0 then stats.CoinMult *= 1.5 end
	stats.EquipSlots += 2 * cLevel("greed4")
	stats.BackpackBonus += 40 * cLevel("greed5")
	if cLevel("greed6") > 0 then stats.CoinMult *= 2 end
	if cLevel("greed7") > 0 then
		stats.CoinMult *= 1.5
		stats.DupeMult += 0.5
	end
	if cLevel("greed8") > 0 then stats.CoinMult *= 2 end
	stats.EquipSlots += 3 * cLevel("greed9")
	if cLevel("greed10") > 0 then stats.CoinMult *= 3 end
	-- luck
	stats.LuckChance += 0.08 * cLevel("luck1")
	stats.LuckChance += 0.08 * cLevel("luck2")
	if cLevel("luck3") > 0 then stats.GodChance *= 2 end
	stats.LuckChance += 0.10 * cLevel("luck4")
	if cLevel("luck5") > 0 then stats.LuckySevens = true end
	stats.LuckChance += 0.12 * cLevel("luck6")
	if cLevel("luck7") > 0 then stats.GodChance *= 2 end
	stats.LuckChance += 0.15 * cLevel("luck8")
	if cLevel("luck9") > 0 then stats.GodChance *= 3 end
	stats.LuckChance += 0.20 * cLevel("luck10")

	-- ----- REBIRTH tree (permanent) -----
	stats.CoinMult *= 2 ^ rLevel("core")
	-- wealth
	if rLevel("rw1") > 0 then stats.CoinMult *= 2 end
	stats.DupeMult += 2 * rLevel("rw2")
	if rLevel("rw3") > 0 then stats.CoinMult *= 3 end
	stats.StartCoins += 50000 * rLevel("rw4")
	if rLevel("rw5") > 0 then
		stats.OfflineUnlocked = true
		stats.OfflineFraction = 1
		stats.OfflineCapHours = 24
	end
	-- luck
	stats.LuckChance += 0.15 * rLevel("rl1")
	if rLevel("rl2") > 0 then stats.GodChance *= 3 end
	stats.LuckChance += 0.15 * rLevel("rl3")
	if rLevel("rl4") > 0 then stats.GodChance *= 3 end
	-- speed
	if rLevel("rs1") > 0 then stats.RollCooldown *= 0.6 end
	stats.MaxRollSpeedLevel += 2 * rLevel("rs2")
	if rLevel("rs3") > 0 then stats.FreshInterval *= 0.5 end
	stats.MaxRollSpeedLevel += 2 * rLevel("rs4")
	-- capacity
	stats.EquipSlots += rLevel("rc1")
	stats.BackpackBonus += 40 * rLevel("rc2")
	stats.EquipSlots += rLevel("rc3")
	stats.EquipSlots += 2 * rLevel("rc4")
	-- meta
	stats.BonusTokens += 2 * rLevel("rm1")
	if rLevel("rm2") > 0 then stats.KeepLegendary = true end
	stats.BonusTokens += 3 * rLevel("rm3")

	-- ----- AUTOMATION tree (permanent) -----
	stats.AutoCore = rLevel("autocore") > 0
	stats.AutoEquipUnlocked = rLevel("autoequip") > 0
	stats.AutoSellUnlocked = rLevel("autosell") > 0
	stats.SmartSellUnlocked = rLevel("smartsell") > 0
	stats.AutoRebirthUnlocked = rLevel("autorebirth") > 0
	if rLevel("overclock1") > 0 then stats.AutoSpeedMult *= 0.75 end
	if rLevel("overclock2") > 0 then stats.AutoSpeedMult *= 0.70 end
	if rLevel("overclock3") > 0 then stats.AutoSpeedMult *= 0.60 end

	-- ----- SHOP items (permanent, coin-bought) -----
	stats.MaxRollSpeedLevel += sLevel("rams") -- each RAM stick = +1 cap
	if sLevel("flask3") > 0 then stats.WalkSpeedMult *= 1.5 end
	stats.HasSpeedCoil = sLevel("speedcoil") > 0
	if sLevel("flask2") > 0 then stats.RarityFloor = "Legendary" end

	-- manual roll speed (TV upgrade), applied last so caps/floors are final
	stats.RollCooldown *= Config.RollSpeed.CooldownFactor ^ rollSpeedLevel

	stats.RollCooldown = math.max(stats.RollCooldown, Config.Roll.MinCooldown)
	stats.LuckChance = math.min(stats.LuckChance, Config.Roll.MaxLuckChance)
	stats.FreshInterval = math.max(stats.FreshInterval, 1)
	return stats
end

return Config
