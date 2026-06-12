-- Everything Card Incremental — client entry point.
-- Wires the UI to the server remotes. No game logic lives here: the server
-- decides every roll, purchase, and coin; the client just displays them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local stateRemote = remotes:WaitForChild("StateChanged")
local rollResultRemote = remotes:WaitForChild("RollResult")
local tickerRemote = remotes:WaitForChild("Ticker")

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
})

local cards = Cards.new(ui.ScreenGui)

stateRemote.OnClientEvent:Connect(function(state)
	latestState = state
	ui:Update(state)
end)

rollResultRemote.OnClientEvent:Connect(function(payload)
	cards:ShowRollResult(payload)
end)

tickerRemote.OnClientEvent:Connect(function(text)
	ui:ShowTicker(text)
end)
