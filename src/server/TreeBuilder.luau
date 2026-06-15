-- Generates the physical world from Config: upgrade pads with glowing paths
-- between them (like an upgrade-tree game), plus the purple card TV kiosk.
-- Pad billboards (cost/level, per-player) are drawn client-side; this module
-- only builds the shared geometry and the buy prompts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local TreeBuilder = {}

local PAD_SIZE = Vector3.new(8, 1, 8)
local PAD_Y = 0.5

-- All three islands sit edge-to-edge in a row (Red | Gold | Green) so they
-- read as one growing landmass. Red is 164 wide (spans x -82..82); each gold/
-- green island is 130 wide, so their centers are placed to butt right up
-- against the previous island's edge.
local RED_CENTER_X = 0 -- MainIsland center (spans -82..82)
local GOLD_CENTER_X = 147 -- spans 82..212, flush with Red's right edge
local GREEN_CENTER_X = 277 -- spans 212..342, flush with Gold's right edge

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

-- The roll TV: a plain purple square screen (no stand). The interactive UI on
-- it — the card, the Roll button, the speed/auto controls — is drawn per-player
-- by the client (a SurfaceGui adorned to this part), so it's touchable and each
-- player sees their own card.
local function buildRollTv(folder)
	local screen = makePart({
		Name = "RollTV",
		Size = Vector3.new(18, 12, 1),
		CFrame = CFrame.new(0, 7, -18),
		Color = Color3.fromRGB(150, 90, 255),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	screen.Anchored = true

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(170, 110, 255)
	glow.Brightness = 1.5
	glow.Range = 26
	glow.Parent = screen
end

-- All three islands are built at runtime so they can have per-player visibility
-- and fade-in effects when unlocked.
local function buildIslands(folder)
	local main = makePart({
		Name = "MainIsland",
		Size = Vector3.new(164, 8, 144),
		CFrame = CFrame.new(RED_CENTER_X, -4, 5),
		Color = Color3.fromRGB(181, 166, 219),
		Material = Enum.Material.Plastic,
		Parent = folder,
	})
	main.TopSurface = Enum.SurfaceType.Studs
	main.Locked = true

	-- Gold/Green start fully built and opaque on the server; the CLIENT hides
	-- them per-player with LocalTransparencyModifier + CanCollide until they're
	-- unlocked, then fades them in. (Setting Transparency=1 here would be a
	-- one-way trip — LocalTransparencyModifier can't make a part LESS
	-- transparent than its base Transparency, so the island could never reveal.)
	local gold = makePart({
		Name = "GoldenIsland",
		Size = Vector3.new(130, 8, 120),
		CFrame = CFrame.new(GOLD_CENTER_X, -4, 5),
		Color = Color3.fromRGB(242, 199, 64),
		Material = Enum.Material.Plastic,
		Parent = folder,
	})
	gold.TopSurface = Enum.SurfaceType.Studs
	gold.Locked = true
	gold:SetAttribute("IslandName", "Gold")

	local green = makePart({
		Name = "GreenIsland",
		Size = Vector3.new(130, 8, 120),
		CFrame = CFrame.new(GREEN_CENTER_X, -4, 5),
		Color = Color3.fromRGB(100, 200, 100),
		Material = Enum.Material.Plastic,
		Parent = folder,
	})
	green.TopSurface = Enum.SurfaceType.Studs
	green.Locked = true
	green:SetAttribute("IslandName", "Green")
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
	altar.Color = Color3.fromRGB(200, 160, 40)
	altar.Material = Enum.Material.SmoothPlastic
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

-- Builds everything. onBuy(player, nodeId) is called when a pad prompt fires.
-- Returns the TV ticker label so the server can announce big pulls.
function TreeBuilder.Build(onBuy)
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

	for _, treeNode in Config.AutomationTree do
		buildPad(treeNode, folder, onBuy)
		local parent = treeNode.Requires and Config.NodeById[treeNode.Requires]
		if parent then
			buildPath(parent, treeNode, folder)
		end
	end

	buildAltar(folder)

	-- No portals: the three islands are flush, so you simply walk across the
	-- seams. Locked islands are hidden and non-collidable per-player (handled
	-- client-side), so you can't reach Gold/Green until you've unlocked them.

	buildRollTv(folder)
	folder.Parent = workspace
end

return TreeBuilder
