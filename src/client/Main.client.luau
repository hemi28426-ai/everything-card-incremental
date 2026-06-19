-- Everything Card Incremental — client entry point.
-- Wires the UI to the server remotes. No game logic lives here: the server
-- decides every roll, purchase, and coin; the client just displays them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local Cards = require(script.Parent:WaitForChild("Cards"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local rollRemote = remotes:WaitForChild("Roll")
local buyRemote = remotes:WaitForChild("BuyUpgrade")
local equipRemote = remotes:WaitForChild("Equip")
local unequipRemote = remotes:WaitForChild("Unequip")
local equipBestRemote = remotes:WaitForChild("EquipBest")
local sellDupesRemote = remotes:WaitForChild("SellDupes")
local sellCardRemote = remotes:WaitForChild("SellCard")
local setAutoSellRemote = remotes:WaitForChild("SetAutoSell")
local toggleAutoRemote = remotes:WaitForChild("ToggleAuto")
local backpackRemote = remotes:WaitForChild("UpgradeBackpack")
local buyRollSpeedRemote = remotes:WaitForChild("BuyRollSpeed")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local setAutoRebirthRemote = remotes:WaitForChild("SetAutoRebirth")
local collectionViewRemote = remotes:WaitForChild("CollectionView")
local unlockPackLoaderRemote = remotes:WaitForChild("UnlockPackLoader")
local equipPackRemote = remotes:WaitForChild("EquipPack")
local stateRemote = remotes:WaitForChild("StateChanged")
local rollResultRemote = remotes:WaitForChild("RollResult")
local tickerRemote = remotes:WaitForChild("Ticker")
local devCheatRemote = remotes:WaitForChild("DevCheat")

local lastRollAt = 0
local latestState = nil

local ui
ui = UI.new({
	OnRoll = function()
		-- mirror the server cooldown so we don't spam remotes it would reject
		local cooldown = latestState and latestState.Stats.RollCooldown or 3
		if os.clock() - lastRollAt < cooldown then
			return
		end
		lastRollAt = os.clock()
		rollRemote:FireServer()
		ui:StartCooldown(cooldown)
	end,
	OnBuy = function(nodeId)
		buyRemote:FireServer(nodeId)
	end,
	OnEquip = function(key)
		equipRemote:FireServer(key)
	end,
	OnUnequip = function(key)
		unequipRemote:FireServer(key)
	end,
	OnEquipBest = function()
		equipBestRemote:FireServer()
	end,
	OnSellDupes = function(target)
		sellDupesRemote:FireServer(target)
	end,
	OnSellCard = function(key)
		sellCardRemote:FireServer(key)
	end,
	OnSetAutoSell = function(tierName, enabled)
		setAutoSellRemote:FireServer(tierName, enabled)
	end,
	OnToggleAuto = function()
		toggleAutoRemote:FireServer()
	end,
	OnUpgradeBackpack = function()
		backpackRemote:FireServer()
	end,
	OnBuyRollSpeed = function()
		buyRollSpeedRemote:FireServer()
	end,
	OnPromptFastAuto = function()
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, Config.Gamepass.FastAuto)
		end)
	end,
	OnRebirth = function()
		rebirthRemote:FireServer()
	end,
	OnSetAutoRebirth = function(enabled, tokens)
		setAutoRebirthRemote:FireServer(enabled, tokens)
	end,
	OnCollectionView = function(open)
		collectionViewRemote:FireServer(open)
	end,
	OnUnlockPackLoader = function()
		unlockPackLoaderRemote:FireServer()
	end,
	OnEquipPack = function(packId)
		equipPackRemote:FireServer(packId)
	end,
	DevCheat = function(command, value)
		devCheatRemote:FireServer(command, value)
	end,
})

local cards = Cards.new(ui.ScreenGui)

stateRemote.OnClientEvent:Connect(function(state)
	latestState = state
	ui:Update(state)
end)

rollResultRemote.OnClientEvent:Connect(function(payload)
	cards:ShowRollResult(payload)
	-- show the pulled card on the TV (the best one of the result)
	if payload.Cards and #payload.Cards > 0 then
		local best = payload.Cards[1]
		ui:ShowTVCard(best)
	end
end)

tickerRemote.OnClientEvent:Connect(function(text)
	ui:ShowTicker(text)
end)
