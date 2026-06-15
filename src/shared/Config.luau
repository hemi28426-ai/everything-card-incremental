-- Everything Card Incremental — all game tuning in one file.
-- Tiers, the legends list, the upgrade tree, roll pacing: edit freely.

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
-- shaves the manual cooldown; cost compounds.
Config.RollSpeed = {
	BaseCost = 50,
	CostMult = 1.6,
	CooldownFactor = 0.9, -- cooldown *= 0.9 per level
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
-- 10Q = 10,000 tokens. Rebirthing wipes coins, the purple tree, and every card
-- below Mythic (Legendaries included). Mythic+, backpack, rolls, the golden
-- tree, and the automation tree all stay.
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

-- ===== Upgrade tree ========================================================
-- The old purple coin tree is gone: rolling/speed/auto now live on the TV, and
-- coins/luck/slots/etc. live on the rebirth (gold) tree. Kept as an empty table
-- so the rest of the code (NodeById, world builder) needs no special-casing.
Config.Tree = {}

-- ===== Golden (rebirth) tree ===============================================
-- A clean branching tree, ONE root (goldinc) with everything chained off it, on
-- the GOLD platform to the NORTH (+z). Bought with Rebirth Tokens. The gold
-- branch is the economy/speed path and leads to the Rebirth altar at the far end.
local R = {}
local function rnode(def)
	def.IsRebirth = true
	def.Branch = "Rebirth"
	def.Area = "gold"
	table.insert(R, def)
end

-- ROOT (the only repeatable node; cost rockets 20x/level so it isn't spammed)
rnode({ Id = "goldinc", Name = "Golden Income", Desc = "x2 ALL coin earnings, forever (cost 20x each level)", Pos = { 0, 112 }, Cost = 1, CostMult = 20, MaxLevel = nil })

-- spine (economy)
rnode({ Id = "dupegold", Name = "Dupe Tycoon", Desc = "+100% dupe & sell value", Pos = { 0, 132 }, Cost = 4, Requires = "goldinc" })
rnode({ Id = "bigbag", Name = "Bottomless Bag", Desc = "+30 backpack capacity", Pos = { 0, 152 }, Cost = 4, Requires = "dupegold" })
rnode({ Id = "megacoin", Name = "Mega Income", Desc = "x3 ALL coin earnings (one-time)", Pos = { 0, 172 }, Cost = 25, Requires = "bigbag" })

-- left branch (speed / qol)
rnode({ Id = "timelord", Name = "Time Lord", Desc = "Manual roll cooldown x0.6", Pos = { -26, 124 }, Cost = 4, Requires = "goldinc" })
rnode({ Id = "overdrive", Name = "Scanner Overdrive", Desc = "Fresh accounts found 2x faster", Pos = { -26, 146 }, Cost = 3, Requires = "timelord" })
rnode({ Id = "quickstart", Name = "Quick Start", Desc = "+25K starting coins after rebirth", Pos = { -26, 168 }, Cost = 3, Requires = "overdrive" })
rnode({ Id = "dreamprofit", Name = "Dream Profits", Desc = "Offline earnings: full rate, 24h cap", Pos = { -48, 168 }, Cost = 5, Requires = "quickstart" })

-- right branch (slots / keep / tokens)
rnode({ Id = "slotmaster", Name = "Slot Master", Desc = "+1 equip slot", Pos = { 26, 124 }, Cost = 4, Requires = "goldinc" })
rnode({ Id = "keeper", Name = "Legendary Keeper", Desc = "Legendary cards survive rebirth", Pos = { 26, 146 }, Cost = 10, Requires = "slotmaster" })
rnode({ Id = "tokenhoard", Name = "Token Hoarder", Desc = "+1 token from every rebirth", Pos = { 26, 168 }, Cost = 12, MaxLevel = 3, CostMult = 1, Requires = "keeper" })

Config.RebirthTree = R

-- ===== Green (luck + automation) tree ======================================
-- On the GREEN platform to the SOUTH (-z). The luck branch is bought with
-- Rebirth Tokens (same as gold). The automation branch (auto-equip/sell/rebirth)
-- only appears once you've bought Automation at the Card Opener (100 tokens),
-- and it's marked IsAutomation. One root each, everything chained.
local A = {}
local function gnode(def)
	def.IsRebirth = true
	def.Branch = "Luck"
	def.Area = "green"
	table.insert(A, def)
end
local function anode(def)
	def.IsRebirth = true
	def.Branch = "Automation"
	def.IsAutomation = true
	def.Area = "green"
	table.insert(A, def)
end

-- luck root + chain
gnode({ Id = "eternalluck", Name = "Eternal Luck", Desc = "+10% rare chance", Pos = { 0, -112 }, Cost = 3 })
gnode({ Id = "luckyseven", Name = "Lucky Sevens", Desc = "Every 7th roll is Rare or better", Pos = { 0, -132 }, Cost = 6, Requires = "eternalluck" })
gnode({ Id = "godmagnet", Name = "God Magnet", Desc = "3x chance to roll a legend", Pos = { 0, -152 }, Cost = 5, Requires = "luckyseven" })
gnode({ Id = "pantheon", Name = "Pantheon", Desc = "3x legend chance AGAIN", Pos = { 0, -172 }, Cost = 12, Requires = "godmagnet" })
gnode({ Id = "luckburst", Name = "Luck Burst", Desc = "+15% rare chance", Pos = { -26, -124 }, Cost = 6, Requires = "eternalluck" })

-- automation cluster (needs Automation bought at the TV)
anode({ Id = "autocore", Name = "Automaton Core", Desc = "Powers automation (root)", Pos = { 28, -124 }, Cost = 3, MaxLevel = 1 })
anode({ Id = "autoequip", Name = "Auto Equip", Desc = "Always keeps your best cards equipped", Pos = { 50, -112 }, Cost = 6, Requires = "autocore" })
anode({ Id = "autosell", Name = "Auto Liquidate", Desc = "Auto-sells duplicate cards for coins", Pos = { 50, -136 }, Cost = 8, Requires = "autocore" })
anode({ Id = "autorebirth", Name = "Auto Rebirth", Desc = "Rebirths automatically when worth it", Pos = { 28, -160 }, Cost = 25, Requires = "autocore" })

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

-- ===== Shop ================================================================
-- A little store to the WEST. Permanent upgrades bought with coins (the coins
-- your cards earn). Each is a repeatable upgrade with a compounding cost.
Config.Shop = {
	{ Id = "luckbrew", Name = "Luck Brew", Desc = "+3% rare chance", Cost = 5000, Mult = 1.6, Value = 0.03 },
	{ Id = "speedbrew", Name = "Speed Brew", Desc = "Manual roll cooldown x0.95", Cost = 8000, Mult = 1.7, Value = 0.95 },
	{ Id = "fortune", Name = "Fortune Tonic", Desc = "x1.25 coin earnings", Cost = 12000, Mult = 1.8, Value = 1.25 },
	{ Id = "tvslot", Name = "TV Upgrade", Desc = "+1 equip slot", Cost = 25000, Mult = 2.2, Value = 1 },
}
Config.ShopById = {}
for _, item in Config.Shop do
	Config.ShopById[item.Id] = item
end

function Config.GetShopCost(item, level)
	return math.floor(item.Cost * item.Mult ^ level)
end

Config.AutomationTokenCost = 100 -- buy Automation at the Card Opener

Config.NodeById = {}
for _, treeNode in Config.Tree do
	if treeNode.MaxLevel == nil and treeNode.CostMult == nil then
		treeNode.MaxLevel = 1 -- plain nodes are one-time purchases
	end
	Config.NodeById[treeNode.Id] = treeNode
end
for _, treeNode in Config.RebirthTree do
	if treeNode.MaxLevel == nil and treeNode.CostMult == nil then
		treeNode.MaxLevel = 1
	end
	Config.NodeById[treeNode.Id] = treeNode
end
for _, treeNode in Config.AutomationTree do
	if treeNode.MaxLevel == nil and treeNode.CostMult == nil then
		treeNode.MaxLevel = 1
	end
	Config.NodeById[treeNode.Id] = treeNode
end

Config.BranchColors = {
	Rolling = Color3.fromRGB(140, 100, 255),
	Luck = Color3.fromRGB(90, 210, 120),
	Economy = Color3.fromRGB(255, 190, 60),
	Endgame = Color3.fromRGB(230, 60, 200),
	Rebirth = Color3.fromRGB(255, 215, 60),
	Automation = Color3.fromRGB(100, 200, 100),
}

function Config.GetNodeCost(treeNode, level)
	return math.floor(treeNode.Cost * (treeNode.CostMult or 1) ^ level)
end

-- Turns a player's rebirth-tree levels + manual roll-speed level into effective
-- stats. (The purple tree is gone; rolling is one card at a time.)
function Config.ComputeStats(rebirthUpgrades, rollSpeedLevel, shopUpgrades)
	rebirthUpgrades = rebirthUpgrades or {}
	rollSpeedLevel = rollSpeedLevel or 0
	shopUpgrades = shopUpgrades or {}
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
		-- automation island
		AutoCore = false,
		AutoEquipUnlocked = false,
		AutoSellUnlocked = false,
		AutoRebirthUnlocked = false,
	}

	local function rLevel(id)
		return rebirthUpgrades[id] or 0
	end

	-- manual roll speed: TV upgrade + Time Lord rebirth bonus
	stats.RollCooldown *= Config.RollSpeed.CooldownFactor ^ rollSpeedLevel
	if rLevel("timelord") > 0 then
		stats.RollCooldown *= 0.6
	end

	-- coins
	stats.CoinMult *= 2 ^ rLevel("goldinc")
	stats.CoinMult *= 3 ^ rLevel("megacoin")
	-- luck
	stats.LuckChance += 0.10 * rLevel("eternalluck")
	stats.LuckChance += 0.15 * rLevel("luckburst")
	-- economy / qol
	stats.StartCoins = 25000 * rLevel("quickstart")
	stats.BackpackBonus += 30 * rLevel("bigbag")
	stats.DupeMult += 1 * rLevel("dupegold")
	if rLevel("overdrive") > 0 then
		stats.FreshInterval *= 0.5
	end
	stats.EquipSlots += rLevel("slotmaster")
	stats.LuckySevens = rLevel("luckyseven") > 0
	stats.BonusTokens = rLevel("tokenhoard")
	stats.KeepLegendary = rLevel("keeper") > 0
	if rLevel("godmagnet") > 0 then
		stats.GodChance *= 3
	end
	if rLevel("pantheon") > 0 then
		stats.GodChance *= 3
	end
	if rLevel("dreamprofit") > 0 then
		stats.OfflineUnlocked = true
		stats.OfflineFraction = 1
		stats.OfflineCapHours = 24
	end

	-- automation island
	stats.AutoCore = rLevel("autocore") > 0
	stats.AutoEquipUnlocked = rLevel("autoequip") > 0
	stats.AutoSellUnlocked = rLevel("autosell") > 0
	stats.AutoRebirthUnlocked = rLevel("autorebirth") > 0

	-- shop upgrades (permanent, coin-bought)
	local function sLevel(id)
		return shopUpgrades[id] or 0
	end
	stats.LuckChance += 0.03 * sLevel("luckbrew")
	stats.RollCooldown *= 0.95 ^ sLevel("speedbrew")
	stats.CoinMult *= 1.25 ^ sLevel("fortune")
	stats.EquipSlots += sLevel("tvslot")

	stats.RollCooldown = math.max(stats.RollCooldown, Config.Roll.MinCooldown)
	stats.LuckChance = math.min(stats.LuckChance, Config.Roll.MaxLuckChance)
	stats.FreshInterval = math.max(stats.FreshInterval, 1)
	return stats
end

return Config
