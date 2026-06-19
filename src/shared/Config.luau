-- Everything Card Incremental — all game tuning in one file.
-- Tiers, the legends list, the upgrade trees, roll pacing: edit freely.
--
-- Layout of the world (built at runtime by TreeBuilder):
--   * HUB (centre, round): the COIN trees, drawn as ONE branching tree. A short
--     trunk forks into the Path of Greed (money) and the Path of Luck (rare
--     odds), each fanning into its own bushy set of branches. Bought with COINS;
--     reset on rebirth.
--   * GOLD / yellow island (north): the REBIRTH tree. One root splitting into
--     five organic branches; boosts EVERYTHING. Bought with TOKENS. Permanent.
--   * GREEN island (west): the AUTOMATION tree. Bought with TOKENS. Permanent.
--   * SHOP island (south): the imported store — a cashier you can talk to and
--     five items. Bought with COINS.

local Config = {}

Config.GameName = "Everything Card Incremental"

-- World geometry shared by the builder + the spawn. {x, z} on the flat plane.
Config.Layout = {
	HubRadius = 100,
	IslandRadius = 82,
	Gold = { 0, 230 }, -- rebirth island (north)
	Green = { -230, 0 }, -- automation island (west)
	Shop = { 0, -230 }, -- imported shop (south)
	TV = { 90, 11, 0 }, -- card opener, east edge
}

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
-- as the fourth root of coins. Rebirthing wipes coins, the HUB coin trees, and
-- every card below Mythic. Mythic+, backpack, rolls, the rebirth tree, the
-- automation tree, and shop purchases all stay.
Config.Rebirth = {
	BaseCoins = 10000,
	KeepTier = "Mythic",
}

function Config.GetRebirthTokens(coins)
	if coins < Config.Rebirth.BaseCoins then
		return 0
	end
	return math.floor(coins ^ 0.25)
end

function Config.GetCoinsForTokens(tokens)
	return math.max(Config.Rebirth.BaseCoins, math.floor((tokens + 1) ^ 4))
end

Config.AutosaveInterval = 60
Config.LeaderboardRefreshInterval = 60
Config.LeaderboardSize = 10

-- ===== tree layout =========================================================
-- A tidy layered tree layout (depth from the root = distance along the growth
-- axis; siblings fan out along the side axis; a parent sits centred over its
-- children). This is what makes the pads read as a branching TREE instead of a
-- row of dots. Sets node.Pos = {x, z} for every node in the list.
local function layoutTree(nodes, rootId, origin, grow, side, zSpace, xSpace)
	local children = {}
	for _, n in nodes do
		if n.Requires then
			children[n.Requires] = children[n.Requires] or {}
			table.insert(children[n.Requires], n.Id)
		end
	end
	local depth, xslot = {}, {}
	local nextLeaf = 0
	local function assign(id, d)
		depth[id] = d
		local kids = children[id]
		if not kids or #kids == 0 then
			xslot[id] = nextLeaf
			nextLeaf += 1
		else
			local sum = 0
			for _, k in kids do
				assign(k, d + 1)
				sum += xslot[k]
			end
			xslot[id] = sum / #kids
		end
	end
	assign(rootId, 0)
	local centre = (nextLeaf - 1) / 2
	for _, n in nodes do
		local sx = (xslot[n.Id] - centre) * xSpace
		local dz = depth[n.Id] * zSpace
		n.Pos = {
			origin[1] + grow[1] * dz + side[1] * sx,
			origin[2] + grow[2] * dz + side[2] * sx,
		}
	end
end

-- A RADIAL tree layout: the root sits at the island centre and its branches
-- radiate outward (each subtree gets an angular slice sized by its leaf count,
-- and forks fan within that slice). This is what makes a "one root → five
-- branches" tree read as an organic SPIDER instead of parallel columns. The
-- angular range leaves a gap (toward the bridge) for the altar/entrance.
local function radialTree(nodes, rootId, centre, startDeg, rangeDeg, step)
	local byId, children = {}, {}
	for _, n in nodes do
		byId[n.Id] = n
		if n.Requires then
			children[n.Requires] = children[n.Requires] or {}
			table.insert(children[n.Requires], n.Id)
		end
	end
	local leaves = {}
	local function countLeaves(id)
		local kids = children[id]
		if not kids then
			leaves[id] = 1
			return 1
		end
		local sum = 0
		for _, k in kids do
			sum += countLeaves(k)
		end
		leaves[id] = sum
		return sum
	end
	countLeaves(rootId)
	local function place(id, a0, a1, depth)
		local ang = math.rad((a0 + a1) / 2)
		local r = depth * step
		byId[id].Pos = { centre[1] + math.cos(ang) * r, centre[2] + math.sin(ang) * r }
		local kids = children[id]
		if kids then
			local cur = a0
			for _, k in kids do
				local seg = (a1 - a0) * leaves[k] / leaves[id]
				place(k, cur, cur + seg, depth + 1)
				cur += seg
			end
		end
	end
	place(rootId, startDeg, startDeg + rangeDeg, 0)
