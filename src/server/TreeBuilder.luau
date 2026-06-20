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

local HUB_RADIUS = Config.Layout.HubRadius
local ISLAND_RADIUS = Config.Layout.IslandRadius
local GOLD = Vector3.new(Config.Layout.Gold[1], 0, Config.Layout.Gold[2])
local GREEN = Vector3.new(Config.Layout.Green[1], 0, Config.Layout.Green[2])
local SHOP = Vector3.new(Config.Layout.Shop[1], 0, Config.Layout.Shop[2])

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
		Color = Color3.fromRGB(20, 18, 28), -- dark tile; the trim + on-pad gui carry the colour
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
		Size = Vector3.new(1, 0.3, math.max(distance - 7, 1)),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = Color3.fromRGB(205, 205, 220), -- bright connector line, like a skill tree
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

-- A standalone, slightly bigger pad that unlocks a Card Pack when bought. Tagged
-- with PackId (not NodeId) so the client renders + gates it separately. Pads on
-- an island carry that Area so they hide until the bridge is built.
local function buildPackPad(pack, folder, onBuyPack)
	local x, z = pack.Pos[1], pack.Pos[2]
	local area = if pack.Area ~= "hub" then pack.Area else nil
	local pad = makePart({
		Name = "PackPad_" .. pack.Id,
		Size = Vector3.new(10, 1, 10),
		CFrame = CFrame.new(x, PAD_Y, z),
		Color = Color3.fromRGB(18, 16, 26),
		Area = area,
		Parent = folder,
	})
	pad:SetAttribute("PackId", pack.Id)
	makePart({
		Name = "PackTrim",
		Size = Vector3.new(11, 0.5, 11),
		CFrame = CFrame.new(x, 0.25, z),
		Color = pack.Color,
		Area = area,
		Parent = pad,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PackPrompt"
	prompt.ActionText = "Unlock"
	prompt.ObjectText = pack.Name
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(function(player)
		onBuyPack(player, pack.Id)
	end)
end

-- ===== the Card TV =========================================================
-- On the EAST edge of the hub (the side with no bridge). Its WEST face (−X)
-- holds the screen, facing the hub centre where you walk up. The clickable
-- buttons live on a SurfaceGui the client parents to this part.

local function buildRollTv(folder)
	local tv = Config.Layout.TV
	local screen = makePart({
		Name = "RollTV",
		Size = Vector3.new(1.5, 18, 30),
		CFrame = CFrame.new(tv[1], tv[2], tv[3]),
		Color = Color3.fromRGB(28, 24, 40),
		Parent = folder,
	})
	makePart({ Name = "TvFrame", Size = Vector3.new(1.2, 20, 32), CFrame = CFrame.new(tv[1] + 0.6, tv[2], tv[3]), Color = Color3.fromRGB(74, 64, 100), Parent = screen })
end

-- ===== Pack Loader 3000 ====================================================
-- A kiosk next to the TV (south of it). Its WEST face holds a SurfaceGui the
-- client builds: the unlock button, then your unlocked card packs to equip.

local function buildPackLoader(folder)
	local tv = Config.Layout.TV
	local machine = makePart({
		Name = "PackLoader",
		Size = Vector3.new(1.5, 16, 16),
		CFrame = CFrame.new(tv[1], 9, tv[3] - 34),
		Color = Color3.fromRGB(26, 30, 44),
		Parent = folder,
	})
	makePart({ Name = "PackFrame", Size = Vector3.new(1.2, 18, 18), CFrame = CFrame.new(tv[1] + 0.6, 9, tv[3] - 34), Color = Color3.fromRGB(70, 80, 110), Parent = machine })
	-- a little sign cube on top
	makePart({ Name = "PackTop", Size = Vector3.new(2, 2, 18), CFrame = CFrame.new(tv[1], 18, tv[3] - 34), Color = Color3.fromRGB(90, 130, 200), Parent = machine })
end

-- ===== rebirth altar (far end of the GOLD island) =========================

local function buildAltar(folder)
	-- sits in the southern gap of the radial rebirth tree, right where the bridge
	-- arrives, so it greets you before you walk up to the Core at the centre
	local altar = makePart({
		Name = "RebirthAltar",
		Size = Vector3.new(14, 1.4, 14),
		CFrame = CFrame.new(0, 0.7, GOLD.Z - 74),
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

-- a little gold key on the shop counter, with a buy prompt (costs tokens+coins)
local function buildKey(parent, cf, onBuyKey)
	local model = Instance.new("Model")
	model.Name = "BackroomsKey"
	local gold = Color3.fromRGB(235, 196, 70)
	local function kp(size, rel, shape)
		local p = makePart({ Name = "KeyPart", Size = size, CFrame = cf * rel, Color = gold, Material = Enum.Material.Metal, Parent = model })
		if shape then
			p.Shape = shape
		end
		return p
	end
	local ring = kp(Vector3.new(0.45, 2.4, 2.4), CFrame.new(-1.6, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	kp(Vector3.new(3.2, 0.5, 0.5), CFrame.new(0.6, 0, 0))
	kp(Vector3.new(0.5, 1.0, 0.5), CFrame.new(1.9, -0.55, 0))
	kp(Vector3.new(0.5, 0.7, 0.5), CFrame.new(2.4, -0.45, 0))
	model.PrimaryPart = ring

	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(230, 64)
	board.StudsOffset = Vector3.new(0, 3, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 60
	board.Parent = ring
	local t1 = Instance.new("TextLabel")
	t1.BackgroundTransparency = 1
	t1.Size = UDim2.new(1, 0, 0.5, 0)
	t1.Font = Enum.Font.GothamBlack
	t1.TextScaled = true
	t1.TextColor3 = Color3.fromRGB(255, 230, 120)
	t1.Text = "🗝️ BACKROOMS KEY"
	t1.Parent = board
	local t2 = Instance.new("TextLabel")
	t2.BackgroundTransparency = 1
	t2.Position = UDim2.new(0, 0, 0.5, 0)
	t2.Size = UDim2.new(1, 0, 0.5, 0)
	t2.Font = Enum.Font.GothamBold
	t2.TextScaled = true
	t2.TextColor3 = Color3.fromRGB(235, 238, 245)
	t2.Text = ("⭐%d  +  🪙5M"):format(Config.Key.Tokens)
	t2.Parent = board

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = "Backrooms Key"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = ring
	prompt.Triggered:Connect(function(player)
		onBuyKey(player)
	end)
	model.Parent = parent
end

-- the metal door behind the cashier: swing script stripped, just an E to enter
local function buildEntryDoor(parent, cf, onEnter)
	local template = ReplicatedStorage:FindFirstChild("MetalDoor")
	if not template then
		return
	end
	local door = template:Clone()
	for _, d in door:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local bbcf, size = door:GetBoundingBox()
	local centerToPivot = bbcf:ToObjectSpace(door:GetPivot())
	door:PivotTo(cf * CFrame.new(0, size.Y / 2, 0) * centerToPivot)
	door.Parent = parent
	local anchor = door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter"
	prompt.ObjectText = "🚪 The Backrooms"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		onEnter(player)
	end)
end

local function placeImportedShop(folder, onBuyShop, onBuyKey, onEnterBackrooms)
	-- ground for the shop island (always visible, no bridge-gating)
	disc(folder, "ShopGround", SHOP, ISLAND_RADIUS, Color3.fromRGB(150, 148, 158), -2)

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

	-- rotate the whole shop so the cashier faces the bridge (toward the hub).
	-- We read the cashier's current facing and spin the model about its centre
	-- until that look points from the shop toward the hub centre.
	local npc = shop:FindFirstChild("showcase npc")
	local root = npc and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso"))
	if root then
		local look = root.CFrame.LookVector
		local curYaw = math.atan2(look.X, look.Z)
		local desiredYaw = math.atan2(-SHOP.X, -SHOP.Z) -- direction shop → hub centre
		local dyaw = desiredYaw - curYaw
		local centre = shop:GetBoundingBox().Position
		shop:PivotTo(CFrame.new(centre) * CFrame.Angles(0, dyaw, 0) * CFrame.new(-centre) * shop:GetPivot())
	end

	for _, item in Config.Shop do
		attachShopPrompt(shop, item, onBuyShop)
	end

	-- the Key (for sale, in front of the cashier) + the Backrooms door (behind him)
	if npc and root then
		local look = root.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)
		if look.Magnitude > 0.01 then
			look = look.Unit
			local pos = root.Position
			if onBuyKey then
				buildKey(folder, CFrame.new(pos.X + look.X * 4, pos.Y + 0.5, pos.Z + look.Z * 4), onBuyKey)
			end
			if onEnterBackrooms then
				local behind = pos - look * 7
				buildEntryDoor(folder, CFrame.lookAt(Vector3.new(behind.X, 0, behind.Z), Vector3.new(behind.X, 0, behind.Z) + look), onEnterBackrooms)
			end
		end
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

function TreeBuilder.Build(onBuy, onBuyBridge, onBuyShop, onBuyPack, onBuyKey, onEnterBackrooms)
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

	-- the four Card Pack unlock buttons, one per island
	for _, pack in Config.Packs do
		buildPackPad(pack, folder, onBuyPack)
	end

	buildRollTv(folder)
	buildPackLoader(folder)
	buildAltar(folder)

	buildBridge(folder, "gold", Vector3.new(0, 0, HUB_RADIUS), Vector3.new(0, 0, GOLD.Z - ISLAND_RADIUS), onBuyBridge)
	buildBridge(folder, "green", Vector3.new(-HUB_RADIUS, 0, 0), Vector3.new(GREEN.X + ISLAND_RADIUS, 0, 0), onBuyBridge)
	buildBridge(folder, "shop", Vector3.new(0, 0, -HUB_RADIUS), Vector3.new(0, 0, SHOP.Z + ISLAND_RADIUS), onBuyBridge)

	folder.Parent = workspace

	-- place the imported shop after the folder exists (it lives in workspace)
	task.spawn(function()
		placeImportedShop(folder, onBuyShop, onBuyKey, onEnterBackrooms)
	end)
end

return TreeBuilder
