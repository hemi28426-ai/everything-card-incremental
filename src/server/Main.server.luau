-- Everything Card Incremental — server entry point.
-- Owns all real state: rolls, the collection, coins, upgrades. The client
-- only asks; everything is validated here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataManager = require(script.Parent:WaitForChild("DataManager"))
local CardPool = require(script.Parent:WaitForChild("CardPool"))
local TreeBuilder = require(script.Parent:WaitForChild("TreeBuilder"))
local Leaderboard = require(script.Parent:WaitForChild("Leaderboard"))

-- ===== remotes =============================================================

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local rollRemote = makeRemote("Roll")
local buyRemote = makeRemote("BuyUpgrade")
local equipRemote = makeRemote("Equip")
local unequipRemote = makeRemote("Unequip")
local equipBestRemote = makeRemote("EquipBest")
local sellDupesRemote = makeRemote("SellDupes")
local toggleAutoRemote = makeRemote("ToggleAuto")
local backpackRemote = makeRemote("UpgradeBackpack")
local stateRemote = makeRemote("StateChanged")
local rollResultRemote = makeRemote("RollResult")
local tickerRemote = makeRemote("Ticker")

remotes.Parent = ReplicatedStorage

-- ===== sessions ============================================================

local sessions = {}
local tvTicker = nil

local function computeRate(data, stats)
	local boostSum = 0
	for _, userIdStr in data.Equipped do
		local card = data.Cards[userIdStr]
		if card then
			boostSum += card.Boost
		end
	end
	return Config.Economy.BaseRate * (1 + boostSum) * stats.CoinMult
end

local function countUnique(cards)
	local count = 0
	for _ in cards do
		count += 1
	end
	return count
end

local function buildState(session, includeCards)
	local data = session.Data
	local state = {
		Coins = data.Coins,
		TotalEarned = data.TotalEarned,
		TotalRolls = data.TotalRolls,
		RollsBalance = data.RollsBalance,
		BackpackLevel = data.BackpackLevel,
		BackpackCapacity = Config.GetBackpackCapacity(data.BackpackLevel),
		BackpackCost = Config.GetBackpackCost(data.BackpackLevel),
		CardCount = countUnique(data.Cards),
		BestTier = data.BestTier,
		Upgrades = data.Upgrades,
		Equipped = data.Equipped,
		AutoOn = data.AutoOn,
		Stats = session.Stats,
		CoinsPerSec = computeRate(data, session.Stats),
	}
	if includeCards then
		state.Cards = data.Cards
	end
	return state
end

local function pushState(player, includeCards)
	local session = sessions[player]
	if not session then
		return
	end
	stateRemote:FireClient(player, buildState(session, includeCards))
	session.CoinsValue.Value = Format(session.Data.Coins)
	session.RollsValue.Value = session.Data.TotalRolls
end

local function announce(text)
	tickerRemote:FireAllClients(text)
	if tvTicker then
		tvTicker.Text = text
	end
end

-- ===== rolling =============================================================

-- Adds a rolled card to the collection. Dupes stack for free; a NEW unique
-- card when the backpack is full gets auto-sold for coins instead.
local function addCardToCollection(data, stats, card)
	local key = tostring(card.UserId)
	local owned = data.Cards[key]
	if owned then
		owned.Count += 1
		return { IsNew = false, Count = owned.Count }
	end
	if countUnique(data.Cards) >= Config.GetBackpackCapacity(data.BackpackLevel) then
		local tier = Config.TierByName[card.Tier]
		local soldFor = math.floor(tier.SellValue * stats.DupeMult)
		data.Coins += soldFor
		data.TotalEarned += soldFor
		return { IsNew = false, Count = 0, AutoSold = true, SoldFor = soldFor }
	end
	data.Cards[key] = {
		UserId = card.UserId,
		Name = card.Name,
		DisplayName = card.DisplayName,
		Tier = card.Tier,
		Boost = card.Boost,
		Traits = card.Traits,
		Flavor = card.Flavor,
		Count = 1,
	}
	return { IsNew = true, Count = 1 }
end

