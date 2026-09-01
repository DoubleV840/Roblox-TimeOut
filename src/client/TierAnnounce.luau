-- L'annonce d'une montee : quand quelqu'un franchit un etage, tout le serveur le
-- voit passer.
--
-- C'est ce qui transforme une progression solitaire en evenement social. Un
-- joueur reste au Quai tant qu'il n'a aucune raison d'en partir ; voir un nom
-- qu'il connait monter a la Tour de l'horloge lui en donne une.
--
-- L'AMPLEUR SUIT L'ETAGE, et c'est le point de l'etape. Une montee a la Salle
-- des pas perdus est une breve : un bandeau discret, deux secondes. Une montee
-- au Terminus arrete la partie : l'ecran s'embrase, le bandeau prend toute la
-- largeur, un coup grave passe sous l'annonce et le nom du joueur reste eclaire
-- plusieurs secondes de l'autre bout de la salle. Si les huit paliers
-- s'annoncaient pareil, le dernier ne ferait plus rever.
--
-- Le joueur concerne, lui, ne voit pas son propre bandeau : il a deja sa
-- notification, son badge qui change et son portique qui s'ouvre. Le doubler
-- d'une annonce lui masquerait l'ecran au pire moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Badge = require(ReplicatedStorage.Shared.Badge)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Nameplates = require(script.Parent.Nameplates)

local TierAnnounce = {}

local localPlayer = Players.LocalPlayer

local BANNER_HEIGHT = 78
local BANNER_Y = 96 -- sous la ligne de notification, qui garde sa place

-- Ce qui grandit avec l'etage. Le palier 2 est a "poids" 0, le Terminus a 1 ;
-- tout le reste s'interpole entre les deux.
local HOLD_MIN, HOLD_MAX = 1.8, 4.6 -- secondes d'affichage
local WIDTH_MIN, WIDTH_MAX = 0.42, 0.82 -- part de la largeur de l'ecran
local PITCH_MIN, PITCH_MAX = 2.05, 1.25 -- le son descend quand l'etage monte

-- A partir d'ici, l'annonce n'est plus une breve : coup grave et flash d'ecran.
local BIG_TIER = 6

local banner = nil
local bannerBadge = nil
local bannerName = nil
local bannerTier = nil
local bannerEdge = nil
local flash = nil

-- Deux montees coup sur coup : seule la derniere doit refermer le bandeau.
local token = 0

--------------------------------------------------------------------------------

local function build(screenGui)
	-- Le flash vit sous le bandeau et par-dessus tout le reste du HUD : c'est la
	-- salle qui s'illumine, pas une fenetre de plus.
	flash = Instance.new("Frame")
	flash.Name = "TierAnnounceFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Visible = false
	flash.ZIndex = 40
	flash.Parent = screenGui

	banner = Instance.new("Frame")
	banner.Name = "TierAnnounce"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, BANNER_Y)
	banner.Size = UDim2.new(WIDTH_MIN, 0, 0, BANNER_HEIGHT)
	banner.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	banner.BackgroundTransparency = 0.12
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.ZIndex = 41
	banner.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = banner
	bannerEdge = stroke

	bannerBadge = Badge.New(Tiers.Get(Tiers.FIRST))
	bannerBadge.AnchorPoint = Vector2.new(0, 0.5)
	bannerBadge.Position = UDim2.new(0, 12, 0.5, 0)
	bannerBadge.Size = UDim2.new(0, 0, 0.7, 0)
	bannerBadge.ZIndex = 42
	bannerBadge.Parent = banner

	bannerName = Instance.new("TextLabel")
	bannerName.Size = UDim2.new(1, -86, 0.55, 0)
	bannerName.Position = UDim2.new(0, 74, 0, 6)
	bannerName.BackgroundTransparency = 1
	bannerName.FontFace = Fonts.Main
	bannerName.TextScaled = true
	bannerName.TextXAlignment = Enum.TextXAlignment.Left
	bannerName.Text = ""
	bannerName.ZIndex = 42
	bannerName.Parent = banner

	bannerTier = Instance.new("TextLabel")
	bannerTier.Size = UDim2.new(1, -86, 0.34, 0)
	bannerTier.Position = UDim2.new(0, 74, 0.6, 0)
	bannerTier.BackgroundTransparency = 1
	bannerTier.FontFace = Fonts.Main
	bannerTier.TextScaled = true
	bannerTier.TextXAlignment = Enum.TextXAlignment.Left
	bannerTier.TextColor3 = Color3.fromRGB(225, 225, 235)
	bannerTier.Text = ""
	bannerTier.ZIndex = 42
	bannerTier.Parent = banner
