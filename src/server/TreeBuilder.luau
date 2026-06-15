-- Builds the whole world at runtime: a central plaza with the Card TV, the GOLD
-- platform (rebirth tree) to the north, the GREEN platform (luck + automation)
-- to the south, and the SHOP to the west — each reached by a grey bridge you
-- build part-by-part. Upgrade-pad billboards are drawn per-player on the client;
-- this module builds the shared geometry, the buy prompts, and the bridges.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local TreeBuilder = {}

local PAD_SIZE = Vector3.new(8, 1, 8)
local PAD_Y = 0.5

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

-- ===== upgrade pads ========================================================

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

	makePart({
		Name = "Trim",
		Size = Vector3.new(PAD_SIZE.X + 0.6, 0.2, PAD_SIZE.Z + 0.6),
		CFrame = CFrame.new(x, 0.1, z),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = pad,
	})

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
		Name = "Path_" .. toNode.Id,
		Size = Vector3.new(1.4, 0.1, math.max(distance - 6, 1)),
		CFrame = CFrame.lookAt(mid, b),
		Color = Config.BranchColors[toNode.Branch] or Color3.fromRGB(200, 200, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		Parent = folder,
	})
end

-- ===== platforms ===========================================================

local function plate(folder, name, cx, cz, sx, sz, color)
	local p = makePart({
		Name = name,
		Size = Vector3.new(sx, 8, sz),
		CFrame = CFrame.new(cx, -4, cz),
		Color = color,
		Material = Enum.Material.Plastic,
		Parent = folder,
	})
	p.TopSurface = Enum.SurfaceType.Studs
	p.Locked = true
	return p
end

-- ===== the Card TV =========================================================

