-- Click Empire — server entry point.
-- Owns all the real game state. The client only *asks* to click/buy/rebirth;
-- everything is validated here so exploiters can't give themselves cash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataManager = require(script.Parent:WaitForChild("DataManager"))
local Leaderboard = require(script.Parent:WaitForChild("Leaderboard"))

-- Remotes the client talks to us through
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local clickRemote = Instance.new("RemoteEvent")
clickRemote.Name = "Click"
clickRemote.Parent = remotes

local buyRemote = Instance.new("RemoteEvent")
buyRemote.Name = "BuyUpgrade"
buyRemote.Parent = remotes

local rebirthRemote = Instance.new("RemoteEvent")
rebirthRemote.Name = "Rebirth"
rebirthRemote.Parent = remotes

local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "StateChanged"
stateRemote.Parent = remotes

remotes.Parent = ReplicatedStorage

-- One session entry per connected player
local sessions = {}

local function buildState(data)
	return {
		Cash = data.Cash,
		TotalEarned = data.TotalEarned,
		TotalClicks = data.TotalClicks,
		Rebirths = data.Rebirths,
		Upgrades = data.Upgrades,
		ClickPower = Config.GetClickPower(data.Upgrades, data.Rebirths),
		AutoPower = Config.GetAutoPower(data.Upgrades, data.Rebirths),
		Multiplier = Config.GetMultiplier(data.Rebirths),
		RebirthCost = Config.GetRebirthCost(data.Rebirths),
		NextMultiplier = Config.GetMultiplier(data.Rebirths + 1),
	}
end

local function pushState(player)
	local session = sessions[player]
	if not session then
		return
	end
	stateRemote:FireClient(player, buildState(session.Data))
	session.CashValue.Value = "$" .. Format(session.Data.Cash)
	session.RebirthsValue.Value = session.Data.Rebirths
end

local function onPlayerAdded(player)
	local data, loadedSafely = DataManager.Load(player)
	if player.Parent ~= Players then
		return -- they left while their data was loading
	end

	-- leaderstats = the built-in player list on the right of the screen
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cashValue = Instance.new("StringValue")
	cashValue.Name = "Cash"
	cashValue.Parent = leaderstats

	local rebirthsValue = Instance.new("IntValue")
	rebirthsValue.Name = "Rebirths"
	rebirthsValue.Parent = leaderstats

	leaderstats.Parent = player

	sessions[player] = {
		Data = data,
		CanSave = loadedSafely,
		WindowStart = 0,
		WindowClicks = 0,
		CashValue = cashValue,
		RebirthsValue = rebirthsValue,
	}
	pushState(player)
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

-- A click: rate-limited per player, then awarded server-side
clickRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end

	local now = os.clock()
	if now - session.WindowStart >= 1 then
		session.WindowStart = now
		session.WindowClicks = 0
	end
	if session.WindowClicks >= Config.MaxClicksPerSecond then
		return
	end
	session.WindowClicks += 1

	local data = session.Data
	local power = Config.GetClickPower(data.Upgrades, data.Rebirths)
	data.Cash += power
	data.TotalEarned += power
	data.TotalClicks += 1
	pushState(player)
end)

buyRemote.OnServerEvent:Connect(function(player, upgradeId)
	local session = sessions[player]
	if not session or type(upgradeId) ~= "string" then
		return
	end
	local upgrade = Config.UpgradeById[upgradeId]
	if not upgrade then
		return
	end

	local data = session.Data
	local owned = data.Upgrades[upgradeId] or 0
	local cost = Config.GetUpgradeCost(upgrade, owned)
	if data.Cash < cost then
		return
	end

	data.Cash -= cost
	data.Upgrades[upgradeId] = owned + 1
	pushState(player)
end)

rebirthRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end

	local data = session.Data
	if data.Cash < Config.GetRebirthCost(data.Rebirths) then
		return
	end

	data.Rebirths += 1
	data.Cash = 0
	data.Upgrades = {}
	pushState(player)
end)

-- Passive income from "auto" upgrades, once per second
task.spawn(function()
	while true do
		task.wait(1)
		for player, session in sessions do
			local data = session.Data
			local auto = Config.GetAutoPower(data.Upgrades, data.Rebirths)
			if auto > 0 then
				data.Cash += auto
				data.TotalEarned += auto
			end
			pushState(player)
		end
	end
end)

-- Autosave so a server crash loses at most a minute of progress
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

Leaderboard.Start()

print(("[%s] server started"):format(Config.GameName))
