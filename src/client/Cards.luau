-- Card visuals: builds card frames, the roll reveal splash, and the
-- fast-roll toast feed. Rare+ pulls always get the big splash; common spam
-- during auto-rolling collapses into small toasts so the screen stays readable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local PANEL_COLOR = Color3.fromRGB(30, 22, 48)
local TEXT_COLOR = Color3.fromRGB(240, 238, 248)
local DIM_COLOR = Color3.fromRGB(160, 152, 185)

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

local Cards = {}
Cards.__index = Cards

function Cards.new(screenGui)
	local self = setmetatable({}, Cards)
	self.ScreenGui = screenGui
	self.DismissToken = 0
	self.Toasts = {}

	self.RevealSound = create("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Parent = screenGui })

	-- full-screen reveal overlay (click anywhere to dismiss)
	self.Overlay = create("TextButton", {
		Name = "RevealOverlay",
		BackgroundColor3 = Color3.fromRGB(10, 6, 20),
		BackgroundTransparency = 0.35,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 10,
		Parent = screenGui,
	})
	self.CardRow = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -20),
		Size = UDim2.new(1, -40, 0, 300),
		ZIndex = 11,
		Parent = self.Overlay,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		Parent = self.CardRow,
	})
	create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = DIM_COLOR,
		Text = "click anywhere to close",
		ZIndex = 11,
		Parent = self.Overlay,
	})

	self.Overlay.Activated:Connect(function()
		self:HideSplash()
	end)

	-- toast stack for fast rolls (bottom right)
	self.ToastColumn = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0, 260, 0, 320),
		Parent = screenGui,
	})
	create("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6),
		Parent = self.ToastColumn,
	})

	return self
end

-- one card frame, used by the reveal splash
function Cards:BuildCardFrame(card, width, parent)
	local tier = Config.TierByName[card.Tier] or Config.Tiers[1]
	local height = math.floor(width * 1.45)

	local frame = create("Frame", {
		BackgroundColor3 = PANEL_COLOR,
		Size = UDim2.fromOffset(width, height),
		ZIndex = 11,
		Parent = parent,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 14), Parent = frame })
	create("UIStroke", { Color = tier.Color, Thickness = 3, Parent = frame })

	local imageSize = math.floor(width * 0.55)
	if card.UserId and card.UserId > 0 then
		local image = create("ImageLabel", {
			BackgroundColor3 = Color3.fromRGB(20, 14, 34),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(imageSize, imageSize),
			Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(card.UserId),
			ZIndex = 12,
			Parent = frame,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = image })
	else
		local placeholder = create("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(20, 14, 34),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(imageSize, imageSize),
			Font = Enum.Font.GothamBlack,
			TextSize = math.floor(imageSize * 0.5),
			TextColor3 = DIM_COLOR,
			Text = "?",
			ZIndex = 12,
			Parent = frame,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = placeholder })
	end

	local y = imageSize + 18
	local tierText = if card.Tier == "Secret" then "SYSTEM ERROR" else card.Tier:upper()
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = tier.Color,
		Text = tierText,
		ZIndex = 12,
		Parent = frame,
	})
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0, y + 20),
		Size = UDim2.new(1, -8, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = TEXT_COLOR,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = card.DisplayName or card.Name,
		ZIndex = 12,
		Parent = frame,
	})
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0, y + 40),
		Size = UDim2.new(1, -8, 0, 14),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = DIM_COLOR,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "@" .. (card.Name or "?"),
		ZIndex = 12,
		Parent = frame,
	})
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0, y + 58),
		Size = UDim2.new(1, -8, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 215, 60),
		Text = "+" .. Format(card.Boost) .. " coins/s",
		ZIndex = 12,
		Parent = frame,
	})

	local detail = card.Flavor
	if not detail and card.Traits and #card.Traits > 0 then
		detail = table.concat(card.Traits, " • ")
	end
	if detail then
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 6, 0, y + 78),
			Size = UDim2.new(1, -12, 1, -(y + 84)),
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = DIM_COLOR,
			Text = detail,
			ZIndex = 12,
			Parent = frame,
		})
	end

	if card.AutoSold then
		local badge = create("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(255, 140, 50),
			Position = UDim2.new(0, -8, 0, -8),
			Size = UDim2.fromOffset(110, 20),
			Font = Enum.Font.GothamBlack,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(60, 25, 0),
			Text = if card.Reason == "full" then "BAG FULL — SOLD" else "AUTO-SOLD",
			Rotation = -8,
			ZIndex = 13,
			Parent = frame,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = badge })
	elseif card.IsNew then
		local badge = create("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(255, 215, 60),
			Position = UDim2.new(0, -8, 0, -8),
			Size = UDim2.fromOffset(48, 20),
			Font = Enum.Font.GothamBlack,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(60, 40, 0),
			Text = "NEW!",
			Rotation = -8,
			ZIndex = 13,
			Parent = frame,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = badge })
	elseif card.Count and card.Count > 1 then
		create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -4),
			Size = UDim2.fromOffset(60, 16),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = DIM_COLOR,
			Text = "x" .. card.Count,
			ZIndex = 12,
			Parent = frame,
		})
	end

	return frame
