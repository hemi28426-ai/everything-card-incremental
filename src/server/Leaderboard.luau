-- Global top-10 leaderboard: a physical board near spawn showing the
-- players who have earned the most coins of all time (OrderedDataStore).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local Leaderboard = {}

local orderedStore = nil
pcall(function()
	orderedStore = DataStoreService:GetOrderedDataStore("ECITotalEarned_v1")
end)

local nameCache = {}
local rowLabels = {}

function Leaderboard.Submit(userId, totalEarned)
	if not orderedStore then
		return
	end
	local amount = math.floor(totalEarned)
	if amount <= 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			orderedStore:SetAsync(tostring(userId), amount)
		end)
	end)
end

local function getName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local name = "Player " .. userId
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok then
		name = result
	end
	nameCache[userId] = name
	return name
end

local function createBoard()
	local board = Instance.new("Part")
	board.Name = "GlobalLeaderboard"
	board.Anchored = true
	board.Size = Vector3.new(1.2, 13, 17) -- thin on X so it faces west like the TV
	board.Position = Vector3.new(90, 9, 32) -- right next to the Card Opener, on the hub's east edge
	board.Color = Color3.fromRGB(25, 18, 40)
	board.Material = Enum.Material.SmoothPlastic

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left -- −X, faces the hub centre (same way as the TV)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 56)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 36
	title.TextColor3 = Color3.fromRGB(255, 215, 60)
	title.Text = "🏆 TOP COLLECTORS"
	title.Parent = gui

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 24, 0, 60)
	list.Size = UDim2.new(1, -48, 1, -70)
	list.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list

	for i = 1, Config.LeaderboardSize do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 26)
		row.Font = Enum.Font.GothamBold
		row.TextSize = 20
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(230, 232, 240)
		row.LayoutOrder = i
		row.Text = ""
		row.Parent = list
		rowLabels[i] = row
	end

	board.Parent = workspace
end

function Leaderboard.Start()
	createBoard()

	if not orderedStore then
		rowLabels[1].Text = "Leaderboard needs a published game with API access"
		return
	end

	task.spawn(function()
		while true do
			local ok, pages = pcall(function()
				return orderedStore:GetSortedAsync(false, Config.LeaderboardSize)
			end)
			if ok then
				local page = pages:GetCurrentPage()
				for i = 1, Config.LeaderboardSize do
					local entry = page[i]
					if entry then
						local userId = tonumber(entry.key) or 0
						rowLabels[i].Text = ("%d.  %s  —  %s coins"):format(i, getName(userId), Format(entry.value))
					else
						rowLabels[i].Text = ""
					end
				end
			end
			task.wait(Config.LeaderboardRefreshInterval)
		end
	end)
end

return Leaderboard
