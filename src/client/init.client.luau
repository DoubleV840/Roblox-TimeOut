local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)
local Ranks = require(ReplicatedStorage.Shared.Ranks)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Colors = require(ReplicatedStorage.Shared.Colors)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Ambience = require(script.Ambience)
local Soundscape = require(script.Soundscape)
local Spin = require(script.Spin)

TextFx.Bind()
Locale.Bind()
Ambience.Start()
Soundscape.Start()
Sounds.Preload()
Spin.Bind(Config.CLICKER_TAG, Config.SPIN_TAG)

-- Petite animation "pop" (rebond) utilisee a l'ouverture des popups.
local function popIn(frame, targetSize)
	frame.Size = UDim2.new(targetSize.X.Scale * 0.7, targetSize.X.Offset * 0.7, targetSize.Y.Scale * 0.7, targetSize.Y.Offset * 0.7)
	frame.Visible = true
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = targetSize }):Play()
	Sounds.Play("ui_popup_open")
end

-- Referme une popup en la faisant sonner -- mais seulement si elle etait
-- ouverte : les fermetures se font aussi en cascade (mort, sortie de zone) sur
-- des popups deja invisibles, et ca ne doit rien declencher.
local function popOut(frame)
	if not frame.Visible then
		return
	end

	frame.Visible = false
	Sounds.Play("ui_popup_close")
end

-- Tout bouton du jeu reagit au survol et au clic. Une seule fonction, appelee a
-- la creation : impossible d'oublier un bouton en route.
local function bindButtonSounds(button)
	button.MouseEnter:Connect(function()
		Sounds.Play("ui_hover")
	end)

	button.MouseButton1Down:Connect(function()
		Sounds.Play("ui_click")
	end)
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TimeOutUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local TIME_COLOR_LOW = Color3.fromRGB(220, 50, 50) -- rouge : temps critique
local TIME_COLOR_HIGH = Color3.fromRGB(80, 220, 120) -- vert : temps confortable

local function timeFactor(timeLeft)
	return math.clamp(timeLeft / Config.BASE_TIME, 0, 1)
end

local function timeColor(timeLeft)
	return TIME_COLOR_LOW:Lerp(TIME_COLOR_HIGH, timeFactor(timeLeft))
end

-- Barre du bas : badge de rang a gauche, chrono + nom du rang a droite.
local bottomBar = Instance.new("Frame")
bottomBar.AnchorPoint = Vector2.new(0.5, 1)
bottomBar.Size = UDim2.new(0, 440, 0, 66)
bottomBar.Position = UDim2.new(0.5, 0, 1, -20)
bottomBar.BackgroundTransparency = 1
bottomBar.Parent = screenGui

local bottomLayout = Instance.new("UIListLayout")
bottomLayout.FillDirection = Enum.FillDirection.Horizontal
bottomLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bottomLayout.VerticalAlignment = Enum.VerticalAlignment.Center
bottomLayout.SortOrder = Enum.SortOrder.LayoutOrder
bottomLayout.Padding = UDim.new(0, 10)
bottomLayout.Parent = bottomBar

local rankBadge = Ranks.NewBadge(Ranks.For(Config.BASE_TIME))
rankBadge.Size = UDim2.new(0, 0, 0.85, 0)
rankBadge.LayoutOrder = 1
rankBadge.Parent = bottomBar

local timeColumn = Instance.new("Frame")
timeColumn.Size = UDim2.new(0, 340, 1, 0)
timeColumn.BackgroundTransparency = 1
timeColumn.LayoutOrder = 2
timeColumn.Parent = bottomBar

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0.66, 0)
label.BackgroundTransparency = 1
label.TextColor3 = TIME_COLOR_HIGH
label.TextStrokeTransparency = 0
label.TextStrokeColor3 = Color3.new(0, 0, 0)
label.TextScaled = true
label.FontFace = Fonts.Main
label.Text = "--:--:--.---"
label.Parent = timeColumn

local rankLabel = Instance.new("TextLabel")
rankLabel.Size = UDim2.new(1, 0, 0.3, 0)
rankLabel.Position = UDim2.new(0, 0, 0.7, 0)
rankLabel.BackgroundTransparency = 1
rankLabel.TextStrokeTransparency = 0
rankLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
rankLabel.TextScaled = true
rankLabel.FontFace = Fonts.Main
rankLabel.Text = ""
rankLabel.Parent = timeColumn

local pulseTween = TweenService:Create(
	label,
	TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ TextTransparency = 0.4 }
)
local isPulsing = false

local function updatePulse(timeLeft)
	local critical = timeFactor(timeLeft) < 0.15
	if critical and not isPulsing then
		isPulsing = true
		pulseTween:Play()
	elseif not critical and isPulsing then
		isPulsing = false
		pulseTween:Cancel()
		label.TextTransparency = 0
	end
end

local currentClickPower = 1
local currentRank = nil

local function updateRank(timeLeft)
	local rank = Ranks.For(timeLeft)
	if rank == currentRank then
		return
	end

	local previous = currentRank
	currentRank = rank
	Ranks.ApplyBadge(rankBadge, rank)
	rankLabel.Text = Locale.Text(rank.key)
	rankLabel.TextColor3 = rank.color

	-- Pas de son au tout premier affichage (previous == nil), ni sur la
	-- degringolade vers zero : la mort a deja sa propre bande-son.
	if not previous or timeLeft <= 0 then
		return
	end

	if rank.index > previous.index then
		Sounds.Play("rank_up")
	else
		Sounds.Play("rank_down")
	end
end

updateRank(Config.BASE_TIME)

-- Le serveur n'envoie le temps qu'une fois par seconde ; on le fait descendre
-- localement entre deux messages pour que les millisecondes defilent vraiment.
local displayTime = Config.BASE_TIME
local countingDown = false

local function renderTime()
	label.Text = TimeFormat.Clock(displayTime)
	label.TextColor3 = timeColor(displayTime)
	updatePulse(displayTime)
	updateRank(displayTime)
	Ambience.SetTimeFactor(timeFactor(displayTime))
	Soundscape.SetTime(displayTime, timeFactor(displayTime))
end

