-- Le panneau au-dessus des joueurs : le pseudo, le badge du palier atteint, et
-- le chrono en direct dans le degrade vert -> rouge du HUD.
--
-- Il montre TOUJOURS quelqu'un d'autre. Le joueur ne voit pas le sien : il a
-- deja le HUD, et un panneau colle a sa nuque generait la camera.
--
-- D'ou vient le chrono d'un autre joueur : de deux attributs poses sur son
-- instance Player par le serveur (voir src/server/Presence). Remotes.TimeUpdated
-- ne parle qu'au proprietaire du chrono ; il ne pouvait donc pas alimenter ce
-- panneau-la. Le serveur ne publie que des secondes entieres, une fois par
-- seconde : les decimales descendent ici, image par image, exactement comme
-- celles du HUD.
--
-- C'est le DEGRADE qui porte l'information -- "qui est en train de mourir ?" --
-- pas le chiffre. Il doit donc etre exactement celui du HUD, sinon on ne peut
-- pas comparer sa propre couleur a celle des autres : les deux echelles vivent
-- dans Colors, et nulle part ailleurs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Colors = require(ReplicatedStorage.Shared.Colors)
local Badge = require(ReplicatedStorage.Shared.Badge)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)

local Nameplates = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local PLATE_SIZE = UDim2.new(8.5, 0, 2.6, 0) -- en studs : taille fixe dans le monde
local PLATE_OFFSET = Vector3.new(0, 3.2, 0)

local NAME_COLOR = Color3.fromRGB(240, 240, 245)

-- Le coup de projecteur d'une montee (etape 12) : le panneau grossit, passe
-- devant le decor et prend la couleur de l'etage paye.
local CHEER_SCALE = 1.45
local CHEER_RISE = 0.8 -- studs gagnes pendant le projecteur

local plates = {}
local loop = nil

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

local function newLabel(parent, size, position, order)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.FontFace = Fonts.Main
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.ZIndex = order
	label.Text = ""
	label.Parent = parent

	return label
end

local function build(player)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nameplate_" .. player.UserId
	billboard.Size = PLATE_SIZE
	billboard.StudsOffsetWorldSpace = PLATE_OFFSET
	-- Depth-teste : un panneau ne traverse pas un plancher. A travers une vitre,
	-- si -- une Part transparente ne masque pas un BillboardGui, ce qui est
	-- exactement ce que les vitres de l'etape 9 doivent laisser voir.
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = Config.NAMEPLATE_FADE_END
	billboard.ResetOnSpawn = false
	billboard.Enabled = false
	billboard.Parent = playerGui

	local top = Instance.new("Frame")
	top.Size = UDim2.fromScale(1, 0.56)
	top.BackgroundTransparency = 1
	top.Parent = billboard

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = top

	local badge = Badge.New(Tiers.Get(Tiers.FIRST))
	badge.Size = UDim2.new(0, 0, 0.9, 0)
	badge.LayoutOrder = 1
	badge.Parent = top

	local nameLabel = newLabel(top, UDim2.fromScale(0.74, 1), UDim2.fromScale(0, 0), 2)
	nameLabel.LayoutOrder = 2
	nameLabel.TextColor3 = NAME_COLOR
	nameLabel.Text = player.DisplayName

	local timeLabel = newLabel(billboard, UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0.58), 2)

	return {
		player = player,
		billboard = billboard,
		badge = badge,
		badgeStroke = badge:FindFirstChildOfClass("UIStroke"),
		badgeSymbol = badge.Symbol,
		nameLabel = nameLabel,
		timeLabel = timeLabel,
		connections = {},
		-- Ce que le serveur a publie en dernier, et qu'on fait descendre ici.
		time = nil,
		text = "",
		cheerUntil = 0,
		highlight = nil,
	}
end

--------------------------------------------------------------------------------
-- Ce que le serveur publie
--------------------------------------------------------------------------------

local function readTier(plate)
	Badge.Apply(plate.badge, Tiers.Get(plate.player:GetAttribute(Config.PRESENCE_TIER_ATTRIBUTE)))
end

local function readTime(plate)
	-- nil = donnees pas encore chargees cote serveur. Le panneau reste alors
	-- muet plutot que d'afficher un zero, qui ferait croire a une agonie.
	plate.time = tonumber(plate.player:GetAttribute(Config.PRESENCE_TIME_ATTRIBUTE))
end

--------------------------------------------------------------------------------
-- Le personnage
--------------------------------------------------------------------------------

local function bindCharacter(plate, character)
	plate.billboard.Enabled = false
	plate.billboard.Adornee = nil

	if not character then
		return
	end

	task.spawn(function()
		local head = character:WaitForChild("Head", 10)

		-- Le joueur a pu mourir, repartir ou quitter pendant l'attente.
		if not head or plates[plate.player] ~= plate or character.Parent == nil then
			return
		end

		plate.billboard.Adornee = head
		plate.billboard.Enabled = true
	end)
end

local function watch(player)
	if player == localPlayer or plates[player] then
		return
	end

	local plate = build(player)
	plates[player] = plate

	readTier(plate)
	readTime(plate)

	plate.connections = {
		player:GetAttributeChangedSignal(Config.PRESENCE_TIER_ATTRIBUTE):Connect(function()
			readTier(plate)
		end),
		player:GetAttributeChangedSignal(Config.PRESENCE_TIME_ATTRIBUTE):Connect(function()
			readTime(plate)
		end),
		player.CharacterAdded:Connect(function(character)
			bindCharacter(plate, character)
		end),
		player.CharacterRemoving:Connect(function()
			bindCharacter(plate, nil)
		end),
	}

	bindCharacter(plate, player.Character)
