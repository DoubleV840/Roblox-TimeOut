-- Le panneau des barrieres de palier, et la fenetre de confirmation qui va avec.
--
-- Tout est construit COTE CLIENT, et c'est le point important : l'etat d'une
-- barriere n'est pas le meme pour deux joueurs cote a cote. L'un la voit ouverte
-- parce qu'il a deja l'etage, l'autre lit le prix, le troisieme lit ce qu'il lui
-- manque encore. Un panneau ecrit par le serveur serait partage par tout le
-- monde et ne pourrait dire qu'une seule de ces trois choses -- en plus de
-- l'ecrire dans une seule langue.
--
-- Dans Studio, la barriere n'a donc besoin que d'une SurfaceGui VIDE, avec sa
-- Face reglee du cote d'ou arrivent les joueurs : elle ne sert qu'a indiquer
-- cette face. Sans elle, le panneau se pose sur la face avant -- mal oriente
-- peut-etre, mais une barriere muette serait pire.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Popup = require(script.Parent.Popup)
local WorldPanel = require(script.Parent.WorldPanel)

local TierGates = {}

local PANEL_PIXELS_PER_STUD = 40
local PANEL_WIDTH = 0.62 -- part de la largeur de la barriere occupee par le panneau
local PANEL_HEIGHT = 0.34

local CONFIRM_SIZE = UDim2.new(0, 320, 0, 214)

local OPEN_COLOR = Color3.fromRGB(120, 220, 140)
local POOR_COLOR = Color3.fromRGB(235, 120, 110)
local LOCKED_COLOR = Color3.fromRGB(200, 200, 210)

-- Le prix ne bouge pas, mais ce qu'il MANQUE change a chaque image. On ne
-- reecrit les panneaux que quelques fois par seconde : le joueur ne voit pas la
-- difference, et une map a sept barrieres ne passe pas son temps a se redessiner.
local REFRESH_INTERVAL = 0.2

local panels = {}
local currentTier = Tiers.FIRST
local currentTime = 0

-- La remise en cours du joueur (carte "Billet coupe-file", lot 3). Le panneau
-- affiche le prix REMISE : sans elle, le joueur lirait un prix plus eleve que
-- celui qu'on va lui prendre, et le bouton apparaitrait trop tard.
local currentDiscount = 0
local lastRefresh = 0

local confirmFrame = nil
local confirmTitle = nil
local confirmInfo = nil
local confirmGate = nil

--------------------------------------------------------------------------------
-- Le panneau plaque sur la barriere
--------------------------------------------------------------------------------

local function newPanelLabel(parent, size, position, order)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.FontFace = Fonts.Main
	label.TextScaled = true
	label.ZIndex = order
	label.Parent = parent

	return label
end

local function buildPanel(gate)
	-- La SurfaceGui posee dans Studio ne sert qu'a dire quelle FACE de la
	-- barriere regarde les joueurs ; WorldPanel l'eteint et pose la notre par
	-- dessus (meme mecanique que les vitres de l'etape 10).
	local surface = WorldPanel.Surface(gate, "TierGatePanel", {
		pixelsPerStud = PANEL_PIXELS_PER_STUD,
	})

	local frame = Instance.new("Frame")
	frame.Name = "TierGatePanel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(PANEL_WIDTH, PANEL_HEIGHT)
	frame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = frame

	local title = newPanelLabel(frame, UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.05), 2)
	local price = newPanelLabel(frame, UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.37), 2)
	price.TextColor3 = Color3.fromRGB(255, 221, 0)

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Size = UDim2.fromScale(0.7, 0.28)
	button.Position = UDim2.fromScale(0.5, 0.62)
	button.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
	button.AutoButtonColor = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.FontFace = Fonts.Main
	button.TextScaled = true
	button.Text = ""
	button.ZIndex = 3
	button.Parent = frame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = button

	-- Etat "ouvert" ou "pas assez" : la place du bouton, mais rien a valider.
	local status = newPanelLabel(frame, UDim2.fromScale(1, 0.28), UDim2.fromScale(0, 0.62), 2)

	Popup.BindButtonSounds(button)

	local panel = {
		gate = gate,
		surface = surface,
		frame = frame,
		stroke = stroke,
		title = title,
		price = price,
		button = button,
		status = status,
	}

	button.MouseButton1Click:Connect(function()
		TierGates.Confirm(gate)
	end)

	return panel
