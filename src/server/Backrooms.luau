-- Backrooms (Level 0): GENERATED at runtime, far from the main world. A randomized
-- maze of mono-yellow rooms — randomized DFS carves a perfect maze, then ~45% of
-- the leftover walls are knocked out so it reads as the open, looping, disorienting
-- "Level 0" instead of a tidy maze. The walls/floor reuse the authentic Level 0
-- textures from the reference model; the ceiling has buzzing fluorescent panels.
--
-- Buy the Key in the shop, use the framed door on the shop island to teleport in
-- (Backrooms.Enter). No entities. The client adds the fog. Exit doors are set INTO
-- the outer walls; one hidden object, lost somewhere in the maze, grants the unique
-- Backrooms card (Backrooms.Init's OnBackroomsCard callback) — once per player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local B = Config.Backrooms
local ORIGIN = B.Origin

local Backrooms = {}

local inBackrooms = {} -- player -> true
local callbacks = {}
local spawnCF = CFrame.new(ORIGIN)

-- ===== small builders ======================================================

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(180, 180, 180)
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

-- tile a texture onto the two broad faces of a wall (Front/Back) or one face
local function texture(part, faces, id, perTile)
	for _, face in faces do
		local t = Instance.new("Texture")
		t.Texture = id
		t.Face = face
		t.StudsPerTileU = perTile or 12
		t.StudsPerTileV = perTile or 12
		t.Parent = part
	end
end

-- ===== the door, set into a wall ===========================================
-- Builds a wall segment `wallWidth` wide with a door-sized opening (two jambs +
-- a lintel) and the metal door standing in the opening, facing cframe.LookVector.
-- Self-contained: fetches the MetalDoor template itself, so callers don't need to
-- know about Backrooms' internal state. Used for the maze exits AND, via require,
-- the shop-island entrance.
local DOOR_GAP_W = 14 -- the metal door is ~12.7 wide; leave a little margin
local DOOR_GAP_H = 10.5

function Backrooms.BuildFramedDoor(parent, cframe, opts)
	opts = opts or {}
	local wallWidth = opts.WallWidth or 24
	local wallHeight = opts.WallHeight or B.WallHeight
	local thick = opts.WallThick or B.WallThick
	local color = opts.WallColor or B.WallColor
	local material = opts.WallMaterial or Enum.Material.Plastic
	local texId = opts.WallTexture

	local frame = Instance.new("Model")
	frame.Name = "BackroomsDoorway"

	-- side panels (fill from the doorway edge out to ±wallWidth/2)
	local sidePanel = (wallWidth - DOOR_GAP_W) / 2
	if sidePanel > 0.5 then
		for _, dir in { 1, -1 } do
			local cx = dir * (DOOR_GAP_W / 2 + sidePanel / 2)
			local panel = makePart({
				Name = "Panel",
				Size = Vector3.new(sidePanel, wallHeight, thick),
				CFrame = cframe * CFrame.new(cx, wallHeight / 2, 0),
				Color = color,
				Material = material,
				Parent = frame,
			})
			if texId then
				texture(panel, { Enum.NormalId.Front, Enum.NormalId.Back }, texId, 12)
			end
		end
	end

	-- lintel above the opening
	if wallHeight - DOOR_GAP_H > 0.5 then
		local lintel = makePart({
			Name = "Lintel",
			Size = Vector3.new(DOOR_GAP_W, wallHeight - DOOR_GAP_H, thick),
			CFrame = cframe * CFrame.new(0, DOOR_GAP_H + (wallHeight - DOOR_GAP_H) / 2, 0),
			Color = color,
			Material = material,
			Parent = frame,
		})
		if texId then
			texture(lintel, { Enum.NormalId.Front, Enum.NormalId.Back }, texId, 12)
		end
	end

	-- the actual metal door, dropped into the opening
	local template = ReplicatedStorage:FindFirstChild("MetalDoor")
	local anchor
	if template then
		local door = template:Clone()
		for _, d in door:GetDescendants() do
			if d:IsA("BaseScript") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = true
			end
		end
		local bbcf, size = door:GetBoundingBox()
		local centerToPivot = bbcf:ToObjectSpace(door:GetPivot())
		door:PivotTo(cframe * CFrame.new(0, size.Y / 2, 0) * centerToPivot)
		door.Parent = frame
		anchor = door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true)
	else
		-- no template — a plain slab so the doorway is never empty
		anchor = makePart({
			Name = "Door",
			Size = Vector3.new(DOOR_GAP_W - 0.5, DOOR_GAP_H, 0.6),
			CFrame = cframe * CFrame.new(0, DOOR_GAP_H / 2, 0),
			Color = Color3.fromRGB(70, 64, 40),
			Material = Enum.Material.Metal,
			Parent = frame,
		})
	end

	if opts.OnTrigger and anchor then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = opts.ActionText or "Use"
		prompt.ObjectText = opts.ObjectText or ""
		prompt.HoldDuration = opts.HoldDuration or 0.3
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(opts.OnTrigger)
	end

	frame.Parent = parent
	return frame