local function buildRollTv(folder)
	-- east of spawn; its WEST face (−X, "Left") holds the screen, facing the
	-- player who walks up from the plaza centre.
	local screen = makePart({
		Name = "RollTV",
		Size = Vector3.new(1, 13, 20),
		CFrame = CFrame.new(18, 8, 0),
		Color = Color3.fromRGB(22, 16, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	makePart({
		Name = "TvBezel",
		Size = Vector3.new(0.8, 15, 22),
		CFrame = CFrame.new(17.7, 8, 0),
		Color = Color3.fromRGB(150, 90, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		Parent = screen,
	})
	makePart({
		Name = "TvMarquee",
		Size = Vector3.new(1.2, 2, 22),
		CFrame = CFrame.new(18, 16, 0),
		Color = Color3.fromRGB(200, 120, 255),
		Material = Enum.Material.Neon,
		Parent = screen,
	})
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(170, 110, 255)
	glow.Brightness = 1.8
	glow.Range = 28
	glow.Parent = screen
end

-- ===== rebirth altar (far end of the GOLD platform, north) =================

local function buildAltar(folder)
	local altar = makePart({
		Name = "RebirthAltar",
		Size = Vector3.new(14, 1.4, 14),
		CFrame = CFrame.new(0, 0.7, 145),
		Color = Color3.fromRGB(255, 215, 60),
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthPrompt"
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "⭐ Rebirth Altar"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = altar
end

-- ===== shop (west) =========================================================

local function buildShop(folder, onBuyShop)
	-- a small store box with a few "machines" you buy from
	local cx, cz = -115, 0
	plate(folder, "ShopFloor", cx, cz, 70, 60, Color3.fromRGB(120, 120, 130))
	-- back + side walls
	makePart({ Name = "ShopWallBack", Size = Vector3.new(2, 22, 60), CFrame = CFrame.new(cx - 34, 11, cz), Color = Color3.fromRGB(225, 220, 200), Parent = folder })
	makePart({ Name = "ShopWallN", Size = Vector3.new(70, 22, 2), CFrame = CFrame.new(cx, 11, cz - 30), Color = Color3.fromRGB(225, 220, 200), Parent = folder })
	makePart({ Name = "ShopWallS", Size = Vector3.new(70, 22, 2), CFrame = CFrame.new(cx, 11, cz + 30), Color = Color3.fromRGB(225, 220, 200), Parent = folder })
	makePart({ Name = "ShopRoof", Size = Vector3.new(72, 2, 62), CFrame = CFrame.new(cx, 22, cz), Color = Color3.fromRGB(90, 90, 100), Parent = folder })
	-- a glowing OPEN sign
	makePart({ Name = "ShopSign", Size = Vector3.new(1, 4, 16), CFrame = CFrame.new(cx + 35, 16, cz), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Neon, Parent = folder })
	local light = Instance.new("PointLight")
	light.Brightness = 1.5
	light.Range = 40
	light.Parent = folder:FindFirstChild("ShopRoof")

	-- vending machines along the back wall, one per shop item
	for index, item in Config.Shop do
		local mz = cz - 22 + (index - 1) * 14
		local machine = makePart({
			Name = "ShopMachine_" .. item.Id,
			Size = Vector3.new(4, 10, 6),
			CFrame = CFrame.new(cx - 30, 5, mz),
			Color = Color3.fromRGB(40, 50, 80),
			Parent = folder,
		})
		makePart({
			Name = "Screen",
			Size = Vector3.new(0.4, 6, 4.5),
			CFrame = CFrame.new(cx - 27.8, 6, mz),
			Color = Color3.fromRGB(120, 200, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
			Parent = machine,
		})
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ShopPrompt"
		prompt.ActionText = "Buy"
		prompt.ObjectText = item.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("ItemId", item.Id)
		prompt.Parent = machine
		prompt.Triggered:Connect(function(player)
			onBuyShop(player, item.Id)
		end)
	end
end

-- ===== bridges =============================================================
-- Each bridge is a row of segments spanning the gap from the plaza to an area.
-- Every segment exists on the server; the client shows the first N (the player's
-- built count) and hides the rest, so it grows as you buy parts. A build prompt
-- sits at the plaza end.

local function buildBridge(folder, which, fromPos, toPos, onBuyBridge)
	local conf = Config.Bridges[which]
	local parts = conf.Parts
	local from = Vector3.new(fromPos.X, 0, fromPos.Z)
	local to = Vector3.new(toPos.X, 0, toPos.Z)
	local total = (to - from)
	local dir = total.Unit
	local segLen = total.Magnitude / parts

	local longX = which == "shop" -- shop bridge runs east-west
	for i = 1, parts do
		local centre = from + dir * (segLen * (i - 0.5))
		local seg = makePart({
			Name = "BridgeSeg",
			Size = if longX then Vector3.new(segLen + 0.05, 1, 7) else Vector3.new(7, 1, segLen + 0.05),
			CFrame = CFrame.new(Vector3.new(centre.X, 0, centre.Z)),
			Color = Color3.fromRGB(120, 120, 125),
			Material = Enum.Material.Concrete,
			Parent = folder,
		})
		seg:SetAttribute("Bridge", which)
		seg:SetAttribute("Index", i)
	end

	-- build prompt at the plaza end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BridgePrompt"
	prompt.ActionText = "Build"
	prompt.ObjectText = "🌉 " .. which:upper() .. " Bridge"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	local anchor = makePart({
		Name = "BridgeAnchor_" .. which,
		Size = Vector3.new(6, 3, 6),
		CFrame = CFrame.new(Vector3.new(from.X, 1.5, from.Z)),
		Color = Color3.fromRGB(90, 90, 95),
		Parent = folder,
	})
	anchor:SetAttribute("Bridge", which)
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		onBuyBridge(player, which)
	end)
end

-- ===== build everything ====================================================

function TreeBuilder.Build(onBuy, onBuyBridge, onBuyShop)
	for _, legacyName in { "Baseplate", "SpawnPlaza", "MainIsland", "GoldenIsland", "GreenIsland", "RebirthBridge", "UpgradeTree" } do
		local legacy = workspace:FindFirstChild(legacyName)
		if legacy then
			legacy:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "UpgradeTree"

	-- plaza + areas
	plate(folder, "Plaza", 0, 0, 90, 90, Color3.fromRGB(181, 166, 219))
	plate(folder, "GoldPlatform", 0, 115, 90, 90, Color3.fromRGB(242, 199, 64))
	plate(folder, "GreenPlatform", 0, -115, 90, 90, Color3.fromRGB(120, 200, 110))

	-- pads
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

	buildRollTv(folder)
	buildAltar(folder)
	buildShop(folder, onBuyShop)

	-- bridges: plaza edge -> area edge
	buildBridge(folder, "gold", Vector3.new(0, 0, 45), Vector3.new(0, 0, 70), onBuyBridge)
	buildBridge(folder, "green", Vector3.new(0, 0, -45), Vector3.new(0, 0, -70), onBuyBridge)
	buildBridge(folder, "shop", Vector3.new(-45, 0, 0), Vector3.new(-80, 0, 0), onBuyBridge)

	folder.Parent = workspace
end

return TreeBuilder