end

--------------------------------------------------------------------------------

-- Le bandeau se ferme en entier -- fond, contour, badge et texte. Ne faire
-- disparaitre que le fond laisserait le nom flotter tout seul au milieu de
-- l'ecran, ce qui se remarque beaucoup plus que le bandeau lui-meme.
local function setFade(fade)
	banner.BackgroundTransparency = 0.12 + fade * 0.88
	bannerEdge.Transparency = fade
	bannerName.TextTransparency = fade
	bannerTier.TextTransparency = fade
	bannerBadge.BackgroundTransparency = 0.3 + fade * 0.7
	bannerBadge:FindFirstChildOfClass("UIStroke").Transparency = fade
	bannerBadge.Symbol.TextTransparency = fade

	-- Pose par TextFx a la premiere annonce, donc absent au tout premier appel.
	local nameStroke = bannerName:FindFirstChild("FxStroke")
	if nameStroke then
		nameStroke.Transparency = 0.3 + fade * 0.7
	end
end

local function fadeOut(seconds)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local badgeStroke = bannerBadge:FindFirstChildOfClass("UIStroke")

	TweenService:Create(banner, info, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(bannerEdge, info, { Transparency = 1 }):Play()
	TweenService:Create(bannerName, info, { TextTransparency = 1 }):Play()
	TweenService:Create(bannerTier, info, { TextTransparency = 1 }):Play()
	TweenService:Create(bannerBadge, info, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(badgeStroke, info, { Transparency = 1 }):Play()
	TweenService:Create(bannerBadge.Symbol, info, { TextTransparency = 1 }):Play()

	local nameStroke = bannerName:FindFirstChild("FxStroke")
	if nameStroke then
		TweenService:Create(nameStroke, info, { Transparency = 1 }):Play()
	end
end

local function announce(player, tierIndex)
	-- Le serveur envoie l'instance Player, pas un pseudo : c'est elle qui permet
	-- d'aller eclairer le bon personnage dans la salle, sans recherche par nom.
	if not banner or player == localPlayer or typeof(player) ~= "Instance" then
		return
	end

	local tier = Tiers.Get(tierIndex)
	-- 0 au premier etage payant, 1 au Terminus.
	local weight = (tier.index - Tiers.FIRST - 1) / math.max(1, Tiers.LAST - Tiers.FIRST - 1)
	weight = math.clamp(weight, 0, 1)

	local hold = HOLD_MIN + (HOLD_MAX - HOLD_MIN) * weight
	local big = tier.index >= BIG_TIER

	token += 1
	local myToken = token

	Sounds.Play("tier_announce", { pitch = PITCH_MIN + (PITCH_MAX - PITCH_MIN) * weight })
	if big then
		Sounds.Play("tier_announce_big")
	end

	Badge.Apply(bannerBadge, tier)
	bannerEdge.Color = tier.color

	bannerName.Text = player.DisplayName
	TextFx.Mark(bannerName, 0.3 + weight * 0.7, tier.color)

	bannerTier.Text = Locale.Text("tier_announce_reaches", { name = Locale.Text(tier.key) })

	-- Tout redevient opaque, PUIS le fond repart de zero : dans l'autre ordre,
	-- setFade ecraserait la valeur de depart du fondu d'entree.
	local width = WIDTH_MIN + (WIDTH_MAX - WIDTH_MIN) * weight
	banner.Size = UDim2.new(width * 0.75, 0, 0, BANNER_HEIGHT)
	setFade(0)
	banner.BackgroundTransparency = 1
	banner.Visible = true

	TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(width, 0, 0, BANNER_HEIGHT),
		BackgroundTransparency = 0.12,
	}):Play()

	-- La salle s'illumine a la couleur de l'etage : reserve aux hauts paliers,
	-- sinon l'ecran clignoterait a chaque joueur qui passe au Buffet.
	if big then
		flash.BackgroundColor3 = tier.color
		flash.BackgroundTransparency = 0.72
		flash.Visible = true
		TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()

		task.delay(0.75, function()
			if myToken == token then
				flash.Visible = false
			end
		end)
	end

	-- Et dans la salle : le panneau du joueur s'allume, pour qu'on sache QUI.
	Nameplates.Cheer(player, tier.index, hold)

	task.delay(hold, function()
		if myToken ~= token then
			return
		end

		fadeOut(0.35)

		task.delay(0.35, function()
			if myToken == token then
				banner.Visible = false
			end
		end)
	end)
end

function TierAnnounce.Start(screenGui)
	build(screenGui)

	Remotes.TierAnnounce.OnClientEvent:Connect(announce)
end

return TierAnnounce
