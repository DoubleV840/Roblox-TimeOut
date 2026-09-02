-- Les zones de power-up, cote joueur : la fenetre d'achat, le panneau flottant
-- au-dessus de la zone, et le bouton de Frenesie.
--
-- Tout est construit ICI et non par le serveur, pour la raison qui vaut partout
-- dans ce jeu : deux joueurs devant la meme zone n'y lisent pas la meme chose.
-- L'un voit "niveau 3, prochain 4 min", l'autre un cadenas et le palier qu'il
-- lui faut. Un panneau ecrit par le serveur serait partage par les deux.
--
-- Le serveur n'envoie que ce que le client ne peut pas deviner -- le niveau de
-- CE joueur et son prix. Les effets, eux, sont recalcules ici depuis
-- src/shared/PowerUps.luau : la fenetre affiche donc exactement ce que le
-- serveur appliquera, parce que les deux lisent la meme fonction.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PowerUps = require(ReplicatedStorage.Shared.PowerUps)
local Popup = require(script.Parent.Popup)

local PowerUpZones = {}

local WINDOW_SIZE = UDim2.new(0, 340, 0, 260)

local LOCKED_COLOR = Color3.fromRGB(200, 200, 210)

local window = nil
local title = nil
local info = nil
local buyButton = nil
local closeButton = nil

local currentZone = nil
local currentLocked = false

-- Ce que le HUD sait des power-ups du joueur : les niveaux possedes, et l'etat
-- de la Frenesie. Le compte a rebours de la recharge descend ICI, image par
-- image -- le serveur ne recale qu'aux changements.
local levels = {}
local frenzyCooldown = 0
local frenzyActive = 0
local frenzyStamp = 0

local frenzyButton = nil
local frenzyLabel = nil
local frenzyPulse = nil
local frenzyPulsing = false

--------------------------------------------------------------------------------
-- La fenetre d'achat
--------------------------------------------------------------------------------

local function buildWindow(screenGui)
	window = Instance.new("Frame")
	window.Name = "PowerUpWindow"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = WINDOW_SIZE
	window.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	window.BackgroundTransparency = 0.1
	window.Visible = false
	window.Parent = screenGui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.Parent = window

	title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.Parent = window

	info = Instance.new("TextLabel")
	info.Size = UDim2.new(1, -24, 1, -140)
	info.Position = UDim2.new(0, 12, 0, 46)
	info.BackgroundTransparency = 1
	info.TextColor3 = Color3.fromRGB(225, 228, 235)
	info.FontFace = Fonts.Main
	info.TextScaled = true
	info.TextWrapped = true
	info.Parent = window

	buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.new(1, -24, 0, 38)
	buyButton.Position = UDim2.new(0, 12, 1, -96)
	buyButton.BackgroundColor3 = Color3.fromRGB(60, 140, 90)
	buyButton.TextColor3 = Color3.new(1, 1, 1)
	buyButton.FontFace = Fonts.Main
	buyButton.TextScaled = true
	buyButton.Parent = window

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 6)
	buyCorner.Parent = buyButton

	closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(1, -24, 0, 34)
	closeButton.Position = UDim2.new(0, 12, 1, -50)
	closeButton.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.FontFace = Fonts.Main
	closeButton.TextScaled = true
	closeButton.Text = Locale.Text("shop_close")
	closeButton.Parent = window

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	Popup.BindButtonSounds(buyButton)
	Popup.BindButtonSounds(closeButton)

	buyButton.MouseButton1Click:Connect(function()
		if currentZone and not currentLocked then
			Remotes.PowerUpBuy:FireServer(currentZone)
		end
	end)

	closeButton.MouseButton1Click:Connect(function()
		PowerUpZones.Hide()
	end)
end

