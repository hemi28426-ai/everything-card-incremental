-- Backrooms (Level 0): the real uploaded map (ServerStorage.BackroomsMap) dropped
-- far from the main world. Buy the Key in the shop, use the door behind the
-- cashier to teleport in. No entities. The client adds the fog. Scattered exit
-- doors take you home; one hidden button grants a free Card Pack.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local ORIGIN = Config.Backrooms.Origin

local Backrooms = {}

local inBackrooms = {} -- player -> true
local callbacks = {}
local doorTemplate
local spawnCF = CFrame.new(ORIGIN)
local floorTopY = ORIGIN.Y

-- Clone the metal door, strip its swing script, anchor it, stand it on the
-- floor, and wire a single E prompt to `onTrigger`.
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
	doorTemplate = ReplicatedStorage:FindFirstChild("MetalDoor")

	local template = ServerStorage:FindFirstChild("BackroomsMap")
	if not template then
		warn("[ECI] BackroomsMap not found (is assets/Backrooms.rbxmx mounted?)")
		return
	end
	local map = template:Clone()
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			d.Shadows = false -- 400 shadow lights would be unplayable
		end
	end
	-- drop it far away: floor bottom -> ORIGIN.Y, centre -> ORIGIN x/z
	local cf, size = map:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	map:TranslateBy(Vector3.new(ORIGIN.X - cf.Position.X, ORIGIN.Y - bottom, ORIGIN.Z - cf.Position.Z))
	map.Name = "BackroomsMap"
	map.Parent = workspace

	floorTopY = ORIGIN.Y + 1
	spawnCF = CFrame.new(ORIGIN.X, ORIGIN.Y + 5, ORIGIN.Z)

	-- scattered exit doors (you find them in the fog)
	local exits = {
		Vector3.new(150, 0, 150),
		Vector3.new(-160, 0, 130),
		Vector3.new(130, 0, -170),
		Vector3.new(-140, 0, -150),
		Vector3.new(0, 0, 190),
		Vector3.new(190, 0, 0),
	}
	for _, e in exits do
		Backrooms.BuildDoor(
			map,
			CFrame.new(ORIGIN.X + e.X, floorTopY, ORIGIN.Z + e.Z) * CFrame.Angles(0, math.rad(math.random(0, 3) * 90), 0),
			"Leave",
			"🚪 Exit",
			function(p)
				Backrooms.Leave(p)
			end
		)
	end

	-- one hidden free-pack button at a random spot — a small pad you click (E)
	local rx, rz = math.random(-180, 180), math.random(-180, 180)
	local pad = Instance.new("Part")
	pad.Name = "FreePackButton"
	pad.Anchored = true
	pad.Size = Vector3.new(3, 1, 3)
	pad.Position = Vector3.new(ORIGIN.X + rx, floorTopY + 0.5, ORIGIN.Z + rz)
	pad.Color = Color3.fromRGB(150, 110, 220)
	pad.Material = Enum.Material.Neon
	pad.Parent = map
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = "Card Pack"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(function(p)
		if callbacks.OnFreePack then
			callbacks.OnFreePack(p)
		end
		pad:Destroy()
	end)

	Players.PlayerRemoving:Connect(function(player)
		inBackrooms[player] = nil
	end)
end

return Backrooms
