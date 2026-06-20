-- Backrooms (Level 0): an endless procedurally-generated yellow maze built far
-- from the main world (Config.Backrooms.Origin). Only players who've teleported
-- in get chunks generated around them. No entities. The client adds the fog so
-- "you can't see the end". Rare exit doors take you home; a rare free-pack button
-- grants a random Card Pack.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local B = Config.Backrooms
local CS = B.ChunkSize
local ORIGIN = B.Origin

local Backrooms = {}

local inBackrooms = {} -- player -> true
local generatedChunks = {} -- "cx,cz" -> Model
local callbacks = {}
local mapFolder
local doorTemplate

-- ===== helpers =============================================================

local function chunkWorld(cx, cz)
	return ORIGIN.X + cx * CS, ORIGIN.Z + cz * CS
end

local function part(parent, name, size, pos, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function tex(parent, id, face, color, u, v, transparency)
	local t = Instance.new("Texture")
	t.Texture = id
	t.Face = face
	t.Color3 = color or Color3.fromRGB(255, 255, 255)
	t.StudsPerTileU = u or 5
	t.StudsPerTileV = v or 6
	if transparency then
		t.Transparency = transparency
	end
	t.Parent = parent
end

local function wall(parent, pos, size, isPillar)
	local w = part(parent, "wall", size, pos, B.WallColor, Enum.Material.SmoothPlastic)
	local faces = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
	for _, face in faces do
		tex(w, B.WallTexture, face, Color3.fromRGB(255, 255, 255), isPillar and 3 or 5, 6)
		tex(w, B.WallTexture2, face, Color3.fromRGB(255, 252, 230), isPillar and 3 or 5, 6, 0.45)
	end
	return w
end

-- ===== chunk generation ====================================================

local function generateChunk(cx, cz)
	local key = cx .. "," .. cz
	if generatedChunks[key] then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Chunk_" .. key
	model.Parent = mapFolder
	generatedChunks[key] = model

	local wx, wz = chunkWorld(cx, cz)

	-- floor
	local floor = part(model, "floor", Vector3.new(CS, 1, CS), Vector3.new(wx, ORIGIN.Y - 0.5, wz), B.FloorColor, Enum.Material.Fabric)
	tex(floor, B.FloorTexture, Enum.NormalId.Top, Color3.fromRGB(255, 235, 120), 3, 3, 0.55)

	-- ceiling
	local ceiling = part(model, "ceiling", Vector3.new(CS, 1, CS), Vector3.new(wx, ORIGIN.Y + B.WallHeight + 0.5, wz), B.CeilingColor, Enum.Material.Plaster)
	tex(ceiling, B.CeilingTexture, Enum.NormalId.Bottom, Color3.fromRGB(255, 244, 224), 6, 6)

	-- procedural maze walls (math.noise, deterministic)
	local nx = math.noise(cx * 0.35, cz * 0.35, 1337)
	local nz = math.noise(cx * 0.35, cz * 0.35, 1457)
	local np = math.noise(cx * 0.5, cz * 0.5, 1587)
	-- always keep the spawn chunk (and its neighbours) open so you never land in a wall
	local nearSpawn = math.abs(cx) <= 1 and math.abs(cz) <= 1

	if not nearSpawn and nx > 0.08 then
		wall(model, Vector3.new(wx, ORIGIN.Y + B.WallHeight / 2, wz - CS / 2), Vector3.new(CS, B.WallHeight, B.WallThickness), false)
	end
	if not nearSpawn and nz > 0.08 then
		wall(model, Vector3.new(wx - CS / 2, ORIGIN.Y + B.WallHeight / 2, wz), Vector3.new(B.WallThickness, B.WallHeight, CS), false)
	end
	local hasPillar = not nearSpawn and np > 0.3 and nx <= 0.08 and nz <= 0.08
	if hasPillar then
		wall(model, Vector3.new(wx, ORIGIN.Y + B.WallHeight / 2, wz), Vector3.new(4, B.WallHeight, 4), true)
	end

	-- fluorescent ceiling panels everywhere (cheap Neon glow for the look), with a
	-- real PointLight on some of them so the maze is actually lit (shadows off for
	-- performance — there can be a lot of these on screen)
	if not hasPillar then
		local panel = part(model, "lightpanel", Vector3.new(5, 0.4, 5), Vector3.new(wx, ORIGIN.Y + B.WallHeight - 0.1, wz), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
		if math.noise(cx * 0.8, cz * 0.8, 99) > 0.05 then
			local pl = Instance.new("PointLight")
			pl.Brightness = 1.4
			pl.Color = Color3.fromRGB(255, 246, 200)
			pl.Range = 28
			pl.Shadows = false
			pl.Parent = panel
		end
	end

	-- rare exit door (clone the metal door, no swing, just an E to go home)
	if not nearSpawn and not hasPillar and math.random() < B.ExitDoorChance and doorTemplate then
		local cf = CFrame.new(wx, ORIGIN.Y, wz) * CFrame.Angles(0, math.rad(math.random(0, 3) * 90), 0)
		Backrooms.BuildDoor(model, cf, "Leave", "🚪 Exit", function(player)
			Backrooms.Leave(player)
		end)
	end

	-- rare free card-pack button
	if not nearSpawn and not hasPillar and math.random() < B.PackButtonChance then
		local pad = part(model, "FreePackButton", Vector3.new(6, 1.4, 6), Vector3.new(wx, ORIGIN.Y + 0.7, wz), Color3.fromRGB(120, 90, 200), Enum.Material.Neon)
		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromOffset(220, 70)
		board.StudsOffset = Vector3.new(0, 4, 0)
		board.AlwaysOnTop = true
		board.MaxDistance = 60
		board.Parent = pad
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.fromRGB(220, 190, 255)
		lbl.Text = "🎁 FREE CARD PACK"
		lbl.Parent = board
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take"
		prompt.ObjectText = "Free Card Pack"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		prompt.Triggered:Connect(function(player)
			if callbacks.OnFreePack then
				callbacks.OnFreePack(player)
			end
			pad:Destroy() -- one free pack per button
		end)
	end
end

-- ===== doors ===============================================================

-- Clone the metal door, strip its swing script, anchor it, sit it on the floor,
-- and wire a single E prompt to `onTrigger`.
function Backrooms.BuildDoor(parent, cframe, actionText, objectText, onTrigger)
	if not doorTemplate then
		return
	end
	local door = doorTemplate:Clone()
	for _, d in door:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	-- stand it on the floor: move the bounding-box centre to cframe + up*height/2,
	-- independent of where the model's pivot happens to be
	local bbcf, size = door:GetBoundingBox()
	local centerToPivot = bbcf:ToObjectSpace(door:GetPivot())
	door:PivotTo(cframe * CFrame.new(0, size.Y / 2, 0) * centerToPivot)
	door.Parent = parent
	local anchor = door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(onTrigger)
	return door
end

-- ===== enter / leave =======================================================

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
	-- make sure the landing area exists, then drop the player in
	for x = -2, 2 do
		for z = -2, 2 do
			generateChunk(x, z)
		end
	end
	root.CFrame = CFrame.new(ORIGIN.X, ORIGIN.Y + 4, ORIGIN.Z)
end

function Backrooms.Leave(player)
	inBackrooms[player] = nil
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and callbacks.GetHomeCFrame then
		root.CFrame = callbacks.GetHomeCFrame()
	end
end

-- ===== streaming loop ======================================================

local function playerChunk(pos)
	local cx = math.floor((pos.X - ORIGIN.X + CS / 2) / CS)
	local cz = math.floor((pos.Z - ORIGIN.Z + CS / 2) / CS)
	return cx, cz
end

local function updateMap()
	local active = {}
	local anyInside = false
	for player in inBackrooms do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			anyInside = true
			local pcx, pcz = playerChunk(root.Position)
			for x = -B.RenderDistance, B.RenderDistance do
				for z = -B.RenderDistance, B.RenderDistance do
					local key = (pcx + x) .. "," .. (pcz + z)
					active[key] = true
					generateChunk(pcx + x, pcz + z)
				end
			end
		end
	end
	-- tear down chunks no one is near (only while someone's inside, so the maze
	-- fully clears out once everybody leaves)
	for key, model in generatedChunks do
		if not active[key] then
			model:Destroy()
			generatedChunks[key] = nil
		end
	end
	return anyInside
end

function Backrooms.Init(opts)
	callbacks = opts or {}
	doorTemplate = ReplicatedStorage:FindFirstChild("MetalDoor")

	mapFolder = Instance.new("Folder")
	mapFolder.Name = "BackroomsMap"
	mapFolder.Parent = workspace

	Players.PlayerRemoving:Connect(function(player)
		inBackrooms[player] = nil
	end)

	local last = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() - last > 0.4 then
			last = os.clock()
			updateMap()
		end
	end)
end

return Backrooms
