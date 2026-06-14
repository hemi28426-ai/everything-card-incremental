-- Scans a real Roblox account and turns it into card data.
--
-- Two layers of signals:
--   1. Engine APIs (always work): username/id heuristics, verified badge,
--      and whatever the account is WEARING right now — worn avatars are
--      public even when inventories are private, which is how we catch a
--      Dominus on a locked-down account.
--   2. RoProxy (optional, needs HTTP enabled): collectible value (RAP) for
--      the Legendary/Mythic robux tiers, account age, Admin/Veteran badges.
--      If the proxy is down or HTTP is off, scans silently fall back to
--      engine-only signals — a roll never fails because of it.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local Scanner = {}

local MAX_WORN_ASSETS_CHECKED = 5
local PROXY_FAILURE_LIMIT = 3
local PROXY_RETRY_AFTER = 300 -- seconds proxy stays disabled after repeated failures

local productInfoCache = {} -- assetId -> {Price, IsLimited, Name}
local httpEnabled = nil -- unknown until first attempt
local proxyFailures = 0
local proxyDisabledUntil = 0

-- ===== proxy helpers =======================================================

local function proxyGet(url)
	if httpEnabled == false then
		return nil
	end
	if os.clock() < proxyDisabledUntil then
		return nil
	end
	local ok, result = pcall(function()
		return HttpService:GetAsync(url)
	end)
	if not ok then
		local message = tostring(result)
		if message:find("not enabled") or message:find("Http requests are not enabled") then
			httpEnabled = false
			warn("[ECI] HTTP requests are disabled — deep scans (RAP tiers) are off. " ..
				"Enable them in Game Settings > Security > Allow HTTP Requests for the full experience.")
			return nil
		end
		proxyFailures += 1
		if proxyFailures >= PROXY_FAILURE_LIMIT then
			proxyDisabledUntil = os.clock() + PROXY_RETRY_AFTER
			proxyFailures = 0
		end
		return nil
	end
	httpEnabled = true
	proxyFailures = 0
	local decoded
	local decodeOk = pcall(function()
		decoded = HttpService:JSONDecode(result)
	end)
	if decodeOk then
		return decoded
	end
	return nil
end

local function fetchAccountAgeYears(userId)
	local info = proxyGet(("https://users.roproxy.com/v1/users/%d"):format(userId))
	if info and type(info.created) == "string" then
		local year = tonumber(info.created:match("^(%d%d%d%d)"))
		if year then
			local currentYear = tonumber(os.date("!%Y"))
			return math.max((currentYear :: number) - year, 0)
		end
	end
	return nil
end

local function fetchRap(userId)
	local canView = proxyGet(("https://inventory.roproxy.com/v1/users/%d/can-view-inventory"):format(userId))
	if not canView or canView.canView ~= true then
		return nil, canView ~= nil -- second value: we did learn their privacy setting
	end
	local page = proxyGet(("https://inventory.roproxy.com/v1/users/%d/assets/collectibles?sortOrder=Asc&limit=100"):format(userId))
	if not page or type(page.data) ~= "table" then
		return nil, true
	end
	local total = 0
	for _, item in page.data do
		if type(item) == "table" and type(item.recentAveragePrice) == "number" then
			total += item.recentAveragePrice
		end
	end
	return total, true
end

local function fetchRobloxBadges(userId)
	local badges = proxyGet(("https://accountinformation.roproxy.com/v1/users/%d/roblox-badges"):format(userId))
	local found = {}
	if type(badges) == "table" then
		for _, badge in badges do
			if type(badge) == "table" and type(badge.name) == "string" then
				found[badge.name] = true
			end
		end
	end
	return found
end

-- ===== engine helpers ======================================================

local function getProductInfo(assetId)
	local cached = productInfoCache[assetId]
	if cached ~= nil then
		return cached
	end
	local info = nil
	pcall(function()
		local raw = MarketplaceService:GetProductInfo(assetId)
		info = {
			Name = raw.Name,
			Price = raw.PriceInRobux or 0,
			IsLimited = raw.IsLimited == true or raw.IsLimitedUnique == true,
		}
	end)
	productInfoCache[assetId] = info or false
	return info or false
end

local function scanWornAssets(userId)
	local worn = {
		DominusCount = 0,
		LimitedCount = 0,
		PriceSum = 0,
		AssetCount = 0,
	}
	local appearance
	pcall(function()
		appearance = Players:GetCharacterAppearanceInfoAsync(userId)
	end)
	if type(appearance) ~= "table" or type(appearance.assets) ~= "table" then
		return worn
	end
	worn.AssetCount = #appearance.assets
	local checked = 0
	for _, asset in appearance.assets do
		if type(asset) ~= "table" or type(asset.id) ~= "number" then
			continue
		end
		local assetName = if type(asset.name) == "string" then asset.name else ""
		if assetName:sub(1, 7) == "Dominus" then
			worn.DominusCount += 1
		end
		if checked < MAX_WORN_ASSETS_CHECKED then
			checked += 1
			local info = getProductInfo(asset.id)
			if info then
				worn.PriceSum += info.Price
				if info.IsLimited then
					worn.LimitedCount += 1
				end
				if info.Name:sub(1, 7) == "Dominus" and assetName:sub(1, 7) ~= "Dominus" then
					worn.DominusCount += 1
				end
			end
		end
	end
	return worn
