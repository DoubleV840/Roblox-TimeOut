-- Le choix qui accompagne chaque achat d'auto-cliqueur : Puissance ou Autonomie.
--
-- Une icone pulse tant qu'un jeton attend ; l'ouvrir presente deux cartes, et en
-- prendre une depense le jeton. La fenetre s'ouvre d'elle-meme au retour d'un
-- achat -- le joueur vient de payer, il attend quelque chose -- mais l'icone
-- reste s'il la referme : rien ne se perd, et un jeton se retrouve intact a la
-- session suivante.
--
-- Chaque carte annonce ce qu'elle change, chiffres en main : "6 s/sec -> 8 s/sec"
-- et pas seulement "+2". Un choix ne se fait pas sur une promesse abstraite.
--
-- C'est deliberement la mecanique que reclament les packs du lot 3 (une
-- recompense en attente, qu'on reclame et qui propose des cartes) : elle est
-- construite ici pour deux cartes, elle se remplira la-bas avec les siennes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Popup = require(script.Parent.Popup)

local AutoClickChoice = {}

local WINDOW_SIZE = UDim2.new(0, 460, 0, 300)

local POWER_COLOR = Color3.fromRGB(255, 130, 215) -- le magenta de l'auto-cliqueur
local FUEL_COLOR = Color3.fromRGB(120, 220, 255) -- le cyan de la duree

local tokens = 0
local power = 0
local fuel = 0

local badge = nil
local badgeLabel = nil
local window = nil
local cards = {}

local badgePulse = nil
local badgeShown = false

--------------------------------------------------------------------------------
-- L'icone qui attend
--------------------------------------------------------------------------------

local function buildBadge(screenGui)
	badge = Instance.new("TextButton")
	badge.Name = "AutoClickToken"
	badge.AnchorPoint = Vector2.new(0, 0)
	badge.Position = UDim2.new(0, 16, 0, 96)
	badge.Size = UDim2.new(0, 220, 0, 42)
	badge.BackgroundColor3 = Color3.fromRGB(24, 18, 26)
	badge.AutoButtonColor = false
	badge.Text = ""
	badge.Visible = false
	badge.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Color = POWER_COLOR
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Parent = badge

	badgeLabel = Instance.new("TextLabel")
	badgeLabel.Size = UDim2.new(1, -16, 1, -10)
	badgeLabel.Position = UDim2.new(0, 8, 0, 5)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.FontFace = Fonts.Main
	badgeLabel.TextScaled = true
	badgeLabel.Text = ""
	badgeLabel.Parent = badge

	badgePulse = TweenService:Create(
		stroke,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.75 }
	)

	Popup.BindButtonSounds(badge)
	badge.MouseButton1Click:Connect(function()
		AutoClickChoice.Open()
	end)
end

local function setBadgeVisible(visible)
	if visible == badgeShown then
		return
	end

	badgeShown = visible
	badge.Visible = visible

	if visible then
		badgePulse:Play()
	else
		badgePulse:Cancel()
	end
end

--------------------------------------------------------------------------------
-- Les deux cartes
--------------------------------------------------------------------------------

local function newCard(parent, order, color, choice)
	local card = Instance.new("TextButton")
	card.Name = choice
	card.Size = UDim2.new(0.5, -18, 1, -104)
	card.Position = UDim2.new(0.5 * (order - 1), order == 1 and 12 or 6, 0, 56)
	card.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	card.AutoButtonColor = false
	card.Text = ""
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -12, 0, 30)
	title.Position = UDim2.new(0, 6, 0, 10)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.Parent = card

	local info = Instance.new("TextLabel")
	info.Size = UDim2.new(1, -16, 1, -52)
	info.Position = UDim2.new(0, 8, 0, 44)
	info.BackgroundTransparency = 1
	info.TextColor3 = Color3.fromRGB(225, 228, 235)
	info.FontFace = Fonts.Main
	info.TextScaled = true
	info.Text = ""
	info.Parent = card

	-- Le survol allume la carte : sans ca, deux rectangles sombres cote a cote ne
	-- donnent pas envie qu'on les touche.
	card.MouseEnter:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0 }):Play()
		TweenService:Create(card, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(28, 28, 34) }):Play()
	end)

	card.MouseLeave:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.35 }):Play()
		TweenService:Create(card, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(16, 16, 20) }):Play()
	end)

	Popup.BindButtonSounds(card)

	card.MouseButton1Click:Connect(function()
		if tokens <= 0 then
			return
		end

		-- On ferme tout de suite et on laisse le serveur trancher : il renverra
		-- l'etat, qui rouvrira la fenetre s'il reste un jeton.
		Remotes.AutoClickChoose:FireServer(choice)
		Sounds.Play("autoclick_bought")
		AutoClickChoice.Close()
	end)

	return { title = title, info = info, stroke = stroke }
