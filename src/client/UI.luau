-- Builds the entire interface from code (no manual Studio UI work needed)
-- and exposes :Update(state) to refresh it whenever the server sends new data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local COLORS = {
	Panel = Color3.fromRGB(28, 30, 40),
	PanelLight = Color3.fromRGB(44, 47, 62),
	Accent = Color3.fromRGB(255, 196, 60),
	AccentDark = Color3.fromRGB(80, 52, 0),
	Green = Color3.fromRGB(70, 200, 120),
	Red = Color3.fromRGB(235, 87, 87),
	Text = Color3.fromRGB(240, 240, 245),
	TextDim = Color3.fromRGB(160, 165, 180),
	Disabled = Color3.fromRGB(70, 74, 90),
}

local function create(className, props)
	local instance: any = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function addCorner(parent, radius)
	create("UICorner", { CornerRadius = radius or UDim.new(0, 12), Parent = parent })
end

local function addStroke(parent, color, thickness)
	create("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function countUpgrades(upgrades)
	local total = 0
	for _, amount in upgrades do
		total += amount
	end
	return total
end

local UI = {}
UI.__index = UI

function UI.new(callbacks)
	local self = setmetatable({}, UI)
	self.Callbacks = callbacks
	self.State = nil
	self.UpgradeRows = {}
	self.RebirthArmed = false
	self.RebirthArmToken = 0
	self:Build()
	return self
end

function UI:Build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = create("ScreenGui", {
		Name = "ClickEmpireUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	self.ScreenGui = screenGui

	-- sounds (built-in engine sounds, so they always load)
	self.ClickSound = create("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Parent = screenGui })
	self.BuySound = create("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, PlaybackSpeed = 0.55, Parent = screenGui })
	self.RebirthSound = create("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, PlaybackSpeed = 1.5, Parent = screenGui })

	-- top-center stats card -------------------------------------------------
	local stats = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(320, 96),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
		Parent = screenGui,
	})
	addCorner(stats, UDim.new(0, 16))
	addStroke(stats, COLORS.Accent, 2)

	self.CashLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 6),
		Size = UDim2.new(1, 0, 0, 42),
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextColor3 = COLORS.Accent,
		Text = "$0",
		Parent = stats,
	})

	self.RateLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = COLORS.Text,
		Text = "+1 per click  •  +0 per sec",
		Parent = stats,
	})

	self.MultLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 68),
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = COLORS.TextDim,
		Text = "Rebirth boost: x1",
		Parent = stats,
	})

	-- the big CLICK button --------------------------------------------------
	local clickButton = create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(170, 170),
		BackgroundColor3 = COLORS.Accent,
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextColor3 = COLORS.AccentDark,
		Text = "CLICK!",
		AutoButtonColor = true,
		Parent = screenGui,
	})
	addCorner(clickButton, UDim.new(1, 0))
	addStroke(clickButton, Color3.fromRGB(255, 235, 170), 4)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 224, 110), Color3.fromRGB(255, 168, 35)),
		Rotation = 90,
		Parent = clickButton,
	})
	self.ClickScale = create("UIScale", { Parent = clickButton })
	self.ClickButton = clickButton

	clickButton.Activated:Connect(function()
		self.ClickScale.Scale = 0.9
		TweenService:Create(self.ClickScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		self.ClickSound:Play()
		if self.State then
			self:SpawnFloatingText("+" .. Format(self.State.ClickPower), COLORS.Accent)
		end
		self.Callbacks.OnClick()
	end)

	self:BuildShop()
	self:BuildRebirth()
end

-- shop panel (left side) ---------------------------------------------------
function UI:BuildShop()
	local toggle = create("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(110, 48),
		BackgroundColor3 = COLORS.Green,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = COLORS.Text,
		Text = "🛒 Shop",
		Parent = self.ScreenGui,
	})
	addCorner(toggle, UDim.new(0, 14))

	local panel = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 132, 0.5, 0),
		Size = UDim2.new(0, 330, 0.85, 0),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.05,
		Visible = true,
		Parent = self.ScreenGui,
	})
	create("UISizeConstraint", { MaxSize = Vector2.new(330, 540), Parent = panel })
	addCorner(panel, UDim.new(0, 16))
	addStroke(panel, COLORS.PanelLight, 2)
	self.ShopPanel = panel
	self.ShopToggle = toggle

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 8),
		Size = UDim2.new(1, -32, 0, 36),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextColor3 = COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "UPGRADES",
		Parent = panel,
	})

	local scroll = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 48),
		Size = UDim2.new(1, -20, 1, -58),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	})
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = scroll,
	})

	for i, upgrade in Config.Upgrades do
		local row = create("Frame", {
			Size = UDim2.new(1, -8, 0, 64),
			BackgroundColor3 = COLORS.PanelLight,
			LayoutOrder = i,
			Parent = scroll,
		})
		addCorner(row, UDim.new(0, 12))

		local nameLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 8),
			Size = UDim2.new(1, -120, 0, 22),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = COLORS.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = upgrade.Name,
			Parent = row,
		})

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 32),
			Size = UDim2.new(1, -120, 0, 20),
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = COLORS.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = upgrade.Desc,
			Parent = row,
		})

		local buyButton = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(92, 44),
			BackgroundColor3 = COLORS.Disabled,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = COLORS.Text,
			Text = "$" .. Format(upgrade.BaseCost),
			AutoButtonColor = false,
			Parent = row,
		})
		addCorner(buyButton, UDim.new(0, 10))

		buyButton.Activated:Connect(function()
			self.Callbacks.OnBuy(upgrade.Id)
		end)

		self.UpgradeRows[upgrade.Id] = {
			Upgrade = upgrade,
			NameLabel = nameLabel,
			BuyButton = buyButton,
		}
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		toggle.Text = panel.Visible and "✕ Close" or "🛒 Shop"
	end)
	toggle.Text = "✕ Close" -- shop starts open