-- Le serveur renvoie le temps a chaque tick, quoi qu'il arrive. On compare a ce
-- que le client affichait deja : le simple ecoulement donne un ecart quasi nul,
-- une depense (mise, amelioration) un vrai plongeon.
--
-- Rien ne sonne quand le chrono MONTE. Chaque source de temps a deja son propre
-- son la ou elle se produit -- l'orbe, le clic, le jackpot, le tiroir-caisse --
-- et un bip de plus sur le HUD ne dirait rien que le joueur ne sache deja.
local LOSS_MARGIN = 1.8

Remotes.TimeUpdated.OnClientEvent:Connect(function(timeLeft)
	if displayTime - timeLeft > Config.TICK_RATE * LOSS_MARGIN then
		Sounds.Play("time_loss")
	end

	displayTime = timeLeft
	countingDown = timeLeft > 0
	renderTime()
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if not countingDown then
		return
	end

	displayTime = math.max(0, displayTime - deltaTime)
	countingDown = displayTime > 0
	renderTime()
end)

-- Ecran de mort plein ecran : fondu au noir, "TIME OUT" puis "TU ES MORT" grave
-- en serif rouge sur une bande sombre, facon ecran de defaite classique.

local DEATH_RED = Color3.fromRGB(190, 30, 30)

local deathScreen = Instance.new("Frame")
deathScreen.Name = "DeathScreen"
deathScreen.Size = UDim2.fromScale(1, 1)
deathScreen.BackgroundColor3 = Color3.new(0, 0, 0)
deathScreen.BackgroundTransparency = 1
deathScreen.BorderSizePixel = 0
deathScreen.Visible = false
deathScreen.ZIndex = 50
deathScreen.Parent = screenGui

-- Bande horizontale sombre derriere le texte, estompee sur les bords.
local deathBand = Instance.new("Frame")
deathBand.Size = UDim2.new(1, 0, 0.34, 0)
deathBand.Position = UDim2.new(0, 0, 0.3, 0)
deathBand.BackgroundColor3 = Color3.fromRGB(25, 0, 0)
deathBand.BackgroundTransparency = 1
deathBand.BorderSizePixel = 0
deathBand.ZIndex = 51
deathBand.Parent = deathScreen

local bandGradient = Instance.new("UIGradient")
bandGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 1),
})
bandGradient.Parent = deathBand

local function newDeathRule(yScale)
	local rule = Instance.new("Frame")
	rule.Size = UDim2.new(0.62, 0, 0, 2)
	rule.Position = UDim2.new(0.19, 0, yScale, 0)
	rule.BackgroundColor3 = DEATH_RED
	rule.BackgroundTransparency = 1
	rule.BorderSizePixel = 0
	rule.ZIndex = 52
	rule.Parent = deathScreen

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = rule

	return rule
end

local deathRuleTop = newDeathRule(0.395)
local deathRuleBottom = newDeathRule(0.575)

local timeOutTitle = Instance.new("TextLabel")
timeOutTitle.AnchorPoint = Vector2.new(0.5, 0.5)
timeOutTitle.Size = UDim2.new(0.6, 0, 0.07, 0)
timeOutTitle.Position = UDim2.new(0.5, 0, 0.355, 0)
timeOutTitle.BackgroundTransparency = 1
timeOutTitle.TextColor3 = Color3.fromRGB(150, 40, 40)
timeOutTitle.TextTransparency = 1
timeOutTitle.FontFace = Fonts.Main
timeOutTitle.TextScaled = true
timeOutTitle.Text = Locale.Text("death_timeout")
timeOutTitle.ZIndex = 52
timeOutTitle.Parent = deathScreen

local deathTitle = Instance.new("TextLabel")
deathTitle.AnchorPoint = Vector2.new(0.5, 0.5)
deathTitle.Size = UDim2.new(0.86, 0, 0.15, 0)
deathTitle.Position = UDim2.new(0.5, 0, 0.485, 0)
deathTitle.BackgroundTransparency = 1
deathTitle.TextColor3 = DEATH_RED
deathTitle.TextTransparency = 1
deathTitle.TextStrokeColor3 = Color3.new(0, 0, 0)
deathTitle.TextStrokeTransparency = 1
deathTitle.FontFace = Fonts.Main
deathTitle.TextScaled = true
deathTitle.Text = Locale.Text("death_title")
deathTitle.ZIndex = 52
deathTitle.Parent = deathScreen

local restartButton = Instance.new("TextButton")
restartButton.AnchorPoint = Vector2.new(0.5, 0)
restartButton.Size = UDim2.new(0, 260, 0, 52)
restartButton.Position = UDim2.new(0.5, 0, 0.68, 0)
restartButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
restartButton.BackgroundTransparency = 1
restartButton.AutoButtonColor = false
restartButton.TextColor3 = Color3.fromRGB(235, 225, 210)
restartButton.TextTransparency = 1
restartButton.FontFace = Fonts.Main
restartButton.TextScaled = true
restartButton.Text = Locale.Text("death_restart")
restartButton.ZIndex = 52
restartButton.Parent = deathScreen

local restartStroke = Instance.new("UIStroke")
restartStroke.Color = DEATH_RED
restartStroke.Thickness = 2
restartStroke.Transparency = 1
restartStroke.Parent = restartButton

local restartHint = Instance.new("TextLabel")
restartHint.AnchorPoint = Vector2.new(0.5, 0)
restartHint.Size = UDim2.new(0, 300, 0, 24)
restartHint.Position = UDim2.new(0.5, 0, 0.68, 64)
restartHint.BackgroundTransparency = 1
restartHint.TextColor3 = Color3.fromRGB(140, 130, 125)
restartHint.TextTransparency = 1
restartHint.FontFace = Fonts.Main
restartHint.TextScaled = true
restartHint.Text = Locale.Text("death_hint", { amount = Config.BASE_TIME })
restartHint.ZIndex = 52
restartHint.Parent = deathScreen

bindButtonSounds(restartButton)

restartButton.MouseEnter:Connect(function()
	TweenService:Create(restartButton, TweenInfo.new(0.15), { BackgroundTransparency = 0.55 }):Play()
end)