end

-- ===== HUB coin tree (Greed + Luck) ========================================
-- One branching tree on the hub. Bought with COINS (data.Upgrades), WIPED on
-- rebirth. A 3-node trunk forks into Luck (left) and Greed (right), each a
-- bushy arm. Greed is pricier and money-focused; Luck is cheaper and all odds.
local HUB = {}
local function hnode(def)
	def.IsRebirth = false
	def.Area = "hub"
	def.TextRot = 180 -- read from the south (you climb the tree northward)
	table.insert(HUB, def)
end

-- trunk
hnode({ Id = "seed", Name = "First Profits", Desc = "x1.5 ALL coin earnings", Icon = "🌱", Branch = "Trunk", Cost = 100 })
hnode({ Id = "clover", Name = "Four-Leaf Clover", Desc = "+5% rare-tier chance", Icon = "🍀", Branch = "Trunk", Cost = 400, Requires = "seed" })
hnode({ Id = "fork", Name = "The Fork", Desc = "+1 equip slot — then choose your path", Icon = "🔀", Branch = "Trunk", Cost = 4000, Requires = "clover" })

-- LUCK arm (defined first so it lays out on the LEFT)
local luckDefs = {
	{ Id = "lA", Name = "Rabbit's Foot", Desc = "+8% rare-tier chance", Icon = "🐰", Cost = 8000, Requires = "fork" },
	{ Id = "lB", Name = "Wishbone", Desc = "+8% rare-tier chance", Icon = "🦴", Cost = 20000, Requires = "lA" },
	{ Id = "lC", Name = "Horseshoe", Desc = "x2 legend chance", Icon = "🧲", Cost = 45000, Requires = "lA" },
	{ Id = "lD", Name = "Shooting Star", Desc = "+10% rare-tier chance", Icon = "🌠", Cost = 110000, Requires = "lB" },
	{ Id = "lE", Name = "Lucky Streak", Desc = "Every 7th roll is Rare or better", Icon = "🎰", Cost = 250000, Requires = "lB" },
	{ Id = "lF", Name = "Fortune's Favor", Desc = "+12% rare-tier chance", Icon = "🔮", Cost = 600000, Requires = "lC" },
	{ Id = "lG", Name = "Black Cat", Desc = "x2 legend chance", Icon = "🐈", Cost = 1_400_000, Requires = "lD" },
	{ Id = "lH", Name = "Cosmic Dice", Desc = "+15% rare-tier chance", Icon = "🎲", Cost = 3_500_000, Requires = "lE" },
	{ Id = "lI", Name = "Jackpot", Desc = "x3 legend chance", Icon = "💫", Cost = 9_000_000, Requires = "lF" },
	{ Id = "lJ", Name = "Destiny", Desc = "+20% rare-tier chance", Icon = "⭐", Cost = 22_000_000, Requires = "lF" },
}
for _, d in luckDefs do
	d.Branch = "Luck"
	hnode(d)
end

