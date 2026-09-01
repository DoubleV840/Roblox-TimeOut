-- Les panneaux d'appel : devant chaque vitre, ce qu'il y a de l'autre cote.
--
-- L'etape 9 laisse le joueur VOIR les mieux lotis vivre leur vie ; celle-ci lui
-- dit combien coute d'en etre. C'est le couple des deux qui fait la retention :
-- une vitre sans panneau montre un endroit sans nom ni prix, un panneau sans
-- vitre annonce un endroit qu'on n'a jamais vu.
--
-- Construit COTE CLIENT, comme les panneaux de barriere et pour la meme raison :
-- deux joueurs devant la meme vitre n'y lisent pas la meme chose. Et celui qui a
-- deja l'etage ne lit rien du tout -- le panneau se tait, il est chez lui.
--
-- Une difference avec la barriere : on ne peut rien acheter ici. Une vitre n'est
-- pas un passage, et un bouton "ENTRER" qui n'ouvrirait rien serait une promesse
-- en l'air. Le panneau donne envie, la barriere encaisse.
--
-- Dans Studio : tag TierWindow, attribut nombre TargetTier, et une SurfaceGui
-- VIDE dont la Face indique de quel cote arrivent les joueurs. Rien d'autre.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Badge = require(ReplicatedStorage.Shared.Badge)
local WorldPanel = require(script.Parent.WorldPanel)

local TierWindows = {}

local PANEL_PIXELS_PER_STUD = 34
local PANEL_WIDTH = 0.46 -- part de la largeur de la vitre occupee par le panneau
local PANEL_HEIGHT = 0.4

-- Le halo : un cadre a la couleur de l'etage, plus large que le panneau, qui
-- respire. C'est lui qu'on voit du fond de la salle, avant de savoir lire ce
-- qui est ecrit dessus.
local HALO_SPREAD = 0.055 -- part de la taille du panneau debordant de chaque cote
local HALO_PERIOD = 1.6

local panels = {}
local currentTier = Tiers.FIRST

--------------------------------------------------------------------------------

local function newLabel(parent, size, position, order)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.FontFace = Fonts.Main
	label.TextScaled = true
	label.ZIndex = order
	label.Text = ""
	label.Parent = parent

	return label
end

local function buildPanel(window)
	local surface = WorldPanel.Surface(window, "TierWindowPanel", {
		pixelsPerStud = PANEL_PIXELS_PER_STUD,
		maxDistance = 260,
	})

	local root = Instance.new("Frame")
	root.Name = "TierWindowPanel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(PANEL_WIDTH, PANEL_HEIGHT)
	root.BackgroundTransparency = 1
	root.Parent = surface

	local halo = Instance.new("Frame")
	halo.Name = "Halo"
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(1 + HALO_SPREAD * 2, 1 + HALO_SPREAD * 2)
	halo.BackgroundTransparency = 0.55
	halo.BorderSizePixel = 0
	halo.ZIndex = 1
	halo.Parent = root

	local haloCorner = Instance.new("UICorner")
	haloCorner.CornerRadius = UDim.new(0, 16)
	haloCorner.Parent = halo

	local frame = Instance.new("Frame")
	frame.Name = "Body"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.ZIndex = 2
	frame.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = frame

	local badge = Badge.New(Tiers.Get(Tiers.FIRST))
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.fromScale(0.035, 0.19)
	badge.Size = UDim2.new(0, 0, 0.24, 0)
	badge.ZIndex = 3
	badge.Parent = frame

	local title = newLabel(frame, UDim2.fromScale(0.74, 0.24), UDim2.fromScale(0.22, 0.07), 3)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local price = newLabel(frame, UDim2.fromScale(0.92, 0.19), UDim2.fromScale(0.04, 0.35), 3)
	price.TextColor3 = Color3.fromRGB(255, 221, 0)

	local multiplier = newLabel(frame, UDim2.fromScale(0.92, 0.16), UDim2.fromScale(0.04, 0.56), 3)
	multiplier.TextColor3 = Color3.fromRGB(225, 225, 235)

	local unlocks = newLabel(frame, UDim2.fromScale(0.92, 0.2), UDim2.fromScale(0.04, 0.74), 3)
	unlocks.TextColor3 = Color3.fromRGB(165, 170, 185)

	local pulse = TweenService:Create(
		halo,
		TweenInfo.new(HALO_PERIOD, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.85 }
	)
	pulse:Play()

	return {
		window = window,
		surface = surface,
		root = root,
		halo = halo,
		stroke = stroke,
		badge = badge,
		title = title,
		price = price,
		multiplier = multiplier,
		unlocks = unlocks,
	}
end

--------------------------------------------------------------------------------

local function refreshPanel(panel)
	local target = tonumber(panel.window:GetAttribute(Config.TIER_TARGET_ATTRIBUTE))

	-- Sans attribut, on ne sait pas quel etage on regarde : mieux vaut une vitre
	-- muette qu'un panneau qui annonce le mauvais prix.
	if not target then
		panel.root.Visible = false
		return
	end

	target = Tiers.Clamp(target)

	-- Chez lui : le panneau se tait. Un joueur n'a pas a se faire vendre en
	-- boucle un etage qu'il a deja paye.
	if currentTier >= target then
		panel.root.Visible = false
		return
	end

	panel.root.Visible = true

	local tier = Tiers.Get(target)

	panel.halo.BackgroundColor3 = tier.color
	panel.stroke.Color = tier.color
	Badge.Apply(panel.badge, tier)

	panel.title.Text = Locale.Text(tier.key)
	-- Plus l'etage est haut, plus le panneau s'agite : c'est la seule chose qui
	-- distingue un appel pour le Buffet d'un appel pour le Terminus quand on ne
	-- sait pas encore lire les prix.
	TextFx.Mark(panel.title, 0.35 + (target / Tiers.LAST) * 0.55, tier.color)

	panel.price.Text = Locale.Text("tier_gate_price", { amount = tier.cost })
	panel.multiplier.Text = Locale.Text("tier_window_multiplier", { multiplier = tier.multiplier })
	panel.unlocks.Text = Locale.Text("tier_window_unlocks_" .. target)
end

local function refreshAll()
	for _, panel in panels do
		refreshPanel(panel)
	end
end

local function setupWindow(window)
	if not window:IsA("BasePart") or panels[window] then
		return
	end

	local panel = buildPanel(window)
	panels[window] = panel

	-- L'attribut peut se regler en direct dans Studio : le panneau suit sans
	-- qu'il faille relancer la partie.
	window:GetAttributeChangedSignal(Config.TIER_TARGET_ATTRIBUTE):Connect(function()
		refreshPanel(panel)
	end)

	refreshPanel(panel)
end

--------------------------------------------------------------------------------

function TierWindows.SetTier(tier)
	currentTier = Tiers.Clamp(tier)
	refreshAll()
end

function TierWindows.Start()
	for _, window in CollectionService:GetTagged(Config.TIER_WINDOW_TAG) do
		setupWindow(window)
	end

	CollectionService:GetInstanceAddedSignal(Config.TIER_WINDOW_TAG):Connect(setupWindow)

	CollectionService:GetInstanceRemovedSignal(Config.TIER_WINDOW_TAG):Connect(function(window)
		local panel = panels[window]
		if panel then
			panel.surface:Destroy()
			panels[window] = nil
		end
	end)
end

return TierWindows
