-- Everything Card Incremental — server entry point.
-- Owns all real state: rolls, the collection, coins, upgrades. The client
-- only asks; everything is validated here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataManager = require(script.Parent:WaitForChild("DataManager"))
local CardPool = require(script.Parent:WaitForChild("CardPool"))
local TreeBuilder = require(script.Parent:WaitForChild("TreeBuilder"))
local Leaderboard = require(script.Parent:WaitForChild("Leaderboard"))
local Backrooms = require(script.Parent:WaitForChild("Backrooms"))

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
local buyRollSpeedRemote = makeRemote("BuyRollSpeed")
local rebirthRemote = makeRemote("Rebirth")
local setAutoRebirthRemote = makeRemote("SetAutoRebirth")
local collectionViewRemote = makeRemote("CollectionView")
local equipPackRemote = makeRemote("EquipPack")
local stateRemote = makeRemote("StateChanged")
local rollResultRemote = makeRemote("RollResult")
local tickerRemote = makeRemote("Ticker")
local devCheatRemote = makeRemote("DevCheat")

remotes.Parent = ReplicatedStorage

-- ===== sessions ============================================================

local sessions = {}
local tvTicker = nil
local applyCharacterEffects -- forward-declared; defined with the shop handlers below

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

-- Cached count of unique cards, so we don't re-scan the whole collection on
-- every single card added (that O(n)-per-roll cost is a big source of the
-- "lag grows as my collection gets huge" problem). Kept in sync by the few
-- places that add/remove cards.
local function uniqueCount(session)
	if not session.UniqueCount then
		session.UniqueCount = countUnique(session.Data.Cards)
	end
	return session.UniqueCount
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

-- ===== card-pack requirements ==============================================

-- total copies of a given tier the player owns
local function tierCardCount(data, tierName)
	local n = 0
	for _, card in data.Cards do
		if card.Tier == tierName then
			n += card.Count
		end
	end
	return n
end

local function allAutomationOwned(data)
	for _, treeNode in Config.AutomationTree do
		if (data.RebirthUpgrades[treeNode.Id] or 0) < 1 then
			return false
		end
	end
	return true
end

-- every upgrade in the game bought at least once (all three trees + all shop items)
local function allUpgradesOwned(data)
	for _, treeNode in Config.NodeById do
		local levels = if treeNode.IsRebirth then data.RebirthUpgrades else data.Upgrades
		if (levels[treeNode.Id] or 0) < 1 then
			return false
		end
	end
	for _, item in Config.Shop do
		if (data.ShopUpgrades[item.Id] or 0) < 1 then
			return false
		end
	end
	return true
end

-- mark a pack owned (from buying its tree node / shop item / the free button) and
-- auto-equip it if nothing is equipped yet
local function unlockPack(data, packId)
	if not packId or not Config.PackById[packId] then
		return
	end
	data.UnlockedPacks[packId] = true
	if data.EquippedPack == false or data.EquippedPack == nil then
		data.EquippedPack = packId
	end
end

