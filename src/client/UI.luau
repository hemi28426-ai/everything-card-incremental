-- HUD (coins / roll button / auto toggle), the collection panel, per-player
-- upgrade pad billboards, and the announcement ticker. Built entirely from
-- code; :Update(state) refreshes everything from the latest server state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local COLORS = {
	Panel = Color3.fromRGB(30, 22, 48),
	PanelLight = Color3.fromRGB(48, 38, 72),
	Purple = Color3.fromRGB(150, 90, 255),
	PurpleDark = Color3.fromRGB(40, 20, 8),
	Gold = Color3.fromRGB(255, 215, 60),
	Green = Color3.fromRGB(80, 200, 120),
	Red = Color3.fromRGB(235, 87, 87),
	Text = Color3.fromRGB(240, 238, 248),
	TextDim = Color3.fromRGB(160, 152, 185),
	Disabled = Color3.fromRGB(70, 64, 95),
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

local UI = {}
UI.__index = UI

function UI.new(callbacks)
	local self = setmetatable({}, UI)
	self.Callbacks = callbacks
	self.State = nil
	self.Cards = {} -- latest full card collection from the server
	self.Pads = {}
	self.CollectionDirty = false
	self.RebuildScheduled = false
	self.TickerToken = 0
	self:Build()
	return self
end

function UI:Build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = create("ScreenGui", {
		Name = "ECIUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	self.ScreenGui = screenGui

	self.ClickSound = create("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Parent = screenGui })
	self.BuySound = create("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, PlaybackSpeed = 0.55, Parent = screenGui })

	-- top stats card
	local stats = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(340, 112),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
		Parent = screenGui,
	})
	addCorner(stats, UDim.new(0, 16))
	create("UIStroke", { Color = COLORS.Purple, Thickness = 2, Parent = stats })

	self.CoinsLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 6),
		Size = UDim2.new(1, 0, 0, 38),
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = COLORS.Gold,
		Text = "🪙 0",
		Parent = stats,
	})
	self.RateLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 44),
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = COLORS.Text,
		Text = "+1 coins/s",
		Parent = stats,
	})
	self.RollsLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 64),
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = COLORS.TextDim,
		Text = "Rolls: 0",
		Parent = stats,
	})
	self.TokenLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 84),
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Gold,
		Text = "⭐ Tokens: 0  •  Rebirths: 0",
		Parent = stats,
	})

	-- ticker (announcements)
	self.TickerLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.new(0, 500, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = COLORS.Gold,
		TextTransparency = 1,
		Text = "",
		Parent = screenGui,
	})

	-- ROLL button
	local rollButton = create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(230, 84),
		BackgroundColor3 = COLORS.Purple,
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = COLORS.Text,
		Text = "ROLL",
		AutoButtonColor = true,
		Parent = screenGui,
	})
	addCorner(rollButton, UDim.new(0, 18))
	create("UIStroke", { Color = Color3.fromRGB(210, 170, 255), Thickness = 3, Parent = rollButton })
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(170, 110, 255), Color3.fromRGB(110, 50, 220)),
		Rotation = 90,
		Parent = rollButton,
	})
	self.RollButton = rollButton

	self.MultiBadge = create("TextLabel", {
		BackgroundColor3 = COLORS.Gold,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(40, 22),
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(60, 40, 0),
		Text = "x2",
		Visible = false,
		Parent = rollButton,
	})
	addCorner(self.MultiBadge, UDim.new(0, 8))

	-- cooldown fill (shrinks left as cooldown runs)
	self.CooldownFill = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.55,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 2,
		Parent = rollButton,
	})
	addCorner(self.CooldownFill, UDim.new(0, 18))

	local rollScale = create("UIScale", { Parent = rollButton })
	rollButton.Activated:Connect(function()
		rollScale.Scale = 0.92
		TweenService:Create(rollScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		self.ClickSound:Play()
		self.Callbacks.OnRoll()
	end)

	-- AUTO toggle (appears once unlocked)
	self.AutoButton = create("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 130, 1, -42),
		Size = UDim2.fromOffset(110, 48),
		BackgroundColor3 = COLORS.Disabled,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = COLORS.Text,
		Text = "AUTO: OFF",
		Visible = false,
		Parent = screenGui,
	})
	addCorner(self.AutoButton, UDim.new(0, 14))
	self.AutoButton.Activated:Connect(function()
		self.Callbacks.OnToggleAuto()
	end)

	self:BuildCollection()
	self:BuildSettings()
	self:BuildRebirthModal()
	task.spawn(function()
		self:BuildPadSurfaces()
	end)

	-- dev cheat menu (only for Hemi286)
	if Players.LocalPlayer.UserId == 508290827 then
		self:BuildDevCheat()
	end
