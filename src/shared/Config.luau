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
	AutoIntervalFast = 0.25, -- with the FAST AUTO gamepass
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
-- A real upgrade TREE bought with Rebirth Tokens on the gold island. Every
-- node (except the root) has Requires, so it only appears once its parent is
-- owned, and a gold path is drawn between them. IsRebirth marks them; levels
-- live in data.RebirthUpgrades and survive every rebirth.
-- Positions are {x, z} on the gold island (centered at x=147).
local R = {}
local function rnode(def)
	def.IsRebirth = true
	def.Branch = "Rebirth"
	table.insert(R, def)
end

-- ROOT — the only repeatable node. Tokens are cheap, so the cost rockets 20x
-- per level (1, 20, 400, 8,000 ...) to keep it from being spam-bought.
rnode({ Id = "goldinc", Name = "Golden Income", Desc = "x2 ALL coin earnings, forever (cost 20x each level)", Pos = { 95, 0 }, Cost = 1, CostMult = 20, MaxLevel = nil })

-- Every other node is a ONE-TIME purchase.
-- Economy branch (grows toward -z)
rnode({ Id = "dupegold", Name = "Dupe Tycoon", Desc = "+100% dupe & sell value", Pos = { 95, -22 }, Cost = 4, Requires = "goldinc" })
rnode({ Id = "bigbag", Name = "Bottomless Bag", Desc = "+30 backpack capacity", Pos = { 120, -22 }, Cost = 4, Requires = "dupegold" })
rnode({ Id = "megacoin", Name = "Mega Income", Desc = "x3 ALL coin earnings (one-time)", Pos = { 145, -22 }, Cost = 25, Requires = "bigbag" })

-- Speed branch (grows toward +x along z=0). Time Lord boosts your MANUAL roll
-- speed on top of the TV upgrade. (Auto-roll speed is set by the gamepass.)
rnode({ Id = "timelord", Name = "Time Lord", Desc = "Manual roll cooldown x0.6", Pos = { 120, 0 }, Cost = 4, Requires = "goldinc" })
rnode({ Id = "overdrive", Name = "Scanner Overdrive", Desc = "Fresh accounts found 2x faster", Pos = { 145, 0 }, Cost = 3, Requires = "timelord" })

-- Luck branch (grows toward +z)
rnode({ Id = "eternalluck", Name = "Eternal Luck", Desc = "+10% rare chance", Pos = { 95, 22 }, Cost = 3, Requires = "goldinc" })
rnode({ Id = "luckyseven", Name = "Lucky Sevens", Desc = "Every 7th roll is Rare or better", Pos = { 95, 44 }, Cost = 6, Requires = "eternalluck" })
rnode({ Id = "godmagnet", Name = "God Magnet", Desc = "3x chance to roll a legend", Pos = { 120, 44 }, Cost = 5, Requires = "luckyseven" })
rnode({ Id = "pantheon", Name = "Pantheon", Desc = "3x legend chance AGAIN", Pos = { 145, 44 }, Cost = 12, Requires = "godmagnet" })
rnode({ Id = "slotmaster", Name = "Slot Master", Desc = "+1 equip slot", Pos = { 120, 22 }, Cost = 4, Requires = "eternalluck" })
rnode({ Id = "luckburst", Name = "Luck Burst", Desc = "+15% rare chance", Pos = { 145, 22 }, Cost = 6, Requires = "slotmaster" })

-- Economy / quality-of-life branch (grows toward +x +z)
rnode({ Id = "quickstart", Name = "Quick Start", Desc = "+25K starting coins after rebirth", Pos = { 170, 22 }, Cost = 3, Requires = "timelord" })
rnode({ Id = "dreamprofit", Name = "Dream Profits", Desc = "Offline earnings: full rate, 24h cap", Pos = { 195, 22 }, Cost = 5, Requires = "quickstart" })
rnode({ Id = "keeper", Name = "Legendary Keeper", Desc = "Legendary cards survive rebirth", Pos = { 170, 44 }, Cost = 10, Requires = "quickstart" })
rnode({ Id = "tokenhoard", Name = "Token Hoarder", Desc = "+1 token from every rebirth", Pos = { 195, 44 }, Cost = 12, MaxLevel = 3, CostMult = 1, Requires = "keeper" })

-- Automation island unlock (auto-equip / auto-sell / auto-rebirth)
rnode({ Id = "automation", Name = "Automation Unlock", Desc = "Unlock the green Automation Island", Pos = { 170, -22 }, Cost = 100, MaxLevel = 1, IsAutomationUnlock = true, Requires = "bigbag" })

Config.RebirthTree = R

-- ===== Automation tree ======================================================
-- A small tree on the green island (bought with Rebirth Tokens) that automates
-- the busywork: keeping your best cards equipped, selling dupes, and rebirthing.
-- The root (autocore) powers it on. Levels live in data.RebirthUpgrades.
-- (Auto-ROLLING is separate — that lives on the TV and is free from the start.)
local A = {}
local function anode(def)
	def.IsRebirth = true
	def.Branch = "Automation"
	def.IsAutomation = true
	table.insert(A, def)
end

anode({ Id = "autocore", Name = "Automaton Core", Desc = "Powers all automation (root)", Pos = { 255, 0 }, Cost = 3, MaxLevel = 1, Requires = "automation" })
anode({ Id = "autoequip", Name = "Auto Equip", Desc = "Always keeps your best cards equipped", Pos = { 285, -16 }, Cost = 6, Requires = "autocore" })
anode({ Id = "autosell", Name = "Auto Liquidate", Desc = "Auto-sells duplicate cards for coins", Pos = { 285, 16 }, Cost = 8, Requires = "autocore" })
anode({ Id = "autorebirth", Name = "Auto Rebirth", Desc = "Rebirths automatically when it's worth it", Pos = { 285, 0 }, Cost = 25, Requires = "autocore" })

Config.AutomationTree = A

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
function Config.ComputeStats(rebirthUpgrades, rollSpeedLevel)
	rebirthUpgrades = rebirthUpgrades or {}
	rollSpeedLevel = rollSpeedLevel or 0
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

	stats.RollCooldown = math.max(stats.RollCooldown, Config.Roll.MinCooldown)
	stats.LuckChance = math.min(stats.LuckChance, Config.Roll.MaxLuckChance)
	stats.FreshInterval = math.max(stats.FreshInterval, 1)
	return stats
end

return Config