-- remove `count` copies of a tier from the collection (used to "spend" cards on
-- a pack button). Unequips any card that hits zero copies.
local function consumeTierCards(session, tierName, count)
	local data = session.Data
	local remaining = count
	for key, card in data.Cards do
		if remaining <= 0 then
			break
		end
		if card.Tier == tierName then
			local take = math.min(card.Count, remaining)
			card.Count -= take
			remaining -= take
			if card.Count <= 0 then
				data.Cards[key] = nil
				local i = table.find(data.Equipped, key)
				if i then
					table.remove(data.Equipped, i)
				end
			end
		end
	end
	session.UniqueCount = nil -- force a recount next time it's needed
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
		CardCount = uniqueCount(session),
		AutoSell = data.AutoSell,
		BestTier = data.BestTier,
		Upgrades = data.Upgrades,
		RebirthUpgrades = data.RebirthUpgrades,
		Equipped = data.Equipped,
		AutoOn = data.AutoOn,
		AutomationUnlocked = data.AutomationUnlocked,
		AutoRebirthOn = data.AutoRebirthOn,
		AutoRebirthTokens = data.AutoRebirthTokens,
		RollSpeedLevel = data.RollSpeedLevel,
		RollSpeedCost = Config.GetRollSpeedCost(data.RollSpeedLevel),
		Bridges = data.Bridges,
		ShopUpgrades = data.ShopUpgrades,
		PackLoaderUnlocked = data.PackLoaderUnlocked == true,
		UnlockedPacks = data.UnlockedPacks,
		EquippedPack = data.EquippedPack,
		RareCardCount = tierCardCount(data, "Rare"),
		DivineCardCount = tierCardCount(data, "Divine"),
		HasKey = data.HasKey == true,
		HasFastAuto = session.HasFastAuto == true,
		AutoInterval = if session.HasFastAuto then Config.Roll.AutoIntervalFast else Config.Roll.AutoInterval,
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
	-- The full card collection can be huge and only matters when the player is
	-- actually looking at the collection panel, so we only ship it then.
	-- Replicating hundreds of cards every second is the main "lag grows over
	-- time" culprit.
	stateRemote:FireClient(player, buildState(session, includeCards and session.WantsCards == true))
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
local function addCardToCollection(session, card, forceKeep)
	local data, stats = session.Data, session.Stats
	local tier = Config.TierByName[card.Tier]
	if data.AutoSell[card.Tier] and not forceKeep then
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
	if uniqueCount(session) >= backpackCapacity(session) then
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
	session.UniqueCount = uniqueCount(session) + 1
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
		-- normal auto-roll fires every 3s. With the FAST AUTO gamepass it instead
		-- fires at YOUR manual roll speed (so roll-speed upgrades also speed up
		-- your auto). No separate auto-speed upgrades exist.
		local interval = if session.HasFastAuto
			then stats.RollCooldown
			else Config.Roll.AutoInterval * stats.AutoSpeedMult
		session.NextAutoAt = now + interval
	else
		if now < session.NextRollAt then
			return
		end
		session.NextRollAt = now + stats.RollCooldown
	end

	-- one card per roll, always
	local count = 1

	local results = {}
	local announceThreshold = Config.TierByName.Mythic.Index
	for index = 1, count do
		-- Lucky Sevens: every 7th all-time roll is forced to at least Rare
		local forcePool = stats.LuckySevens and (data.TotalRolls + 1) % 7 == 0
		-- only the first card of a roll may block on a fresh scan; the rest take
		-- from the buffer so a huge multi-roll never stalls the server
		local card = CardPool.Draw(stats, forcePool, index == 1)
		if not card then
			-- no real account available right now — never fabricate one. Stop here
			-- and (if we got nothing at all) tell the client we're still scanning.
			break
		end
		data.TotalRolls += 1
		data.RollsBalance += 1
		local outcome = addCardToCollection(session, card)

		local tier = Config.TierByName[card.Tier]
		if tier.Index > data.BestTier then
			data.BestTier = tier.Index
		end
		-- only announce the genuinely rare pulls server-wide (Legendary is common
		-- with luck, so announcing every one would spam every client)
		if tier.Index >= announceThreshold then
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
			TierIndex = tier.Index,
		})
	end

	if #results == 0 then
		-- couldn't fetch any real account this instant; let the player know
		-- instead of handing them a fake card
		rollResultRemote:FireClient(player, { Cards = {}, Total = 0, Auto = isAuto, Scanning = true })
		pushState(player, false)
		return
	end

	-- Only send the rarest few cards to the client (it shows ~5 + "more"
	-- anyway). Sending all of a 40-card multi-roll every pull is pure lag.
	local total = #results
	if total > 12 then
		table.sort(results, function(a, b)
			return a.TierIndex > b.TierIndex
		end)
		for i = total, 13, -1 do
			results[i] = nil
		end
	end
	rollResultRemote:FireClient(player, { Cards = results, Total = total, Auto = isAuto })
	-- don't resend the whole collection per roll (lag!) — the income loop
	-- flushes it within a second, and only if the player's looking at it
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

	local stats = Config.ComputeStats(data)
	local session = {
		Data = data,
		CanSave = loadedSafely,
		Stats = stats,
		NextRollAt = 0,
		NextAutoAt = 0,
		CardsDirty = false,
		HasFastAuto = false,
		CoinsValue = coinsValue,
		RollsValue = rollsValue,
	}
	sessions[player] = session

	-- shop speed effects (walk speed flask, speed coil) on every spawn
	player.CharacterAdded:Connect(function()
		task.wait(0.2) -- let the Humanoid exist
		if sessions[player] then
			applyCharacterEffects(player, session)
		end
	end)
	if player.Character then
		applyCharacterEffects(player, session)
	end

	-- does this player own the FAST AUTO gamepass?
	task.spawn(function()
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.Gamepass.FastAuto)
		end)
		if ok and owns and sessions[player] then
			session.HasFastAuto = true
			pushState(player, false)
		end
	end)

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
	-- pack-unlock nodes are owned forever (the hub one resets on rebirth, so this
	-- stops you re-buying / re-spending Rares for a pack you already have)
	if treeNode.UnlocksPack and data.UnlockedPacks[treeNode.UnlocksPack] then
		return
	end
	if treeNode.Requires and (levels[treeNode.Requires] or 0) < 1 then
		return
	end
	if treeNode.IsAutomation and not data.AutomationUnlocked then
		return -- must buy Automation at the Card Opener first
	end
	-- extra gates for pack-unlock nodes
	if treeNode.RequireAllAutomation and not allAutomationOwned(data) then
		return
	end
	if treeNode.SpendRares and tierCardCount(data, "Rare") < treeNode.SpendRares then
		return -- need the Rare cards to spend
	end
	local cost = Config.ApplyPrice(Config.GetNodeCost(treeNode, level), session.Stats)
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

	-- Buying the Automaton Core (root of the green tree) unlocks auto-roll.
	if nodeId == "autocore" then
		data.AutomationUnlocked = true
	end
	-- pack-unlock nodes: spend the cards, grant the pack (+ the loader for Basic)
	if treeNode.SpendRares then
		consumeTierCards(session, "Rare", treeNode.SpendRares)
		session.CardsDirty = true
	end
	if treeNode.GrantsLoader then
		data.PackLoaderUnlocked = true
	end
	if treeNode.UnlocksPack then
		unlockPack(data, treeNode.UnlocksPack)
		announce(("📦 %s unlocked the %s!"):format(player.Name, Config.PackById[treeNode.UnlocksPack].Name))
	end

	session.Stats = Config.ComputeStats(data)
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
	elseif command == "SetTokens" and type(value) == "number" then
		session.Data.RebirthTokens = math.floor(value)
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

