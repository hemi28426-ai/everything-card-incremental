-- Builds the world at runtime: a ROUND central hub (with a raised ring rim) that
-- holds the Card TV, plus three areas reached by grey bridges you build part by
-- part — GOLD (rebirth tree) north, GREEN (luck + automation) south, SHOP west.
-- Areas, their pads, and the shop stay hidden per-player until you finish the
-- bridge to them (handled client-side). No neon — clean matte materials.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local TreeBuilder = {}

local PAD_SIZE = Vector3.new(8, 1, 8)
local PAD_Y = 0.5

local HUB_RADIUS = 50
local GOLD = Vector3.new(0, 0, 150)
local GREEN = Vector3.new(0, 0, -150)
local SHOP = Vector3.new(-150, 0, 0)

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

-- ===== the Card TV =========================================================
-- On the EAST side of the hub (the side with no bridge). Its WEST face (−X)
-- holds the screen, facing the hub centre where you walk up. The clickable
-- buttons live on a SurfaceGui the client parents to this part.

local function buildRollTv(folder)
	local screen = makePart({
		Name = "RollTV",
		Size = Vector3.new(1.5, 18, 30),
		CFrame = CFrame.new(42, 11, 0),
		Color = Color3.fromRGB(28, 24, 40),
		Parent = folder,
	})
	makePart({ Name = "TvFrame", Size = Vector3.new(1.2, 20, 32), CFrame = CFrame.new(42.6, 11, 0), Color = Color3.fromRGB(74, 64, 100), Parent = screen })
	makePart({ Name = "TvBase", Size = Vector3.new(5, 9, 12), CFrame = CFrame.new(42.6, 4.5, 0), Color = Color3.fromRGB(55, 48, 75), Parent = screen })
end

-- ===== rebirth altar (far end of the GOLD platform) ========================

local function buildAltar(folder)
	local altar = makePart({
		Name = "RebirthAltar",
		Size = Vector3.new(14, 1.4, 14),
		CFrame = CFrame.new(0, 0.7, 205),
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

-- ===== shop (west) =========================================================

local function buildShop(folder, onBuyShop)
	local cx, cz = SHOP.X, SHOP.Z
	disc(folder, "ShopGround", SHOP, 60, Color3.fromRGB(150, 148, 158), -2, "shop")

	-- enclosed building: floor, four walls (with a doorway gap to the east), roof
	makePart({ Name = "ShopWallW", Size = Vector3.new(2, 24, 56), CFrame = CFrame.new(cx - 26, 12, cz), Color = Color3.fromRGB(228, 222, 205), Area = "shop", Parent = folder })
	makePart({ Name = "ShopWallN", Size = Vector3.new(54, 24, 2), CFrame = CFrame.new(cx, 12, cz - 27), Color = Color3.fromRGB(228, 222, 205), Area = "shop", Parent = folder })
	makePart({ Name = "ShopWallS", Size = Vector3.new(54, 24, 2), CFrame = CFrame.new(cx, 12, cz + 27), Color = Color3.fromRGB(228, 222, 205), Area = "shop", Parent = folder })
	-- east wall split into two with a doorway in the middle
	makePart({ Name = "ShopWallE1", Size = Vector3.new(2, 24, 20), CFrame = CFrame.new(cx + 26, 12, cz - 18), Color = Color3.fromRGB(228, 222, 205), Area = "shop", Parent = folder })
	makePart({ Name = "ShopWallE2", Size = Vector3.new(2, 24, 20), CFrame = CFrame.new(cx + 26, 12, cz + 18), Color = Color3.fromRGB(228, 222, 205), Area = "shop", Parent = folder })
	makePart({ Name = "ShopRoof", Size = Vector3.new(58, 2, 58), CFrame = CFrame.new(cx, 24.5, cz), Color = Color3.fromRGB(150, 70, 70), Area = "shop", Parent = folder })

	-- big "SHOP" sign on top of the roof
	local sign = makePart({ Name = "ShopSign", Size = Vector3.new(24, 6, 2), CFrame = CFrame.new(cx, 28.5, cz + 26), Color = Color3.fromRGB(40, 44, 70), Area = "shop", Parent = folder })
	local sgui = Instance.new("SurfaceGui")
	sgui.Face = Enum.NormalId.Front
	sgui.Parent = sign
	local slabel = Instance.new("TextLabel")
	slabel.BackgroundTransparency = 1
	slabel.Size = UDim2.new(1, 0, 1, 0)
	slabel.Font = Enum.Font.GothamBlack
	slabel.TextScaled = true
	slabel.TextColor3 = Color3.fromRGB(255, 235, 140)
	slabel.Text = "SHOP"
	slabel.Parent = sgui

	-- ceiling lights so the interior isn't pitch black
	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 50
	light.Parent = folder:FindFirstChild("ShopRoof")

	-- a counter machine per shop item along the west wall
	for index, item in Config.Shop do
		local mz = cz - 18 + (index - 1) * 12
		local machine = makePart({
			Name = "ShopMachine_" .. item.Id,
			Size = Vector3.new(5, 11, 7),
			CFrame = CFrame.new(cx - 21, 5.5, mz),
			Color = Color3.fromRGB(60, 66, 96),
			Area = "shop",
			Parent = folder,
		})
		makePart({ Name = "Panel", Size = Vector3.new(0.4, 6, 5), CFrame = CFrame.new(cx - 18.3, 6.5, mz), Color = Color3.fromRGB(150, 170, 210), Area = "shop", Parent = machine })
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ShopPrompt"
		prompt.ActionText = "Buy"
		prompt.ObjectText = item.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = machine
		prompt.Triggered:Connect(function(player)
			onBuyShop(player, item.Id)
		end)
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
	end

	local padColor = if which == "gold"
		then Color3.fromRGB(232, 200, 96)
		elseif which == "green" then Color3.fromRGB(140, 202, 116)
		else Color3.fromRGB(150, 182, 232)
	local anchor = makePart({
		Name = "BridgeStart_" .. which,
		Size = Vector3.new(9, 0.5, 9),
		CFrame = CFrame.new(from.X, 0.3, from.Z),
		Color = padColor,
		Parent = folder,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BridgePrompt"
	prompt.ActionText = "Build"
	prompt.ObjectText = "🌉 " .. which:upper() .. " Bridge"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
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

	-- round hub with a raised ring rim
	disc(folder, "HubRing", Vector3.new(0, 0, 0), HUB_RADIUS + 6, Color3.fromRGB(120, 108, 160), -2.6)
	disc(folder, "Hub", Vector3.new(0, 0, 0), HUB_RADIUS, Color3.fromRGB(186, 172, 222), -2)

	-- area platforms (hidden per-player until their bridge is finished)
	disc(folder, "GoldPlatform", GOLD, 70, Color3.fromRGB(226, 192, 86), -2, "gold")
	disc(folder, "GreenPlatform", GREEN, 70, Color3.fromRGB(132, 196, 110), -2, "green")

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

	buildBridge(folder, "gold", Vector3.new(0, 0, 50), Vector3.new(0, 0, 80), onBuyBridge)
	buildBridge(folder, "green", Vector3.new(0, 0, -50), Vector3.new(0, 0, -80), onBuyBridge)
	buildBridge(folder, "shop", Vector3.new(-50, 0, 0), Vector3.new(-90, 0, 0), onBuyBridge)

	folder.Parent = workspace
end

return TreeBuilder
