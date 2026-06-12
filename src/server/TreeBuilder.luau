-- Generates the physical world from Config: upgrade pads with glowing paths
-- between them (like an upgrade-tree game), plus the purple card TV kiosk.
-- Pad billboards (cost/level, per-player) are drawn client-side; this module
-- only builds the shared geometry and the buy prompts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local TreeBuilder = {}

local PAD_SIZE = Vector3.new(8, 1, 8)
local PAD_Y = 0.5

-- the golden island lives far out in the void, reachable only by portal
local GOLD_CENTER_Z = -400

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
	trim.Transparency = 0

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

-- Both islands are built here at runtime so the layout is always correct
-- no matter how the project is loaded (fresh file, Rojo sync, old place).
local function buildIslands(folder)
	local main = makePart({
		Name = "MainIsland",
		Size = Vector3.new(164, 8, 144),
		CFrame = CFrame.new(0, -4, 5),
		Color = Color3.fromRGB(181, 166, 219),
		Material = Enum.Material.Plastic,
		Parent = folder,
	})
	main.TopSurface = Enum.SurfaceType.Studs
	main.Locked = true

	local gold = makePart({
		Name = "GoldenIsland",
		Size = Vector3.new(130, 8, 120),
		CFrame = CFrame.new(0, -4, GOLD_CENTER_Z),
		Color = Color3.fromRGB(242, 199, 64),
		Material = Enum.Material.Plastic,
		Parent = folder,
	})
	gold.TopSurface = Enum.SurfaceType.Studs
	gold.Locked = true
end

-- The rebirth altar lives on the MAIN island's south edge (you must be able
-- to rebirth before the golden island reveals itself). The client shows a
-- confirm panel when the prompt fires.
local function buildAltar(folder)
	local altar = Instance.new("Part")
	altar.Name = "RebirthAltar"
	altar.Anchored = true
	altar.Size = Vector3.new(12, 1.2, 12)
	altar.Position = Vector3.new(0, 0.6, -59)
	altar.Color = Color3.fromRGB(255, 215, 60)
	altar.Material = Enum.Material.Neon
	altar.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthPrompt"
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "⭐ Rebirth Altar"
	prompt.HoldDuration = 0.5 -- small hold so nobody triggers it by accident
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = altar
end

local function buildPortal(folder, name, position, labelText)
	local portal = makePart({
		Name = name,
		Size = Vector3.new(8, 0.6, 8),
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(255, 215, 60),
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = portal
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Rotation = 180
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 30
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(60, 40, 0)
	label.Text = labelText
	label.Parent = gui
	return portal
end

-- Builds everything. onBuy(player, nodeId) is called when a pad prompt
-- fires; getRebirths(player) gates the golden portal server-side.
-- Returns the TV ticker label so the server can announce big pulls on it.
function TreeBuilder.Build(onBuy, getRebirths)
	-- clear world pieces from any older version of the game, no matter how
	-- this got loaded (old file, Rojo sync into an existing place, etc.)
	for _, legacyName in { "Baseplate", "SpawnPlaza", "MainIsland", "GoldenIsland", "RebirthBridge", "UpgradeTree" } do
		local legacy = workspace:FindFirstChild(legacyName)
		if legacy then
			legacy:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "UpgradeTree"

	buildIslands(folder)

	for _, treeNode in Config.Tree do
		buildPad(treeNode, folder, onBuy)
		local parent = treeNode.Requires and Config.NodeById[treeNode.Requires]
		if parent then
			buildPath(parent, treeNode, folder)
		end
	end
	for _, treeNode in Config.RebirthTree do
		buildPad(treeNode, folder, onBuy)
		local parent = treeNode.Requires and Config.NodeById[treeNode.Requires]
		if parent then
			buildPath(parent, treeNode, folder)
		end
	end

	buildAltar(folder)

	-- portals between the islands (golden side is rebirth-gated)
	local toGold = buildPortal(folder, "GoldenPortal", Vector3.new(12, 0.3, -62), "⭐ GOLDEN ISLAND")
	local toMain = buildPortal(folder, "ReturnPortal", Vector3.new(0, 0.3, GOLD_CENTER_Z + 54), "↩ BACK")

	local teleportCooldown = {}
	Players.PlayerRemoving:Connect(function(player)
		teleportCooldown[player] = nil
	end)
	local function makeTeleporter(portal, destination, needsRebirth)
		portal.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end
			if needsRebirth and getRebirths(player) < 1 then
				return
			end
			local now = os.clock()
			if (teleportCooldown[player] or 0) > now then
				return
			end
			teleportCooldown[player] = now + 2
			character:PivotTo(CFrame.new(destination))
		end)
	end
	makeTeleporter(toGold, Vector3.new(0, 4, GOLD_CENTER_Z + 44), true)
	makeTeleporter(toMain, Vector3.new(0, 4, -50), false)

	local ticker = buildTv(folder)
	folder.Parent = workspace
	return ticker
end

return TreeBuilder
