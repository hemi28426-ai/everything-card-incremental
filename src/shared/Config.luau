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
	BaseCooldown = 3.0, -- seconds between manual rolls
	MinCooldown = 0.3,
	BaseAutoCooldown = 6.0,
	MinAutoCooldown = 0.5,
	BaseLuckChance = 0.02, -- chance a roll draws from the discovered rare pool
	MaxLuckChance = 0.75,
	BaseGodChance = 1 / 5000, -- chance a roll hits the legends list
	BaseFreshInterval = 4.0, -- seconds between background account scans
	MaxUserId = 8_500_000_000, -- rough top of the current id space
	BufferTarget = 24, -- scanned cards kept ready per server
}

-- Random ids are sampled from these ranges (older accounts are rarer rolls).
Config.IdRanges = {
	{ Min = 1_000_000_000, Max = Config.Roll.MaxUserId, Weight = 70 },
	{ Min = 100_000_000, Max = 1_000_000_000, Weight = 15 },
	{ Min = 1_000_000, Max = 100_000_000, Weight = 10 },
	{ Min = 10_000, Max = 1_000_000, Weight = 4 },
	{ Min = 1, Max = 10_000, Weight = 1 },
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
-- Each node becomes a physical pad in the world at Pos = {x, z}.
-- MaxLevel = nil means infinitely repeatable (cost compounds by CostMult).
-- Requires = id of the pad that must be owned first (also draws the path).
local T = {}
local function node(def)
	table.insert(T, def)
end

-- Rolling branch (west, purple)
node({ Id = "rs1", Name = "Roll Speed I", Desc = "-0.5s roll cooldown", Branch = "Rolling", Pos = { -18, 6 }, Cost = 50, Effect = "RollSpeed", Value = -0.5 })
node({ Id = "rs2", Name = "Roll Speed II", Desc = "-0.5s roll cooldown", Branch = "Rolling", Pos = { -30, 6 }, Cost = 250, Effect = "RollSpeed", Value = -0.5, Requires = "rs1" })
node({ Id = "rs3", Name = "Roll Speed III", Desc = "-0.5s roll cooldown", Branch = "Rolling", Pos = { -42, 6 }, Cost = 1000, Effect = "RollSpeed", Value = -0.5, Requires = "rs2" })
node({ Id = "rs4", Name = "Roll Speed IV", Desc = "-0.5s roll cooldown", Branch = "Rolling", Pos = { -54, 6 }, Cost = 5000, Effect = "RollSpeed", Value = -0.5, Requires = "rs3" })
node({ Id = "rs5", Name = "Roll Speed V", Desc = "-0.5s roll cooldown", Branch = "Rolling", Pos = { -66, 6 }, Cost = 25000, Effect = "RollSpeed", Value = -0.5, Requires = "rs4" })
node({ Id = "multi2", Name = "Multi-Roll x2", Desc = "2 cards per roll", Branch = "Rolling", Pos = { -18, -8 }, Cost = 500, Effect = "MultiRoll", Value = 2, Requires = "rs1" })
node({ Id = "multi3", Name = "Multi-Roll x3", Desc = "3 cards per roll", Branch = "Rolling", Pos = { -30, -8 }, Cost = 10000, Effect = "MultiRoll", Value = 3, Requires = "multi2" })
node({ Id = "multi5", Name = "Multi-Roll x5", Desc = "5 cards per roll", Branch = "Rolling", Pos = { -42, -8 }, Cost = 200000, Effect = "MultiRoll", Value = 5, Requires = "multi3" })
node({ Id = "auto", Name = "Auto-Roller", Desc = "Rolls happen automatically", Branch = "Rolling", Pos = { -18, 20 }, Cost = 2000, Effect = "AutoUnlock", Requires = "rs1" })
node({ Id = "as1", Name = "Auto Speed I", Desc = "-1.5s auto cooldown", Branch = "Rolling", Pos = { -30, 20 }, Cost = 5000, Effect = "AutoSpeed", Value = -1.5, Requires = "auto" })
node({ Id = "as2", Name = "Auto Speed II", Desc = "-1.5s auto cooldown", Branch = "Rolling", Pos = { -42, 20 }, Cost = 25000, Effect = "AutoSpeed", Value = -1.5, Requires = "as1" })
node({ Id = "as3", Name = "Auto Speed III", Desc = "-1.5s auto cooldown", Branch = "Rolling", Pos = { -54, 20 }, Cost = 100000, Effect = "AutoSpeed", Value = -1.5, Requires = "as2" })
node({ Id = "automulti", Name = "Auto Multi-Roll", Desc = "Auto rolls use your multi-roll", Branch = "Rolling", Pos = { -66, 20 }, Cost = 500000, Effect = "AutoMulti", Requires = "as3" })

-- Luck branch (north, green)
node({ Id = "luck1", Name = "Luck I", Desc = "+2% rare pool chance", Branch = "Luck", Pos = { 0, 18 }, Cost = 100, Effect = "Luck", Value = 0.02 })
node({ Id = "luck2", Name = "Luck II", Desc = "+2% rare pool chance", Branch = "Luck", Pos = { 0, 30 }, Cost = 1000, Effect = "Luck", Value = 0.02, Requires = "luck1" })
node({ Id = "luck3", Name = "Luck III", Desc = "+2% rare pool chance", Branch = "Luck", Pos = { 0, 42 }, Cost = 10000, Effect = "Luck", Value = 0.02, Requires = "luck2" })
node({ Id = "luck4", Name = "Luck IV", Desc = "+2% rare pool chance", Branch = "Luck", Pos = { 0, 54 }, Cost = 100000, Effect = "Luck", Value = 0.02, Requires = "luck3" })
node({ Id = "luck5", Name = "Luck V", Desc = "+2% rare pool chance", Branch = "Luck", Pos = { 0, 66 }, Cost = 1000000, Effect = "Luck", Value = 0.02, Requires = "luck4" })
node({ Id = "fs1", Name = "Fresh Scans I", Desc = "New accounts found faster", Branch = "Luck", Pos = { -14, 30 }, Cost = 5000, Effect = "FreshScan", Value = -1.25, Requires = "luck2" })
node({ Id = "fs2", Name = "Fresh Scans II", Desc = "New accounts found faster", Branch = "Luck", Pos = { -14, 42 }, Cost = 50000, Effect = "FreshScan", Value = -1.25, Requires = "fs1" })
node({ Id = "god", Name = "God Hunter", Desc = "3x chance to roll a legend", Branch = "Luck", Pos = { 14, 54 }, Cost = 250000, Effect = "GodHunter", Value = 3, Requires = "luck4" })

-- Economy branch (east, gold)
node({ Id = "coin1", Name = "Coins I", Desc = "x1.5 coin earnings", Branch = "Economy", Pos = { 18, 6 }, Cost = 200, Effect = "CoinMult", Value = 1.5 })
node({ Id = "coin2", Name = "Coins II", Desc = "x1.5 coin earnings", Branch = "Economy", Pos = { 30, 6 }, Cost = 2000, Effect = "CoinMult", Value = 1.5, Requires = "coin1" })
node({ Id = "coin3", Name = "Coins III", Desc = "x1.5 coin earnings", Branch = "Economy", Pos = { 42, 6 }, Cost = 20000, Effect = "CoinMult", Value = 1.5, Requires = "coin2" })
node({ Id = "coin4", Name = "Coins IV", Desc = "x1.5 coin earnings", Branch = "Economy", Pos = { 54, 6 }, Cost = 200000, Effect = "CoinMult", Value = 1.5, Requires = "coin3" })
node({ Id = "coin5", Name = "Coins V", Desc = "x1.5 coin earnings", Branch = "Economy", Pos = { 66, 6 }, Cost = 2000000, Effect = "CoinMult", Value = 1.5, Requires = "coin4" })
node({ Id = "slot1", Name = "Equip Slot +1", Desc = "Equip one more card", Branch = "Economy", Pos = { 18, 20 }, Cost = 300, Effect = "Slot", Value = 1, Requires = "coin1" })
node({ Id = "slot2", Name = "Equip Slot +1", Desc = "Equip one more card", Branch = "Economy", Pos = { 30, 20 }, Cost = 5000, Effect = "Slot", Value = 1, Requires = "slot1" })
node({ Id = "slot3", Name = "Equip Slot +1", Desc = "Equip one more card", Branch = "Economy", Pos = { 42, 20 }, Cost = 75000, Effect = "Slot", Value = 1, Requires = "slot2" })
node({ Id = "slot4", Name = "Equip Slot +1", Desc = "Equip one more card", Branch = "Economy", Pos = { 54, 20 }, Cost = 1000000, Effect = "Slot", Value = 1, Requires = "slot3" })
node({ Id = "dupe1", Name = "Dupe Value I", Desc = "+50% coins from selling dupes", Branch = "Economy", Pos = { 18, -8 }, Cost = 1000, Effect = "DupeValue", Value = 0.5, Requires = "coin1" })
node({ Id = "dupe2", Name = "Dupe Value II", Desc = "+50% coins from selling dupes", Branch = "Economy", Pos = { 30, -8 }, Cost = 20000, Effect = "DupeValue", Value = 0.5, Requires = "dupe1" })
node({ Id = "dupe3", Name = "Dupe Value III", Desc = "+50% coins from selling dupes", Branch = "Economy", Pos = { 42, -8 }, Cost = 400000, Effect = "DupeValue", Value = 0.5, Requires = "dupe2" })
node({ Id = "offline", Name = "Offline Earnings", Desc = "Earn while away (half rate, 8h cap)", Branch = "Economy", Pos = { 54, -8 }, Cost = 50000, Effect = "Offline", Requires = "coin3" })

-- Endgame zone (south, magenta) — infinitely repeatable, compounding costs
node({ Id = "infcoin", Name = "∞ Coin Boost", Desc = "x1.1 coins, forever", Branch = "Endgame", Pos = { -21, -48 }, Cost = 100000, CostMult = 1.5, MaxLevel = nil, Effect = "InfCoin", Value = 1.1 })
node({ Id = "influck", Name = "∞ Luck", Desc = "+0.5% rare pool chance, forever", Branch = "Endgame", Pos = { -7, -48 }, Cost = 250000, CostMult = 1.6, MaxLevel = nil, Effect = "InfLuck", Value = 0.005 })
node({ Id = "infhaste", Name = "∞ Roll Haste", Desc = "x0.97 roll cooldown, forever", Branch = "Endgame", Pos = { 7, -48 }, Cost = 500000, CostMult = 1.7, MaxLevel = nil, Effect = "InfHaste", Value = 0.97 })
node({ Id = "infauto", Name = "∞ Auto Efficiency", Desc = "x0.97 auto cooldown, forever", Branch = "Endgame", Pos = { 21, -48 }, Cost = 750000, CostMult = 1.7, MaxLevel = nil, Effect = "InfAuto", Value = 0.97 })

Config.Tree = T

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

-- Every other node below is a ONE-TIME purchase.
-- Cards branch (grows toward -z)
rnode({ Id = "carddouble", Name = "Card Doubler", Desc = "2x cards per roll", Pos = { 95, -22 }, Cost = 3, Requires = "goldinc" })
rnode({ Id = "cardquad", Name = "Card Quadrupler", Desc = "2x cards again (4x total)", Pos = { 120, -22 }, Cost = 8, Requires = "carddouble" })
rnode({ Id = "cardocta", Name = "Card Octupler", Desc = "2x cards again (8x total)", Pos = { 145, -22 }, Cost = 20, Requires = "cardquad" })
rnode({ Id = "dupegold", Name = "Dupe Tycoon", Desc = "+100% dupe & sell value", Pos = { 95, -44 }, Cost = 4, Requires = "carddouble" })
rnode({ Id = "bigbag", Name = "Bottomless Bag", Desc = "+30 backpack capacity", Pos = { 120, -44 }, Cost = 4, Requires = "dupegold" })
rnode({ Id = "cardsurge", Name = "Card Surge", Desc = "+1 card per roll", Pos = { 145, -44 }, Cost = 8, Requires = "bigbag" })

-- Speed branch (grows toward +x along z=0)
rnode({ Id = "timelord", Name = "Time Lord", Desc = "Roll cooldown x0.6", Pos = { 120, 0 }, Cost = 4, Requires = "goldinc" })
rnode({ Id = "chrono", Name = "Chrono Master", Desc = "Auto-roll cooldown x0.6", Pos = { 145, 0 }, Cost = 4, Requires = "timelord" })
rnode({ Id = "overdrive", Name = "Scanner Overdrive", Desc = "Fresh accounts found 2x faster", Pos = { 170, 0 }, Cost = 3, Requires = "chrono" })
rnode({ Id = "hyperspeed", Name = "Hyperspeed", Desc = "Roll & auto cooldown x0.5", Pos = { 195, 0 }, Cost = 8, Requires = "overdrive" })

-- Luck branch (grows toward +z)
rnode({ Id = "eternalluck", Name = "Eternal Luck", Desc = "+10% rare chance", Pos = { 95, 22 }, Cost = 3, Requires = "goldinc" })
rnode({ Id = "luckyseven", Name = "Lucky Sevens", Desc = "Every 7th roll is Rare or better", Pos = { 95, 44 }, Cost = 6, Requires = "eternalluck" })
rnode({ Id = "godmagnet", Name = "God Magnet", Desc = "3x chance to roll a legend", Pos = { 120, 44 }, Cost = 5, Requires = "luckyseven" })
rnode({ Id = "pantheon", Name = "Pantheon", Desc = "3x legend chance AGAIN", Pos = { 145, 44 }, Cost = 12, Requires = "godmagnet" })
rnode({ Id = "slotmaster", Name = "Slot Master", Desc = "+1 equip slot", Pos = { 120, 22 }, Cost = 4, Requires = "eternalluck" })
rnode({ Id = "luckburst", Name = "Luck Burst", Desc = "+15% rare chance", Pos = { 145, 22 }, Cost = 6, Requires = "slotmaster" })

-- Economy / quality-of-life branch (grows toward +x +z)
rnode({ Id = "quickstart", Name = "Quick Start", Desc = "+25K starting coins after rebirth", Pos = { 170, 22 }, Cost = 3, Requires = "chrono" })
rnode({ Id = "dreamprofit", Name = "Dream Profits", Desc = "Offline earnings: full rate, 24h cap", Pos = { 195, 22 }, Cost = 5, Requires = "quickstart" })
rnode({ Id = "keeper", Name = "Legendary Keeper", Desc = "Legendary cards survive rebirth", Pos = { 170, 44 }, Cost = 10, Requires = "quickstart" })
rnode({ Id = "tokenhoard", Name = "Token Hoarder", Desc = "+1 token from every rebirth", Pos = { 195, 44 }, Cost = 12, MaxLevel = 3, CostMult = 1, Requires = "keeper" })

-- Automation unlock + payoff (deep in the cards branch)
rnode({ Id = "automation", Name = "Automation Unlock", Desc = "Unlock the green Automation Island", Pos = { 170, -22 }, Cost = 100, MaxLevel = 1, IsAutomationUnlock = true, Requires = "cardocta" })
rnode({ Id = "megacoin", Name = "Mega Income", Desc = "x3 ALL coin earnings (one-time)", Pos = { 195, -22 }, Cost = 25, Requires = "automation" })

Config.RebirthTree = R

-- ===== Automation tree ======================================================
-- A tree bought with Rebirth Tokens on the green island. The root (autocore)
-- switches automation ON; each branch auto-buys a category of purple upgrades,
-- or automates equipping / selling / rebirthing. Levels live in
-- data.RebirthUpgrades (survive rebirth). Positions are on the green island
-- (centered at x=277). Requires the Automation Unlock node first.
local A = {}
local function anode(def)
	def.IsRebirth = true
	def.Branch = "Automation"
	def.IsAutomation = true
	table.insert(A, def)
end

-- ROOT — needs the gold-tree Automation Unlock; turns the auto-buyer on
anode({ Id = "autocore", Name = "Automaton Core", Desc = "Powers all automation (root)", Pos = { 240, 0 }, Cost = 3, MaxLevel = 1, Requires = "automation" })

-- auto-buy branches (each spends your coins on a category of purple upgrades)
anode({ Id = "autoroll", Name = "Auto Roll-Speed", Desc = "Auto-buys roll-speed upgrades", Pos = { 240, -22 }, Cost = 5, Requires = "autocore" })
anode({ Id = "automulti", Name = "Auto Multi/Auto", Desc = "Auto-buys multi-roll & auto-roller", Pos = { 265, -22 }, Cost = 8, Requires = "autoroll" })
anode({ Id = "autobag", Name = "Auto Backpack", Desc = "Auto-buys backpack expansions", Pos = { 290, -22 }, Cost = 10, Requires = "automulti" })

anode({ Id = "autocoin", Name = "Auto Income", Desc = "Auto-buys coin upgrades", Pos = { 240, 22 }, Cost = 5, Requires = "autocore" })
anode({ Id = "autoslot", Name = "Auto Slots", Desc = "Auto-buys equip-slot upgrades", Pos = { 265, 22 }, Cost = 8, Requires = "autocoin" })
anode({ Id = "autodupe", Name = "Auto Dupe Value", Desc = "Auto-buys dupe-value upgrades", Pos = { 290, 22 }, Cost = 8, Requires = "autoslot" })

anode({ Id = "autoluck", Name = "Auto Luck", Desc = "Auto-buys luck upgrades", Pos = { 265, 0 }, Cost = 6, Requires = "autocore" })
anode({ Id = "autofresh", Name = "Auto Scanner", Desc = "Auto-buys fresh-scan upgrades", Pos = { 290, 0 }, Cost = 8, Requires = "autoluck" })
anode({ Id = "autoendgame", Name = "Auto Endgame", Desc = "Auto-buys the infinite endgame upgrades", Pos = { 315, 0 }, Cost = 15, Requires = "autofresh" })

-- automate the rest of the loop
anode({ Id = "autoequip", Name = "Auto Equip", Desc = "Always keeps your best cards equipped", Pos = { 315, 22 }, Cost = 6, Requires = "autodupe" })
anode({ Id = "autosell", Name = "Auto Liquidate", Desc = "Auto-sells duplicate cards for coins", Pos = { 315, -22 }, Cost = 8, Requires = "autobag" })
anode({ Id = "autorebirth", Name = "Auto Rebirth", Desc = "Rebirths automatically when it's worth it", Pos = { 240, 44 }, Cost = 25, Requires = "autocoin" })
anode({ Id = "autohaste", Name = "Automation Haste", Desc = "Automation runs 2x faster", Pos = { 265, 44 }, Cost = 10, Requires = "autorebirth" })

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

-- Turns a player's owned upgrade levels (both trees) into effective stats.
function Config.ComputeStats(upgrades, rebirthUpgrades)
	rebirthUpgrades = rebirthUpgrades or {}
	local stats = {
		RollCooldown = Config.Roll.BaseCooldown,
		MultiRoll = 1,
		CardOutputMult = 1, -- golden tree: multiplies cards per roll
		CardBonus = 0, -- golden tree: flat extra cards per roll
		AutoUnlocked = false,
		AutoCooldown = Config.Roll.BaseAutoCooldown,
		AutoMulti = false,
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
		-- automation (green tree)
		AutoCore = false,
		AutoBuy = {}, -- category -> true
		AutoEquipUnlocked = false,
		AutoSellUnlocked = false,
		AutoRebirthUnlocked = false,
		AutoHaste = 0,
	}
	for _, treeNode in Config.Tree do
		local level = upgrades[treeNode.Id] or 0
		if level > 0 then
			local effect = treeNode.Effect
			if effect == "RollSpeed" then
				stats.RollCooldown += treeNode.Value * level
			elseif effect == "MultiRoll" then
				stats.MultiRoll = math.max(stats.MultiRoll, treeNode.Value)
			elseif effect == "AutoUnlock" then
				stats.AutoUnlocked = true
			elseif effect == "AutoSpeed" then
				stats.AutoCooldown += treeNode.Value * level
			elseif effect == "AutoMulti" then
				stats.AutoMulti = true
			elseif effect == "Luck" then
				stats.LuckChance += treeNode.Value * level
			elseif effect == "GodHunter" then
				stats.GodChance *= treeNode.Value
			elseif effect == "FreshScan" then
				stats.FreshInterval += treeNode.Value * level
			elseif effect == "CoinMult" then
				stats.CoinMult *= treeNode.Value ^ level
			elseif effect == "Slot" then
				stats.EquipSlots += treeNode.Value * level
			elseif effect == "DupeValue" then
				stats.DupeMult += treeNode.Value * level
			elseif effect == "Offline" then
				stats.OfflineUnlocked = true
			elseif effect == "InfCoin" then
				stats.CoinMult *= treeNode.Value ^ level
			elseif effect == "InfLuck" then
				stats.LuckChance += treeNode.Value * level
			elseif effect == "InfHaste" then
				stats.RollCooldown *= treeNode.Value ^ level
			elseif effect == "InfAuto" then
				stats.AutoCooldown *= treeNode.Value ^ level
			end
		end
	end
	-- golden tree effects (levels survive rebirth)
	local function rLevel(id)
		return rebirthUpgrades[id] or 0
	end
	-- cards: doublers multiply (2x/4x/8x), Card Surge adds flat extra
	stats.CardOutputMult = 2 ^ (math.min(rLevel("carddouble"), 1)
		+ math.min(rLevel("cardquad"), 1)
		+ math.min(rLevel("cardocta"), 1))
	stats.CardBonus += rLevel("cardsurge")
	-- coins
	stats.CoinMult *= 2 ^ rLevel("goldinc")
	stats.CoinMult *= 3 ^ rLevel("megacoin")
	-- luck
	stats.LuckChance += 0.10 * rLevel("eternalluck")
	stats.LuckChance += 0.15 * rLevel("luckburst")
	-- economy / qol
	stats.StartCoins = 25000 * rLevel("quickstart")
	if rLevel("timelord") > 0 then
		stats.RollCooldown *= 0.6
	end
	stats.RollCooldown *= 0.5 ^ rLevel("hyperspeed")
	stats.AutoCooldown *= 0.5 ^ rLevel("hyperspeed")
	stats.BackpackBonus += 30 * rLevel("bigbag")
	stats.DupeMult += 1 * rLevel("dupegold")
	if rLevel("overdrive") > 0 then
		stats.FreshInterval *= 0.5
	end
	if rLevel("chrono") > 0 then
		stats.AutoCooldown *= 0.6
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

	-- automation tree (green island)
	stats.AutoCore = rLevel("autocore") > 0
	local autoBuyMap = {
		autoroll = "rollspeed",
		automulti = "multi",
		autobag = "backpack",
		autocoin = "coin",
		autoslot = "slot",
		autodupe = "dupe",
		autoluck = "luck",
		autofresh = "fresh",
		autoendgame = "endgame",
	}
	for id, category in autoBuyMap do
		if rLevel(id) > 0 then
			stats.AutoBuy[category] = true
		end
	end
	stats.AutoEquipUnlocked = rLevel("autoequip") > 0
	stats.AutoSellUnlocked = rLevel("autosell") > 0
	stats.AutoRebirthUnlocked = rLevel("autorebirth") > 0
	stats.AutoHaste = rLevel("autohaste")

	stats.RollCooldown = math.max(stats.RollCooldown, Config.Roll.MinCooldown)
	stats.AutoCooldown = math.max(stats.AutoCooldown, Config.Roll.MinAutoCooldown)
	stats.LuckChance = math.min(stats.LuckChance, Config.Roll.MaxLuckChance)
	stats.FreshInterval = math.max(stats.FreshInterval, 1)
	return stats
end

return Config