local function performRoll(player, isAuto)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.Data
	local stats = session.Stats

	local now = os.clock()
	if isAuto then
		if now < session.NextAutoAt then
			return
		end
		session.NextAutoAt = now + stats.AutoCooldown
	else
		if now < session.NextRollAt then
			return
		end
		session.NextRollAt = now + stats.RollCooldown
	end

	local count = stats.MultiRoll
	if isAuto and not stats.AutoMulti then
		count = 1
	end

	local results = {}
	for _ = 1, count do
		local card = CardPool.Draw(stats)
		local outcome = addCardToCollection(data, stats, card)
		data.TotalRolls += 1
		data.RollsBalance += 1

		local tier = Config.TierByName[card.Tier]
		if tier.Index > data.BestTier then
			data.BestTier = tier.Index
		end
		if tier.Index >= Config.TierByName.Legendary.Index then
			announce(("🎉 %s pulled %s %s!"):format(player.Name, card.Tier:upper(), card.DisplayName))
		end

		table.insert(results, {
			UserId = card.UserId,
			Name = card.Name,
			DisplayName = card.DisplayName,
			Tier = card.Tier,
			Boost = card.Boost,
			Traits = card.Traits,
			Flavor = card.Flavor,
			IsNew = outcome.IsNew,
			Count = outcome.Count,
			AutoSold = outcome.AutoSold,
			SoldFor = outcome.SoldFor,
		})
	end

	rollResultRemote:FireClient(player, { Cards = results, Auto = isAuto })
	-- don't resend the whole collection per roll (lag!) — the income loop
	-- flushes it within a second
	session.CardsDirty = true
	pushState(player, false)
end

-- ===== player lifecycle ====================================================

local function onPlayerAdded(player)
	local data, loadedSafely = DataManager.Load(player)
	if player.Parent ~= Players then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coinsValue = Instance.new("StringValue")
	coinsValue.Name = "Coins"
	coinsValue.Parent = leaderstats

	local rollsValue = Instance.new("IntValue")
	rollsValue.Name = "Rolls"
	rollsValue.Parent = leaderstats

	leaderstats.Parent = player

	local stats = Config.ComputeStats(data.Upgrades)
	local session = {
		Data = data,
		CanSave = loadedSafely,
		Stats = stats,
		NextRollAt = 0,
		NextAutoAt = 0,
		CardsDirty = false,
		CoinsValue = coinsValue,
		RollsValue = rollsValue,
	}
	sessions[player] = session

	-- offline earnings
	if stats.OfflineUnlocked and data.LastSeen > 0 then
		local away = math.min(os.time() - data.LastSeen, Config.Economy.OfflineCapHours * 3600)
		if away > 60 then
			local earned = math.floor(computeRate(data, stats) * away * Config.Economy.OfflineFraction)
			if earned > 0 then
				data.Coins += earned
				data.TotalEarned += earned
				task.delay(3, function()
					if sessions[player] then
						tickerRemote:FireClient(player, ("💤 You earned %s coins while away!"):format(Format(earned)))
					end
				end)
			end
		end
	end

	pushState(player, true)
	CardPool.CapturePlayer(player) -- their real account joins the card pool
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

local function saveSession(player, session)
	if not session.CanSave then
		return
	end
	DataManager.Save(player, session.Data)
	Leaderboard.Submit(player.UserId, session.Data.TotalEarned)
end

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	sessions[player] = nil
	if session then
		saveSession(player, session)
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		local session = sessions[player]
		sessions[player] = nil
		if session then
			saveSession(player, session)
		end
	end
end)

-- ===== remote handlers =====================================================

rollRemote.OnServerEvent:Connect(function(player)
	performRoll(player, false)
end)

local function onBuyUpgrade(player, nodeId)
	local session = sessions[player]
	if not session or type(nodeId) ~= "string" then
		return
	end
	local treeNode = Config.NodeById[nodeId]
	if not treeNode then
		return
	end

	local data = session.Data
	local level = data.Upgrades[nodeId] or 0
	if treeNode.MaxLevel and level >= treeNode.MaxLevel then
		return
	end
	if treeNode.Requires and (data.Upgrades[treeNode.Requires] or 0) < 1 then
		return
	end
	local cost = Config.GetNodeCost(treeNode, level)
	if data.Coins < cost then
		return
	end

	data.Coins -= cost
	data.Upgrades[nodeId] = level + 1
	session.Stats = Config.ComputeStats(data.Upgrades)
	pushState(player, false)