end

local function isCleanName(name)
	return name:match("^[A-Za-z]+$") ~= nil
end

-- ===== tier decision =======================================================

local function decideTier(facts, traits)
	local function trait(text)
		table.insert(traits, text)
	end

	-- collect trait labels first (they show on the card)
	if facts.DominusCount >= 1 then
		trait(facts.DominusCount > 1 and ("Dominus x" .. facts.DominusCount) or "Dominus")
	end
	if facts.Rap and facts.Rap > 0 then
		trait("RAP " .. Format(facts.Rap))
	end
	if facts.LimitedCount >= 1 then
		trait("Limited worn")
	end
	if facts.Verified then
		trait("Verified")
	end
	if facts.AdminBadge then
		trait("Roblox Admin")
	end
	if facts.VeteranBadge then
		trait("Veteran")
	end
	if facts.UserId <= 10_000 then
		trait("OG id")
	elseif facts.UserId <= 1_000_000 then
		trait("Early id")
	end
	if facts.UserId % 100_000 == 0 then
		trait("Round id")
	end
	if facts.NameLength <= 4 and facts.CleanName then
		trait("Rare name")
	end
	if facts.AccountAge and facts.AccountAge >= 15 then
		trait(facts.AccountAge .. "y account")
	end

	-- highest tier whose condition holds wins (God/Divine/Secret come from the
	-- legends list, not from scanning — those are the fixed famous accounts)
	if (facts.Rap and facts.Rap >= 5_000_000) or facts.DominusCount >= 3 then
		return "Ancient"
	end
	if facts.AdminBadge or (facts.Rap and facts.Rap >= 1_000_000) or facts.DominusCount >= 2 then
		return "Mythic"
	end
	if (facts.Rap and facts.Rap >= 100_000) or facts.DominusCount >= 1 or facts.UserId <= 10_000 then
		return "Legendary"
	end
	if (facts.Rap and facts.Rap >= 25_000)
		or (facts.LimitedCount >= 1 and facts.Verified)
		or facts.UserId <= 100_000
		or (facts.AccountAge ~= nil and facts.AccountAge >= 12)
	then
		return "Epic"
	end
	if (facts.Rap and facts.Rap > 0)
		or facts.LimitedCount >= 1
		or facts.Verified
		or facts.VeteranBadge
		or facts.UserId <= 1_000_000
		or facts.UserId % 100_000 == 0
		or (facts.NameLength <= 4 and facts.CleanName)
	then
		return "Rare"
	end
	if facts.UserId <= 100_000_000
		or (facts.NameLength <= 6 and facts.CleanName)
		or facts.PriceSum >= 1_000
		or (facts.AccountAge ~= nil and facts.AccountAge >= 8)
	then
		return "Uncommon"
	end
	return "Common"
end

-- ===== public API ==========================================================

-- Look up several user ids at once; returns map of userId -> {Username, DisplayName, Verified}.
-- One web call for the whole batch. Returns nil if the lookup itself failed (offline).
function Scanner.LookupUsers(userIds)
	local result = nil
	pcall(function()
		local infos = UserService:GetUserInfosByUserIdsAsync(userIds)
		result = {}
		for _, info in infos do
			result[info.Id] = {
				Username = info.Username,
				DisplayName = info.DisplayName,
				Verified = info.HasVerifiedBadge == true,
			}
		end
	end)
	return result
end

-- Full scan of one account. basicInfo comes from LookupUsers.
-- Returns a complete card data table.
function Scanner.Scan(userId, basicInfo)
	local worn = scanWornAssets(userId)
	local rap = fetchRap(userId)
	local robloxBadges = fetchRobloxBadges(userId)
	local accountAge = fetchAccountAgeYears(userId)

	local username = basicInfo.Username or ("User" .. userId)
	local facts = {
		UserId = userId,
		NameLength = #username,
		CleanName = isCleanName(username),
		Verified = basicInfo.Verified == true,
		DominusCount = worn.DominusCount,
		LimitedCount = worn.LimitedCount,
		PriceSum = worn.PriceSum,
		Rap = rap,
		AdminBadge = robloxBadges["Administrator"] == true,
		VeteranBadge = robloxBadges["Veteran"] == true,
		AccountAge = accountAge,
	}

	local traits = {}
	local tierName = decideTier(facts, traits)
	local tier = Config.TierByName[tierName]

	return {
		UserId = userId,
		Name = username,
		DisplayName = basicInfo.DisplayName or username,
		Tier = tierName,
		Boost = tier.Boost,
		Traits = traits,
	}
end

-- Build a card for a configured legend (skips scanning entirely).
function Scanner.BuildLegendCard(legend)
	local tier = Config.TierByName[legend.Tier] or Config.TierByName.God
	return {
		UserId = legend.ResolvedId,
		Name = legend.Username,
		DisplayName = legend.Username,
		Tier = tier.Name,
		Boost = legend.Boost or tier.Boost,
		Traits = { "Legend" },
		Flavor = legend.Flavor,
	}
end

return Scanner