end

function UI:BuildDevCheat()
	local devPanel = create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -112),
		Size = UDim2.fromOffset(200, 132),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
		Parent = self.ScreenGui,
	})
	addCorner(devPanel, UDim.new(0, 12))
	create("UIStroke", { Color = COLORS.Red, Thickness = 2, Parent = devPanel })

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -40, 0, 16),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = COLORS.Red,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "DEV CHEAT",
		Parent = devPanel,
	})

	-- a small re-open chip that sits where the panel was, hidden until closed
	local reopen = create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -112),
		Size = UDim2.fromOffset(54, 26),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = COLORS.Red,
		Text = "🛠 DEV",
		Visible = false,
		Parent = self.ScreenGui,
	})
	addCorner(reopen, UDim.new(0, 8))
	create("UIStroke", { Color = COLORS.Red, Thickness = 2, Parent = reopen })

	-- close (✕) button
	local closeBtn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 4),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = COLORS.Red,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Text,
		Text = "✕",
		Parent = devPanel,
	})
	addCorner(closeBtn, UDim.new(0, 6))
	closeBtn.Activated:Connect(function()
		devPanel.Visible = false
		reopen.Visible = true
	end)
	reopen.Activated:Connect(function()
		devPanel.Visible = true
		reopen.Visible = false
	end)

	-- one labelled "Coins: [input] [Set]" row factory
	local function field(y, placeholder, command)
		local input = create("TextBox", {
			BackgroundColor3 = COLORS.PanelLight,
			Position = UDim2.new(0, 8, 0, y),
			Size = UDim2.new(1, -64, 0, 24),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = COLORS.Text,
			ClearTextOnFocus = false,
			PlaceholderText = placeholder,
			Text = "",
			Parent = devPanel,
		})
		addCorner(input)
		local setButton = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = COLORS.Red,
			Position = UDim2.new(1, -8, 0, y),
			Size = UDim2.fromOffset(48, 24),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = COLORS.Text,
			Text = "Set",
			Parent = devPanel,
		})
		addCorner(setButton)
		setButton.Activated:Connect(function()
			local amount = tonumber(input.Text)
			if amount then
				self.Callbacks.DevCheat(command, amount)
			end
		end)
	end

	field(26, "Coins", "SetCoins")
	field(58, "Tokens", "SetTokens")
end

-- ===== settings (auto-sell) ================================================

function UI:BuildSettings()
	local toggle = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = COLORS.PanelLight,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = COLORS.Text,
		Text = "⚙️",
		Parent = self.ScreenGui,
	})
	addCorner(toggle, UDim.new(0, 14))

	local panel = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 66),
		Size = UDim2.fromOffset(250, 350),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = self.ScreenGui,
	})
	addCorner(panel, UDim.new(0, 16))
	create("UIStroke", { Color = COLORS.PanelLight, Thickness = 2, Parent = panel })

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -28, 0, 22),
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "SETTINGS",
		Parent = panel,
	})
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 32),
		Size = UDim2.new(1, -28, 0, 16),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = COLORS.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Auto-sell (skip) rarities:",
		Parent = panel,
	})

	-- a scrolling list with one toggle per rarity (every tier can be skipped)
	local sellScroll = create("ScrollingFrame", {
		Position = UDim2.new(0, 10, 0, 52),
		Size = UDim2.new(1, -20, 0, 132),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.PanelLight,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	})
	create("UIListLayout", { Padding = UDim.new(0, 3), Parent = sellScroll })

	self.AutoSellButtons = {}
	for _, tier in Config.Tiers do
		local tierName = tier.Name
		local row = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 0, 26),
			Parent = sellScroll,
		})
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 4, 0, 0),
			Size = UDim2.new(1, -76, 1, 0),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = tier.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = tierName,
			Parent = row,
		})
		local button = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			Size = UDim2.fromOffset(60, 22),
			BackgroundColor3 = COLORS.Disabled,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = COLORS.Text,
			Text = "OFF",
			Parent = row,
		})
		addCorner(button, UDim.new(0, 7))
		button.Activated:Connect(function()
			local current = self.State and self.State.AutoSell[tierName] == true
			self.Callbacks.OnSetAutoSell(tierName, not current)
		end)
		self.AutoSellButtons[tierName] = button
	end

	-- ===== auto-rebirth (unlocked on the green island) =====
	create("Frame", {
		Position = UDim2.new(0, 14, 0, 192),
		Size = UDim2.new(1, -28, 0, 2),
		BackgroundColor3 = COLORS.PanelLight,
		BorderSizePixel = 0,
		Parent = panel,
	})
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 200),
		Size = UDim2.new(1, -28, 0, 20),
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = COLORS.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "⭐ AUTO-REBIRTH",
		Parent = panel,
	})
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 224),
		Size = UDim2.new(1, -100, 0, 28),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Enabled",
		Parent = panel,
	})
	local rebirthToggle = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 224),
		Size = UDim2.fromOffset(64, 28),
		BackgroundColor3 = COLORS.Disabled,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Text,
		Text = "OFF",
		Parent = panel,
	})
	addCorner(rebirthToggle, UDim.new(0, 8))
	self.AutoRebirthToggle = rebirthToggle
	rebirthToggle.Activated:Connect(function()
		local on = self.State and self.State.AutoRebirthOn == true
		local tokens = self.State and self.State.AutoRebirthTokens or 10
		self.Callbacks.OnSetAutoRebirth(not on, tokens)
	end)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 258),
		Size = UDim2.new(1, -100, 0, 28),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Rebirth at (tokens)",
		Parent = panel,
	})
	local tokenInput = create("TextBox", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 258),
		Size = UDim2.fromOffset(64, 28),
		BackgroundColor3 = COLORS.PanelLight,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = COLORS.Text,
		ClearTextOnFocus = false,
		Text = "10",
		Parent = panel,
	})
	addCorner(tokenInput, UDim.new(0, 8))
	self.AutoRebirthInput = tokenInput
	tokenInput.FocusLost:Connect(function()
		local value = math.floor(tonumber(tokenInput.Text) or 0)
		if value < 1 then
			value = 1
		end
		local on = self.State and self.State.AutoRebirthOn == true
		self.Callbacks.OnSetAutoRebirth(on, value)
	end)

	self.AutoRebirthHint = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 292),
		Size = UDim2.new(1, -28, 0, 30),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = COLORS.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "Unlock on the green Automation Island.",
		Parent = panel,
	})

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

