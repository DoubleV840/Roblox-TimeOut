-- Affiche, sur n'importe quelle Part taguee Config.BOARD_TAG, le classement EN DIRECT
-- des joueurs actuellement connectes, tries par temps restant (les "plus riches").

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Badge = require(ReplicatedStorage.Shared.Badge)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PlayerData = require(script.Parent.PlayerData)
local TimeBalance = require(script.Parent.TimeBalance)

local HallOfFameBoard = {}

local function buildEntries()
	local onlineUserIds = {}
	local entries = {}

	-- joueurs connectes : valeur live, exacte a la seconde pres
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data then
			onlineUserIds[player.UserId] = true
			table.insert(entries, { name = player.Name, timeLeft = data.TimeLeft, tier = data.Tier })
		end
	end

	-- joueurs deconnectes : derniere valeur sauvegardee (en pause)
	for _, entry in TimeBalance.GetTop(Config.LEADERBOARD_SIZE) do
		if entry.userId and not onlineUserIds[entry.userId] then
			table.insert(entries, { name = entry.name, timeLeft = entry.timeLeft, tier = entry.tier })
		end
	end

	table.sort(entries, function(a, b)
		return a.timeLeft > b.timeLeft
	end)

	return entries
end

local function newRow(index)
	local row = Instance.new("Frame")
	row.Name = "Row" .. index
	row.Size = UDim2.new(1, 0, 1 / Config.LEADERBOARD_SIZE, 0)
	row.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	local position = Instance.new("TextLabel")
	position.Name = "Position"
	position.Size = UDim2.new(0.09, 0, 0.8, 0)
	position.BackgroundTransparency = 1
	position.TextColor3 = Color3.fromRGB(180, 180, 180)
	position.FontFace = Fonts.Main
	position.TextScaled = true
	position.TextXAlignment = Enum.TextXAlignment.Right
	position.Text = index .. "."
	position.LayoutOrder = 1
	position.Parent = row

	local badge = Badge.New(Tiers.Get(1))
	badge.Size = UDim2.new(0, 0, 0.8, 0)
	badge.LayoutOrder = 2
	badge.Parent = row

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	-- 0.46 (et non 0.5) : le badge de rang prend maintenant une vraie largeur
	-- (= sa hauteur), il faut lui laisser la place sur les panneaux etroits.
	name.Size = UDim2.new(0.46, 0, 0.8, 0)
	name.BackgroundTransparency = 1
	name.FontFace = Fonts.Main
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.LayoutOrder = 3
	name.Parent = row

	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "TimeLeft"
	timeLabel.Size = UDim2.new(0.29, 0, 0.8, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.TextColor3 = Color3.new(1, 1, 1)
	timeLabel.FontFace = Fonts.Main
	timeLabel.TextScaled = true
	timeLabel.TextXAlignment = Enum.TextXAlignment.Right
	timeLabel.LayoutOrder = 4
	timeLabel.Parent = row

	return { frame = row, badge = badge, name = name, timeLabel = timeLabel }
end

local function fillRow(row, entry)
	if not entry then
		Badge.Apply(row.badge, Tiers.Get(1))
		row.badge.Visible = false
		row.name.Text = "---"
		TextFx.Mark(row.name, 0, Color3.fromRGB(110, 110, 110))
		Locale.Unmark(row.timeLabel)
		row.timeLabel.Text = ""
		return
	end

	-- Le badge affiche le PALIER atteint, pas un rang calcule sur le temps
	-- possede : c'est la meme regle que le HUD, et les deux ne peuvent plus se
	-- contredire.
	local tier = Tiers.Get(entry.tier)

	-- Plus le joueur est haut dans l'echelle, plus sa ligne s'agite : en un coup
	-- d'oeil on voit qui domine le classement sans lire les chiffres.
	local intensity = (tier.index - 1) / (Tiers.LAST - 1)

	row.badge.Visible = true
	Badge.Apply(row.badge, tier)
	row.name.Text = entry.name
	TextFx.Mark(row.name, intensity, tier.color)
	Locale.Mark(row.timeLabel, "board_time", { amount = entry.timeLeft })
	TextFx.Mark(row.timeLabel, intensity * 0.6, tier.color)
end

local function setupBoard(part)
	if not part:IsA("BasePart") then
		return
	end

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.PixelsPerStud = 100
	surfaceGui.Parent = part

	-- Plus de fond noir : un simple lisere neon delimite le panneau et laisse voir
	-- la Part (et le decor) derriere. La lisibilite est assuree par le contour des
	-- textes, pose par TextFx.
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.Parent = surfaceGui

	local edge = Instance.new("UIStroke")
	edge.Thickness = 3
	edge.Color = Color3.fromRGB(255, 221, 0)
	edge.Transparency = 0.35
	edge.Parent = background

	local edgeGradient = Instance.new("UIGradient")
	edgeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 221, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 221, 0)),
	})
	edgeGradient.Rotation = 30
	edgeGradient.Parent = edge

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.09, 0)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.Parent = background

	-- Panneau partage : chaque client le traduit de son cote.
	Locale.Mark(title, "board_title")
	TextFx.Mark(title, 0.55, Color3.fromRGB(255, 221, 0))

	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, 0, 0.91, 0)
	list.Position = UDim2.new(0, 0, 0.09, 0)
	list.BackgroundTransparency = 1
	list.Parent = background

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = list

	local rows = {}
	for i = 1, Config.LEADERBOARD_SIZE do
		local row = newRow(i)
		row.frame.LayoutOrder = i
		row.frame.Parent = list
		rows[i] = row
	end

	-- Nom du premier au dernier rafraichissement. Le panneau se met a jour toutes
	-- les quelques secondes : seul un changement de tete d'affiche merite un son,
	-- sinon il bipperait en boucle pour rien.
	local lastLeader = nil

	local function refresh()
		local entries = buildEntries()
		for i, row in rows do
			fillRow(row, entries[i])
		end

		local leader = entries[1] and entries[1].name or nil
		if leader and lastLeader and leader ~= lastLeader then
			Sounds.PlayAt("board_new_leader", part)
		end
		lastLeader = leader
	end

	refresh()

	task.spawn(function()
		while part.Parent do
			task.wait(Config.LIVE_BOARD_REFRESH_INTERVAL)
			refresh()
		end
	end)
end

function HallOfFameBoard.Start()
	for _, part in CollectionService:GetTagged(Config.BOARD_TAG) do
		setupBoard(part)
	end

	CollectionService:GetInstanceAddedSignal(Config.BOARD_TAG):Connect(setupBoard)
end

return HallOfFameBoard
