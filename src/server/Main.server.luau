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
local sellCardRemote = makeRemote("SellCard")
local setAutoSellRemote = makeRemote("SetAutoSell")
local toggleAutoRemote = makeRemote("ToggleAuto")
local backpackRemote = makeRemote("UpgradeBackpack")
local rebirthRemote = makeRemote("Rebirth")
local stateRemote = makeRemote("StateChanged")
local rollResultRemote = makeRemote("RollResult")
local tickerRemote = makeRemote("Ticker")
local devCheatRemote = makeRemote("DevCheat")

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

local function hasLegendaryPlus(data)
	local needed = Config.TierByName.Legendary.Index
	for _, card in data.Cards do
		local tier = Config.TierByName[card.Tier]
		if tier and tier.Index >= needed then
			return true
		end
	end
	return false
end

local function backpackCapacity(session)
	return Config.GetBackpackCapacity(session.Data.BackpackLevel) + session.Stats.BackpackBonus
end

local function buildState(session, includeCards)
	local data = session.Data
	local tokensIfNow = Config.GetRebirthTokens(data.Coins)
	local state = {
		Coins = data.Coins,
		TotalEarned = data.TotalEarned,
		TotalRolls = data.TotalRolls,
		RollsBalance = data.RollsBalance,
		BackpackLevel = data.BackpackLevel,
		BackpackCapacity = backpackCapacity(session),
		BackpackCost = Config.GetBackpackCost(data.BackpackLevel),
		CardCount = countUnique(data.Cards),
		AutoSell = data.AutoSell,
		BestTier = data.BestTier,
		Upgrades = data.Upgrades,
		RebirthUpgrades = data.RebirthUpgrades,
		Equipped = data.Equipped,
		AutoOn = data.AutoOn,
		AutomationUnlocked = data.AutomationUnlocked,
		Stats = session.Stats,
		CoinsPerSec = computeRate(data, session.Stats),
		Rebirths = data.Rebirths,
		RebirthTokens = data.RebirthTokens,
		Rebirth = {
			HasLegendary = hasLegendaryPlus(data),
			TokensIfNow = tokensIfNow,
			BonusTokens = session.Stats.BonusTokens,
			NextAt = Config.GetCoinsForTokens(tokensIfNow),
			KeepTier = if session.Stats.KeepLegendary then "Legendary" else Config.Rebirth.KeepTier,
		},
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

-- Adds a rolled card to the collection. Auto-sell settings convert the pull
-- straight to coins; dupes stack for free; a NEW unique card when the
-- backpack is full gets auto-sold too.
local function addCardToCollection(session, card)
	local data, stats = session.Data, session.Stats
	local tier = Config.TierByName[card.Tier]
	if data.AutoSell[card.Tier] then
		local soldFor = math.floor(tier.SellValue * stats.DupeMult)
		data.Coins += soldFor
		data.TotalEarned += soldFor
		return { IsNew = false, Count = 0, AutoSold = true, SoldFor = soldFor, Reason = "setting" }
	end
	local key = tostring(card.UserId)
	local owned = data.Cards[key]
	if owned then
		owned.Count += 1
		return { IsNew = false, Count = owned.Count }
	end
	if countUnique(data.Cards) >= backpackCapacity(session) then
		local soldFor = math.floor(tier.SellValue * stats.DupeMult)
		data.Coins += soldFor
		data.TotalEarned += soldFor
		return { IsNew = false, Count = 0, AutoSold = true, SoldFor = soldFor, Reason = "full" }
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
	-- new players shouldn't have to find the equip menu to start earning
	if #data.Equipped < stats.EquipSlots then
		table.insert(data.Equipped, key)
	end
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
	count *= stats.CardOutputMult -- golden tree card doubler/quadrupler

	local results = {}
	for _ = 1, count do
		data.TotalRolls += 1
		data.RollsBalance += 1
		-- Lucky Sevens: every 7th all-time roll comes from the rare pool
		local forcePool = stats.LuckySevens and data.TotalRolls % 7 == 0
		local card = CardPool.Draw(stats, forcePool)
		local outcome = addCardToCollection(session, card)

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
			Reason = outcome.Reason,
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

	local stats = Config.ComputeStats(data.Upgrades, data.RebirthUpgrades)
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
		local away = math.min(os.time() - data.LastSeen, stats.OfflineCapHours * 3600)
		if away > 60 then
			local earned = math.floor(computeRate(data, stats) * away * stats.OfflineFraction)
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
	-- golden tree nodes cost Rebirth Tokens; purple ones cost coins
	local levels = if treeNode.IsRebirth then data.RebirthUpgrades else data.Upgrades
	local level = levels[nodeId] or 0
	if treeNode.MaxLevel and level >= treeNode.MaxLevel then
		return
	end
	if treeNode.Requires and (levels[treeNode.Requires] or 0) < 1 then
		return
	end
	local cost = Config.GetNodeCost(treeNode, level)
	if treeNode.IsRebirth then
		if data.RebirthTokens < cost then
			return
		end
		data.RebirthTokens -= cost
	else
		if data.Coins < cost then
			return
		end
		data.Coins -= cost
	end

	levels[nodeId] = level + 1

	-- Handle special upgrade effects
	if nodeId == "automation" then
		data.AutomationUnlocked = true
	end

	session.Stats = Config.ComputeStats(data.Upgrades, data.RebirthUpgrades)
	pushState(player, false)
end

buyRemote.OnServerEvent:Connect(onBuyUpgrade)

-- dev cheat menu (only for Hemi286)
devCheatRemote.OnServerEvent:Connect(function(player, command, value)
	if player.UserId ~= 508290827 then
		return
	end
	local session = sessions[player]
	if not session then
		return
	end
	if command == "SetCoins" and type(value) == "number" then
		session.Data.Coins = math.floor(value)
		pushState(player, false)
	end
end)

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

-- sell a whole card (all copies), unequipping it if needed
sellCardRemote.OnServerEvent:Connect(function(player, key)
	local session = sessions[player]
	if not session or type(key) ~= "string" then
		return
	end
	local data = session.Data
	local card = data.Cards[key]
	if not card then
		return
	end
	local tier = Config.TierByName[card.Tier]
	local earned = math.floor(tier.SellValue * card.Count * session.Stats.DupeMult)
	data.Cards[key] = nil
	local equippedIndex = table.find(data.Equipped, key)
	if equippedIndex then
		table.remove(data.Equipped, equippedIndex)
	end
	data.Coins += earned
	data.TotalEarned += earned
	pushState(player, true)
end)

local AUTO_SELL_ALLOWED = { Common = true, Uncommon = true, Rare = true }

setAutoSellRemote.OnServerEvent:Connect(function(player, tierName, enabled)
	local session = sessions[player]
	if not session or type(tierName) ~= "string" or not AUTO_SELL_ALLOWED[tierName] then
		return
	end
	session.Data.AutoSell[tierName] = if enabled == true then true else nil
	pushState(player, false)
end)

toggleAutoRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end
	session.Data.AutoOn = not session.Data.AutoOn
	pushState(player, false)
end)