restartButton.MouseLeave:Connect(function()
	TweenService:Create(restartButton, TweenInfo.new(0.15), { BackgroundTransparency = 0.85 }):Play()
end)

local deathToken = 0

local function playDeathScreen()
	deathToken += 1
	local myToken = deathToken

	-- La bande-son du chrono s'arrete net : plus de tic-tac, plus de coeur, plus
	-- de musique. C'est le vide qui fait l'effet, pas un son de plus.
	Soundscape.SetDead(true)
	Sounds.Play("death_impact")

	deathScreen.Visible = true
	deathScreen.BackgroundTransparency = 1
	deathBand.BackgroundTransparency = 1
	deathRuleTop.BackgroundTransparency = 1
	deathRuleBottom.BackgroundTransparency = 1
	deathRuleTop.Size = UDim2.new(0, 0, 0, 2)
	deathRuleBottom.Size = UDim2.new(0, 0, 0, 2)
	timeOutTitle.TextTransparency = 1
	deathTitle.TextTransparency = 1
	deathTitle.TextStrokeTransparency = 1
	deathTitle.Size = UDim2.new(0.74, 0, 0.13, 0)
	restartButton.BackgroundTransparency = 1
	restartButton.TextTransparency = 1
	restartStroke.Transparency = 1
	restartHint.TextTransparency = 1

	TweenService:Create(deathScreen, TweenInfo.new(0.7), { BackgroundTransparency = 0.12 }):Play()
	TweenService:Create(deathBand, TweenInfo.new(1.2), { BackgroundTransparency = 0.25 }):Play()

	local ruleTween = TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(deathRuleTop, ruleTween, { Size = UDim2.new(0.62, 0, 0, 2), BackgroundTransparency = 0.3 }):Play()
	TweenService:Create(deathRuleBottom, ruleTween, { Size = UDim2.new(0.62, 0, 0, 2), BackgroundTransparency = 0.3 }):Play()

	TweenService:Create(timeOutTitle, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()

	-- La nappe grave arrive avec le titre, pas avec le coup : elle enterre.
	task.delay(0.35, function()
		if myToken == deathToken and deathScreen.Visible then
			Sounds.Play("death_stinger")
		end
	end)

	TweenService:Create(deathTitle, TweenInfo.new(1.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextStrokeTransparency = 0.5,
		Size = UDim2.new(0.86, 0, 0.15, 0),
	}):Play()

	task.delay(1.5, function()
		if myToken ~= deathToken or not deathScreen.Visible then
			return
		end

		local reveal = TweenInfo.new(0.5)
		TweenService:Create(restartButton, reveal, { BackgroundTransparency = 0.85, TextTransparency = 0 }):Play()
		TweenService:Create(restartStroke, reveal, { Transparency = 0.2 }):Play()
		TweenService:Create(restartHint, reveal, { TextTransparency = 0.15 }):Play()
	end)
end

restartButton.MouseButton1Click:Connect(function()
	deathToken += 1
	Remotes.RequestRestart:FireServer()
	deathScreen.Visible = false
	Soundscape.SetDead(false)
	Sounds.Play("restart")
end)

local notifyLabel = Instance.new("TextLabel")
notifyLabel.Size = UDim2.new(0, 320, 0, 40)
notifyLabel.Position = UDim2.new(0.5, -160, 0, 90)
notifyLabel.BackgroundTransparency = 1
notifyLabel.TextScaled = true
notifyLabel.FontFace = Fonts.Main
notifyLabel.Text = ""
notifyLabel.Visible = false
notifyLabel.Parent = screenGui

local notifyToken = 0

-- Chaque notification a son son. La plupart se contentent du timbre de leur
-- couleur (jaune = info, vert = gagne, rouge = perdu) ; celles qui listees ici
-- meritent mieux -- un refus sec, un tiroir-caisse, un cadenas qui saute.
local NOTIFY_SOUNDS = {
	notify_bet_poor = "ui_denied",
	notify_upgrade_poor = "ui_denied",
	notify_shop_failed = "ui_purchase_failed",
	notify_shop_granted = "ui_purchase_success",
	notify_autoclick_granted = "autoclick_bought",
	notify_bet_unlocked = "bet_unlocked",
}

local function playNotifySound(key, color)
	local named = NOTIFY_SOUNDS[key]
	if named then
		Sounds.Play(named)
		return
	end

	if color == Colors.WIN then
		Sounds.Play("ui_notify_win")
	elseif color == Colors.LOSE then
		Sounds.Play("ui_notify_lose")
	else
		Sounds.Play("ui_notify_info")
	end
end

-- Le serveur envoie une cle + ses parametres, jamais une phrase toute faite :
-- c'est ici, cote joueur, qu'on sait dans quelle langue l'ecrire.
Remotes.Notify.OnClientEvent:Connect(function(key, params, color)
	notifyToken += 1
	local myToken = notifyToken

	playNotifySound(key, color)

	-- Une notif "gagne"/"perdu" doit sauter aux yeux, une info neutre reste calme.
	local notifyColor = color or Color3.fromRGB(235, 235, 235)
	local notifyIntensity = 0.3
	if color then
		notifyIntensity = 0.8
	end

	TextFx.Mark(notifyLabel, notifyIntensity, notifyColor)
	notifyLabel.Text = Locale.Text(key, params)
	notifyLabel.TextTransparency = 1
	notifyLabel.Position = UDim2.new(0.5, -160, 0, 70)
	notifyLabel.Visible = true

	TweenService:Create(notifyLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		Position = UDim2.new(0.5, -160, 0, 90),
	}):Play()

	task.delay(2.5, function()
		if myToken == notifyToken then
			notifyLabel.Visible = false
		end
	end)
end)

-- Popup de confirmation de pari

-- Les popups gagnent POPUP_TOP_PADDING en hauteur ET en marge haute : le titre
-- respire, et tout le reste (positions internes, marge sous les boutons) est inchange.
local POPUP_TOP_PADDING = 14

local function addTopPadding(frame)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, POPUP_TOP_PADDING)
	padding.Parent = frame
end