end

--------------------------------------------------------------------------------
-- Etat d'une barriere pour CE joueur
--------------------------------------------------------------------------------

local function refreshPanel(panel)
	local target = tonumber(panel.gate:GetAttribute(Config.TIER_TARGET_ATTRIBUTE))
	if not target then
		panel.frame.Visible = false
		return
	end

	target = Tiers.Clamp(target)
	panel.frame.Visible = true

	local tier = Tiers.Get(target)
	local price = Tiers.Price(target, currentDiscount)
	local required = Tiers.Required(target, currentDiscount)

	panel.stroke.Color = tier.color
	panel.title.Text = Locale.Text(tier.key)
	TextFx.Mark(panel.title, 0.35 + (target / Tiers.LAST) * 0.5, tier.color)
	panel.price.Text = Locale.Text(
		currentDiscount > 0 and "tier_gate_price_discount" or "tier_gate_price",
		{ amount = price, full = tier.cost }
	)

	-- Chez lui : le panneau se tait, la barriere ne bloque plus.
	if currentTier >= target then
		panel.button.Visible = false
		panel.status.Visible = true
		panel.status.Text = Locale.Text("tier_gate_open")
		panel.status.TextColor3 = OPEN_COLOR
		panel.price.Visible = false
		return
	end

	panel.price.Visible = true

	-- Une marche sautee : rien a proposer ici tant que la precedente n'est pas payee.
	if target > currentTier + 1 then
		panel.button.Visible = false
		panel.status.Visible = true
		panel.status.Text = Locale.Text("tier_gate_needs", { tier = currentTier + 1 })
		panel.status.TextColor3 = LOCKED_COLOR
		return
	end

	if currentTime < required then
		panel.button.Visible = false
		panel.status.Visible = true
		panel.status.Text = Locale.Text("tier_gate_missing", { amount = math.ceil(required - currentTime) })
		panel.status.TextColor3 = POOR_COLOR
		return
	end

	panel.button.Visible = true
	panel.status.Visible = false
	panel.button.Text = Locale.Text("tier_gate_buy")
	panel.button.BackgroundColor3 = tier.color:Lerp(Color3.new(0, 0, 0), 0.55)
end

local function refreshAll()
	for _, panel in panels do
		refreshPanel(panel)
	end
end

local function setupGate(gate)
	if not gate:IsA("BasePart") or panels[gate] then
		return
	end

	local panel = buildPanel(gate)
	panels[gate] = panel

	gate:GetAttributeChangedSignal(Config.TIER_TARGET_ATTRIBUTE):Connect(function()
		refreshPanel(panel)
	end)

	refreshPanel(panel)
end

--------------------------------------------------------------------------------
-- La confirmation
--------------------------------------------------------------------------------