-- ===== collection panel ====================================================

function UI:BuildCollection()
	local toggle = create("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(110, 48),
		BackgroundColor3 = COLORS.Purple,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = COLORS.Text,
		Text = "🃏 Cards",
		Parent = self.ScreenGui,
	})
	addCorner(toggle, UDim.new(0, 14))

	local panel = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 132, 0.5, 0),
		Size = UDim2.new(0, 380, 0.85, 0),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = self.ScreenGui,
	})
	create("UISizeConstraint", { MaxSize = Vector2.new(380, 560), Parent = panel })
	addCorner(panel, UDim.new(0, 16))
	create("UIStroke", { Color = COLORS.PanelLight, Thickness = 2, Parent = panel })
	self.CollectionPanel = panel

	self.SlotsLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 8),
		Size = UDim2.new(1, -32, 0, 24),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "CARDS — equipped 0/3",
		Parent = panel,
	})

	local equipBest = create("TextButton", {
		Position = UDim2.new(0, 16, 0, 38),
		Size = UDim2.fromOffset(104, 32),
		BackgroundColor3 = COLORS.Green,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Text,
		Text = "Equip Best",
		Parent = panel,
	})
	addCorner(equipBest, UDim.new(0, 10))
	equipBest.Activated:Connect(function()
		self.Callbacks.OnEquipBest()
	end)

	local sellDupes = create("TextButton", {
		Position = UDim2.new(0, 126, 0, 38),
		Size = UDim2.fromOffset(104, 32),
		BackgroundColor3 = COLORS.Gold,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(60, 40, 0),
		Text = "Sell Dupes",
		Parent = panel,
	})
	addCorner(sellDupes, UDim.new(0, 10))
	sellDupes.Activated:Connect(function()
		self.BuySound:Play()
		self.Callbacks.OnSellDupes("ALL")
	end)

	-- backpack upgrade: paid in ROLLS, +5 capacity, cost grows 45% each time
	self.BackpackButton = create("TextButton", {
		Position = UDim2.new(0, 236, 0, 38),
		Size = UDim2.fromOffset(128, 32),
		BackgroundColor3 = COLORS.Disabled,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Text,
		Text = "🎒 +5 — 30 rolls",
		Parent = panel,
	})
	addCorner(self.BackpackButton, UDim.new(0, 10))
	self.BackpackButton.Activated:Connect(function()
		self.Callbacks.OnUpgradeBackpack()
	end)

	self.CollectionScroll = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 80),
		Size = UDim2.new(1, -20, 1, -90),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	})
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = self.CollectionScroll,
	})

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		toggle.Text = panel.Visible and "✕ Close" or "🃏 Cards"
		-- tell the server to only stream the (potentially huge) collection while
		-- this panel is actually open
		if self.Callbacks.OnCollectionView then
			self.Callbacks.OnCollectionView(panel.Visible)
		end
		if panel.Visible then
			self:RebuildCollection()
		end
	end)