end

function Cards:HideSplash()
	self.DismissToken += 1
	self.Overlay.Visible = false
end

function Cards:ShowSplash(rollCards, holdSeconds)
	for _, child in self.CardRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local width = if #rollCards <= 1 then 210 elseif #rollCards <= 3 then 180 else 150
	for index, card in rollCards do
		local frame = self:BuildCardFrame(card, width, self.CardRow)
		-- pop-in: each card springs up in sequence
		local scale = Instance.new("UIScale")
		scale.Scale = 0.2
		scale.Parent = frame
		TweenService:Create(
			scale,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (index - 1) * 0.08),
			{ Scale = 1 }
		):Play()
	end

	self.Overlay.Visible = true
	self.DismissToken += 1
	local token = self.DismissToken
	task.delay(holdSeconds, function()
		if self.DismissToken == token then
			self.Overlay.Visible = false
		end
	end)
end

function Cards:ShowToast(card)
	-- cap the stack so fast auto-rolling can't flood the screen (lag guard)
	local labels = {}
	for _, child in self.ToastColumn:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels >= 8 then
		labels[1]:Destroy() -- oldest goes first
	end

	local tier = Config.TierByName[card.Tier] or Config.Tiers[1]
	local text = ("+ %s  %s"):format(card.Tier, card.DisplayName or card.Name)
	if card.AutoSold then
		local why = if card.Reason == "full" then "full bag" else "auto-sell"
		text = ("💰 %s — sold %s (+%s)"):format(why, card.DisplayName or card.Name, Format(card.SoldFor or 0))
	end
	local toast = create("TextLabel", {
		BackgroundColor3 = PANEL_COLOR,
		BackgroundTransparency = 0.15,
		Size = UDim2.new(0, 250, 0, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = tier.Color,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
		Parent = self.ToastColumn,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = toast })
	-- slide in from invisible
	toast.TextTransparency = 1
	toast.BackgroundTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.15), { TextTransparency = 0, BackgroundTransparency = 0.15 }):Play()
	task.delay(1.6, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween.Completed:Once(function()
			toast:Destroy()
		end)
		tween:Play()
	end)
end

-- quick colored flash across the whole screen for big pulls
function Cards:FlashScreen(color)
	local flash = create("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.55,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 9,
		Parent = self.ScreenGui,
	})
	local tween = TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	tween.Completed:Once(function()
		flash:Destroy()
	end)
	tween:Play()
end

-- three rising pings instead of one — the "you just hit something" sound
function Cards:PlayFanfare(bestIndex)
	for i = 1, 3 do
		task.delay((i - 1) * 0.09, function()
			self.RevealSound.PlaybackSpeed = 0.8 + bestIndex * 0.08 + i * 0.18
			self.RevealSound:Play()
		end)
	end
end

-- entry point for every roll result from the server
function Cards:ShowRollResult(payload)
	local rollCards = payload.Cards
	local bestIndex = 1
	for _, card in rollCards do
		local tier = Config.TierByName[card.Tier]
		if tier and tier.Index > bestIndex then
			bestIndex = tier.Index
		end
	end

	local isExciting = bestIndex >= Config.TierByName.Rare.Index
	local isHuge = bestIndex >= Config.TierByName.Legendary.Index

	if isHuge then
		self:PlayFanfare(bestIndex)
		self:FlashScreen(Config.Tiers[bestIndex].Color)
	else
		self.RevealSound.PlaybackSpeed = 0.9 + bestIndex * 0.12
		self.RevealSound:Play()
	end

	-- auto-roll spam of commons becomes toasts; anything exciting gets the splash
	if payload.Auto and not isExciting then
		for _, card in rollCards do
			self:ShowToast(card)
		end
		return
	end
	self:ShowSplash(rollCards, if isExciting then 4.5 else 2.2)
end

return Cards