end

buyRemote.OnServerEvent:Connect(onBuyUpgrade)

equipRemote.OnServerEvent:Connect(function(player, userIdStr)
	local session = sessions[player]
	if not session or type(userIdStr) ~= "string" then
		return
	end
	local data = session.Data
	if not data.Cards[userIdStr] then
		return
	end
	if table.find(data.Equipped, userIdStr) then
		return
	end
	if #data.Equipped >= session.Stats.EquipSlots then
		return
	end
	table.insert(data.Equipped, userIdStr)
	pushState(player, false)
end)

unequipRemote.OnServerEvent:Connect(function(player, userIdStr)
	local session = sessions[player]
	if not session or type(userIdStr) ~= "string" then
		return
	end
	local index = table.find(session.Data.Equipped, userIdStr)
	if index then
		table.remove(session.Data.Equipped, index)
		pushState(player, false)
	end
end)

equipBestRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.Data
	local owned = {}
	for userIdStr, card in data.Cards do
		table.insert(owned, { Key = userIdStr, Boost = card.Boost })
	end
	table.sort(owned, function(a, b)
		return a.Boost > b.Boost
	end)
	data.Equipped = {}
	for i = 1, math.min(session.Stats.EquipSlots, #owned) do
		table.insert(data.Equipped, owned[i].Key)
	end
	pushState(player, false)
end)

local function sellDupesFor(data, stats, userIdStr)
	local card = data.Cards[userIdStr]
	if not card or card.Count <= 1 then
		return 0
	end
	local tier = Config.TierByName[card.Tier]
	local dupes = card.Count - 1
	card.Count = 1
	return math.floor(tier.SellValue * dupes * stats.DupeMult)
end

sellDupesRemote.OnServerEvent:Connect(function(player, target)
	local session = sessions[player]
	if not session or type(target) ~= "string" then
		return
	end
	local data = session.Data
	local earned = 0
	if target == "ALL" then
		for userIdStr in data.Cards do
			earned += sellDupesFor(data, session.Stats, userIdStr)
		end
	else
		earned = sellDupesFor(data, session.Stats, target)
	end
	if earned > 0 then
		data.Coins += earned
		data.TotalEarned += earned
		pushState(player, true)
	end
end)

toggleAutoRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end
	session.Data.AutoOn = not session.Data.AutoOn
	pushState(player, false)
end)

backpackRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.Data
	local cost = Config.GetBackpackCost(data.BackpackLevel)
	if data.RollsBalance < cost then
		return
	end
	data.RollsBalance -= cost
	data.BackpackLevel += 1
	pushState(player, false)
end)

-- ===== loops ===============================================================

-- coin income once per second; also flushes the collection to the client
-- if rolls changed it since the last tick (throttled to avoid lag)
task.spawn(function()
	while true do
		task.wait(1)
		for player, session in sessions do
			local earned = computeRate(session.Data, session.Stats)
			session.Data.Coins += earned
			session.Data.TotalEarned += earned
			local includeCards = session.CardsDirty
			session.CardsDirty = false
			pushState(player, includeCards)
		end
	end
end)

-- auto-roller heartbeat
task.spawn(function()
	while true do
		task.wait(0.25)
		for player, session in sessions do
			if session.Stats.AutoUnlocked and session.Data.AutoOn then
				task.spawn(performRoll, player, true)
			end
		end
	end
end)

-- autosave
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, player in Players:GetPlayers() do
			local session = sessions[player]
			if session then
				saveSession(player, session)
			end
		end
	end
end)

-- ===== world ===============================================================

tvTicker = TreeBuilder.Build(onBuyUpgrade)
Leaderboard.Start()

-- the card pool scans fastest when someone bought Fresh Scan upgrades
CardPool.Init(function()
	local best = Config.Roll.BaseFreshInterval
	for _, session in sessions do
		if session.Stats.FreshInterval < best then
			best = session.Stats.FreshInterval
		end
	end
	return best
end)

print(("[%s] server started"):format(Config.GameName))