end

function UI:RebuildCollection()
	if not self.CollectionPanel.Visible or not self.State then
		return
	end

	for _, child in self.CollectionScroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local equippedSet = {}
	for _, key in self.State.Equipped do
		equippedSet[key] = true
	end

	local sorted = {}
	for key, card in self.Cards do
		table.insert(sorted, { Key = key, Card = card })
	end
	table.sort(sorted, function(a, b)
		return a.Card.Boost > b.Card.Boost
	end)

	if #sorted == 0 then
		local hint = create("Frame", {
			Size = UDim2.new(1, -8, 0, 56),
			BackgroundColor3 = COLORS.Panel,
			Parent = self.CollectionScroll,
		})
		addCorner(hint, UDim.new(0, 10))
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = COLORS.TextDim,
			Text = "No cards yet — press ROLL to pull your first one!",
			Parent = hint,
		})
		return
	end

	local slotsFull = #self.State.Equipped >= self.State.Stats.EquipSlots

	-- only render the top rows; a collection of hundreds would build hundreds of
	-- frames and stall. The rest are summarized at the bottom.
	local RENDER_CAP = 80
	local hiddenCount = math.max(#sorted - RENDER_CAP, 0)

	for order, entry in sorted do
		if order > RENDER_CAP then
			break
		end
		local key, card = entry.Key, entry.Card
		local tier = Config.TierByName[card.Tier] or Config.Tiers[1]
		local isEquipped = equippedSet[key] == true

		local row = create("Frame", {
			Size = UDim2.new(1, -8, 0, 56),
			BackgroundColor3 = if isEquipped then COLORS.PanelLight else COLORS.Panel,
			LayoutOrder = order,
			Parent = self.CollectionScroll,
		})
		addCorner(row, UDim.new(0, 10))
		create("UIStroke", { Color = tier.Color, Thickness = if isEquipped then 2 else 1, Parent = row })

		if card.UserId and card.UserId > 0 then
			local thumb = create("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(20, 14, 34),
				Position = UDim2.new(0, 6, 0.5, -21),
				Size = UDim2.fromOffset(42, 42),
				Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(card.UserId),
				Parent = row,
			})
			addCorner(thumb, UDim.new(1, 0))
		end

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 56, 0, 6),
			Size = UDim2.new(1, -200, 0, 20),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = COLORS.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = (card.DisplayName or card.Name) .. (card.Count > 1 and ("  x" .. card.Count) or ""),
			Parent = row,
		})
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 56, 0, 28),
			Size = UDim2.new(1, -200, 0, 18),
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = tier.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ("%s  •  +%s/s"):format(card.Tier, Format(card.Boost)),
			Parent = row,
		})

		local equipButton = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(72, 34),
			BackgroundColor3 = if isEquipped
				then COLORS.Red
				elseif slotsFull then COLORS.Disabled
				else COLORS.Green,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = COLORS.Text,
			Text = if isEquipped then "Unequip" else "Equip",
			Parent = row,
		})
		addCorner(equipButton, UDim.new(0, 8))
		equipButton.Activated:Connect(function()
			if isEquipped then
				self.Callbacks.OnUnequip(key)
			else
				self.Callbacks.OnEquip(key)
			end
		end)

		-- sells the WHOLE card (all copies); big tiers ask for a second click
		local sellButton = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -86, 0.5, 0),
			Size = UDim2.fromOffset(56, 34),
			BackgroundColor3 = COLORS.Gold,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(60, 40, 0),
			Text = card.Count > 1 and ("Sell x" .. card.Count) or "Sell",
			Parent = row,
		})
		addCorner(sellButton, UDim.new(0, 8))
		local needsConfirm = tier.Index >= Config.TierByName.Legendary.Index
		local armed = false
		sellButton.Activated:Connect(function()
			if needsConfirm and not armed then
				armed = true
				sellButton.Text = "Sure?"
				sellButton.BackgroundColor3 = COLORS.Red
				task.delay(3, function()
					if armed and sellButton.Parent then
						armed = false
						sellButton.Text = card.Count > 1 and ("Sell x" .. card.Count) or "Sell"
						sellButton.BackgroundColor3 = COLORS.Gold
					end
				end)
				return
			end
			self.BuySound:Play()
			self.Callbacks.OnSellCard(key)
		end)
	end

	if hiddenCount > 0 then
		local note = create("Frame", {
			Size = UDim2.new(1, -8, 0, 36),
			BackgroundColor3 = COLORS.Panel,
			LayoutOrder = RENDER_CAP + 1,
			Parent = self.CollectionScroll,
		})
		addCorner(note, UDim.new(0, 10))
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = COLORS.TextDim,
			Text = ("…and %d more (showing your top %d)"):format(hiddenCount, RENDER_CAP),
			Parent = note,
		})
	end