-- GREED arm (defined second → lays out on the RIGHT)
local greedDefs = {
	{ Id = "gA", Name = "Greedy Hands", Desc = "x2 ALL coin earnings", Icon = "💰", Cost = 12000, Requires = "fork" },
	{ Id = "gB", Name = "Coin Magnet", Desc = "+100% dupe & sell value", Icon = "🧲", Cost = 30000, Requires = "gA" },
	{ Id = "gC", Name = "Compound Interest", Desc = "x1.5 ALL coin earnings", Icon = "📈", Cost = 80000, Requires = "gA" },
	{ Id = "gD", Name = "Tax Haven", Desc = "+2 equip slots", Icon = "🏝️", Cost = 200000, Requires = "gB" },
	{ Id = "gE", Name = "Big Pockets", Desc = "+40 backpack capacity", Icon = "🎒", Cost = 450000, Requires = "gB" },
	{ Id = "gF", Name = "Market Boom", Desc = "x2 ALL coin earnings", Icon = "💵", Cost = 1_000_000, Requires = "gC" },
	{ Id = "gG", Name = "Gold Rush", Desc = "x1.5 coins & +50% sell value", Icon = "⛏️", Cost = 2_500_000, Requires = "gD" },
	{ Id = "gH", Name = "Monopoly", Desc = "x2 ALL coin earnings", Icon = "🏦", Cost = 6_000_000, Requires = "gE" },
	{ Id = "gI", Name = "Empire", Desc = "+3 equip slots", Icon = "👑", Cost = 15_000_000, Requires = "gF" },
	{ Id = "gJ", Name = "Midas Touch", Desc = "x3 ALL coin earnings", Icon = "✨", Cost = 40_000_000, Requires = "gF" },
}
for _, d in greedDefs do
	d.Branch = "Greed"
	hnode(d)
end

layoutTree(HUB, "seed", { 0, -45 }, { 0, 1 }, { 1, 0 }, 15, 15)
Config.Tree = HUB

-- ===== REBIRTH tree (gold / yellow island, tokens) =========================
-- One root that forks into FIVE organic branches; boosts everything. Grows
-- north into the gold island. Bought with Rebirth Tokens; permanent.
local R = {}
local function rnode(def)
	def.IsRebirth = true
	def.Branch = def.Branch or "Rebirth"
	def.Area = "gold"
	def.TextRot = 0
	table.insert(R, def)
end