-- Rebirth: needs a Legendary+ card and enough coins for at least 1 token.
-- Wipes coins, the purple tree, and all cards below the keep tier
-- (Mythic, or Legendary with the Keeper upgrade). Tokens scale with coins.
rebirthRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.Data
	local tokens = Config.GetRebirthTokens(data.Coins)
	if tokens < 1 or not hasLegendaryPlus(data) then
		return
	end
	tokens += session.Stats.BonusTokens

	local keepIndex = if session.Stats.KeepLegendary
		then Config.TierByName.Legendary.Index
		else Config.TierByName[Config.Rebirth.KeepTier].Index

	for key, card in data.Cards do
		local tier = Config.TierByName[card.Tier]
		if not tier or tier.Index < keepIndex then
			data.Cards[key] = nil
		end
	end
	for index = #data.Equipped, 1, -1 do
		if not data.Cards[data.Equipped[index]] then
			table.remove(data.Equipped, index)
		end
	end

	data.Rebirths += 1
	data.RebirthTokens += tokens
	data.Upgrades = {}
	session.Stats = Config.ComputeStats(data.Upgrades, data.RebirthUpgrades)
	data.Coins = session.Stats.StartCoins

	announce(("🌟 %s rebirthed and earned %d token%s!"):format(player.Name, tokens, tokens == 1 and "" or "s"))
	pushState(player, true)
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

tvTicker = TreeBuilder.Build(onBuyUpgrade, function(player)
	local session = sessions[player]
	return if session then session.Data.Rebirths else 0
end, function(player)
	local session = sessions[player]
	return if session then session.Data.AutomationUnlocked else false
end)
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