end

-- rebirth panel (top right) ------------------------------------------------
function UI:BuildRebirth()
	local toggle = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(130, 48),
		BackgroundColor3 = COLORS.Red,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = COLORS.Text,
		Text = "⭐ Rebirth",
		Parent = self.ScreenGui,
	})
	addCorner(toggle, UDim.new(0, 14))

	local panel = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 66),
		Size = UDim2.fromOffset(300, 196),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = self.ScreenGui,
	})
	addCorner(panel, UDim.new(0, 16))
	addStroke(panel, COLORS.Red, 2)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 10),
		Size = UDim2.new(1, -32, 0, 28),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = COLORS.Red,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "⭐ REBIRTH",
		Parent = panel,
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 40),
		Size = UDim2.new(1, -32, 0, 56),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = COLORS.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Reset your cash and upgrades in exchange for a permanent boost to everything you earn!",
		Parent = panel,
	})

	self.RebirthInfo = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 98),
		Size = UDim2.new(1, -32, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = COLORS.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Cost: $100K   •   Next boost: x2",
		Parent = panel,
	})

	self.RebirthConfirm = create("TextButton", {
		Position = UDim2.new(0, 16, 1, -56),
		Size = UDim2.new(1, -32, 0, 44),
		BackgroundColor3 = COLORS.Disabled,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = COLORS.Text,
		Text = "Rebirth",
		AutoButtonColor = false,
		Parent = panel,
	})
	addCorner(self.RebirthConfirm, UDim.new(0, 10))

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	self.RebirthConfirm.Activated:Connect(function()
		local state = self.State
		if not state or state.Cash < state.RebirthCost then
			return
		end
		if self.RebirthArmed then
			self.RebirthArmed = false
			self.RebirthConfirm.Text = "Rebirth"
			self.Callbacks.OnRebirth()
		else
			self.RebirthArmed = true
			self.RebirthArmToken += 1
			local token = self.RebirthArmToken
			self.RebirthConfirm.Text = "Click again to confirm!"
			task.delay(3, function()
				if self.RebirthArmToken == token and self.RebirthArmed then
					self.RebirthArmed = false
					self.RebirthConfirm.Text = "Rebirth"
				end
			end)
		end
	end)
end

-- floating "+5" text above the click button ---------------------------------
function UI:SpawnFloatingText(text, color)
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, math.random(-80, 80), 1, -210),
		Size = UDim2.fromOffset(160, 32),
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
		TextColor3 = color or COLORS.Accent,
		TextStrokeTransparency = 0.6,
		Text = text,
		Parent = self.ScreenGui,
	})
	local tween = TweenService:Create(
		label,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = label.Position - UDim2.fromOffset(0, 90),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	tween.Completed:Once(function()
		label:Destroy()
	end)
	tween:Play()
end

-- refresh every label/button from the latest server state -------------------
function UI:Update(state)
	local previous = self.State
	self.State = state

	-- celebrate things that just happened
	if previous then
		if state.Rebirths > previous.Rebirths then
			self.RebirthSound:Play()
			self:SpawnFloatingText(("REBIRTH! x%s earnings"):format(state.Multiplier), COLORS.Red)
		elseif countUpgrades(state.Upgrades) > countUpgrades(previous.Upgrades) then
			self.BuySound:Play()
		end
	end

	self.CashLabel.Text = "$" .. Format(state.Cash)
	self.RateLabel.Text = ("+%s per click  •  +%s per sec"):format(Format(state.ClickPower), Format(state.AutoPower))
	self.MultLabel.Text = ("Rebirth boost: x%s"):format(state.Multiplier)

	for id, row in self.UpgradeRows do
		local owned = state.Upgrades[id] or 0
		local cost = Config.GetUpgradeCost(row.Upgrade, owned)
		if owned > 0 then
			row.NameLabel.Text = ("%s  ×%d"):format(row.Upgrade.Name, owned)
		else
			row.NameLabel.Text = row.Upgrade.Name
		end
		row.BuyButton.Text = "$" .. Format(cost)
		local affordable = state.Cash >= cost
		row.BuyButton.BackgroundColor3 = if affordable then COLORS.Green else COLORS.Disabled
		row.BuyButton.AutoButtonColor = affordable
	end

	self.RebirthInfo.Text = ("Cost: $%s   •   Next boost: x%s"):format(Format(state.RebirthCost), state.NextMultiplier)
	local canRebirth = state.Cash >= state.RebirthCost
	self.RebirthConfirm.BackgroundColor3 = if canRebirth then COLORS.Red else COLORS.Disabled
	self.RebirthConfirm.AutoButtonColor = canRebirth
	if not self.RebirthArmed then
		self.RebirthConfirm.Text = if canRebirth then "Rebirth" else "Not enough cash"
	end
end

return UI