end

function UI:ScheduleCollectionRebuild()
	if self.RebuildScheduled then
		return
	end
	self.RebuildScheduled = true
	task.delay(0.3, function()
		self.RebuildScheduled = false
		self:RebuildCollection()
	end)
end

-- ===== upgrade pads ========================================================
-- Text is drawn ON each pad (SurfaceGui on the top face), and pads only
-- appear once their prerequisite is owned — the tree reveals itself one
-- upgrade at a time. All of this is per-player, so it's done locally.

function UI:BuildPadSurfaces()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local tree = workspace:WaitForChild("UpgradeTree", 30)
	if not tree then
		return
	end

	local pathParts = {}
	for _, child in tree:GetChildren() do
		local nodeId = child.Name:match("^Path_(.+)$")
		if nodeId then
			pathParts[nodeId] = child
		end
	end

	for _, pad in tree:GetChildren() do
		local nodeId = pad:GetAttribute("NodeId")
		local treeNode = nodeId and Config.NodeById[nodeId]
		if not treeNode then
			continue
		end

		local gui = create("SurfaceGui", {
			Adornee = pad,
			Face = Enum.NormalId.Top,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 25,
			-- only render the billboard when you're near it; with ~75 pads this
			-- is the single biggest perf win as the tree fills out
			MaxDistance = 65,
			Parent = playerGui,
		})
		local bg = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			-- endgame pads are approached from the north, flip their text
			Rotation = if treeNode.Branch == "Endgame" then 180 else 0,
			Parent = gui,
		})
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 0, 6),
			Size = UDim2.new(1, -16, 0, 44),
			Font = Enum.Font.GothamBlack,
			TextSize = 24,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(15, 10, 25),
			Text = treeNode.Name,
			Parent = bg,
		})
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 52),
			Size = UDim2.new(1, -20, 0, 60),
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(35, 26, 55),
			Text = treeNode.Desc,
			Parent = bg,
		})
		local costLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 1, -62),
			Size = UDim2.new(1, -16, 0, 54),
			Font = Enum.Font.GothamBlack,
			TextSize = 28,
			TextWrapped = true,
			TextColor3 = COLORS.Text,
			Text = "",
			Parent = bg,
		})

		local entry = {
			Pad = pad,
			Trim = pad:FindFirstChild("Trim"),
			Prompt = pad:FindFirstChildWhichIsA("ProximityPrompt"),
			Path = pathParts[nodeId],
			Gui = gui,
			CostLabel = costLabel,
		}
		self.Pads[nodeId] = entry
		-- hide every pad up front; UpdatePads reveals the unlocked ones once the
		-- first state arrives, so nothing flashes on screen before then
		pad.LocalTransparencyModifier = 1
		if entry.Trim then
			entry.Trim.LocalTransparencyModifier = 1
		end
		if entry.Path then
			entry.Path.LocalTransparencyModifier = 1
		end
		if entry.Prompt then
			entry.Prompt.Enabled = false
		end
		gui.Enabled = false
	end

	-- the gold island stays hidden (and unwalkable) until your first rebirth;
	-- the green island until you buy Automation Unlock. Hidden immediately so
	-- they're invisible from the very first frame, before any state arrives.
	self.GoldenParts = {}
	self.GreenParts = {}
	local goldIsland = tree:FindFirstChild("GoldenIsland")
	if goldIsland and goldIsland:IsA("BasePart") then
		table.insert(self.GoldenParts, goldIsland)
	end
	local greenIsland = tree:FindFirstChild("GreenIsland")
	if greenIsland and greenIsland:IsA("BasePart") then
		table.insert(self.GreenParts, greenIsland)
	end

	-- hide both groups up front (state-driven reveal happens in UpdatePads)
	for _, part in self.GoldenParts do
		part.LocalTransparencyModifier = 1
		part.CanCollide = false
	end
	for _, part in self.GreenParts do
		part.LocalTransparencyModifier = 1
		part.CanCollide = false
	end

	-- the rebirth altar: live progress text + client-side confirm
	local altar = tree:WaitForChild("RebirthAltar", 10)
	if altar then
		local gui = create("SurfaceGui", {
			Adornee = altar,
			Face = Enum.NormalId.Top,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 22,
			Parent = playerGui,
		})
		local bg = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Rotation = 180, -- approached from the bridge (north)
			Parent = gui,
		})
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 0, 8),
			Size = UDim2.new(1, -16, 0, 56),
			Font = Enum.Font.GothamBlack,
			TextSize = 34,
			TextColor3 = Color3.fromRGB(60, 40, 0),
			Text = "⭐ REBIRTH",
			Parent = bg,
		})
		self.AltarLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 64),
			Size = UDim2.new(1, -20, 1, -72),
			Font = Enum.Font.GothamBold,
			TextSize = 20,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(60, 40, 0),
			Text = "",
			Parent = bg,
		})
		local prompt = altar:FindFirstChild("RebirthPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function()
				self:OpenRebirthModal()
			end)
		end
	end

	if self.State then
		self:UpdatePads()
	end
