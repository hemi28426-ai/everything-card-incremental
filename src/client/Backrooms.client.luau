-- Backrooms client ambience: dim, foggy lighting whenever the LOCAL player is in
-- the far-off Backrooms region. Client-only, so it never affects the main world
-- for anyone else, and the fog is what makes it so "you can't see the end".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local B = Config.Backrooms
local player = Players.LocalPlayer

local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
local saved = {
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
	FogEnd = Lighting.FogEnd,
	FogStart = Lighting.FogStart,
	FogColor = Lighting.FogColor,
	ClockTime = Lighting.ClockTime,
	GlobalShadows = Lighting.GlobalShadows,
	AtmosDensity = atmos and atmos.Density or nil,
}
local inside = false

local function setBackrooms(on)
	if on == inside then
		return
	end
	inside = on
	if on then
		Lighting.Ambient = Color3.fromRGB(48, 45, 33)
		Lighting.OutdoorAmbient = Color3.fromRGB(18, 17, 11)
		Lighting.Brightness = 0.4
		Lighting.ClockTime = 0
		Lighting.GlobalShadows = true
		Lighting.FogColor = Color3.fromRGB(120, 112, 70)
		Lighting.FogStart = 12
		Lighting.FogEnd = B.FogEnd
		if atmos then
			atmos.Density = 0.05
		end
	else
		Lighting.Ambient = saved.Ambient
		Lighting.OutdoorAmbient = saved.OutdoorAmbient
		Lighting.Brightness = saved.Brightness
		Lighting.ClockTime = saved.ClockTime
		Lighting.GlobalShadows = saved.GlobalShadows
		Lighting.FogColor = saved.FogColor
		Lighting.FogStart = saved.FogStart
		Lighting.FogEnd = saved.FogEnd
		if atmos and saved.AtmosDensity then
			atmos.Density = saved.AtmosDensity
		end
	end
end

local origin2d = Vector3.new(B.Origin.X, 0, B.Origin.Z)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then
		return
	end
	acc = 0
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
		setBackrooms((flat - origin2d).Magnitude < 50000)
	end
end)