-- Equip the highest-boost cards into every available slot. Returns true if the
-- equipped set actually changed (so automation can avoid needless state pushes).
local function equipBest(session)
	local data = session.Data
	local owned = {}
	for userIdStr, card in data.Cards do
		table.insert(owned, { Key = userIdStr, Boost = card.Boost })
	end
	table.sort(owned, function(a, b)
		return a.Boost > b.Boost
	end)
	local newEquipped = {}
	for i = 1, math.min(session.Stats.EquipSlots, #owned) do
		table.insert(newEquipped, owned[i].Key)
	end
	local changed = #newEquipped ~= #data.Equipped
	if not changed then
		for i, key in newEquipped do
			if data.Equipped[i] ~= key then
				changed = true
				break
			end
		end
	end
	data.Equipped = newEquipped
	return changed
end

equipBestRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end
	equipBest(session)
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

-- Sell every duplicate the player owns; returns coins earned.
local function sellAllDupes(session)
	local data = session.Data
	local earned = 0
	for userIdStr in data.Cards do
		earned += sellDupesFor(data, session.Stats, userIdStr)
	end
	if earned > 0 then
		data.Coins += earned
		data.TotalEarned += earned
	end
	return earned
end

sellDupesRemote.OnServerEvent:Connect(function(player, target)
	local session = sessions[player]
	if not session or type(target) ~= "string" then
		return
	end
	local data = session.Data
	local earned = 0
	if target == "ALL" then
		earned = sellAllDupes(session)
	else
		earned = sellDupesFor(data, session.Stats, target)
		if earned > 0 then
			data.Coins += earned
			data.TotalEarned += earned
		end
	end
	if earned > 0 then
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
	session.UniqueCount = uniqueCount(session) - 1
	local equippedIndex = table.find(data.Equipped, key)
	if equippedIndex then
		table.remove(data.Equipped, equippedIndex)
	end
	data.Coins += earned
	data.TotalEarned += earned
	pushState(player, true)
end)

setAutoSellRemote.OnServerEvent:Connect(function(player, tierName, enabled)
	local session = sessions[player]
	-- any real tier can be auto-sold (skipped) now, even the top ones
	if not session or type(tierName) ~= "string" or not Config.TierByName[tierName] then
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

-- Client tells us when the collection panel is open. We only replicate the full
-- card collection while it's open (and push it once immediately on open).
collectionViewRemote.OnServerEvent:Connect(function(player, open)
	local session = sessions[player]
	if not session then
		return
	end
	session.WantsCards = open == true
	if session.WantsCards then
		pushState(player, true)
	end
end)

-- Grant a random pack the player doesn't own yet (the Backrooms free button).
local function grantRandomPack(player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.Data
	local missing = {}
	for _, pack in Config.Packs do
		if not data.UnlockedPacks[pack.Id] then
			table.insert(missing, pack.Id)
		end
	end
	if #missing == 0 then
		tickerRemote:FireClient(player, "🎁 You already own every Card Pack!")
		return
	end
	local id = missing[math.random(1, #missing)]
	data.PackLoaderUnlocked = true -- the free find also lets you equip
	unlockPack(data, id)
	session.Stats = Config.ComputeStats(data)
	tickerRemote:FireClient(player, ("🎁 Free Card Pack: %s!"):format(Config.PackById[id].Name))
	pushState(player, false)
end

-- Buy the Backrooms Key in the shop (costs a lot of tokens AND coins).
local function onBuyKey(player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.Data
	if data.HasKey then
		return
	end
	local tokenCost = Config.ApplyPrice(Config.Key.Tokens, session.Stats)
	local coinCost = Config.ApplyPrice(Config.Key.Coins, session.Stats)
	if data.RebirthTokens < tokenCost or data.Coins < coinCost then
		return
	end
	data.RebirthTokens -= tokenCost
	data.Coins -= coinCost
	data.HasKey = true
	tickerRemote:FireClient(player, "🗝️ You bought the Backrooms Key! Use the door behind the cashier.")
	pushState(player, false)
end

-- The door behind the cashier: needs the Key, then teleports you into Level 0.
local function onEnterBackrooms(player)
	local session = sessions[player]
	if not session then
		return
	end
	if not session.Data.HasKey then
		tickerRemote:FireClient(player, "🔒 The door is locked. Buy the Backrooms Key in the shop.")
		return
	end
	Backrooms.Enter(player)
end

-- Equip one card pack (or "" / false to unequip). Only owned packs allowed.
equipPackRemote.OnServerEvent:Connect(function(player, packId)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.Data
	if not data.PackLoaderUnlocked then
		return
	end
	if packId == false or packId == "" or packId == nil then
		data.EquippedPack = false
	elseif type(packId) == "string" and Config.PackById[packId] and data.UnlockedPacks[packId] then
		-- toggle off if re-equipping the same one
		data.EquippedPack = if data.EquippedPack == packId then false else packId
	else
		return
	end
	session.Stats = Config.ComputeStats(data)
	pushState(player, false)
end)

-- Player configures auto-rebirth: whether it's on, and the token threshold it
-- waits for before firing. The threshold does NOT escalate — it fires every
-- time you bank that many tokens' worth of coins.
setAutoRebirthRemote.OnServerEvent:Connect(function(player, enabled, tokens)
	local session = sessions[player]
	if not session then
		return
	end
	session.Data.AutoRebirthOn = enabled == true
	if type(tokens) == "number" and tokens == tokens then -- reject NaN
		session.Data.AutoRebirthTokens = math.clamp(math.floor(tokens), 1, 1_000_000)
	end
	pushState(player, false)
end)

-- Rebirth: needs a Legendary+ card and enough coins for at least 1 token.
-- Wipes coins, the purple tree, and all cards below the keep tier
-- (Mythic, or Legendary with the Keeper upgrade). Tokens scale with coins.
-- Returns the number of tokens earned (0 if the rebirth wasn't allowed).
local function doRebirth(player, session)
	local data = session.Data
	local tokens = Config.GetRebirthTokens(data.Coins)
	if tokens < 1 or not hasLegendaryPlus(data) then
		return 0
	end
	tokens += session.Stats.BonusTokens
	tokens = math.floor(tokens * session.Stats.TokenMult) -- Rebirth pack boosts this

	local keepIndex = if session.Stats.KeepLegendary
		then Config.TierByName.Legendary.Index
		else Config.TierByName[Config.Rebirth.KeepTier].Index

	for key, card in data.Cards do
		local tier = Config.TierByName[card.Tier]
		if not tier or tier.Index < keepIndex then
			data.Cards[key] = nil
		end
	end
	session.UniqueCount = countUnique(data.Cards)
	for index = #data.Equipped, 1, -1 do
		if not data.Cards[data.Equipped[index]] then
			table.remove(data.Equipped, index)
		end
	end

	data.Rebirths += 1
	data.RebirthTokens += tokens
	data.Upgrades = {}
	session.Stats = Config.ComputeStats(data)
	data.Coins = session.Stats.StartCoins

	announce(("🌟 %s rebirthed and earned %d token%s!"):format(player.Name, tokens, tokens == 1 and "" or "s"))
	return tokens
end

rebirthRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end
	if doRebirth(player, session) > 0 then
		pushState(player, true)
	end
end)

-- Buy one backpack expansion (paid in rolls). Returns true on success.
local function buyBackpack(session)
	local data = session.Data
	local cost = Config.GetBackpackCost(data.BackpackLevel)
	if data.RollsBalance < cost then
		return false
	end
	data.RollsBalance -= cost
	data.BackpackLevel += 1
	return true
end

backpackRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end
	if buyBackpack(session) then
		pushState(player, false)
	end
end)

-- Buy one manual roll-speed level (paid in coins) right on the TV.
buyRollSpeedRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.Data
	-- the level cap (20) is raised by RAM sticks and rebirth speed nodes
	if data.RollSpeedLevel >= session.Stats.MaxRollSpeedLevel then
		return
	end
	local cost = Config.ApplyPrice(Config.GetRollSpeedCost(data.RollSpeedLevel), session.Stats)
	if data.Coins < cost then
		return
	end
	data.Coins -= cost
	data.RollSpeedLevel += 1
	session.Stats = Config.ComputeStats(data)
	pushState(player, false)
end)

-- Flip on FAST AUTO the moment the gamepass is bought.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if wasPurchased and gamePassId == Config.Gamepass.FastAuto then
		local session = sessions[player]
		if session then
			session.HasFastAuto = true
			pushState(player, false)
		end
	end
end)

-- Build the next part of a bridge (paid in coins, via the bridge prompt). Buys
-- as many parts as you can afford at once so you're not spamming it 50 times.
local function onBuyBridge(player, which)
	local session = sessions[player]
	local conf = type(which) == "string" and Config.Bridges[which]
	if not session or not conf then
		return
	end
	local data = session.Data
	local built = data.Bridges[which] or 0
	local bought = false
	while built < conf.Parts do
		local cost = Config.ApplyPrice(Config.GetBridgeCost(which, built), session.Stats)
		if data.Coins < cost then
			break
		end
		data.Coins -= cost
		built += 1
		bought = true
	end
	if bought then
		data.Bridges[which] = built
		pushState(player, false)
	end
end

-- Give the player the Speed Coil tool (cloned from the template TreeBuilder
-- stashes in ServerStorage). Goes to both the Backpack and StarterGear so it
-- survives respawns.
local function grantSpeedCoil(player)
	local template = ServerStorage:FindFirstChild("SpeedCoilTemplate")
	if not template then
		return
	end
	local function ensureIn(container)
		if container and not container:FindFirstChild(template.Name) then
			template:Clone().Parent = container
		end
	end
	ensureIn(player:FindFirstChildOfClass("StarterGear"))
	ensureIn(player:FindFirstChildOfClass("Backpack"))
end

-- Apply per-character effects from the shop: the speed flask scales walk speed,
-- and the speed coil is (re)granted. Safe to call whenever stats change or a
-- character spawns.
function applyCharacterEffects(player, session)
	local stats = session.Stats
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = Config.Economy.BaseWalkSpeed * stats.WalkSpeedMult
		end
	end
	if stats.HasSpeedCoil then
		grantSpeedCoil(player)
	end
end

-- Buy a shop item (paid in coins, via a proximity prompt on the physical item).
-- Most items are stat unlocks; the Lucky Block instead grants a card on the spot.
local function onBuyShop(player, itemId)
	local session = sessions[player]
	local item = type(itemId) == "string" and Config.ShopById[itemId]
	if not session or not item then
		return
	end
	local data = session.Data
	local level = data.ShopUpgrades[itemId] or 0
	if item.MaxLevel and level >= item.MaxLevel then
		return
	end
	local cost = Config.ApplyPrice(Config.GetShopCost(item, level), session.Stats)
	if data.Coins < cost then
		return
	end
	-- the Ultimate Pack item also costs tokens + a Divine card
	local tokenCost = item.TokenCost and Config.ApplyPrice(item.TokenCost, session.Stats) or 0
	if data.RebirthTokens < tokenCost then
		return
	end
	if item.DivineCards and tierCardCount(data, "Divine") < item.DivineCards then
		return
	end

	if itemId == "luckyblock" then
		-- a guaranteed Mythic+ card with bonus value, straight into the collection
		local lb = Config.LuckyBlock
		local card = CardPool.DrawGuaranteed(lb.MinTier, lb.MaxTier, lb.ValueMult)
		if not card then
			tickerRemote:FireClient(player, "🎁 Lucky Block fizzled — still scanning accounts, try again!")
			return
		end
		data.Coins -= cost
		data.ShopUpgrades[itemId] = level + 1
		local outcome = addCardToCollection(session, card, true) -- keep it, never auto-sell
		local tier = Config.TierByName[card.Tier]
		if tier and tier.Index > data.BestTier then
			data.BestTier = tier.Index
		end
		announce(("🎁 %s opened a Lucky Block: %s %s!"):format(player.Name, card.Tier:upper(), card.DisplayName))
		rollResultRemote:FireClient(player, { Cards = { {
			UserId = card.UserId, Name = card.Name, DisplayName = card.DisplayName,
			Tier = card.Tier, Boost = card.Boost, Traits = card.Traits, Flavor = card.Flavor,
			IsNew = outcome.IsNew, Count = outcome.Count, AutoSold = outcome.AutoSold,
			SoldFor = outcome.SoldFor, Reason = outcome.Reason, TierIndex = tier and tier.Index or 0,
		} }, Total = 1, Auto = false })
		session.CardsDirty = true
		pushState(player, false)
		return
	end

	data.Coins -= cost
	data.RebirthTokens -= tokenCost
	if item.DivineCards then
		consumeTierCards(session, "Divine", item.DivineCards)
		session.CardsDirty = true
	end
	data.ShopUpgrades[itemId] = level + 1
	if item.UnlocksPack then
		unlockPack(data, item.UnlocksPack)
		announce(("📦 %s unlocked the %s!"):format(player.Name, Config.PackById[item.UnlocksPack].Name))
	end
	session.Stats = Config.ComputeStats(data)
	applyCharacterEffects(player, session)
	pushState(player, false)
end

-- ===== automation island (auto-equip / auto-sell / auto-rebirth) ==========

-- Run one automation pass for a player. Returns true if anything changed.
local function runAutomation(player, session)
	local stats = session.Stats
	if not stats.AutoCore then
		return false
	end
	local data = session.Data
	local changed = false

	if stats.AutoRebirthUnlocked and data.AutoRebirthOn then
		local threshold = math.max(1, data.AutoRebirthTokens or 10)
		if Config.GetRebirthTokens(data.Coins) >= threshold and hasLegendaryPlus(data) then
			if doRebirth(player, session) > 0 then
				session.Stats = Config.ComputeStats(data)
				return true
			end
		end
	end

	if stats.AutoSellUnlocked and sellAllDupes(session) > 0 then
		changed = true
	end
	-- Smart Seller: actively liquidate any OWNED cards whose tier you've toggled
	-- to auto-sell (not just dupes), unequipping them first.
	if stats.SmartSellUnlocked then
		local earned = 0
		for key, card in data.Cards do
			if data.AutoSell[card.Tier] then
				local tier = Config.TierByName[card.Tier]
				earned += math.floor(tier.SellValue * card.Count * stats.DupeMult)
				data.Cards[key] = nil
				local eqi = table.find(data.Equipped, key)
				if eqi then
					table.remove(data.Equipped, eqi)
				end
			end
		end
		if earned > 0 then
			session.UniqueCount = countUnique(data.Cards)
			data.Coins += earned
			data.TotalEarned += earned
			changed = true
		end
	end
	if stats.AutoEquipUnlocked and equipBest(session) then
		changed = true
	end

	-- Automation pack: auto-buy roll-speed levels whenever you can afford them
	if stats.AutoBuySpeed then
		local bought = false
		while data.RollSpeedLevel < stats.MaxRollSpeedLevel do
			local cost = Config.ApplyPrice(Config.GetRollSpeedCost(data.RollSpeedLevel), stats)
			if data.Coins < cost then
				break
			end
			data.Coins -= cost
			data.RollSpeedLevel += 1
			bought = true
		end
		if bought then
			session.Stats = Config.ComputeStats(data)
			changed = true
		end
	end

	return changed
end

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

-- auto-roller heartbeat (TV auto-roll). Available from the start via the AutoOn
-- toggle; performRoll itself enforces the 3s / gamepass-fast interval.
task.spawn(function()
	while true do
		task.wait(0.2)
		for player, session in sessions do
			if session.Data.AutoOn and session.Data.AutomationUnlocked then
				task.spawn(performRoll, player, true)
			end
		end
	end
end)

-- automation island heartbeat (auto-equip / auto-sell / auto-rebirth), 1s pace
task.spawn(function()
	while true do
		task.wait(1)
		for player, session in sessions do
			if session.Stats.AutoCore then
				if runAutomation(player, session) then
					session.CardsDirty = true
					pushState(player, false)
				end
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

TreeBuilder.Build(onBuyUpgrade, onBuyBridge, onBuyShop, onBuyKey, onEnterBackrooms)
Leaderboard.Start()

-- Backrooms (Level 0): a far-off maze you reach with the Key + the shop door
Backrooms.Init({
	OnFreePack = grantRandomPack,
	GetHomeCFrame = function()
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
		if spawn then
			return spawn.CFrame * CFrame.new(0, 4, 0)
		end
		return CFrame.new(0, 6, -56)
	end,
})

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
