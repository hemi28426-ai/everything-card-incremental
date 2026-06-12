-- Keeps rolls instant and the card supply endless:
--   * a buffer of freshly scanned random accounts, refilled in the background
--   * a global pool (DataStore) of every Rare+ account any server discovered,
--     shared across all servers — luck upgrades draw from here
--   * the legends list (resolved from usernames at startup) for god rolls
--   * an offline stub mode so the game is fully testable in Studio
--     with no internet APIs at all

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Scanner = require(script.Parent:WaitForChild("Scanner"))

local CardPool = {}

local POOL_KEY = "RarePool_v1"
local POOL_CAP = 300
local POOL_READ_INTERVAL = 120
local POOL_FLUSH_INTERVAL = 60
local OFFLINE_AFTER_FAILURES = 3

local poolStore = nil
pcall(function()
	poolStore = DataStoreService:GetDataStore("ECISharedPool_v1")
end)

local buffer = {} -- scanned cards ready to be rolled
local scanCache = {} -- userId -> card (everything scanned this server session)
local cacheList = {} -- same cards as an array, for fast random fallback picks
local refilling = false
local rarePool = {} -- tierName -> {card, ...} (merged from the global store)
local pendingSubmits = {} -- discovered Rare+ cards not yet flushed to the store
local legendCards = {}
local consecutiveLookupFailures = 0
local offlineMode = false
local statsProvider = nil -- set by Init; returns the best FreshInterval online

local TIER_POOL_WEIGHTS = { Rare = 70, Legendary = 25, Mythic = 5 }
local OFFLINE_TIER_WEIGHTS = {
	{ Tier = "Common", Weight = 70 },
	{ Tier = "Uncommon", Weight = 20 },
	{ Tier = "Rare", Weight = 8 },
	{ Tier = "Legendary", Weight = 1.7 },
	{ Tier = "Mythic", Weight = 0.3 },
}

-- ===== random account ids ==================================================

local function randomUserId()
	local totalWeight = 0
	for _, range in Config.IdRanges do
		totalWeight += range.Weight
	end
	local pick = math.random() * totalWeight
	for _, range in Config.IdRanges do
		pick -= range.Weight
		if pick <= 0 then
			return math.floor(range.Min + math.random() * (range.Max - range.Min))
		end
	end
	return math.floor(math.random() * Config.Roll.MaxUserId) + 1
end

-- ===== global pool (DataStore) =============================================

local function rememberPoolCard(card)
	local list = rarePool[card.Tier]
	if not list then
		list = {}
		rarePool[card.Tier] = list
	end
	for _, existing in list do
		if existing.UserId == card.UserId then
			return
		end
	end
	table.insert(list, card)
end

local function readGlobalPool()
	if not poolStore then
		return
	end
	pcall(function()
		local stored = poolStore:GetAsync(POOL_KEY)
		if type(stored) == "table" and type(stored.Cards) == "table" then
			for _, card in stored.Cards do
				if type(card) == "table" and card.UserId and card.Tier then
					rememberPoolCard(card)
				end
			end
		end
	end)
end