local betFrame = Instance.new("Frame")
betFrame.Size = UDim2.new(0, 300, 0, 164)
betFrame.Position = UDim2.new(0.5, -150, 0.5, -82)
betFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
betFrame.BackgroundTransparency = 0.1
betFrame.Visible = false
betFrame.Parent = screenGui

addTopPadding(betFrame)

local betTitle = Instance.new("TextLabel")
betTitle.Size = UDim2.new(1, 0, 0, 40)
betTitle.BackgroundTransparency = 1
betTitle.FontFace = Fonts.Main
betTitle.TextScaled = true
betTitle.Text = Locale.Text("bet_title")
betTitle.Parent = betFrame

TextFx.Mark(betTitle, 0.6, Color3.fromRGB(255, 150, 60))

local betAmountLabel = Instance.new("TextLabel")
betAmountLabel.Size = UDim2.new(1, 0, 0, 30)
betAmountLabel.Position = UDim2.new(0, 0, 0, 40)
betAmountLabel.BackgroundTransparency = 1
betAmountLabel.TextColor3 = Color3.fromRGB(255, 221, 0)
betAmountLabel.FontFace = Fonts.Main
betAmountLabel.TextScaled = true
betAmountLabel.Text = ""
betAmountLabel.Parent = betFrame

local acceptButton = Instance.new("TextButton")
acceptButton.Size = UDim2.new(0.45, 0, 0, 40)
acceptButton.Position = UDim2.new(0.025, 0, 1, -50)
acceptButton.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
acceptButton.TextColor3 = Color3.new(1, 1, 1)
acceptButton.FontFace = Fonts.Main
acceptButton.TextScaled = true
acceptButton.Text = Locale.Text("bet_accept")
acceptButton.Parent = betFrame

local declineButton = Instance.new("TextButton")
declineButton.Size = UDim2.new(0.45, 0, 0, 40)
declineButton.Position = UDim2.new(0.525, 0, 1, -50)
declineButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
declineButton.TextColor3 = Color3.new(1, 1, 1)
declineButton.FontFace = Fonts.Main
declineButton.TextScaled = true
declineButton.Text = Locale.Text("bet_decline")
declineButton.Parent = betFrame

local currentBetZone = nil
local currentBetLocked = false

local function hideBetPrompt()
	currentBetZone = nil
	currentBetLocked = false
	popOut(betFrame)
end

bindButtonSounds(acceptButton)
bindButtonSounds(declineButton)

acceptButton.MouseButton1Click:Connect(function()
	if currentBetZone and not currentBetLocked then
		Remotes.BetAccept:FireServer(currentBetZone)
	end
	hideBetPrompt()
end)

declineButton.MouseButton1Click:Connect(function()
	hideBetPrompt()
end)

-- La meme popup sert aux deux etats de la zone : ouverte, elle propose de miser ;
-- verrouillee, elle dit ce qu'il faut avoir atteint pour y avoir droit. Un seul
-- bouton dans ce cas -- il n'y a rien a valider.
local function showBetPrompt(zone, amount, lockedAt)
	currentBetZone = zone
	currentBetLocked = lockedAt ~= nil

	if currentBetLocked then
		betTitle.Text = Locale.Text("bet_locked_title")
		TextFx.Mark(betTitle, 0.2, Color3.fromRGB(200, 200, 210))
		betAmountLabel.Text = Locale.Text("bet_locked_info", { amount = lockedAt })
		betAmountLabel.TextColor3 = Color3.fromRGB(200, 200, 210)

		acceptButton.Visible = false
		declineButton.Size = UDim2.new(0.95, 0, 0, 40)
		declineButton.Position = UDim2.new(0.025, 0, 1, -50)
		declineButton.Text = Locale.Text("shop_close")
	else
		betTitle.Text = Locale.Text("bet_title")
		TextFx.Mark(betTitle, 0.6, Color3.fromRGB(255, 150, 60))
		betAmountLabel.Text = Locale.Text("bet_amount", { amount = amount })
		betAmountLabel.TextColor3 = Color3.fromRGB(255, 221, 0)

		acceptButton.Visible = true
		declineButton.Size = UDim2.new(0.45, 0, 0, 40)
		declineButton.Position = UDim2.new(0.525, 0, 1, -50)
		declineButton.Text = Locale.Text("bet_decline")
	end

	popIn(betFrame, UDim2.new(0, 300, 0, 164))

	-- Une zone encore fermee se signale a l'oreille : le "pop" de la popup est le
	-- meme pour tout le monde, le refus qui le suit ne trompe pas.
	if currentBetLocked then
		Sounds.Play("ui_denied")
	end
end

Remotes.BetPrompt.OnClientEvent:Connect(showBetPrompt)

Remotes.BetPromptHide.OnClientEvent:Connect(function(zone)
	if currentBetZone == zone then
		hideBetPrompt()
	end
end)

-- Popup d'amelioration de clic

local upgradeFrame = Instance.new("Frame")
upgradeFrame.Size = UDim2.new(0, 300, 0, 204)
upgradeFrame.Position = UDim2.new(0.5, -150, 0.5, -102)
upgradeFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
upgradeFrame.BackgroundTransparency = 0.1
upgradeFrame.Visible = false
upgradeFrame.Parent = screenGui

addTopPadding(upgradeFrame)

local upgradeTitle = Instance.new("TextLabel")
upgradeTitle.Size = UDim2.new(1, 0, 0, 36)
upgradeTitle.BackgroundTransparency = 1
upgradeTitle.FontFace = Fonts.Main
upgradeTitle.TextScaled = true
upgradeTitle.Text = Locale.Text("upgrade_title")
upgradeTitle.Parent = upgradeFrame

TextFx.Mark(upgradeTitle, 0.6, Color3.fromRGB(255, 90, 200))

local upgradeInfo = Instance.new("TextLabel")
upgradeInfo.Size = UDim2.new(1, 0, 0, 90)
upgradeInfo.Position = UDim2.new(0, 0, 0, 36)
upgradeInfo.BackgroundTransparency = 1
upgradeInfo.TextColor3 = Color3.fromRGB(255, 221, 0)
upgradeInfo.FontFace = Fonts.Main
upgradeInfo.TextScaled = true
upgradeInfo.TextXAlignment = Enum.TextXAlignment.Center
upgradeInfo.TextYAlignment = Enum.TextYAlignment.Center
upgradeInfo.Text = ""
upgradeInfo.Parent = upgradeFrame