-- root (the one repeatable node; cost rockets 20x/level so it isn't spammed).
-- Sits at the island CENTRE; the five branches radiate out and fork.
rnode({ Id = "core", Name = "Rebirth Core", Desc = "x2 ALL coin earnings, forever (cost 20x each level)", Icon = "♻️", Cost = 1, CostMult = 20, MaxLevel = nil })

-- Wealth branch (forks at Dynasty: Fortune 500 → Trust Fund, plus Dream Profits)
rnode({ Id = "rw1", Name = "Old Money", Desc = "x2 ALL coin earnings", Icon = "💰", Cost = 3, Requires = "core" })
rnode({ Id = "rw2", Name = "Dynasty", Desc = "+200% dupe & sell value", Icon = "💎", Cost = 6, Requires = "rw1" })
rnode({ Id = "rw3", Name = "Fortune 500", Desc = "x3 ALL coin earnings", Icon = "📈", Cost = 14, Requires = "rw2" })
rnode({ Id = "rw4", Name = "Trust Fund", Desc = "+50K starting coins after rebirth", Icon = "🏦", Cost = 18, Requires = "rw3" })
rnode({ Id = "rw5", Name = "Dream Profits", Desc = "Offline earnings: full rate, 24h cap", Icon = "💤", Cost = 20, Requires = "rw2" })

-- Luck branch (forks at Eternal Luck)
rnode({ Id = "rl1", Name = "Eternal Luck", Desc = "+15% rare-tier chance", Icon = "🍀", Branch = "RLuck", Cost = 4, Requires = "core" })
rnode({ Id = "rl2", Name = "God Magnet", Desc = "x3 legend chance", Icon = "🧲", Branch = "RLuck", Cost = 7, Requires = "rl1" })
rnode({ Id = "rl3", Name = "Cosmic Favor", Desc = "+15% rare-tier chance", Icon = "🔮", Branch = "RLuck", Cost = 12, Requires = "rl2" })
rnode({ Id = "rl4", Name = "Pantheon", Desc = "x3 legend chance AGAIN", Icon = "⭐", Branch = "RLuck", Cost = 20, Requires = "rl1" })

-- Speed branch (forks at Overclock) — the speed nodes raise the Roll-Speed cap
rnode({ Id = "rs1", Name = "Time Lord", Desc = "Manual roll cooldown x0.6", Icon = "⏱️", Branch = "RSpeed", Cost = 4, Requires = "core" })
rnode({ Id = "rs2", Name = "Overclock", Desc = "+2 max Roll-Speed levels", Icon = "⚡", Branch = "RSpeed", Cost = 8, Requires = "rs1" })
rnode({ Id = "rs3", Name = "Scanner Overdrive", Desc = "Fresh accounts found 2x faster", Icon = "📡", Branch = "RSpeed", Cost = 6, Requires = "rs2" })
rnode({ Id = "rs4", Name = "Light Speed", Desc = "+2 max Roll-Speed levels", Icon = "🚀", Branch = "RSpeed", Cost = 14, Requires = "rs2" })

-- Capacity branch (forks at Deep Pockets)
rnode({ Id = "rc1", Name = "Deep Pockets", Desc = "+1 equip slot", Icon = "💼", Branch = "RCap", Cost = 5, Requires = "core" })
rnode({ Id = "rc2", Name = "Bottomless Bag", Desc = "+40 backpack capacity", Icon = "🎒", Branch = "RCap", Cost = 6, Requires = "rc1" })
rnode({ Id = "rc3", Name = "Hoarder", Desc = "+1 equip slot", Icon = "📦", Branch = "RCap", Cost = 12, Requires = "rc1" })
rnode({ Id = "rc4", Name = "Vault Lord", Desc = "+2 equip slots", Icon = "🗄️", Branch = "RCap", Cost = 22, Requires = "rc2" })

-- Meta branch (forks at Token Tithe)
rnode({ Id = "rm1", Name = "Token Tithe", Desc = "+2 tokens from every rebirth", Icon = "🪙", Branch = "RMeta", Cost = 6, Requires = "core" })
rnode({ Id = "rm2", Name = "Legendary Keeper", Desc = "Legendary cards survive rebirth", Icon = "🛡️", Branch = "RMeta", Cost = 10, Requires = "rm1" })
rnode({ Id = "rm3", Name = "Token Hoarder", Desc = "+3 tokens from every rebirth", Icon = "⭐", Branch = "RMeta", Cost = 18, Requires = "rm1" })

-- radiate from the island centre over 300°, leaving the south (toward the
-- bridge) open for the altar
radialTree(R, "core", Config.Layout.Gold, -60, 300, 18)
Config.RebirthTree = R

-- ===== AUTOMATION tree (green island, tokens) ==============================
-- Root (autocore) unlocks auto-roll when bought; everything else hangs off it.
-- Grows WEST into the green island. Bought with Tokens; permanent.
local A = {}
local function anode(def)
	def.IsRebirth = true
	def.Branch = "Automation"
	def.Area = "green"
	def.TextRot = 0
	def.IsAutomation = def.Id ~= "autocore"
	table.insert(A, def)
end

anode({ Id = "autocore", Name = "Automaton Core", Desc = "Unlocks AUTO-ROLL on the TV (root)", Icon = "🤖", Cost = 8, MaxLevel = 1 })
anode({ Id = "autoequip", Name = "Auto Equip", Desc = "Always keeps your best cards equipped", Icon = "🧤", Cost = 6, Requires = "autocore" })
anode({ Id = "autosell", Name = "Auto Liquidate", Desc = "Auto-sells duplicate cards for coins", Icon = "💱", Cost = 8, Requires = "autoequip" })
anode({ Id = "smartsell", Name = "Smart Seller", Desc = "Also auto-sells the rarities you toggled off", Icon = "🧠", Cost = 12, Requires = "autosell" })
anode({ Id = "overclock1", Name = "Overclock I", Desc = "Auto-roll 25% faster", Icon = "⚡", Cost = 6, Requires = "autocore" })
anode({ Id = "overclock2", Name = "Overclock II", Desc = "Auto-roll 30% faster again", Icon = "⚡", Cost = 10, Requires = "overclock1" })
anode({ Id = "overclock3", Name = "Overclock III", Desc = "Auto-roll 40% faster again", Icon = "⚡", Cost = 16, Requires = "overclock2" })
anode({ Id = "autorebirth", Name = "Auto Rebirth", Desc = "Rebirths automatically when worth it", Icon = "🔁", Cost = 25, Requires = "autocore" })

-- radiate from the green island centre over 300°, leaving the east (toward the
-- bridge) open
radialTree(A, "autocore", Config.Layout.Green, 120, 300, 20)
Config.AutomationTree = A

-- ===== Bridges =============================================================
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
		cost *= 10
	end
	return math.floor(cost)
end

-- ===== Shop (imported store, south) ========================================
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

Config.LuckyBlock = { MinTier = "Mythic", MaxTier = "Divine", ValueMult = 1.6 }

-- ===== Card Packs ==========================================================
-- Each pack is UNLOCKED by buying a dedicated upgrade button out in the world
-- (it spends cards / tokens). Once bought it's yours forever; you then EQUIP one
-- at a time at the Pack Loader 3000. Buttons:
--   * Basic     — on the HUB (also switches the Pack Loader on). Spend 5 Rares.
--   * Rebirth   — on the GOLD island. Costs 1,000 tokens.
--   * Automation— on the GREEN island. Needs every Automation upgrade.
--   * Ultimate  — in the SHOP. 1,000 tokens + a Divine card + every upgrade.
-- Art (Image) is filled in later; for now each shows an icon.
Config.Packs = {
	{
		Id = "basic",
		Name = "Basic Pack",
		Icon = "🃏",
		Color = Color3.fromRGB(150, 120, 255),
		Image = "", -- set to "rbxassetid://..." when you have the texture
		Desc = "↑ Legendary odds + 5 free Roll-Speed levels",
		Area = "hub",
		Pos = { 64, -22 },
		ReqText = "Spend 5 Rare cards + 250K coins",
		Unlock = { RareCards = 5, Coins = 250000, GrantsLoader = true },
	},
	{
		Id = "rebirth",
		Name = "Rebirth Pack",
		Icon = "♻️",
		Color = Color3.fromRGB(255, 215, 80),
		Image = "",
		Desc = "+50% tokens & more Legendary+ — but rolls are 2x slower",
		Area = "gold",
		Pos = { 24, 160 },
		ReqText = "Costs 1,000 Rebirth Tokens",
		Unlock = { Tokens = 1000 },
	},
	{
		Id = "automation",
		Name = "Automation Pack",
		Icon = "🤖",
		Color = Color3.fromRGB(120, 220, 150),
		Image = "",
		Desc = "Automation runs much faster & auto-buys Roll Speed",
		Area = "green",
		Pos = { -230, 70 },
		ReqText = "Own every Automation upgrade",
		Unlock = { AllAutomation = true },
	},
	{
		Id = "ultimate",
		Name = "Ultimate Pack",
		Icon = "👑",
		Color = Color3.fromRGB(255, 120, 200),
		Image = "",
		Desc = "+20 Roll-Speed levels, Mythic+ boost, ALL prices halved",
		Area = "shop",
		Pos = { 0, -160 },
		ReqText = "1,000 Tokens + a Divine card + every upgrade",
		Unlock = { Tokens = 1000, AllUpgrades = true, DivineCards = 1 },
	},
}
Config.PackById = {}
for _, pack in Config.Packs do
	Config.PackById[pack.Id] = pack
end

-- Apply the equipped pack's price multiplier to a coin/token cost.
function Config.ApplyPrice(cost, stats)
	local mult = (stats and stats.PriceMult) or 1
	return math.max(1, math.floor(cost * mult))
end

Config.NodeById = {}
local function indexTree(tree)
	for _, treeNode in tree do
		if treeNode.MaxLevel == nil and treeNode.CostMult == nil then
			treeNode.MaxLevel = 1
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

-- Turns a player's data into effective stats. Pass the whole data table.
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
		RarityFloor = nil,
		AutoSpeedMult = 1,
		AutoCore = false,
		AutoEquipUnlocked = false,
		AutoSellUnlocked = false,
		SmartSellUnlocked = false,
		AutoRebirthUnlocked = false,
		-- card packs (one equipped at a time)
		BonusRollSpeedLevels = 0, -- free roll-speed levels (don't need buying / cap)
		LegendaryChance = 0, -- chance per roll to grade the card up to >= Legendary
		MythicChance = 0, -- chance per roll to grade the card up to >= Mythic
		TokenMult = 1, -- multiplies tokens earned on rebirth
		PriceMult = 1, -- multiplies coin/token costs (Ultimate halves them)
		RollCooldownMult = 1, -- extra cooldown factor (Rebirth pack doubles it)
		AutoBuySpeed = false, -- automation pack auto-buys roll-speed levels
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
	stats.EquipSlots += cLevel("fork")
	-- greed (money)
	if cLevel("gA") > 0 then stats.CoinMult *= 2 end
	stats.DupeMult += 1 * cLevel("gB")
	if cLevel("gC") > 0 then stats.CoinMult *= 1.5 end
	stats.EquipSlots += 2 * cLevel("gD")
	stats.BackpackBonus += 40 * cLevel("gE")
	if cLevel("gF") > 0 then stats.CoinMult *= 2 end
	if cLevel("gG") > 0 then
		stats.CoinMult *= 1.5
		stats.DupeMult += 0.5
	end
	if cLevel("gH") > 0 then stats.CoinMult *= 2 end
	stats.EquipSlots += 3 * cLevel("gI")
	if cLevel("gJ") > 0 then stats.CoinMult *= 3 end
	-- luck
	stats.LuckChance += 0.08 * cLevel("lA")
	stats.LuckChance += 0.08 * cLevel("lB")
	if cLevel("lC") > 0 then stats.GodChance *= 2 end
	stats.LuckChance += 0.10 * cLevel("lD")
	if cLevel("lE") > 0 then stats.LuckySevens = true end
	stats.LuckChance += 0.12 * cLevel("lF")
	if cLevel("lG") > 0 then stats.GodChance *= 2 end
	stats.LuckChance += 0.15 * cLevel("lH")
	if cLevel("lI") > 0 then stats.GodChance *= 3 end
	stats.LuckChance += 0.20 * cLevel("lJ")

	-- ----- REBIRTH tree (permanent) -----
	stats.CoinMult *= 2 ^ rLevel("core")
	if rLevel("rw1") > 0 then stats.CoinMult *= 2 end
	stats.DupeMult += 2 * rLevel("rw2")
	if rLevel("rw3") > 0 then stats.CoinMult *= 3 end
	stats.StartCoins += 50000 * rLevel("rw4")
	if rLevel("rw5") > 0 then
		stats.OfflineUnlocked = true
		stats.OfflineFraction = 1
		stats.OfflineCapHours = 24
	end
	stats.LuckChance += 0.15 * rLevel("rl1")
	if rLevel("rl2") > 0 then stats.GodChance *= 3 end
	stats.LuckChance += 0.15 * rLevel("rl3")
	if rLevel("rl4") > 0 then stats.GodChance *= 3 end
	if rLevel("rs1") > 0 then stats.RollCooldown *= 0.6 end
	stats.MaxRollSpeedLevel += 2 * rLevel("rs2")
	if rLevel("rs3") > 0 then stats.FreshInterval *= 0.5 end
	stats.MaxRollSpeedLevel += 2 * rLevel("rs4")
	stats.EquipSlots += rLevel("rc1")
	stats.BackpackBonus += 40 * rLevel("rc2")
	stats.EquipSlots += rLevel("rc3")
	stats.EquipSlots += 2 * rLevel("rc4")
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
	stats.MaxRollSpeedLevel += sLevel("rams")
	if sLevel("flask3") > 0 then stats.WalkSpeedMult *= 1.5 end
	stats.HasSpeedCoil = sLevel("speedcoil") > 0
	if sLevel("flask2") > 0 then stats.RarityFloor = "Legendary" end

	-- ----- CARD PACK (one equipped at a time) -----
	local pack = data.EquippedPack
	if pack == "basic" then
		stats.LegendaryChance += 0.15
		stats.BonusRollSpeedLevels += 5
	elseif pack == "rebirth" then
		stats.LegendaryChance += 0.30
		stats.TokenMult *= 1.5
		stats.RollCooldownMult *= 2 -- the downside: rolling is 2x slower
	elseif pack == "automation" then
		stats.AutoSpeedMult *= 0.4
		stats.AutoBuySpeed = true
	elseif pack == "ultimate" then
		stats.BonusRollSpeedLevels += 20
		stats.MythicChance += 0.20
		stats.PriceMult = 0.5
	end

	-- roll speed: bought levels + any free pack levels, then the pack cooldown mult
	stats.RollCooldown *= Config.RollSpeed.CooldownFactor ^ (rollSpeedLevel + stats.BonusRollSpeedLevels)
	stats.RollCooldown *= stats.RollCooldownMult

	stats.RollCooldown = math.max(stats.RollCooldown, Config.Roll.MinCooldown)
	stats.LuckChance = math.min(stats.LuckChance, Config.Roll.MaxLuckChance)
	stats.FreshInterval = math.max(stats.FreshInterval, 1)
	return stats
end

return Config
