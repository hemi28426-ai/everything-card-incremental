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
	self.PadBillboards = {}
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
		Size = UDim2.fromOffset(340, 92),
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

	-- ticker (announcements)
	self.TickerLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
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

	rollButton.Activated:Connect(function()
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
	task.spawn(function()
		self:BuildPadBillboards()
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
		Size = UDim2.fromOffset(120, 32),
		BackgroundColor3 = COLORS.Green,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = COLORS.Text,
		Text = "Equip Best",
		Parent = panel,
	})
	addCorner(equipBest, UDim.new(0, 10))
	equipBest.Activated:Connect(function()
		self.Callbacks.OnEquipBest()
	end)

	local sellDupes = create("TextButton", {
		Position = UDim2.new(0, 146, 0, 38),
		Size = UDim2.fromOffset(130, 32),
		BackgroundColor3 = COLORS.Gold,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(60, 40, 0),
		Text = "Sell All Dupes",
		Parent = panel,
	})
	addCorner(sellDupes, UDim.new(0, 10))
	sellDupes.Activated:Connect(function()
		self.BuySound:Play()
		self.Callbacks.OnSellDupes("ALL")
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

	for order, entry in sorted do
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
			BackgroundColor3 = if isEquipped then COLORS.Red else COLORS.Green,
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

		if card.Count > 1 then
			local sellButton = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -86, 0.5, 0),
				Size = UDim2.fromOffset(56, 34),
				BackgroundColor3 = COLORS.Gold,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(60, 40, 0),
				Text = "Sell",
				Parent = row,
			})
			addCorner(sellButton, UDim.new(0, 8))
			sellButton.Activated:Connect(function()
				self.BuySound:Play()
				self.Callbacks.OnSellDupes(key)
			end)
		end
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

-- ===== upgrade pad billboards ==============================================

function UI:BuildPadBillboards()
	local tree = workspace:WaitForChild("UpgradeTree", 30)
	if not tree then
		return
	end
	for _, pad in tree:GetChildren() do
		local nodeId = pad:GetAttribute("NodeId")
		local treeNode = nodeId and Config.NodeById[nodeId]
		if not treeNode then
			continue
		end

		local billboard = create("BillboardGui", {
			Adornee = pad,
			Size = UDim2.fromOffset(170, 92),
			StudsOffset = Vector3.new(0, 4.6, 0),
			MaxDistance = 70,
			Parent = self.ScreenGui,
		})
		local bg = create("Frame", {
			BackgroundColor3 = COLORS.Panel,
			BackgroundTransparency = 0.2,
			Size = UDim2.new(1, 0, 1, 0),
			Parent = billboard,
		})
		addCorner(bg, UDim.new(0, 10))
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 6, 0, 4),
			Size = UDim2.new(1, -12, 0, 22),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = Config.BranchColors[treeNode.Branch] or COLORS.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = treeNode.Name,
			Parent = bg,
		})
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 6, 0, 26),
			Size = UDim2.new(1, -12, 0, 30),
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextWrapped = true,
			TextColor3 = COLORS.TextDim,
			Text = treeNode.Desc,
			Parent = bg,
		})
		local costLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 6, 1, -28),
			Size = UDim2.new(1, -12, 0, 24),
			Font = Enum.Font.GothamBlack,
			TextSize = 14,
			TextColor3 = COLORS.Gold,
			Text = "",
			Parent = bg,
		})
		self.PadBillboards[nodeId] = costLabel
	end
	if self.State then
		self:UpdatePads()
	end
end

function UI:UpdatePads()
	local state = self.State
	for nodeId, costLabel in self.PadBillboards do
		local treeNode = Config.NodeById[nodeId]
		local level = state.Upgrades[nodeId] or 0
		local locked = treeNode.Requires and (state.Upgrades[treeNode.Requires] or 0) < 1

		if treeNode.MaxLevel and level >= treeNode.MaxLevel then
			costLabel.Text = "✓ OWNED"
			costLabel.TextColor3 = COLORS.Green
		elseif locked then
			local parent = Config.NodeById[treeNode.Requires]
			costLabel.Text = "🔒 needs " .. parent.Name
			costLabel.TextColor3 = COLORS.TextDim
		else
			local cost = Config.GetNodeCost(treeNode, level)
			local prefix = if treeNode.MaxLevel == nil then ("Lv %d  •  "):format(level) else ""
			costLabel.Text = prefix .. "🪙 " .. Format(cost)
			costLabel.TextColor3 = if state.Coins >= cost then COLORS.Green else COLORS.Red
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
	self.RollsLabel.Text = ("Rolls: %s%s"):format(
		Format(state.TotalRolls),
		bestTier and ("  •  Best: " .. bestTier.Name) or ""
	)

	self.MultiBadge.Visible = state.Stats.MultiRoll > 1
	self.MultiBadge.Text = "x" .. state.Stats.MultiRoll

	self.AutoButton.Visible = state.Stats.AutoUnlocked
	self.AutoButton.Text = state.AutoOn and "AUTO: ON" or "AUTO: OFF"
	self.AutoButton.BackgroundColor3 = if state.AutoOn then COLORS.Green else COLORS.Disabled

	self.SlotsLabel.Text = ("CARDS — equipped %d/%d"):format(#state.Equipped, state.Stats.EquipSlots)

	-- remotes deep-copy tables, so compare equipped by content, not identity
	if previous and table.concat(state.Equipped, ",") ~= table.concat(previous.Equipped, ",") then
		self:ScheduleCollectionRebuild()
	end
	self:UpdatePads()
end

return UI