end

local function forget(player)
	local plate = plates[player]
	if not plate then
		return
	end

	plates[player] = nil

	for _, connection in plate.connections do
		connection:Disconnect()
	end

	if plate.highlight then
		plate.highlight:Destroy()
	end

	plate.billboard:Destroy()
end

--------------------------------------------------------------------------------
-- Rendu
--------------------------------------------------------------------------------

-- Un hall plein ne doit pas devenir un mur de texte : le panneau s'efface avec
-- la distance, et a disparu bien avant d'etre de toute facon illisible.
local function fadeFor(plate)
	local camera = Workspace.CurrentCamera
	local adornee = plate.billboard.Adornee
	if not camera or not adornee then
		return 1
	end

	local distance = (camera.CFrame.Position - adornee.Position).Magnitude
	if distance <= Config.NAMEPLATE_FADE_START then
		return 0
	end

	local span = math.max(1, Config.NAMEPLATE_FADE_END - Config.NAMEPLATE_FADE_START)
	return math.clamp((distance - Config.NAMEPLATE_FADE_START) / span, 0, 1)
end

local function render(plate, deltaTime, clock)
	if not plate.billboard.Enabled then
		return
	end

	if plate.time then
		-- Entre deux publications, le chrono descend ici : sans ca il avancerait
		-- par saccades d'une seconde, et le degrade sauterait avec lui.
		plate.time = math.max(0, plate.time - deltaTime)

		local text = TimeFormat.Short(plate.time)
		if text ~= plate.text then
			plate.text = text
			plate.timeLabel.Text = text
		end

		plate.timeLabel.TextColor3 = Colors.ForTime(plate.time)
	elseif plate.text ~= "" then
		plate.text = ""
		plate.timeLabel.Text = ""
	end

	-- Pendant le projecteur le panneau ne s'efface pas : c'est justement le
	-- moment ou il doit se voir du fond de la salle.
	local fade = if clock < plate.cheerUntil then 0 else fadeFor(plate)

	plate.nameLabel.TextTransparency = fade
	plate.nameLabel.TextStrokeTransparency = 0.35 + fade * 0.65
	plate.timeLabel.TextTransparency = fade
	plate.timeLabel.TextStrokeTransparency = 0.35 + fade * 0.65
	plate.badge.BackgroundTransparency = 0.3 + fade * 0.7
	plate.badgeStroke.Transparency = fade
	plate.badgeSymbol.TextTransparency = fade
end

local function startLoop()
	if loop then
		return
	end

	loop = RunService.RenderStepped:Connect(function(deltaTime)
		local clock = os.clock()

		for _, plate in plates do
			render(plate, deltaTime, clock)
		end
	end)
end

--------------------------------------------------------------------------------
-- Le coup de projecteur (etape 12)
--------------------------------------------------------------------------------

-- "Son nom mis en avant un instant" : le panneau de celui qui vient de monter
-- grossit, passe devant le decor et prend la couleur de l'etage. Sans ca,
-- l'annonce n'est qu'un texte dans un coin de l'ecran et personne ne sait QUI a
-- monte -- alors que c'est tout l'interet de l'annoncer.
function Nameplates.Cheer(player, tierIndex, seconds)
	local plate = plates[player]
	if not plate then
		return
	end

	local tier = Tiers.Get(tierIndex)

	plate.cheerUntil = os.clock() + seconds
	plate.billboard.Size = UDim2.new(PLATE_SIZE.X.Scale * CHEER_SCALE, 0, PLATE_SIZE.Y.Scale * CHEER_SCALE, 0)
	plate.billboard.StudsOffsetWorldSpace = PLATE_OFFSET + Vector3.new(0, CHEER_RISE, 0)
	plate.billboard.AlwaysOnTop = true
	plate.nameLabel.TextColor3 = tier.color

	if plate.highlight then
		plate.highlight:Destroy()
		plate.highlight = nil
	end

	local character = player.Character
	if character then
		-- Cree cote client : le Highlight n'existe que dans les yeux de celui
		-- qui regarde, et il ne coute rien a personne d'autre.
		local highlight = Instance.new("Highlight")
		highlight.FillColor = tier.color
		highlight.FillTransparency = 0.65
		highlight.OutlineColor = tier.color
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Adornee = character
		highlight.Parent = character
		plate.highlight = highlight
	end

	task.delay(seconds, function()
		-- Une seconde montee pendant le projecteur a repousse cheerUntil : c'est
		-- a elle de rendre le panneau a son etat normal, pas a ce timer-ci.
		if plates[player] ~= plate or os.clock() < plate.cheerUntil then
			return
		end

		plate.billboard.Size = PLATE_SIZE
		plate.billboard.StudsOffsetWorldSpace = PLATE_OFFSET
		plate.billboard.AlwaysOnTop = false
		plate.nameLabel.TextColor3 = NAME_COLOR

		if plate.highlight then
			plate.highlight:Destroy()
			plate.highlight = nil
		end
	end)
end

--------------------------------------------------------------------------------

function Nameplates.Start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(forget)

	for _, player in Players:GetPlayers() do
		watch(player)
	end

	startLoop()
end

return Nameplates