local upgradeInfoPadding = Instance.new("UIPadding")
upgradeInfoPadding.PaddingLeft = UDim.new(0, 12)
upgradeInfoPadding.PaddingRight = UDim.new(0, 12)
upgradeInfoPadding.Parent = upgradeInfo

local upgradeBuyButton = Instance.new("TextButton")
upgradeBuyButton.Size = UDim2.new(0.45, 0, 0, 40)
upgradeBuyButton.Position = UDim2.new(0.025, 0, 1, -50)
upgradeBuyButton.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
upgradeBuyButton.TextColor3 = Color3.new(1, 1, 1)
upgradeBuyButton.FontFace = Fonts.Main
upgradeBuyButton.TextScaled = true
upgradeBuyButton.Text = Locale.Text("upgrade_buy")
upgradeBuyButton.Parent = upgradeFrame

local upgradeCloseButton = Instance.new("TextButton")
upgradeCloseButton.Size = UDim2.new(0.45, 0, 0, 40)
upgradeCloseButton.Position = UDim2.new(0.525, 0, 1, -50)
upgradeCloseButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
upgradeCloseButton.TextColor3 = Color3.new(1, 1, 1)
upgradeCloseButton.FontFace = Fonts.Main
upgradeCloseButton.TextScaled = true
upgradeCloseButton.Text = Locale.Text("upgrade_close")
upgradeCloseButton.Parent = upgradeFrame

local currentUpgradeZone = nil

local function hideUpgradePrompt()
	currentUpgradeZone = nil
	popOut(upgradeFrame)
end

bindButtonSounds(upgradeBuyButton)
bindButtonSounds(upgradeCloseButton)

upgradeBuyButton.MouseButton1Click:Connect(function()
	if currentUpgradeZone then
		Remotes.UpgradeAccept:FireServer(currentUpgradeZone)
	end
end)

upgradeCloseButton.MouseButton1Click:Connect(function()
	hideUpgradePrompt()
end)

-- Panneau flottant au-dessus de la zone, cree localement -> visible seulement par ce joueur.
local upgradeWorldSigns = {}

-- La ligne de stats chauffe avec le niveau : blanche au debut, cyan puis magenta
-- survolte quand le joueur a beaucoup investi (sature au niveau 10).
local function markUpgradeSign(sign, clickPower)
	local heat = math.clamp((clickPower - 1) / 9, 0, 1)
	local color = Color3.fromRGB(235, 235, 235):Lerp(Color3.fromRGB(255, 90, 200), heat)
	TextFx.Mark(sign.statsLabel, heat, color)
end

local function getUpgradeWorldSign(zone)
	local sign = upgradeWorldSigns[zone]
	if sign then
		return sign
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MyChronoBoostSign"
	billboard.Size = UDim2.new(10, 0, 4, 0) -- en studs : taille fixe dans le monde
	billboard.StudsOffset = Vector3.new(0, 4.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = true
	billboard.Parent = zone

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.FontFace = Fonts.Main
	nameLabel.TextScaled = true
	nameLabel.Text = Locale.Text("upgrade_title")
	nameLabel.Parent = billboard

	TextFx.Mark(nameLabel, 0.5, Color3.fromRGB(255, 221, 0))

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(1, 0, 0.6, 0)
	statsLabel.Position = UDim2.new(0, 0, 0.4, 0)
	statsLabel.BackgroundTransparency = 1
	statsLabel.FontFace = Fonts.Main
	statsLabel.TextScaled = true
	statsLabel.Text = Locale.Text("upgrade_stats", { level = currentClickPower, bonus = Config.CLICKER_REWARD * currentClickPower })
	statsLabel.Parent = billboard

	sign = { billboard = billboard, statsLabel = statsLabel }
	markUpgradeSign(sign, currentClickPower)
	upgradeWorldSigns[zone] = sign
	return sign
end

-- Le panneau est cree pour chaque zone des le depart (pas besoin d'y avoir marche dessus).
for _, zone in CollectionService:GetTagged(Config.UPGRADE_TAG) do
	getUpgradeWorldSign(zone)
end

CollectionService:GetInstanceAddedSignal(Config.UPGRADE_TAG):Connect(getUpgradeWorldSign)

Remotes.UpgradePrompt.OnClientEvent:Connect(function(zone, info)
	currentUpgradeZone = zone
	currentClickPower = info.level
	upgradeInfo.Text = Locale.Text("upgrade_info", {
		level = info.nextLevel,
		bonus = info.nextBonus,
		amount = info.cost,
	})

	if not upgradeFrame.Visible then
		popIn(upgradeFrame, UDim2.new(0, 300, 0, 204))
	end

	-- le panneau au-dessus de la zone reste affiche en permanence une fois cree
	local sign = getUpgradeWorldSign(zone)
	sign.statsLabel.Text = Locale.Text("upgrade_stats", { level = info.level, bonus = info.currentBonus })
	markUpgradeSign(sign, info.level)
	sign.billboard.Enabled = true
end)

Remotes.UpgradePromptHide.OnClientEvent:Connect(function(zone)
	if currentUpgradeZone == zone then
		hideUpgradePrompt()
	end
end)

Remotes.ClickPowerUpdated.OnClientEvent:Connect(function(clickPower)
	currentClickPower = clickPower

	for _, sign in upgradeWorldSigns do
		sign.statsLabel.Text = Locale.Text("upgrade_stats", { level = clickPower, bonus = Config.CLICKER_REWARD * clickPower })
		markUpgradeSign(sign, clickPower)
	end
end)

-- Popups des guichets (achats Robux)
--
-- Deux guichets, distingues par l'attribut ShopKind de la zone : l'un vend des
-- paquets de temps (liste figee), l'autre des auto-cliqueurs (un seul palier a la
-- fois, celui qui suit ce que le joueur possede deja).

-- Un produit sans productId n'existe pas encore dans le Creator Dashboard : le
-- serveur refuse de le vendre, donc on ne l'affiche pas non plus.
local shopProducts = {}
for _, product in Config.TIME_PRODUCTS do
	if product.productId ~= 0 then
		table.insert(shopProducts, product)
	end
end

local SHOP_ROW_HEIGHT = 42
local SHOP_ROW_GAP = 6
local SHOP_CONTENT_TOP = 50 -- sous le titre
local SHOP_FOOTER = 52 -- bouton Fermer + son air autour

-- Hauteur totale d'une popup de guichet. Le POPUP_TOP_PADDING compte : il rogne
-- la zone utile, donc sans lui le bouton Fermer viendrait mordre la derniere ligne.
local function shopHeight(contentHeight)
	return POPUP_TOP_PADDING + SHOP_CONTENT_TOP + contentHeight + SHOP_FOOTER
end

local function newShopFrame(height)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 320, 0, height)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.1
	frame.Visible = false
	frame.Parent = screenGui

	addTopPadding(frame)
	return frame
