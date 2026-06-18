-- Builds the world at runtime: a big ROUND central hub holding the Card TV and
-- the COIN trees (the Greed/Luck split), plus three areas reached by grey
-- bridges you build part by part — GOLD (rebirth tree) north, GREEN (automation
-- tree) south, and the imported SHOP west. The shop model itself is mounted by
-- Rojo (assets/Shop.rbxmx) as workspace.ImportedShop; here we just move it onto
-- the shop island and wire a Buy prompt onto each item.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local TreeBuilder = {}

local PAD_SIZE = Vector3.new(8, 1, 8)
local PAD_Y = 0.5

local HUB_RADIUS = 82
local ISLAND_RADIUS = 78
local GOLD = Vector3.new(0, 0, 200)
local GREEN = Vector3.new(0, 0, -200)
local SHOP = Vector3.new(-210, 0, 0)

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
	if props.Area then
		part:SetAttribute("Area", props.Area)
	end
	part.Parent = props.Parent
	return part
end

-- a flat round disc (cylinder rotated so its axis is vertical)
local function disc(folder, name, center, radius, color, y, area)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.Locked = true
	p.Material = Enum.Material.SmoothPlastic
	p.Size = Vector3.new(4, radius * 2, radius * 2)
	p.CFrame = CFrame.new(center.X, y or -2, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	if area then
		p:SetAttribute("Area", area)
	end
	p.Parent = folder
	return p
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
		Area = treeNode.Area,
		Parent = folder,
	})
	pad:SetAttribute("NodeId", treeNode.Id)

	makePart({
		Name = "Trim",
		Size = Vector3.new(PAD_SIZE.X + 0.8, 0.4, PAD_SIZE.Z + 0.8),
		CFrame = CFrame.new(x, 0.2, z),
		Color = color,
		Area = treeNode.Area,
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
	local a = Vector3.new(fromNode.Pos[1], 0.25, fromNode.Pos[2])
	local b = Vector3.new(toNode.Pos[1], 0.25, toNode.Pos[2])
	local distance = (b - a).Magnitude
	if distance < 1 then
		return
	end
	makePart({
		Name = "Path_" .. toNode.Id,
		Size = Vector3.new(1.6, 0.2, math.max(distance - 6, 1)),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = (Config.BranchColors[toNode.Branch] or Color3.fromRGB(200, 200, 200)):Lerp(Color3.new(0, 0, 0), 0.25),
		Area = toNode.Area,
		Parent = folder,
	})
end

local function buildTree(tree, folder, onBuy)
	for _, treeNode in tree do
		buildPad(treeNode, folder, onBuy)
		local parent = treeNode.Requires and Config.NodeById[treeNode.Requires]
		if parent then
			buildPath(parent, treeNode, folder)
		end
	end
end

-- ===== the Card TV =========================================================
-- On the EAST edge of the hub (the side with no bridge). Its WEST face (−X)
-- holds the screen, facing the hub centre where you walk up. The clickable
-- buttons live on a SurfaceGui the client parents to this part.

local function buildRollTv(folder)
	local screen = makePart({
		Name = "RollTV",
		Size = Vector3.new(1.5, 18, 30),
		CFrame = CFrame.new(76, 11, 0),
		Color = Color3.fromRGB(28, 24, 40),
		Parent = folder,
	})
	makePart({ Name = "TvFrame", Size = Vector3.new(1.2, 20, 32), CFrame = CFrame.new(76.6, 11, 0), Color = Color3.fromRGB(74, 64, 100), Parent = screen })
end

-- ===== rebirth altar (far end of the GOLD island) =========================

local function buildAltar(folder)
	local altar = makePart({
		Name = "RebirthAltar",
		Size = Vector3.new(14, 1.4, 14),
		CFrame = CFrame.new(0, 0.7, GOLD.Z + 62),
		Color = Color3.fromRGB(214, 170, 40),
		Area = "gold",
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

-- ===== imported shop (west) ================================================

-- find a Model/Tool by name anywhere inside the shop, then a representative
-- BasePart to hang the prompt + price tag on
local function findItem(shop, name)
	if shop:FindFirstChild(name) then
		return shop:FindFirstChild(name)
	end
	for _, d in shop:GetDescendants() do
		if d.Name == name and (d:IsA("Model") or d:IsA("Tool")) then
			return d
		end
	end
	return nil
end

local function representativePart(inst)
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") and inst.PrimaryPart then
		return inst.PrimaryPart
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function attachShopPrompt(shop, item, onBuyShop)
	local inst = findItem(shop, item.ItemName)
	if not inst then
		warn(("[ECI] shop item not found: %s"):format(item.ItemName))
		return
	end
	local part = representativePart(inst)
	if not part then
		return
	end
	part:SetAttribute("ShopItem", item.Id)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = item.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		onBuyShop(player, item.Id)
	end)

	-- floating name + price (the client keeps the price current per player)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShopTag"
	billboard.Size = UDim2.fromOffset(190, 56)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Parent = part
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.5, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 235, 150)
	title.Text = item.Name
	title.Parent = billboard
	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.BackgroundTransparency = 1
	price.Position = UDim2.new(0, 0, 0.5, 0)
	price.Size = UDim2.new(1, 0, 0.5, 0)
	price.Font = Enum.Font.GothamBold
	price.TextScaled = true
	price.TextColor3 = Color3.fromRGB(235, 238, 245)
	price.Text = "🪙 " .. item.Cost
	price.Parent = billboard
end

local function placeImportedShop(folder, onBuyShop)
	-- ground for the shop island (always visible, no bridge-gating)
	disc(folder, "ShopGround", SHOP, 80, Color3.fromRGB(150, 148, 158), -2)

	local shop = workspace:WaitForChild("ImportedShop", 15)
	if not shop then
		warn("[ECI] ImportedShop not found (is assets/Shop.rbxmx mounted?)")
		return
	end

	-- stash the Speed Coil as an unanchored template we can clone to buyers, and
	-- stop the display copy from being grabbed for free (a Tool in the workspace
	-- is otherwise pickup-on-touch)
	local coil = findItem(shop, "SpeedCoil")
	if coil and coil:IsA("Tool") then
		if not ServerStorage:FindFirstChild("SpeedCoilTemplate") then
			local template = coil:Clone()
			template.Name = "SpeedCoilTemplate"
			template.Parent = ServerStorage
		end
		local handle = coil:FindFirstChild("Handle")
		if handle then
			handle.CanTouch = false
		end
	end

	-- anchor everything (it's static decor now) and move it onto the island,
	-- keeping its height so its floor still rests just above the ground disc
	for _, d in shop:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local pivot = shop:GetBoundingBox()
	shop:TranslateBy(Vector3.new(SHOP.X - pivot.X, 0, SHOP.Z - pivot.Z))

	for _, item in Config.Shop do
		attachShopPrompt(shop, item, onBuyShop)
	end
end

-- ===== bridges =============================================================

local function buildBridge(folder, which, from, to, onBuyBridge)
	local conf = Config.Bridges[which]
	local parts = conf.Parts
	local total = to - from
	local dir = total.Unit
	local segLen = total.Magnitude / parts
	local longX = math.abs(dir.X) > math.abs(dir.Z)

	local firstSeg
	for i = 1, parts do
		local centre = from + dir * (segLen * (i - 0.5))
		local seg = makePart({
			Name = "BridgeSeg",
			Size = if longX then Vector3.new(segLen + 0.05, 1, 8) else Vector3.new(8, 1, segLen + 0.05),
			CFrame = CFrame.new(centre.X, 0, centre.Z),
			Color = Color3.fromRGB(120, 120, 128),
			Material = Enum.Material.Concrete,
			Parent = folder,
		})
		seg:SetAttribute("Bridge", which)
		seg:SetAttribute("Index", i)
		if i == 1 then
			firstSeg = seg
		end
	end

	-- the build prompt sits on the bridge's first tile (no separate block); the
	-- client keeps that first tile always visible so you can stand on it to build
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BridgePrompt"
	prompt.ActionText = "Build"
	prompt.ObjectText = "🌉 " .. which:upper() .. " Bridge"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = firstSeg
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

	-- round hub with a raised ring rim (always visible — holds the coin trees)
	disc(folder, "HubRing", Vector3.new(0, 0, 0), HUB_RADIUS + 6, Color3.fromRGB(120, 108, 160), -2.6)
	disc(folder, "Hub", Vector3.new(0, 0, 0), HUB_RADIUS, Color3.fromRGB(186, 172, 222), -2)

	-- area platforms (hidden per-player until their bridge is finished)
	disc(folder, "GoldPlatform", GOLD, ISLAND_RADIUS, Color3.fromRGB(226, 192, 86), -2, "gold")
	disc(folder, "GreenPlatform", GREEN, ISLAND_RADIUS, Color3.fromRGB(132, 196, 110), -2, "green")

	buildTree(Config.Tree, folder, onBuy) -- hub coin trees (Greed + Luck)
	buildTree(Config.RebirthTree, folder, onBuy) -- gold island
	buildTree(Config.AutomationTree, folder, onBuy) -- green island

	buildRollTv(folder)
	buildAltar(folder)

	buildBridge(folder, "gold", Vector3.new(0, 0, HUB_RADIUS), Vector3.new(0, 0, GOLD.Z - ISLAND_RADIUS), onBuyBridge)
	buildBridge(folder, "green", Vector3.new(0, 0, -HUB_RADIUS), Vector3.new(0, 0, GREEN.Z + ISLAND_RADIUS), onBuyBridge)
	buildBridge(folder, "shop", Vector3.new(-HUB_RADIUS, 0, 0), Vector3.new(SHOP.X + 80, 0, 0), onBuyBridge)

	folder.Parent = workspace

	-- place the imported shop after the folder exists (it lives in workspace)
	task.spawn(function()
		placeImportedShop(folder, onBuyShop)
	end)
end

return TreeBuilder