local function buildConfirm(screenGui)
	local frame = Instance.new("Frame")
	frame.Name = "TierConfirm"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = CONFIRM_SIZE
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.1
	frame.Visible = false
	frame.Parent = screenGui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.Parent = frame

	confirmTitle = Instance.new("TextLabel")
	confirmTitle.Size = UDim2.new(1, 0, 0, 40)
	confirmTitle.BackgroundTransparency = 1
	confirmTitle.FontFace = Fonts.Main
	confirmTitle.TextScaled = true
	confirmTitle.Parent = frame

	confirmInfo = Instance.new("TextLabel")
	confirmInfo.Size = UDim2.new(1, -24, 0, 96)
	confirmInfo.Position = UDim2.new(0, 12, 0, 44)
	confirmInfo.BackgroundTransparency = 1
	confirmInfo.TextColor3 = Color3.fromRGB(255, 221, 0)
	confirmInfo.FontFace = Fonts.Main
	confirmInfo.TextScaled = true
	confirmInfo.Text = ""
	confirmInfo.Parent = frame

	local accept = Instance.new("TextButton")
	accept.Size = UDim2.new(0.45, 0, 0, 40)
	accept.Position = UDim2.new(0.025, 0, 1, -50)
	accept.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
	accept.TextColor3 = Color3.new(1, 1, 1)
	accept.FontFace = Fonts.Main
	accept.TextScaled = true
	accept.Text = Locale.Text("tier_confirm_accept")
	accept.Parent = frame

	local decline = Instance.new("TextButton")
	decline.Size = UDim2.new(0.45, 0, 0, 40)
	decline.Position = UDim2.new(0.525, 0, 1, -50)
	decline.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	decline.TextColor3 = Color3.new(1, 1, 1)
	decline.FontFace = Fonts.Main
	decline.TextScaled = true
	decline.Text = Locale.Text("tier_confirm_decline")
	decline.Parent = frame

	Popup.BindButtonSounds(accept)
	Popup.BindButtonSounds(decline)

	accept.MouseButton1Click:Connect(function()
		if confirmGate then
			Remotes.TierBuy:FireServer(confirmGate)
		end
		TierGates.HideConfirm()
	end)

	decline.MouseButton1Click:Connect(function()
		TierGates.HideConfirm()
	end)

	confirmFrame = frame
end

function TierGates.HideConfirm()
	confirmGate = nil
	if confirmFrame then
		Popup.Out(confirmFrame)
	end
end

function TierGates.Confirm(gate)
	local target = tonumber(gate:GetAttribute(Config.TIER_TARGET_ATTRIBUTE))
	if not confirmFrame or not target then
		return
	end

	target = Tiers.Clamp(target)
	local tier = Tiers.Get(target)
	local required = Tiers.Required(target, currentDiscount)

	-- Le serveur refuserait de toute facon : autant le dire ici, sans ouvrir une
	-- fenetre qui ne propose rien.
	if currentTier >= target or target > currentTier + 1 or currentTime < required then
		Sounds.Play("tier_denied")
		return
	end

	confirmGate = gate
	confirmTitle.Text = Locale.Text(tier.key)
	TextFx.Mark(confirmTitle, 0.6, tier.color)
	confirmInfo.Text = Locale.Text("tier_confirm_info", {
		amount = Tiers.Price(target, currentDiscount),
		multiplier = tier.multiplier,
	})

	Popup.In(confirmFrame, CONFIRM_SIZE)
end

--------------------------------------------------------------------------------

function TierGates.SetTier(tier, discount)
	currentTier = Tiers.Clamp(tier)
	currentDiscount = discount or 0
	refreshAll()

	-- Le palier vient d'etre paye : la fenetre encore ouverte ne propose plus rien.
	TierGates.HideConfirm()
end

function TierGates.SetTime(seconds)
	currentTime = seconds

	local now = os.clock()
	if now - lastRefresh < REFRESH_INTERVAL then
		return
	end

	lastRefresh = now
	refreshAll()
end

function TierGates.Start(screenGui)
	buildConfirm(screenGui)

	for _, gate in CollectionService:GetTagged(Config.TIER_GATE_TAG) do
		setupGate(gate)
	end

	CollectionService:GetInstanceAddedSignal(Config.TIER_GATE_TAG):Connect(setupGate)

	CollectionService:GetInstanceRemovedSignal(Config.TIER_GATE_TAG):Connect(function(gate)
		local panel = panels[gate]
		if panel then
			panel.surface:Destroy()
			panels[gate] = nil
		end
	end)
end

return TierGates