end

-- ===== maze generation =====================================================

-- Carve a perfect maze with randomized DFS, then open it up. Returns two grids of
-- booleans: vwall[x][z] = wall between cell (x,z) and (x+1,z); hwall[x][z] = wall
-- between (x,z) and (x,z+1). true = wall present.
local function generateMaze(W, H)
	local vwall, hwall, visited = {}, {}, {}
	for x = 0, W - 1 do
		vwall[x], hwall[x], visited[x] = {}, {}, {}
		for z = 0, H - 1 do
			vwall[x][z] = true
			hwall[x][z] = true
			visited[x][z] = false
		end
	end

	-- iterative DFS (recursion would risk the Luau stack on big grids)
	local stack = { { math.random(0, W - 1), math.random(0, H - 1) } }
	visited[stack[1][1]][stack[1][2]] = true
	while #stack > 0 do
		local cur = stack[#stack]
		local x, z = cur[1], cur[2]
		local options = {}
		if x > 0 and not visited[x - 1][z] then table.insert(options, "W") end
		if x < W - 1 and not visited[x + 1][z] then table.insert(options, "E") end
		if z > 0 and not visited[x][z - 1] then table.insert(options, "S") end
		if z < H - 1 and not visited[x][z + 1] then table.insert(options, "N") end
		if #options == 0 then
			table.remove(stack)
		else
			local dir = options[math.random(1, #options)]
			if dir == "W" then
				vwall[x - 1][z] = false
				visited[x - 1][z] = true
				table.insert(stack, { x - 1, z })
			elseif dir == "E" then
				vwall[x][z] = false
				visited[x + 1][z] = true
				table.insert(stack, { x + 1, z })
			elseif dir == "S" then
				hwall[x][z - 1] = false
				visited[x][z - 1] = true
				table.insert(stack, { x, z - 1 })
			else
				hwall[x][z] = false
				visited[x][z + 1] = true
				table.insert(stack, { x, z + 1 })
			end
		end
	end

	-- knock out extra walls so it's open and loopy, not a tidy maze
	for x = 0, W - 1 do
		for z = 0, H - 1 do
			if x < W - 1 and vwall[x][z] and math.random() < B.ExtraOpenChance then
				vwall[x][z] = false
			end
			if z < H - 1 and hwall[x][z] and math.random() < B.ExtraOpenChance then
				hwall[x][z] = false
			end
		end
	end

	return vwall, hwall
end

-- ===== build =================================================================

local function cellCenter(W, H, gx, gz)
	local x = ORIGIN.X - W * B.Cell / 2 + (gx + 0.5) * B.Cell
	local z = ORIGIN.Z - H * B.Cell / 2 + (gz + 0.5) * B.Cell
	return x, z
end

-- Pick distinct outer-wall segments to leave open for exit doors. Each is one
-- cell wide on a given side; buildMap skips them and placeExits fills them.
local function chooseExits(W, H)
	local edges = {}
	for x = 0, W - 1 do
		table.insert(edges, { side = "S", i = x })
		table.insert(edges, { side = "N", i = x })
	end
	for z = 0, H - 1 do
		table.insert(edges, { side = "W", i = z })
		table.insert(edges, { side = "E", i = z })
	end
	for i = #edges, 2, -1 do
		local j = math.random(1, i)
		edges[i], edges[j] = edges[j], edges[i]
	end
	local exits, lookup = {}, {}
	for n = 1, math.min(B.ExitCount, #edges) do
		exits[n] = edges[n]
		lookup[edges[n].side .. ":" .. edges[n].i] = true
	end
	return exits, lookup
end

local function buildMap(exitLookup)
	local W, H, C = B.GridW, B.GridH, B.Cell
	local wallY = ORIGIN.Y + B.WallHeight / 2
	local map = Instance.new("Folder")
	map.Name = "BackroomsMap"

	-- floor + ceiling: one slab each, carpet texture tiled across
	local spanX, spanZ = W * C, H * C
	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(spanX, 2, spanZ),
		CFrame = CFrame.new(ORIGIN.X, ORIGIN.Y - 1, ORIGIN.Z),
		Color = B.FloorColor,
		Material = Enum.Material.Fabric,
		Parent = map,
	})
	texture(floor, { Enum.NormalId.Top }, B.FloorTexture, C)
	local ceiling = makePart({
		Name = "Ceiling",
		Size = Vector3.new(spanX, 1, spanZ),
		CFrame = CFrame.new(ORIGIN.X, ORIGIN.Y + B.WallHeight + 0.5, ORIGIN.Z),
		Color = B.CeilingColor,
		Material = Enum.Material.Concrete,
		Parent = map,
	})
	texture(ceiling, { Enum.NormalId.Bottom }, B.FloorTexture, C)

	-- interior walls
	local vwall, hwall = generateMaze(W, H)
	for x = 0, W - 1 do
		for z = 0, H - 1 do
			local cx, cz = cellCenter(W, H, x, z)
			if x < W - 1 and vwall[x][z] then
				local wall = makePart({
					Name = "Wall",
					Size = Vector3.new(B.WallThick, B.WallHeight, C),
					CFrame = CFrame.new(cx + C / 2, wallY, cz),
					Color = B.WallColor,
					Material = Enum.Material.Plastic,
					Parent = map,
				})
				texture(wall, { Enum.NormalId.Front, Enum.NormalId.Back }, B.WallTexture, 12)
			end
			if z < H - 1 and hwall[x][z] then
				local wall = makePart({
					Name = "Wall",
					Size = Vector3.new(C, B.WallHeight, B.WallThick),
					CFrame = CFrame.new(cx, wallY, cz + C / 2),
					Color = B.WallColor,
					Material = Enum.Material.Plastic,
					Parent = map,
				})
				texture(wall, { Enum.NormalId.Left, Enum.NormalId.Right }, B.WallTexture, 12)
			end
		end
	end

	-- solid outer perimeter (so you can't walk off the floor), with a one-cell gap
	-- left wherever an exit door will go
	local halfX, halfZ = W * C / 2, H * C / 2
	for x = 0, W - 1 do
		local cx = cellCenter(W, H, x, 0)
		if not (exitLookup and exitLookup["S:" .. x]) then
			local wall = makePart({ Name = "Wall", Size = Vector3.new(C, B.WallHeight, B.WallThick), CFrame = CFrame.new(cx, wallY, ORIGIN.Z - halfZ), Color = B.WallColor, Material = Enum.Material.Plastic, Parent = map })
			texture(wall, { Enum.NormalId.Left, Enum.NormalId.Right }, B.WallTexture, 12)
		end
		if not (exitLookup and exitLookup["N:" .. x]) then
			local wall = makePart({ Name = "Wall", Size = Vector3.new(C, B.WallHeight, B.WallThick), CFrame = CFrame.new(cx, wallY, ORIGIN.Z + halfZ), Color = B.WallColor, Material = Enum.Material.Plastic, Parent = map })
			texture(wall, { Enum.NormalId.Left, Enum.NormalId.Right }, B.WallTexture, 12)
		end
	end
	for z = 0, H - 1 do
		local _, cz = cellCenter(W, H, 0, z)
		if not (exitLookup and exitLookup["W:" .. z]) then
			local wall = makePart({ Name = "Wall", Size = Vector3.new(B.WallThick, B.WallHeight, C), CFrame = CFrame.new(ORIGIN.X - halfX, wallY, cz), Color = B.WallColor, Material = Enum.Material.Plastic, Parent = map })
			texture(wall, { Enum.NormalId.Front, Enum.NormalId.Back }, B.WallTexture, 12)
		end
		if not (exitLookup and exitLookup["E:" .. z]) then
			local wall = makePart({ Name = "Wall", Size = Vector3.new(B.WallThick, B.WallHeight, C), CFrame = CFrame.new(ORIGIN.X + halfX, wallY, cz), Color = B.WallColor, Material = Enum.Material.Plastic, Parent = map })
			texture(wall, { Enum.NormalId.Front, Enum.NormalId.Back }, B.WallTexture, 12)
		end
	end

	-- ceiling lights (fluorescent panels + a soft point light), shadows off so a
	-- few dozen lights stay playable
	for x = 0, W - 1, B.LightEvery do
		for z = 0, H - 1, B.LightEvery do
			local cx, cz = cellCenter(W, H, x, z)
			local panel = makePart({
				Name = "light",
				Size = Vector3.new(C * 0.5, 0.3, 2),
				CFrame = CFrame.new(cx, ORIGIN.Y + B.WallHeight - 0.2, cz),
				Color = Color3.fromRGB(255, 250, 225),
				Material = Enum.Material.Neon,
				Parent = map,
			})
			local light = Instance.new("PointLight")
			light.Brightness = 1.4
			light.Range = C * 1.6
			light.Color = Color3.fromRGB(255, 247, 215)
			light.Shadows = false
			light.Parent = panel
		end
	end

	return map
end

-- ===== exits + hidden reward ================================================

-- Fill each chosen perimeter gap with a framed door that faces inward, so every
-- exit is genuinely set into the outer wall.
local function placeExits(map, W, H, exits)
	local halfX, halfZ = W * B.Cell / 2, H * B.Cell / 2
	for _, e in exits do
		local centre, inward
		if e.side == "S" then
			local cx = cellCenter(W, H, e.i, 0)
			centre = Vector3.new(cx, ORIGIN.Y, ORIGIN.Z - halfZ)
			inward = Vector3.new(0, 0, 1)
		elseif e.side == "N" then
			local cx = cellCenter(W, H, e.i, 0)
			centre = Vector3.new(cx, ORIGIN.Y, ORIGIN.Z + halfZ)
			inward = Vector3.new(0, 0, -1)
		elseif e.side == "W" then
			local _, cz = cellCenter(W, H, 0, e.i)
			centre = Vector3.new(ORIGIN.X - halfX, ORIGIN.Y, cz)
			inward = Vector3.new(1, 0, 0)
		else
			local _, cz = cellCenter(W, H, 0, e.i)
			centre = Vector3.new(ORIGIN.X + halfX, ORIGIN.Y, cz)
			inward = Vector3.new(-1, 0, 0)
		end
		Backrooms.BuildFramedDoor(map, CFrame.lookAt(centre, centre + inward), {
			WallWidth = B.Cell,
			WallTexture = B.WallTexture,
			ActionText = "Leave",
			ObjectText = "🚪 Exit",
			OnTrigger = function(p)
				Backrooms.Leave(p)
			end,
		})
	end
end

-- One hidden object, dropped at a random far-from-spawn cell, grants the unique
-- Backrooms card. No billboard — you have to actually find it in the fog.
local function placeReward(map, W, H)
	local centreX, centreZ = math.floor(W / 2), math.floor(H / 2)
	local gx, gz
	repeat
		gx, gz = math.random(0, W - 1), math.random(0, H - 1)
	until math.abs(gx - centreX) + math.abs(gz - centreZ) >= math.floor((W + H) / 4)
	local cx, cz = cellCenter(W, H, gx, gz)

	local jug = Instance.new("Model")
	jug.Name = "AlmondWater"
	local body = makePart({
		Name = "Carton",
		Size = Vector3.new(1.6, 2.4, 1.6),
		CFrame = CFrame.new(cx, ORIGIN.Y + 1.2, cz),
		Color = Color3.fromRGB(245, 240, 220),
		Material = Enum.Material.SmoothPlastic,
		Parent = jug,
	})
	makePart({
		Name = "Cap",
		Size = Vector3.new(0.8, 0.5, 0.8),
		CFrame = CFrame.new(cx, ORIGIN.Y + 2.6, cz),
		Color = Color3.fromRGB(120, 150, 95),
		Material = Enum.Material.SmoothPlastic,
		Parent = jug,
	})
	jug.PrimaryPart = body
	local glow = Instance.new("PointLight")
	glow.Brightness = 2
	glow.Range = 10
	glow.Color = Color3.fromRGB(220, 235, 180)
	glow.Shadows = false
	glow.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = "???"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = true
	prompt.Parent = body
	-- the object PERSISTS (one shared maze, many players): the server grants the
	-- card only once per player, so everyone gets exactly one chance to find it
	prompt.Triggered:Connect(function(p)
		if callbacks.OnBackroomsCard then
			callbacks.OnBackroomsCard(p)
		end
	end)
end

-- ===== teleport in/out =====================================================

function Backrooms.IsInside(player)
	return inBackrooms[player] == true
end

function Backrooms.Enter(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	inBackrooms[player] = true
	root.CFrame = spawnCF
end

function Backrooms.Leave(player)
	inBackrooms[player] = nil
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and callbacks.GetHomeCFrame then
		root.CFrame = callbacks.GetHomeCFrame()
	end
end

function Backrooms.Init(opts)
	callbacks = opts or {}

	local W, H = B.GridW, B.GridH
	local exits, exitLookup = chooseExits(W, H)
	local map = buildMap(exitLookup)
	placeExits(map, W, H, exits)
	placeReward(map, W, H)
	map.Parent = workspace

	-- spawn on the floor at the centre cell
	local sx, sz = cellCenter(W, H, math.floor(W / 2), math.floor(H / 2))
	spawnCF = CFrame.new(sx, ORIGIN.Y + 4, sz)

	Players.PlayerRemoving:Connect(function(player)
		inBackrooms[player] = nil
	end)
end

return Backrooms
