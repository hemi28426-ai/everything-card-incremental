-- The roll engine. Every roll is a fresh, real Roblox account drawn from a
-- weighted-random id (see Config.IdRanges) and scanned into a card. A background
-- buffer keeps freshly-scanned accounts ready so rolls are instant.
--
-- IMPORTANT: there are NO fake/"test" cards. If a real account genuinely can't
-- be fetched at that moment (HTTP off, API down), a roll returns nothing and the
-- client shows a "scanning…" notice — it will never invent a placeholder card.
--
--   * buffer: fresh real accounts, refilled in the background
--   * legends: the configured famous accounts (resolved at startup) for god rolls
--   * luck: a chance to grade a drawn card up a tier

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Scanner = require(script.Parent:WaitForChild("Scanner"))

local CardPool = {}

local DOWN_AFTER_FAILURES = 3 -- consecutive empty refills before we stop hammering

local buffer = {} -- fresh scanned accounts ready to be rolled (each id unique)
local scanCache = {} -- userId -> true: every id scanned this session (dedup)
local refilling = false
local legendCards = {}
local consecutiveLookupFailures = 0
local statsProvider = nil -- set by Init; returns the best FreshInterval online

local function lookupsDown()
	return consecutiveLookupFailures >= DOWN_AFTER_FAILURES
end

-- ===== random account ids ==================================================

-- A random id weighted by account era (see Config.IdRanges). Older/lower ids
-- are rarer, which is what lets higher rarities actually show up.
local function randomUserId()
	local total = 0
	for _, range in Config.IdRanges do
		total += range.Weight
	end
	local pick = math.random() * total
	for _, range in Config.IdRanges do
		pick -= range.Weight
		if pick <= 0 then
			return math.floor(range.Min + math.random() * (range.Max - range.Min))
		end
	end
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

-- Refill the buffer with fresh real accounts. Scanner.LookupUsers uses the
-- RoProxy bulk endpoint (and an engine per-id fallback), both of which simply
-- skip ids that don't exist instead of erroring, so one batch reliably yields
-- several real accounts. We track failures only to stop hammering a dead API;
-- it recovers automatically the moment a later call succeeds.
local function refillTick()
	if refilling or #buffer >= Config.Roll.BufferTarget then
		return
	end
	refilling = true

	local candidates = {}
	for _ = 1, 25 do
		local id = randomUserId()
		if not scanCache[id] then
			table.insert(candidates, id)
		end
	end

	local found = Scanner.LookupUsers(candidates)
	local added = 0
	for userId, basicInfo in found do
		if #buffer >= Config.Roll.BufferTarget then
			break
		end
		if not scanCache[userId] then
			table.insert(buffer, scanAndStore(userId, basicInfo))
			added += 1
		end
	end

	if added > 0 then
		consecutiveLookupFailures = 0
	else
		consecutiveLookupFailures += 1
		if consecutiveLookupFailures == DOWN_AFTER_FAILURES then
			warn(("[ECI] Account lookups returning nothing — rolls will show 'scanning…' until this clears. Last error: %s  (turn ON Allow HTTP Requests; in Studio also Allow Studio Access to API Services)"):format(tostring(Scanner.LastLookupError)))
		end
	end
	refilling = false
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

	-- startup self-test + prime the buffer
	task.spawn(function()
		local test = Scanner.LookupUsers({ 1, 156, 261 }) -- Roblox, builderman, Shedletsky
		local names = {}
		for _, info in test do
			table.insert(names, info.Username)
		end
		if #names > 0 then
			print(("[ECI] Account lookups WORKING — real cards incoming (sample: %s)"):format(table.concat(names, ", ")))
		else
			warn(("[ECI] Account lookups NOT working — rolls will say 'scanning…'. Last error: %s. Enable Game Settings > Security > Allow HTTP Requests (and in Studio, Allow Studio Access to API Services)."):format(tostring(Scanner.LastLookupError)))
		end
		for _ = 1, 4 do
			if #buffer >= Config.Roll.BufferTarget then
				break
			end
			refillTick()
		end
	end)

	-- background refill loop
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

-- A real account fetched on demand when the buffer is empty. Tries a few ids so
-- a single dead id doesn't make us give up. Yields (web calls), so it's only
-- used for the FIRST card of a roll. Returns nil if no real account can be got.
local function freshFallback()
	task.spawn(refillTick)
	if lookupsDown() then
		return nil -- don't hammer a dead API; the background loop will retry
	end
	for _ = 1, 3 do
		local userId = randomUserId()
		if not scanCache[userId] then
			local found = Scanner.LookupUsers({ userId })
			local basicInfo = found and found[userId]
			if basicInfo then
				return scanAndStore(userId, basicInfo)
			end
		end
	end
	return nil
end

-- Returns a real account, or nil if none is available right now. `allowYield`
-- lets it fetch on demand when the buffer is empty (first card of a roll only);
-- the bulk of a multi-roll just takes from the buffer so it never blocks.
local function drawOneFresh(allowYield)
	local card = popBuffer()
	if card then
		return card
	end
	task.spawn(refillTick)
	if allowYield then
		return freshFallback()
	end
	return nil
end

-- Promote a card to at least `tierName`. The account stays the same real account
-- (same id), it's just graded up — used by luck and the Lucky Sevens pity.
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

-- Draw one card for a roll. Returns a REAL account, or nil if none can be
-- fetched right now (the caller then shows a "scanning…" notice — never a fake
-- card). Luck gives the drawn card a chance to grade up a tier; forcePool
-- (Lucky Sevens) guarantees at least a Rare.
function CardPool.Draw(stats, forcePool, isPrimary)
	-- god roll: a fixed famous account (the only intentional "repeat")
	if #legendCards > 0 and math.random() < stats.GodChance then
		return legendCards[math.random(1, #legendCards)]
	end

	local card = drawOneFresh(isPrimary ~= false)
	if not card then
		return nil
	end

	-- luck = chance to bump the card up a tier (repeatable for big luck)
	local luck = stats.LuckChance or 0
	while luck > 0 and tierIndex(card) < #Config.Tiers do
		if math.random() < math.min(luck, 1) then
			card = promoteTier(card, Config.Tiers[tierIndex(card) + 1].Name)
		else
			break
		end
		luck -= 1
	end

	if forcePool then
		card = promoteTier(card, "Rare")
	end
	return card
end

return CardPool