end

-- confirm dialog so a rebirth is never a misclick
function UI:BuildRebirthModal()
	local overlay = create("TextButton", {
		BackgroundColor3 = Color3.fromRGB(10, 6, 20),
		BackgroundTransparency = 0.4,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 20,
		Parent = self.ScreenGui,
	})
	overlay.Activated:Connect(function()
		overlay.Visible = false
	end)
	self.RebirthOverlay = overlay

	local panel = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(360, 250),
		BackgroundColor3 = COLORS.Panel,
		ZIndex = 21,
		Parent = overlay,
	})
	addCorner(panel, UDim.new(0, 18))
	create("UIStroke", { Color = COLORS.Gold, Thickness = 3, Parent = panel })

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 12),
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = COLORS.Gold,
		Text = "⭐ REBIRTH?",
		ZIndex = 21,
		Parent = panel,
	})
	self.RebirthModalBody = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 48),
		Size = UDim2.new(1, -40, 0, 130),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.Text,
		Text = "",
		ZIndex = 21,
		Parent = panel,
	})
	self.RebirthConfirmButton = create("TextButton", {
		Position = UDim2.new(0, 20, 1, -58),
		Size = UDim2.new(0.5, -30, 0, 44),
		BackgroundColor3 = COLORS.Gold,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(60, 40, 0),
		Text = "REBIRTH",
		ZIndex = 21,
		Parent = panel,
	})
	addCorner(self.RebirthConfirmButton, UDim.new(0, 12))
	self.RebirthConfirmButton.Activated:Connect(function()
		overlay.Visible = false
		self.Callbacks.OnRebirth()
	end)

	local cancel = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 1, -58),
		Size = UDim2.new(0.5, -30, 0, 44),
		BackgroundColor3 = COLORS.Disabled,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = COLORS.Text,
		Text = "Cancel",
		ZIndex = 21,
		Parent = panel,
	})
	addCorner(cancel, UDim.new(0, 12))
	cancel.Activated:Connect(function()
		overlay.Visible = false
	end)
end

function UI:OpenRebirthModal()
	if not self.State then
		return
	end
	self:RefreshRebirthModal()
	self.RebirthOverlay.Visible = true
end

function UI:RefreshRebirthModal()
	local state = self.State
	local r = state.Rebirth
	local ready = r.HasLegendary and r.TokensIfNow >= 1
	local total = r.TokensIfNow + (r.TokensIfNow >= 1 and r.BonusTokens or 0)

	local lines = {
		("You will gain:  ⭐ %d token%s"):format(total, total == 1 and "" or "s"),
		"",
		("KEPT:  %s+ cards, golden tree, backpack, rolls"):format(r.KeepTier),
		("WIPED:  coins, purple upgrades, all cards below %s"):format(r.KeepTier),
		"",
		r.HasLegendary and "✓ Legendary+ card owned" or "✗ You need a Legendary+ card",
		r.TokensIfNow >= 1 and ("✓ %s coins banked"):format(Format(state.Coins))
			or ("✗ Need %s coins (you have %s)"):format(Format(Config.Rebirth.BaseCoins), Format(state.Coins)),
	}
	self.RebirthModalBody.Text = table.concat(lines, "\n")
	self.RebirthConfirmButton.BackgroundColor3 = if ready then COLORS.Gold else COLORS.Disabled
	self.RebirthConfirmButton.AutoButtonColor = ready
end

local function setPadVisible(entry, visible)
	-- skip if nothing changed — UpdatePads runs on every state push, and writing
	-- transparency/Enabled to ~75 pads every time is needless render churn
	if entry.LastVisible == visible then
		return
	end
	entry.LastVisible = visible
	local modifier = if visible then 0 else 1
	entry.Pad.LocalTransparencyModifier = modifier
	if entry.Trim then
		entry.Trim.LocalTransparencyModifier = modifier
	end
	if entry.Path then
		entry.Path.LocalTransparencyModifier = modifier
	end
	if entry.Prompt then
		entry.Prompt.Enabled = visible
	end
	entry.Gui.Enabled = visible