end

local function buildWindow(screenGui)
	window = Instance.new("Frame")
	window.Name = "AutoClickChoiceWindow"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = WINDOW_SIZE
	window.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	window.BackgroundTransparency = 0.1
	window.Visible = false
	window.ZIndex = 20
	window.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = window

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 12)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.Text = Locale.Text("autoclick_choice_title")
	title.Parent = window

	TextFx.Mark(title, 0.7, POWER_COLOR)

	cards.power = newCard(window, 1, POWER_COLOR, Config.AUTOCLICK_CHOICE_POWER)
	cards.fuel = newCard(window, 2, FUEL_COLOR, Config.AUTOCLICK_CHOICE_FUEL)

	TextFx.Mark(cards.power.title, 0.55, POWER_COLOR)
	TextFx.Mark(cards.fuel.title, 0.55, FUEL_COLOR)

	cards.power.title.Text = Locale.Text("autoclick_card_power")
	cards.fuel.title.Text = Locale.Text("autoclick_card_fuel")

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Size = UDim2.new(0, 180, 0, 32)
	close.Position = UDim2.new(0.5, 0, 1, -10)
	close.BackgroundColor3 = Color3.fromRGB(60, 50, 60)
	close.TextColor3 = Color3.fromRGB(220, 215, 225)
	close.FontFace = Fonts.Main
	close.TextScaled = true
	close.Text = Locale.Text("autoclick_choice_later")
	close.Parent = window

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = close

	Popup.BindButtonSounds(close)
	close.MouseButton1Click:Connect(function()
		AutoClickChoice.Close()
	end)
end

--------------------------------------------------------------------------------

local function refresh()
	local rate = Config.AUTOCLICK_BASE_RATE + Config.AUTOCLICK_POWER_STEP * power

	-- Chaque carte dit d'ou on part et ou on arrive : c'est la comparaison qui
	-- fait le choix, pas le "+2" tout seul.
	cards.power.info.Text = Locale.Text("autoclick_card_power_info", {
		step = Config.AUTOCLICK_POWER_STEP,
		from = rate,
		to = rate + Config.AUTOCLICK_POWER_STEP,
	})

	cards.fuel.info.Text = Locale.Text("autoclick_card_fuel_info", {
		step = Config.AUTOCLICK_FUEL_STEP,
		from = math.ceil(fuel),
		to = math.ceil(fuel) + Config.AUTOCLICK_FUEL_STEP,
	})

	badgeLabel.Text = Locale.Text("hud_autoclick_token", { count = tokens })
	badgeLabel.TextColor3 = POWER_COLOR

	setBadgeVisible(tokens > 0)

	if tokens <= 0 then
		AutoClickChoice.Close()
	end
end

function AutoClickChoice.Open()
	if tokens <= 0 or window.Visible then
		return
	end

	refresh()
	Popup.In(window, WINDOW_SIZE)
end

function AutoClickChoice.Close()
	if window then
		Popup.Out(window)
	end
end

-- Appele a chaque fois que le serveur annonce l'etat de l'auto-cliqueur.
-- "fresh" est vrai quand un jeton vient d'apparaitre : la fenetre s'ouvre alors
-- toute seule, parce que le joueur vient de payer.
function AutoClickChoice.SetState(state)
	local gained = (state.tokens or 0) > tokens

	tokens = state.tokens or 0
	power = state.power or 0
	fuel = state.fuel or 0

	refresh()

	if gained then
		AutoClickChoice.Open()
	end
end

function AutoClickChoice.Start(screenGui)
	buildBadge(screenGui)
	buildWindow(screenGui)
	refresh()
end

return AutoClickChoice
