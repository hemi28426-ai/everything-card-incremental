-- Loads and saves player progress with DataStores.
-- NOTE: DataStores only work once the game is published and
-- "Enable Studio Access to API Services" is turned on in Game Settings > Security.
-- Until then the game still runs — progress just doesn't persist.

local DataStoreService = game:GetService("DataStoreService")

local DataManager = {}

local STORE_NAME = "PlayerData_v1"
local KEY_PREFIX = "player_"
local RETRIES = 3

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[ClickEmpire] DataStores unavailable — progress will NOT save. " ..
			"(Normal in Studio until the game is published with API access enabled.) " .. tostring(result))
	end
end

local DEFAULT_DATA = {
	Cash = 0,
	TotalEarned = 0,
	TotalClicks = 0,
	Rebirths = 0,
	Upgrades = {}, -- map of upgrade id -> amount owned
}

function DataManager.NewDefault()
	local data = table.clone(DEFAULT_DATA)
	data.Upgrades = {}
	return data
end

-- Returns (data, loadedSafely). When loadedSafely is false we refuse to save
-- later, so a temporary outage can never wipe a player's real progress.
function DataManager.Load(player)
	if not store then
		return DataManager.NewDefault(), false
	end

	local key = KEY_PREFIX .. player.UserId
	for attempt = 1, RETRIES do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			if type(result) == "table" then
				-- fill in any fields added to the game since this player last played
				for field, defaultValue in DEFAULT_DATA do
					if result[field] == nil then
						result[field] = if type(defaultValue) == "table" then {} else defaultValue
					end
				end
				return result, true
			end
			return DataManager.NewDefault(), true -- brand new player
		end
		if attempt < RETRIES then
			task.wait(attempt)
		end
	end

	warn(("[ClickEmpire] Failed to load data for %s — playing without saving this session"):format(player.Name))
	return DataManager.NewDefault(), false
end

function DataManager.Save(player, data)
	if not store then
		return false
	end

	local key = KEY_PREFIX .. player.UserId
	for attempt = 1, RETRIES do
		local ok = pcall(function()
			store:UpdateAsync(key, function()
				return data
			end)
		end)
		if ok then
			return true
		end
		if attempt < RETRIES then
			task.wait(attempt)
		end
	end

	warn(("[ClickEmpire] Failed to save data for %s"):format(player.Name))
	return false
end

return DataManager