end

-- Show or hide an island's parts. `flag` tracks whether we've already revealed
-- it, so the fade-in only plays once (on the transition from locked to unlocked).
function UI:RevealIsland(parts, unlocked, flag)
	if not parts then
		return
	end
	local firstReveal = unlocked and not self[flag]
	for _, part in parts do
		part.CanCollide = unlocked
		for _, descendant in part:GetDescendants() do
			if descendant:IsA("SurfaceGui") then
				descendant.Enabled = unlocked
			end
		end
		if not unlocked then
			part.LocalTransparencyModifier = 1
		elseif firstReveal then
			part.LocalTransparencyModifier = 1
			TweenService:Create(part, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
				LocalTransparencyModifier = 0,
			}):Play()
		else
			part.LocalTransparencyModifier = 0
		end
	end
	if unlocked then
		self[flag] = true
	end
end

function UI:UpdatePads()
	local state = self.State
	local goldUnlocked = state.Rebirths >= 1
	local greenUnlocked = state.AutomationUnlocked

	-- reveal/hide the gold & green islands (per-player, local only). The first
	-- time an island unlocks we fade it in; after that we just keep it shown.
	self:RevealIsland(self.GoldenParts, goldUnlocked, "GoldShown")
	self:RevealIsland(self.GreenParts, greenUnlocked, "GreenShown")

	for nodeId, entry in self.Pads do
		local treeNode = Config.NodeById[nodeId]
		local levels = if treeNode.IsRebirth then state.RebirthUpgrades else state.Upgrades
		local level = levels[nodeId] or 0
		local unlocked = (not treeNode.Requires or (levels[treeNode.Requires] or 0) >= 1)
			and (not treeNode.IsRebirth or goldUnlocked)
			and (not treeNode.IsAutomation or greenUnlocked)

		setPadVisible(entry, unlocked)
		if not unlocked then
			continue
		end

		-- pads you own glow warm white (local-only color change). Cache so we
		-- only write the property when the owned state actually flips.
		local owned = level >= 1
		if entry.Trim and entry.LastOwned ~= owned then
			entry.LastOwned = owned
			entry.Trim.Color = if owned
				then Color3.fromRGB(255, 250, 220)
				else (Config.BranchColors[treeNode.Branch] or Color3.fromRGB(200, 200, 200))
		end

		-- compute the cost label + affordability, then only write if changed
		local text, affordable
		if treeNode.MaxLevel and level >= treeNode.MaxLevel then
			text, affordable = "✓ OWNED", true
		else
			local cost = Config.GetNodeCost(treeNode, level)
			local prefix = if treeNode.MaxLevel == nil then ("Lv %d\n"):format(level) else ""
			local icon = if treeNode.IsRebirth then "⭐" else "🪙"
			local wallet = if treeNode.IsRebirth then state.RebirthTokens else state.Coins
			text = prefix .. icon .. " " .. Format(cost)
			affordable = wallet >= cost
		end
		if entry.LastText ~= text then
			entry.LastText = text
			entry.CostLabel.Text = text
		end
		if entry.LastAfford ~= affordable then
			entry.LastAfford = affordable
			entry.CostLabel.TextColor3 = if affordable
				then Color3.fromRGB(10, 60, 25)
				else Color3.fromRGB(120, 20, 30)
		end
		if entry.Prompt then
			local promptOn = not (treeNode.MaxLevel and level >= treeNode.MaxLevel)
			if entry.LastPrompt ~= promptOn then
				entry.LastPrompt = promptOn
				entry.Prompt.Enabled = promptOn
			end
		end
	end

	-- altar progress text
	if self.AltarLabel then
		local r = state.Rebirth
		if r.HasLegendary and r.TokensIfNow >= 1 then
			local total = r.TokensIfNow + r.BonusTokens
			self.AltarLabel.Text = ("READY!  Hold E for ⭐ %d token%s\nNext token at 🪙 %s")
				:format(total, total == 1 and "" or "s", Format(r.NextAt))
		else
			self.AltarLabel.Text = ("%s Legendary+ card\n%s 🪙 %s / %s")
				:format(
					r.HasLegendary and "✓" or "✗",
					r.TokensIfNow >= 1 and "✓" or "✗",
					Format(state.Coins),
					Format(Config.Rebirth.BaseCoins)
				)
		end
	end