-- La meme fenetre sert aux trois etats de la zone : ouverte (on achete),
-- verrouillee (on lit ce qu'il faut atteindre), et au plafond (il n'y a plus
-- rien a acheter). Un seul bouton dans les deux derniers cas -- il n'y a rien a
-- valider.
local function showPrompt(zone, prompt)
	local power = PowerUps.Get(prompt.key)
	if not power then
		return
	end

	currentZone = zone
	currentLocked = prompt.locked ~= nil or prompt.maxed

	local nameKey = "powerup_" .. power.key .. "_name"

	if prompt.locked then
		title.Text = Locale.Text("bet_locked_title")
		TextFx.Mark(title, 0.2, LOCKED_COLOR)
		info.Text = Locale.Text("powerup_locked_info", {
			name = Locale.Text(nameKey),
			tier = prompt.locked,
		})
		info.TextColor3 = LOCKED_COLOR
	else
		title.Text = Locale.Text(nameKey)
		TextFx.Mark(title, 0.6, power.color)
		info.TextColor3 = Color3.fromRGB(225, 228, 235)

		if prompt.maxed then
			info.Text = Locale.Text("powerup_maxed", {
				level = prompt.level,
				value = PowerUps.Value(power, prompt.level, prompt.timeLeft),
			})
		else
			-- On annonce d'ou on part ET ou on arrive : c'est la comparaison qui
			-- fait la decision, pas la valeur d'arrivee toute seule.
			info.Text = Locale.Text("powerup_" .. power.key .. "_info", {
				level = prompt.level,
				next = prompt.level + 1,
				from = PowerUps.Value(power, prompt.level, prompt.timeLeft),
				to = PowerUps.Value(power, prompt.level + 1, prompt.timeLeft),
				amount = prompt.cost,
			})
		end
	end

	buyButton.Visible = not currentLocked
	buyButton.Text = Locale.Text("powerup_buy", { amount = prompt.cost })

	if not window.Visible then
		Popup.In(window, WINDOW_SIZE)

		if prompt.locked then
			-- Une zone encore fermee se signale a l'oreille : le "pop" de la
			-- fenetre est le meme pour tout le monde, le refus qui le suit ne
			-- trompe pas.
			Sounds.Play("ui_denied")
		end
	end
end

function PowerUpZones.Hide()
	currentZone = nil
	currentLocked = false

	if window then
		Popup.Out(window)
	end
end

--------------------------------------------------------------------------------
-- Le bouton de Frenesie
--------------------------------------------------------------------------------

-- Le seul power-up qui se DECLENCHE. Il lui faut donc un bouton permanent, et
-- pas seulement une ligne dans une fenetre qu'on ouvre en marchant sur une
-- dalle : un pic de puissance ne sert a rien s'il faut traverser la salle pour
-- l'allumer.
local FRENZY_READY = Color3.fromRGB(255, 110, 60)
local FRENZY_WAIT = Color3.fromRGB(120, 120, 130)

local function buildFrenzy(screenGui)
	frenzyButton = Instance.new("TextButton")
	frenzyButton.Name = "FrenzyButton"
	frenzyButton.AnchorPoint = Vector2.new(0.5, 1)
	frenzyButton.Position = UDim2.new(0.5, 0, 1, -100)
	frenzyButton.Size = UDim2.new(0, 200, 0, 42)
	frenzyButton.BackgroundColor3 = Color3.fromRGB(28, 20, 18)
	frenzyButton.AutoButtonColor = false
	frenzyButton.Text = ""
	frenzyButton.Visible = false
	frenzyButton.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frenzyButton

	local stroke = Instance.new("UIStroke")
	stroke.Color = FRENZY_READY
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = frenzyButton

	frenzyLabel = Instance.new("TextLabel")
	frenzyLabel.Size = UDim2.new(1, -16, 1, -10)
	frenzyLabel.Position = UDim2.new(0, 8, 0, 5)
	frenzyLabel.BackgroundTransparency = 1
	frenzyLabel.FontFace = Fonts.Main
	frenzyLabel.TextScaled = true
	frenzyLabel.Parent = frenzyButton

	frenzyPulse = TweenService:Create(
		stroke,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8 }
	)

	Popup.BindButtonSounds(frenzyButton)

	frenzyButton.MouseButton1Click:Connect(function()
		if frenzyCooldown <= 0 and frenzyActive <= 0 then
			Remotes.PowerUpUse:FireServer()
		end
	end)

	return stroke
end

local frenzyStroke = nil

local function setFrenzyPulse(active)
	if active == frenzyPulsing then
		return
	end

	frenzyPulsing = active

	if active then
		frenzyPulse:Play()
	else
		frenzyPulse:Cancel()
		frenzyStroke.Transparency = 0.2
	end
end

--------------------------------------------------------------------------------
-- Le panneau au-dessus de la zone
--------------------------------------------------------------------------------

-- Cree localement, donc visible du seul joueur : il porte SON niveau. Un panneau
-- partage ne pourrait afficher que le nom du power-up, ce que le serveur fait
-- deja de son cote.
local worldSigns = {}