local function flushSubmits()
	if not poolStore or #pendingSubmits == 0 then
		return
	end
	local toAdd = pendingSubmits
	pendingSubmits = {}
	pcall(function()
		poolStore:UpdateAsync(POOL_KEY, function(stored)
			if type(stored) ~= "table" or type(stored.Cards) ~= "table" then
				stored = { Cards = {} }
			end
			local seen = {}
			for _, card in stored.Cards do
				if type(card) == "table" and card.UserId then
					seen[card.UserId] = true
				end
			end
			for _, card in toAdd do
				if not seen[card.UserId] then
					table.insert(stored.Cards, card)
					seen[card.UserId] = true
				end
			end
			while #stored.Cards > POOL_CAP do
				table.remove(stored.Cards, math.random(1, #stored.Cards))
			end
			return stored
		end)
	end)
end

local function submitIfRare(card)
	local tier = Config.TierByName[card.Tier]
	if tier and tier.Index >= Config.TierByName.Rare.Index and tier.Index < Config.TierByName.God.Index then
		rememberPoolCard(card)
		table.insert(pendingSubmits, card)
	end
end

-- ===== scanning ============================================================

local function scanAndStore(userId, basicInfo)
	local card = Scanner.Scan(userId, basicInfo)
	scanCache[userId] = card
	table.insert(cacheList, card)
	submitIfRare(card)
	return card
end

local function refillTick()
	if refilling or #buffer >= Config.Roll.BufferTarget then
		return
	end
	refilling = true

	local candidates = {}
	for _ = 1, 15 do
		table.insert(candidates, randomUserId())
	end
	local found = Scanner.LookupUsers(candidates)
	if found == nil then
		consecutiveLookupFailures += 1
		if consecutiveLookupFailures >= OFFLINE_AFTER_FAILURES and not offlineMode then
			offlineMode = true
			warn("[ECI] Account lookups unavailable (offline Studio?) — switching to stub cards so you can still test.")
		end
		refilling = false
		return
	end
	consecutiveLookupFailures = 0
	offlineMode = false

	local scanned = 0
	for userId, basicInfo in found do
		if scanned >= 6 then
			break
		end
		if not scanCache[userId] then
			scanned += 1
			table.insert(buffer, scanAndStore(userId, basicInfo))
		end
	end
	refilling = false
end

-- ===== offline stubs =======================================================

local stubCounter = 0

local function makeStubCard()
	local totalWeight = 0
	for _, entry in OFFLINE_TIER_WEIGHTS do
		totalWeight += entry.Weight
	end
	local pick = math.random() * totalWeight
	local tierName = "Common"
	for _, entry in OFFLINE_TIER_WEIGHTS do
		pick -= entry.Weight
		if pick <= 0 then
			tierName = entry.Tier
			break
		end
	end
	stubCounter += 1
	local tier = Config.TierByName[tierName]
	return {
		UserId = -stubCounter, -- negative = fake; never collides with real accounts
		Name = "TestUser" .. stubCounter,
		DisplayName = "Test User " .. stubCounter,
		Tier = tierName,
		Boost = tier.Boost,
		Traits = { "Offline stub" },
	}
end

-- ===== public API ==========================================================

function CardPool.Init(getBestFreshInterval)
	statsProvider = getBestFreshInterval

	-- resolve legend usernames to ids (so we never trust hardcoded numbers)
	task.spawn(function()
		for _, legend in Config.Legends do
			local resolved = nil
			pcall(function()
				resolved = Players:GetUserIdFromNameAsync(legend.Username)
			end)
			legend.ResolvedId = resolved or legend.KnownId
			if legend.ResolvedId then
				table.insert(legendCards, Scanner.BuildLegendCard(legend))
			end
		end
	end)

	task.spawn(function()
		readGlobalPool()
		while true do
			task.wait(POOL_READ_INTERVAL)
			readGlobalPool()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(POOL_FLUSH_INTERVAL)
			flushSubmits()
		end
	end)

	task.spawn(function()
		while true do
			local interval = Config.Roll.BaseFreshInterval
			if statsProvider then
				interval = statsProvider()
			end
			task.wait(interval)
			refillTick()
		end
	end)
end

-- Scan a player who actually joined this server (free real account data!)
function CardPool.CapturePlayer(player)
	task.spawn(function()
		if scanCache[player.UserId] then
			return
		end
		local found = Scanner.LookupUsers({ player.UserId })
		local basicInfo = found and found[player.UserId]
		if basicInfo then
			scanAndStore(player.UserId, basicInfo)
		end
	end)
end

local function drawFromRarePool()
	local available = {}
	local totalWeight = 0
	for tierName, weight in TIER_POOL_WEIGHTS do
		local list = rarePool[tierName]
		if list and #list > 0 then
			table.insert(available, { List = list, Weight = weight })
			totalWeight += weight
		end
	end
	if totalWeight == 0 then
		return nil
	end
	local pick = math.random() * totalWeight
	for _, entry in available do
		pick -= entry.Weight
		if pick <= 0 then
			return entry.List[math.random(1, #entry.List)]
		end
	end
	return nil
end

local function anyCachedCard()
	if #cacheList > 0 then
		return cacheList[math.random(1, #cacheList)]
	end
	return nil
end

-- Draw one card for a roll. Never fails.
function CardPool.Draw(stats)
	if #legendCards > 0 and math.random() < stats.GodChance then
		return legendCards[math.random(1, #legendCards)]
	end

	if math.random() < stats.LuckChance then
		local poolCard = drawFromRarePool()
		if poolCard then
			return poolCard
		end
	end

	if #buffer > 0 then
		local card = table.remove(buffer, 1)
		if #buffer < Config.Roll.BufferTarget / 2 then
			task.spawn(refillTick) -- start restocking before we run dry
		end
		return card
	end

	-- buffer dry: restock urgently, and serve a random known card meanwhile
	task.spawn(refillTick)
	return anyCachedCard()
		or drawFromRarePool()
		or makeStubCard()
end

return CardPool