end

-- ===== ticker / cooldown ===================================================

function UI:ShowTicker(text)
	self.TickerToken += 1
	local token = self.TickerToken
	self.TickerLabel.Text = text
	self.TickerLabel.TextTransparency = 0
	task.delay(4, function()
		if self.TickerToken == token then
			TweenService:Create(self.TickerLabel, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

function UI:StartCooldown(duration)
	self.CooldownFill.Size = UDim2.new(1, 0, 1, 0)
	TweenService:Create(self.CooldownFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 1, 0),
	}):Play()
end

-- ===== state refresh =======================================================

function UI:Update(state)
	local previous = self.State
	self.State = state
	if state.Cards then
		self.Cards = state.Cards
		self:ScheduleCollectionRebuild()
	end

	if not self.WelcomedOnce and state.TotalRolls == 0 then
		self.WelcomedOnce = true
		self:ShowTicker("👇 Press ROLL to pull your first card!")
	end
	if previous and state.Rebirths > previous.Rebirths then
		self:ShowTicker("🌟 The Golden Island awaits! Step on the portal beside the altar →")
	end

	if previous then
		local prevLevels = 0
		local newLevels = 0
		for _, level in previous.Upgrades do
			prevLevels += level
		end
		for _, level in state.Upgrades do
			newLevels += level
		end
		if newLevels > prevLevels then
			self.BuySound:Play()
		end
	end

	self.CoinsLabel.Text = "🪙 " .. Format(state.Coins)
	self.RateLabel.Text = ("+%s coins/s"):format(Format(state.CoinsPerSec))
	local bestTier = Config.Tiers[state.BestTier]
	self.RollsLabel.Text = ("Rolls: %s  (all-time %s)%s"):format(
		Format(state.RollsBalance),
		Format(state.TotalRolls),
		bestTier and ("  •  Best: " .. bestTier.Name) or ""
	)

	self.TokenLabel.Text = ("⭐ Tokens: %s  •  Rebirths: %s"):format(Format(state.RebirthTokens), Format(state.Rebirths))

	local cardsPerRoll = math.floor(state.Stats.MultiRoll * state.Stats.CardOutputMult + (state.Stats.CardBonus or 0))
	self.MultiBadge.Visible = cardsPerRoll > 1
	self.MultiBadge.Text = "x" .. cardsPerRoll

	if self.RebirthOverlay and self.RebirthOverlay.Visible then
		self:RefreshRebirthModal()
	end

	self.AutoButton.Visible = state.Stats.AutoUnlocked
	self.AutoButton.Text = state.AutoOn and "AUTO: ON" or "AUTO: OFF"
	self.AutoButton.BackgroundColor3 = if state.AutoOn then COLORS.Green else COLORS.Disabled

	self.SlotsLabel.Text = ("CARDS %d/%d  —  equipped %d/%d"):format(
		state.CardCount,
		state.BackpackCapacity,
		#state.Equipped,
		state.Stats.EquipSlots
	)
	self.BackpackButton.Text = ("🎒 +%d — %s rolls"):format(
		Config.Backpack.CapacityPerUpgrade,
		Format(state.BackpackCost)
	)
	self.BackpackButton.BackgroundColor3 = if state.RollsBalance >= state.BackpackCost
		then COLORS.Purple
		else COLORS.Disabled

	for tierName, button in self.AutoSellButtons do
		local enabled = state.AutoSell[tierName] == true
		button.Text = enabled and "ON" or "OFF"
		button.BackgroundColor3 = if enabled then COLORS.Green else COLORS.Disabled
	end

	-- auto-rebirth controls
	if self.AutoRebirthToggle then
		local unlocked = state.Stats.AutoRebirthUnlocked == true
		local on = state.AutoRebirthOn == true
		self.AutoRebirthToggle.Text = on and "ON" or "OFF"
		self.AutoRebirthToggle.BackgroundColor3 = if on then COLORS.Gold else COLORS.Disabled
		self.AutoRebirthToggle.AutoButtonColor = unlocked
		self.AutoRebirthToggle.Active = unlocked
		if not self.AutoRebirthInput:IsFocused() then
			self.AutoRebirthInput.Text = tostring(state.AutoRebirthTokens or 10)
		end
		self.AutoRebirthInput.TextEditable = unlocked
		self.AutoRebirthHint.Visible = not unlocked
	end

	-- remotes deep-copy tables, so compare equipped by content, not identity
	if previous and table.concat(state.Equipped, ",") ~= table.concat(previous.Equipped, ",") then
		self:ScheduleCollectionRebuild()
	end
	self:UpdatePads()
end

return UI