end

local function newShopTitle(parent, key, color)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.Text = Locale.Text(key)
	title.Parent = parent

	TextFx.Mark(title, 0.6, color)
	return title
end

local function newShopCloseButton(parent)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -24, 0, 38)
	button.Position = UDim2.new(0, 12, 1, -46)
	button.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.FontFace = Fonts.Main
	button.TextScaled = true
	button.Text = Locale.Text("shop_close")
	button.Parent = parent

	bindButtonSounds(button)
	return button
end

-- Une ligne d'achat : le libelle a gauche, le prix en Robux a droite.
local function newShopRow(parent, index)
	local row = Instance.new("TextButton")
	row.Name = "Pack" .. index
	row.Size = UDim2.new(1, -24, 0, SHOP_ROW_HEIGHT)
	row.Position = UDim2.new(0, 12, 0, SHOP_CONTENT_TOP + (index - 1) * (SHOP_ROW_HEIGHT + SHOP_ROW_GAP))
	row.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
	row.BackgroundTransparency = 0.15
	row.AutoButtonColor = true
	row.Text = ""
	row.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = row

	local amount = Instance.new("TextLabel")
	amount.Size = UDim2.new(0.62, 0, 1, -10)
	amount.Position = UDim2.new(0, 10, 0, 5)
	amount.BackgroundTransparency = 1
	amount.TextColor3 = Color3.fromRGB(255, 221, 0)
	amount.FontFace = Fonts.Main
	amount.TextScaled = true
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.Parent = row

	local price = Instance.new("TextLabel")
	price.Size = UDim2.new(0.32, 0, 1, -10)
	price.Position = UDim2.new(0.66, 0, 0, 5)
	price.BackgroundTransparency = 1
	price.TextColor3 = Color3.fromRGB(120, 220, 140)
	price.FontFace = Fonts.Main
	price.TextScaled = true
	price.TextXAlignment = Enum.TextXAlignment.Right
	price.Parent = row

	bindButtonSounds(row)

	return { button = row, amount = amount, price = price }
end

--------------------------------------------------------------------------------
-- Guichet "Time" : paquets de secondes
--------------------------------------------------------------------------------

