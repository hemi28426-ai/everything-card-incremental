-- Generates the physical world from Config: upgrade pads with glowing paths
-- between them (like an upgrade-tree game), plus the purple card TV kiosk.
-- Pad billboards (cost/level, per-player) are drawn client-side; this module
-- only builds the shared geometry and the buy prompts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local TreeBuilder = {}

local PAD_SIZE = Vector3.new(8, 0.6, 8)
local PAD_Y = 0.3

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function buildPad(treeNode, folder, onBuy)
	local x, z = treeNode.Pos[1], treeNode.Pos[2]
	local color = Config.BranchColors[treeNode.Branch] or Color3.fromRGB(200, 200, 200)

	local pad = makePart({
		Name = "Pad_" .. treeNode.Id,
		Size = PAD_SIZE,
		CFrame = CFrame.new(x, PAD_Y, z),
		Color = color,
		Parent = folder,
	})
	pad:SetAttribute("NodeId", treeNode.Id)

	local trim = makePart({
		Name = "Trim",
		Size = Vector3.new(PAD_SIZE.X + 0.6, 0.2, PAD_SIZE.Z + 0.6),
		CFrame = CFrame.new(x, 0.1, z),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = pad,
	})
	trim.Transparency = 0.2

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = treeNode.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(function(player)
		onBuy(player, treeNode.Id)
	end)
end

local function buildPath(fromNode, toNode, folder)
	local a = Vector3.new(fromNode.Pos[1], 0.15, fromNode.Pos[2])
	local b = Vector3.new(toNode.Pos[1], 0.15, toNode.Pos[2])
	local distance = (b - a).Magnitude
	if distance < 1 then
		return
	end
	local mid = (a + b) / 2
	makePart({
		Name = "Path_" .. toNode.Id, -- client shows/hides this with its pad
		Size = Vector3.new(1.4, 0.1, distance - 6),
		CFrame = CFrame.lookAt(mid, b),
		Color = Config.BranchColors[toNode.Branch] or Color3.fromRGB(200, 200, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		Parent = folder,
	})
end

local function buildTv(folder)
	-- stand
	makePart({
		Name = "TvStand",
		Size = Vector3.new(4, 3, 2),
		CFrame = CFrame.new(0, 1.5, -20),
		Color = Color3.fromRGB(40, 30, 60),
		Parent = folder,
	})
	-- screen body
	local screen = makePart({
		Name = "CardTv",
		Size = Vector3.new(15, 8, 1.2),
		CFrame = CFrame.new(0, 7, -20),
		Color = Color3.fromRGB(25, 18, 40),
		Parent = folder,
	})
	-- neon frame
	makePart({
		Name = "TvFrame",
		Size = Vector3.new(15.8, 8.8, 1),
		CFrame = CFrame.new(0, 7, -20.2),
		Color = Color3.fromRGB(150, 80, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		Parent = screen,
	})

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(170, 110, 255)
	glow.Brightness = 2
	glow.Range = 32
	glow.Parent = screen

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- faces spawn
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = screen

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 110)
	title.Position = UDim2.new(0, 0, 0, 16)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 64
	title.TextColor3 = Color3.fromRGB(200, 150, 255)
	title.Text = "EVERYTHING CARDS"
	title.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, 0, 0, 40)
	subtitle.Position = UDim2.new(0, 0, 0, 120)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 24
	subtitle.TextColor3 = Color3.fromRGB(150, 140, 180)
	subtitle.Text = "Every card is a real Roblox account. Press ROLL."
	subtitle.Parent = gui

	local ticker = Instance.new("TextLabel")
	ticker.Name = "Ticker"
	ticker.BackgroundTransparency = 1
	ticker.Size = UDim2.new(1, -40, 0, 120)
	ticker.Position = UDim2.new(0, 20, 0, 180)
	ticker.Font = Enum.Font.GothamBold
	ticker.TextSize = 30
	ticker.TextWrapped = true
	ticker.TextColor3 = Color3.fromRGB(255, 215, 60)
	ticker.Text = "Big pulls will be announced here..."
	ticker.Parent = gui

	return ticker
end

local function buildPlaza(folder)
	local ring = Instance.new("Part")
	ring.Name = "SpawnPlaza"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.Size = Vector3.new(0.3, 22, 22)
	ring.CFrame = CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(150, 90, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.45
	ring.Parent = folder
end

-- Builds everything. onBuy(player, nodeId) is called when a pad prompt fires.
-- Returns the TV ticker label so the server can announce big pulls on it.
function TreeBuilder.Build(onBuy)
	local folder = Instance.new("Folder")
	folder.Name = "UpgradeTree"

	buildPlaza(folder)

	for _, treeNode in Config.Tree do
		buildPad(treeNode, folder, onBuy)
		local parent = treeNode.Requires and Config.NodeById[treeNode.Requires]
		if parent then
			buildPath(parent, treeNode, folder)
		end
	end

	local ticker = buildTv(folder)
	folder.Parent = workspace
	return ticker
end

return TreeBuilder