local function ensureWorldSign(zone, power)
	local sign = worldSigns[zone]
	if sign then
		return sign
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MyPowerUpLevel"
	billboard.Size = UDim2.new(9, 0, 1.8, 0) -- en studs : taille fixe dans le monde
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Fonts.Main
	label.TextScaled = true
	label.Parent = billboard

	sign = { billboard = billboard, label = label, power = power }
	worldSigns[zone] = sign

	return sign
end

local function refreshWorldSign(zone, prompt)
	local power = PowerUps.Get(prompt.key)
	if not power then
		return
	end

	local sign = ensureWorldSign(zone, power)

	if prompt.locked then
		sign.label.Text = Locale.Text("powerup_sign_locked", { tier = prompt.locked })
		TextFx.Mark(sign.label, 0.15, LOCKED_COLOR)
	elseif prompt.level > 0 then
		sign.label.Text = Locale.Text("powerup_sign_level", { level = prompt.level })
		TextFx.Mark(sign.label, math.min(1, prompt.level / PowerUps.MAX_LEVEL), power.color)
	else
		sign.label.Text = Locale.Text("powerup_sign_new")
		TextFx.Mark(sign.label, 0.5, power.color)
	end
end

--------------------------------------------------------------------------------

local function refreshFrenzy()
	local owned = (levels[PowerUps.FRENZY] or 0) > 0

	frenzyButton.Visible = owned

	if not owned then
		setFrenzyPulse(false)
		return
	end

	if frenzyActive > 0 then
		frenzyLabel.Text = Locale.Text("hud_frenzy_active", { seconds = math.ceil(frenzyActive) })
		frenzyLabel.TextColor3 = FRENZY_READY
		frenzyStroke.Color = FRENZY_READY
		setFrenzyPulse(true)
	elseif frenzyCooldown > 0 then
		frenzyLabel.Text = Locale.Text("hud_frenzy_wait", { seconds = math.ceil(frenzyCooldown) })
		frenzyLabel.TextColor3 = FRENZY_WAIT
		frenzyStroke.Color = FRENZY_WAIT
		setFrenzyPulse(false)
	else
		frenzyLabel.Text = Locale.Text("hud_frenzy_ready")
		frenzyLabel.TextColor3 = FRENZY_READY
		frenzyStroke.Color = FRENZY_READY
		setFrenzyPulse(true)
	end
end

function PowerUpZones.SetState(state)
	levels = state.levels or {}
	frenzyCooldown = state.frenzyCooldown or 0
	frenzyActive = state.frenzyActive or 0
	frenzyStamp = os.clock()

	refreshFrenzy()
end

-- La Frenesie est aussi declenchee par un cadeau de survie (lot 7) : le serveur
-- renvoie alors l'etat, et ce module n'a rien de particulier a faire.
function PowerUpZones.Start(screenGui)
	buildWindow(screenGui)
	frenzyStroke = buildFrenzy(screenGui)

	Remotes.PowerUpPrompt.OnClientEvent:Connect(function(zone, prompt)
		refreshWorldSign(zone, prompt)
		showPrompt(zone, prompt)
	end)

	Remotes.PowerUpPromptHide.OnClientEvent:Connect(function(zone)
		if currentZone == zone then
			PowerUpZones.Hide()
		end
	end)

	Remotes.PowerUpUpdated.OnClientEvent:Connect(PowerUpZones.SetState)

	-- L'etat est reclame, pas attendu (meme raison que partout ailleurs : les
	-- Remotes ne sont pas branches a l'arrivee du joueur).
	Remotes.PowerUpUpdated:FireServer()

	-- Le compte a rebours descend ici, image par image, exactement comme le
	-- chrono et la jauge de carburant : le serveur ne le recale qu'aux
	-- changements, au lieu d'un message par seconde et par joueur.
	task.spawn(function()
		while true do
			task.wait(0.25)

			local elapsed = os.clock() - frenzyStamp
			frenzyStamp = os.clock()

			if frenzyActive > 0 then
				frenzyActive = math.max(0, frenzyActive - elapsed)
				refreshFrenzy()
			elseif frenzyCooldown > 0 then
				frenzyCooldown = math.max(0, frenzyCooldown - elapsed)
				refreshFrenzy()
			end
		end
	end)
end

return PowerUpZones
