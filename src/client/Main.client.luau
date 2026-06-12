-- Click Empire — client entry point.
-- Wires the UI to the server remotes. No game logic lives here on purpose:
-- the server is the source of truth, the client just displays it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local clickRemote = remotes:WaitForChild("Click")
local buyRemote = remotes:WaitForChild("BuyUpgrade")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local stateRemote = remotes:WaitForChild("StateChanged")

-- Mirror the server's click rate limit so we don't waste network traffic
-- firing clicks the server would ignore anyway.
local windowStart = 0
local windowClicks = 0

local ui = UI.new({
	OnClick = function()
		local now = os.clock()
		if now - windowStart >= 1 then
			windowStart = now
			windowClicks = 0
		end
		if windowClicks >= Config.MaxClicksPerSecond then
			return
		end
		windowClicks += 1
		clickRemote:FireServer()
	end,
	OnBuy = function(upgradeId)
		buyRemote:FireServer(upgradeId)
	end,
	OnRebirth = function()
		rebirthRemote:FireServer()
	end,
})

stateRemote.OnClientEvent:Connect(function(state)
	ui:Update(state)
end)