local TIME_SHOP_SIZE = UDim2.new(0, 320, 0, shopHeight(#shopProducts * (SHOP_ROW_HEIGHT + SHOP_ROW_GAP)))

local shopFrame = newShopFrame(TIME_SHOP_SIZE.Y.Offset)
newShopTitle(shopFrame, "shop_title", Color3.fromRGB(120, 220, 255))

for index, product in shopProducts do
	local row = newShopRow(shopFrame, index)
	row.amount.Text = Locale.Text("shop_pack", { amount = product.seconds })
	row.price.Text = Locale.Text("shop_price", { price = product.robux })

	-- L'achat lui-meme est declenche par le serveur (PromptProductPurchase) :
	-- le client ne fait que demander, il n'a aucun pouvoir sur le credit.
	row.button.MouseButton1Click:Connect(function()
		Sounds.Play("ui_purchase_prompt")
		Remotes.ShopBuy:FireServer(product.productId)
	end)
end

local shopCloseButton = newShopCloseButton(shopFrame)

--------------------------------------------------------------------------------
-- Guichet "AutoClick" : auto-cliqueurs
--------------------------------------------------------------------------------

local AUTO_SHOP_SIZE = UDim2.new(0, 320, 0, shopHeight(28 + SHOP_ROW_HEIGHT + SHOP_ROW_GAP))

local autoShopFrame = newShopFrame(AUTO_SHOP_SIZE.Y.Offset)
newShopTitle(autoShopFrame, "shop_auto_title", Color3.fromRGB(255, 150, 220))

local autoOwnedLabel = Instance.new("TextLabel")
autoOwnedLabel.Size = UDim2.new(1, -24, 0, 26)
autoOwnedLabel.Position = UDim2.new(0, 12, 0, SHOP_CONTENT_TOP - 4)
autoOwnedLabel.BackgroundTransparency = 1
autoOwnedLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
autoOwnedLabel.FontFace = Fonts.Main
autoOwnedLabel.TextScaled = true
autoOwnedLabel.Text = ""
autoOwnedLabel.Parent = autoShopFrame

local autoRow = newShopRow(autoShopFrame, 1)
autoRow.button.Position = UDim2.new(0, 12, 0, SHOP_CONTENT_TOP + 28)

local autoShopCloseButton = newShopCloseButton(autoShopFrame)

local autoClickersOwned = 0

-- Le debit se calcule pareil des deux cotes (voir AutoClicker.RateAt cote serveur) :
-- rien a faire transiter, le client refait le calcul a partir du niveau.
local function autoRateAt(level)
	if level <= 0 then
		return 0
	end

	return Config.AUTOCLICK_BASE_RATE * Config.AUTOCLICK_GROWTH ^ (level - 1)
end

-- Un seul produit, rachetable a l'infini : il n'y a jamais de palier "epuise",
-- juste le niveau suivant et son debit double.
local function refreshAutoShop()
	autoOwnedLabel.Text = Locale.Text("shop_auto_owned", { rate = autoRateAt(autoClickersOwned) })
	autoRow.amount.Text = Locale.Text("shop_auto_next", {
		level = autoClickersOwned + 1,
		rate = autoRateAt(autoClickersOwned + 1),
	})
	autoRow.price.Text = Locale.Text("shop_price", { price = Config.AUTOCLICK_PRODUCT.robux })
end

-- Point d'entree unique quand le nombre d'auto-cliqueurs change : le guichet se
-- met a jour et le bourdonnement passif monte d'un cran.
local function setAutoClickers(owned)
	autoClickersOwned = owned or 0
	refreshAutoShop()
	Soundscape.SetAutoClickLevel(autoClickersOwned)
end

autoRow.button.MouseButton1Click:Connect(function()
	Sounds.Play("ui_purchase_prompt")
	Remotes.ShopBuy:FireServer(Config.AUTOCLICK_PRODUCT.productId)
end)

--------------------------------------------------------------------------------

local currentShopZone = nil

local function hideShopPrompt()
	currentShopZone = nil
	popOut(shopFrame)
	popOut(autoShopFrame)
end

shopCloseButton.MouseButton1Click:Connect(hideShopPrompt)
autoShopCloseButton.MouseButton1Click:Connect(hideShopPrompt)

Remotes.ShopPrompt.OnClientEvent:Connect(function(zone, kind, owned)
	if kind == Config.SHOP_KIND_AUTOCLICK then
		setAutoClickers(owned)
		currentShopZone = zone
		popIn(autoShopFrame, AUTO_SHOP_SIZE)
		return
	end

	-- Guichet a temps sans aucun paquet vendable (aucun productId renseigne) :
	-- inutile d'ouvrir une popup vide, on laisse le joueur passer son chemin.
	if #shopProducts == 0 then
		return
	end

	currentShopZone = zone
	popIn(shopFrame, TIME_SHOP_SIZE)
end)

Remotes.ShopPromptHide.OnClientEvent:Connect(function(zone)
	if currentShopZone == zone then
		hideShopPrompt()
	end
end)

-- L'achat aboutit pendant que la popup est ouverte : elle passe au palier suivant
-- sans que le joueur ait besoin de ressortir de la zone.
Remotes.AutoClickUpdated.OnClientEvent:Connect(setAutoClickers)


-- Du temps achete alors qu'on etait devant l'ecran de mort : on repart en jeu
-- sans passer par "Recommencer", qui remettrait le temps de base.
Remotes.Revived.OnClientEvent:Connect(function()
	deathToken += 1
	deathScreen.Visible = false
	Soundscape.SetDead(false)
	Sounds.Play("revive")
end)

--------------------------------------------------------------------------------
-- Cadenas des zones de pari verrouillees
--------------------------------------------------------------------------------

-- Le verrou est propre a chaque joueur alors que le panneau de la zone est
-- partage par tous : c'est donc le client qui dessine le cadenas, sur un
-- BillboardGui a lui, cree et detruit au gre des messages du serveur.
local betLockSigns = {}

local function setBetLock(zone, locked, unlockAt)
	local sign = betLockSigns[zone]

	if not locked then
		if sign then
			sign.billboard:Destroy()
			betLockSigns[zone] = nil
		end
		return
	end

	if not sign then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "MyBetLockSign"
		billboard.Size = UDim2.new(8, 0, 3, 0) -- en studs : taille fixe dans le monde
		billboard.StudsOffset = Vector3.new(0, 7, 0) -- au-dessus du panneau de mise
		billboard.AlwaysOnTop = true
		billboard.Parent = zone

		-- Le cadenas est un emoji : aucune police du jeu ne le contient, c'est le
		-- repli systeme de Roblox qui le dessine. Le texte en dessous porte le
		-- sens a lui seul, pour que rien ne soit perdu si le glyphe manque.
		local glyph = Instance.new("TextLabel")
		glyph.Size = UDim2.new(1, 0, 0.55, 0)
		glyph.BackgroundTransparency = 1
		glyph.FontFace = Fonts.Symbol
		glyph.TextScaled = true
		glyph.Text = "\u{1F512}"
		glyph.TextColor3 = Color3.fromRGB(200, 200, 210)
		glyph.Parent = billboard

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0.45, 0)
		label.Position = UDim2.new(0, 0, 0.55, 0)
		label.BackgroundTransparency = 1
		label.FontFace = Fonts.Main
		label.TextScaled = true
		label.Parent = billboard

		TextFx.Mark(label, 0.25, Color3.fromRGB(200, 200, 210))

		sign = { billboard = billboard, label = label }
		betLockSigns[zone] = sign
	end

	sign.label.Text = Locale.Text("bet_locked_sign", { amount = unlockAt })
end

Remotes.BetLockUpdated.OnClientEvent:Connect(setBetLock)

--------------------------------------------------------------------------------
-- HUD des paris en cours
--------------------------------------------------------------------------------

-- Une fois sa mise partie, le joueur repart farmer ailleurs : le panneau de la
-- zone ne lui dit plus rien. Ce bandeau le suit et fait descendre le compte a
-- rebours du tirage, meme a l'autre bout de la map. Les tours ouverts ou il n'a
-- rien mis y figurent aussi, en gris : c'est ce qui donne envie d'y courir avant
-- la fin du decompte.
--
-- Le serveur n'envoie qu'une echeance (son horloge, partagee avec le client) a
-- chaque changement de tour ; le decompte, lui, tourne ici, image par image.

local BET_HUD_WIDTH = 240
local BET_HUD_TITLE_HEIGHT = 26
local BET_HUD_ROW_HEIGHT = 46
local BET_HUD_ROW_GAP = 6
local BET_HUD_TIMER_WIDTH = 74

local BET_HUD_CALM = Color3.fromRGB(120, 220, 140) -- il reste le temps de miser
local BET_HUD_URGENT = Color3.fromRGB(255, 90, 70) -- tirage imminent
local BET_HUD_MINE = Color3.fromRGB(255, 200, 60) -- ma mise est engagee dedans
local BET_HUD_OTHER = Color3.fromRGB(150, 160, 175) -- tour ouvert, sans moi

local betHud = Instance.new("Frame")
betHud.Name = "BetHud"
betHud.AnchorPoint = Vector2.new(1, 0)
betHud.Position = UDim2.new(1, -16, 0, 96)
betHud.Size = UDim2.new(0, BET_HUD_WIDTH, 0, BET_HUD_TITLE_HEIGHT)
betHud.BackgroundTransparency = 1
betHud.Visible = false
betHud.Parent = screenGui

local betHudTitle = Instance.new("TextLabel")
betHudTitle.Size = UDim2.new(1, 0, 0, BET_HUD_TITLE_HEIGHT)
betHudTitle.BackgroundTransparency = 1
betHudTitle.FontFace = Fonts.Main
betHudTitle.TextScaled = true
betHudTitle.TextXAlignment = Enum.TextXAlignment.Right
betHudTitle.Text = Locale.Text("bet_hud_title")
betHudTitle.Parent = betHud

TextFx.Mark(betHudTitle, 0.35, Color3.fromRGB(255, 150, 60))

local betHudList = Instance.new("Frame")
betHudList.Position = UDim2.new(0, 0, 0, BET_HUD_TITLE_HEIGHT + BET_HUD_ROW_GAP)
betHudList.Size = UDim2.new(1, 0, 1, -(BET_HUD_TITLE_HEIGHT + BET_HUD_ROW_GAP))
betHudList.BackgroundTransparency = 1
betHudList.Parent = betHud

local betHudLayout = Instance.new("UIListLayout")
betHudLayout.SortOrder = Enum.SortOrder.LayoutOrder
betHudLayout.Padding = UDim.new(0, BET_HUD_ROW_GAP)
betHudLayout.Parent = betHudList

-- Une ligne = un tour ouvert : la mise et le nombre de parieurs a gauche, le
-- compte a rebours a droite.
local function newBetHudRow(index, joined)
	local accent = joined and BET_HUD_MINE or BET_HUD_OTHER

	local frame = Instance.new("Frame")
	frame.Name = "Round" .. index
	frame.Size = UDim2.new(1, 0, 0, BET_HUD_ROW_HEIGHT)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = joined and 0.15 or 0.4
	frame.LayoutOrder = index
	frame.Parent = betHudList

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = joined and 2 or 1
	stroke.Transparency = joined and 0.1 or 0.55
	stroke.Parent = frame

	local amount = Instance.new("TextLabel")
	amount.Size = UDim2.new(1, -(BET_HUD_TIMER_WIDTH + 20), 0, 22)
	amount.Position = UDim2.new(0, 10, 0, 4)
	amount.BackgroundTransparency = 1
	amount.TextColor3 = accent
	amount.FontFace = Fonts.Main
	amount.TextScaled = true
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.Parent = frame

	local players = Instance.new("TextLabel")
	players.Size = UDim2.new(1, -(BET_HUD_TIMER_WIDTH + 20), 0, 16)
	players.Position = UDim2.new(0, 10, 0, 26)
	players.BackgroundTransparency = 1
	players.TextColor3 = Color3.fromRGB(190, 195, 205)
	players.FontFace = Fonts.Main
	players.TextScaled = true
	players.TextXAlignment = Enum.TextXAlignment.Left
	players.Parent = frame

	local timer = Instance.new("TextLabel")
	timer.Size = UDim2.new(0, BET_HUD_TIMER_WIDTH, 1, -12)
	timer.Position = UDim2.new(1, -(BET_HUD_TIMER_WIDTH + 10), 0, 6)
	timer.BackgroundTransparency = 1
	timer.TextColor3 = BET_HUD_CALM
	timer.TextStrokeTransparency = 0.4
	timer.TextStrokeColor3 = Color3.new(0, 0, 0)
	timer.FontFace = Fonts.Main
	timer.TextScaled = true
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.Parent = frame

	return { frame = frame, amount = amount, players = players, timer = timer }
end

local betHudRows = {}

local function clearBetHudRows()
	for _, row in betHudRows do
		row.frame:Destroy()
	end

	table.clear(betHudRows)
end

Remotes.BetRoundsUpdated.OnClientEvent:Connect(function(rounds)
	clearBetHudRows()

	for index, round in rounds do
		local row = newBetHudRow(index, round.joined)

		row.amount.Text = Locale.Text("bet_amount", { amount = round.amount })
		row.players.Text = Locale.Text(round.joined and "bet_hud_mine" or "bet_hud_players", { count = round.count })
		row.endsAt = round.endsAt

		table.insert(betHudRows, row)
	end

	betHud.Size = UDim2.new(
		0,
		BET_HUD_WIDTH,
		0,
		BET_HUD_TITLE_HEIGHT + BET_HUD_ROW_GAP + #betHudRows * (BET_HUD_ROW_HEIGHT + BET_HUD_ROW_GAP)
	)
	betHud.Visible = #betHudRows > 0
end)

-- Le decompte se calcule a partir de l'horloge serveur : aucune derive possible,
-- et deux joueurs devant la meme zone voient exactement le meme chiffre.
RunService.Heartbeat:Connect(function()
	if #betHudRows == 0 then
		return
	end

	local now = Workspace:GetServerTimeNow()

	for _, row in betHudRows do
		local remaining = math.max(0, (row.endsAt or now) - now)
		local urgency = 1 - math.clamp(remaining / Config.BET_JOIN_WINDOW, 0, 1)

		row.timer.Text = Locale.Text("bet_hud_timer", { seconds = string.format("%.1f", remaining) })
		row.timer.TextColor3 = BET_HUD_CALM:Lerp(BET_HUD_URGENT, urgency)
	end
end)

-- Au demarrage, un tour peut deja tourner : on reclame l'etat courant plutot
-- que d'attendre le prochain changement.
Remotes.BetRoundsUpdated:FireServer()

Remotes.PlayerTimedOut.OnClientEvent:Connect(function()
	displayTime = 0
	countingDown = false
	label.Text = TimeFormat.Clock(0)
	label.TextColor3 = TIME_COLOR_LOW
	hideBetPrompt()
	hideUpgradePrompt()
	hideShopPrompt()
	playDeathScreen()
end)
