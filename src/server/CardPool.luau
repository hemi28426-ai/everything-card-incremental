-- The roll engine. Every roll is an INDEPENDENT, uniformly-random account id
-- drawn from the whole 1..MaxUserId space, so it's truly "1 in 8.5 billion" for
-- every player, and duplicates essentially never happen (a collision in 8.5B is
-- astronomically unlikely). To keep rolls instant we keep a background buffer of
-- freshly-scanned random accounts; a roll just consumes one. Nothing is ever
-- served from a cache or a shared pool, which is what used to cause repeats.
--
--   * buffer: fresh random accounts, refilled in the background
--   * legends: the configured famous accounts (resolved at startup) for god rolls
--   * luck: extra fresh draws per roll, keeping the rarest (still all unique)
--   * offline stub mode: unique fake cards so the game is testable in Studio
--     with no internet APIs at all

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Scanner = require(script.Parent:WaitForChild("Scanner"))

local CardPool = {}

local OFFLINE_AFTER_FAILURES = 3

local buffer = {} -- fresh scanned accounts ready to be rolled (each id unique)
local scanCache = {} -- userId -> true: every id scanned this session (dedup)
local refilling = false
local legendCards = {}
local consecutiveLookupFailures = 0
local offlineMode = false
local statsProvider = nil -- set by Init; returns the best FreshInterval online

local OFFLINE_TIER_WEIGHTS = {
	{ Tier = "Common", Weight = 70 },
	{ Tier = "Uncommon", Weight = 20 },
	{ Tier = "Rare", Weight = 8 },
	{ Tier = "Legendary", Weight = 1.7 },
	{ Tier = "Mythic", Weight = 0.3 },
}

-- ===== random account ids ==================================================

-- A flat, uniform pick across the entire id space: truly 1 in MaxUserId.
local function randomUserId()
	return math.floor(math.random() * Config.Roll.MaxUserId) + 1
end

local function tierIndex(card)
	local tier = Config.TierByName[card.Tier]
	return tier and tier.Index or 0
end

-- ===== scanning ============================================================

local function scanAndStore(userId, basicInfo)
	local card = Scanner.Scan(userId, basicInfo)
	scanCache[userId] = true
	return card
end

local function refillTick()
	if refilling or #buffer >= Config.Roll.BufferTarget then
		return
	end
	refilling = true

	local candidates = {}
	for _ = 1, 25 do
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
		if scanned >= 12 then
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
			table.insert(buffer, scanAndStore(player.UserId, basicInfo))
		end
	end)
end

-- Take one fresh account from the buffer (each is a unique random id).
local function popBuffer()
	if #buffer > 0 then
		local card = table.remove(buffer, 1)
		if #buffer < Config.Roll.BufferTarget / 2 then
			task.spawn(refillTick) -- start restocking before we run dry
		end
		return card
	end
	return nil
end

-- A guaranteed fresh card. Online, if the buffer is empty, it scans one new
-- random account right now (this yields briefly, but only when fully drained).
-- Offline, it returns a unique stub.
local function freshFallback()
	task.spawn(refillTick)
	if not offlineMode then
		local userId = randomUserId()
		if not scanCache[userId] then
			local found = Scanner.LookupUsers({ userId })
			local basicInfo = found and found[userId]
			if basicInfo then
				return scanAndStore(userId, basicInfo)
			end
		end
	end
	return makeStubCard()
end

-- Returns a fresh, unique card. `allowYield` lets it scan on demand when the
-- buffer is empty; extra (luck) attempts pass false so they never block.
local function drawOneFresh(allowYield)
	local card = popBuffer()
	if card then
		return card
	end
	if offlineMode then
		return makeStubCard()
	end
	if allowYield then
		return freshFallback()
	end
	return nil
end

-- Promote a card to at least `tierName` (used by the Lucky Sevens pity). The
-- account stays the same real account (same id), it's just graded up.
local function promoteTier(card, tierName)
	local tier = Config.TierByName[tierName]
	if not tier or tierIndex(card) >= tier.Index then
		return card
	end
	return {
		UserId = card.UserId,
		Name = card.Name,
		DisplayName = card.DisplayName,
		Tier = tier.Name,
		Boost = tier.Boost,
		Traits = card.Traits,
		Flavor = card.Flavor,
	}
end

-- Draw one card for a roll. Never fails, never duplicates (except legends, which
-- are intentionally a fixed set). Luck adds extra fresh draws and keeps the
-- rarest of them. forcePool (Lucky Sevens) guarantees at least a Rare.
function CardPool.Draw(stats, forcePool)
	-- god roll: a fixed famous account (the only intentional "repeat")
	if #legendCards > 0 and math.random() < stats.GodChance then
		return legendCards[math.random(1, #legendCards)]
	end

	-- luck = "best of N" fresh, independent, uniformly-random accounts
	local attempts = 1 + math.min(math.floor((stats.LuckChance or 0) / 0.15), 6)
	local best = nil
	for index = 1, attempts do
		local card = drawOneFresh(index == 1)
		if card then
			if not best or tierIndex(card) > tierIndex(best) then
				best = card
			end
		end
	end
	if not best then
		best = makeStubCard()
	end

	if forcePool then
		best = promoteTier(best, "Rare")
	end
	return best
end

return CardPool
