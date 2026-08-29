-- Zone d'amelioration : entrer dans une Part taguee Config.UPGRADE_TAG ouvre une popup
-- montrant le niveau actuel, le prochain niveau et son cout. Si le joueur valide (et
-- est toujours dans la zone, et a assez de temps), son ClickPower augmente definitivement.
--
-- Cout du niveau N -> N+1 : Config.UPGRADE_BASE_COST * Config.UPGRADE_GROWTH^N
--
-- La zone est habillee en code (portique neon + rotor, voir createDecor plus bas) :
-- il n'y a qu'une Part a poser et a taguer dans Studio, rien a decorer a la main.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Colors = require(ReplicatedStorage.Shared.Colors)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local ZoneAura = require(ReplicatedStorage.Shared.ZoneAura)
local PlayerData = require(script.Parent.PlayerData)

local ClickUpgrade = {}

local zoneStates = {}

--------------------------------------------------------------------------------
-- Decor de la zone
--------------------------------------------------------------------------------

-- La zone n'est qu'une Part posee a la main dans Studio : c'est le serveur qui
-- l'habille, pour qu'un pad nu devienne une cabine d'aiguillage -- deux montants,
-- une poutre neon, et un rotor qui tourne au-dessus.
--
-- Tout est ancre, sans collision et parente a la zone : effacer la Part emporte
-- le decor avec elle, et le joueur traverse le portique sans s'accrocher dedans.
-- Rien n'est a poser a la main, le tag suffit -- mais le decor est pose une fois
-- pour toutes au demarrage : bouger la zone ensuite ne le deplace pas.

local BOOST_NEON = Color3.fromRGB(255, 90, 200) -- le magenta du Chrono Boost (popup, panneau)
local BOOST_METAL = Color3.fromRGB(46, 44, 46)
local BOOST_AURA_INTENSITY = 0.7

local POST_THICKNESS = 0.7
local BEAM_THICKNESS = 0.8

local function newDecorPart(zone, name, size, offset, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = zone.CFrame * offset
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.Anchored = true
	-- Decor pur : ni collision, ni touch, ni raycast.
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = zone

	return part
end

-- Deux pales croisees et un moyeu. Les pales portent Config.SPIN_TAG : elles
-- tournent donc cote client, en phase avec le cookie du hall (voir Spin), sans
-- qu'un seul CFrame ne transite par le reseau. Le moyeu, lui, ne tourne pas --
-- une sphere qui tourne ne se voit pas, et une pale hors de son centre partirait
-- en orbite au lieu de pivoter sur elle-meme.
local function createRotor(zone, height, span)
	local hub = newDecorPart(zone, "BoostHub", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, height, 0), BOOST_NEON, Enum.Material.Neon)
	hub.Shape = Enum.PartType.Ball

	local light = Instance.new("PointLight")
	light.Color = BOOST_NEON
	light.Brightness = 1.8
	light.Range = span + 12
	light.Parent = hub

	for blade = 0, 1 do
		local part = newDecorPart(
			zone,
			"BoostBlade",
			Vector3.new(span, 0.25, 0.7),
			CFrame.new(0, height, 0) * CFrame.Angles(0, math.rad(blade * 90), 0),
			BOOST_NEON,
			Enum.Material.Neon
		)

		CollectionService:AddTag(part, Config.SPIN_TAG)
	end
end

local function createDecor(zone)
	ZoneAura.Create(zone, BOOST_NEON, BOOST_AURA_INTENSITY)

	local halfX = zone.Size.X / 2
	local top = zone.Size.Y / 2

	-- Le portique se met a l'echelle de la zone : un petit pad en recoit un
	-- discret, une grande estrade un haut -- sans que rien ne soit a regler.
	local height = math.clamp(math.max(zone.Size.X, zone.Size.Z) * 0.8, 5, 12)
	local beamY = top + height

	for _, side in { -1, 1 } do
		newDecorPart(
			zone,
			"BoostPost",
			Vector3.new(POST_THICKNESS, height, POST_THICKNESS),
			CFrame.new(side * (halfX - POST_THICKNESS / 2), top + height / 2, 0),
			BOOST_METAL
		)

		-- Lisere neon plaque sur la face interieure du montant.
		newDecorPart(
			zone,
			"BoostPostNeon",
			Vector3.new(0.18, height * 0.86, 0.24),
			CFrame.new(side * (halfX - POST_THICKNESS - 0.09), top + height / 2, 0),
			BOOST_NEON,
			Enum.Material.Neon
		)
	end

	newDecorPart(
		zone,
		"BoostBeam",
		Vector3.new(zone.Size.X, BEAM_THICKNESS, BEAM_THICKNESS * 1.4),
		CFrame.new(0, beamY + BEAM_THICKNESS / 2, 0),
		BOOST_METAL
	)

	local strip = newDecorPart(
		zone,
		"BoostBeamNeon",
		Vector3.new(zone.Size.X * 0.86, 0.22, 0.9),
		CFrame.new(0, beamY - 0.14, 0),
		BOOST_NEON,
		Enum.Material.Neon
	)

	local glow = Instance.new("PointLight")
	glow.Color = BOOST_NEON
	glow.Brightness = 1.4
	glow.Range = math.max(zone.Size.X, zone.Size.Z) + 14
	glow.Parent = strip

	-- Le rotor passe au-dessus du panneau du joueur (BillboardGui a 4.2 studs) et
	-- reste sous la poutre : les trois etages se lisent sans se recouvrir.
	createRotor(zone, top + height * 0.82, math.min(zone.Size.X, zone.Size.Z) * 0.75)
end

local function getCost(clickPower)
	local level = clickPower - 1
	return math.floor(Config.UPGRADE_BASE_COST * (Config.UPGRADE_GROWTH ^ level))
end

local function sendPrompt(player, zone, data)
	local cost = getCost(data.ClickPower)
	local currentBonus = Config.CLICKER_REWARD * data.ClickPower
	local nextBonus = Config.CLICKER_REWARD * (data.ClickPower + 1)

	Remotes.UpgradePrompt:FireClient(player, zone, {
		level = data.ClickPower,
		currentBonus = currentBonus,
		nextLevel = data.ClickPower + 1,
		nextBonus = nextBonus,
		cost = cost,
	})
end

local function tryAcceptUpgrade(player, zone, state)
	if not state.playersInside[player] then
		return
	end

	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local cost = getCost(data.ClickPower)

	if data.TimeLeft < cost then
		Remotes.Notify:FireClient(player, "notify_upgrade_poor", { amount = cost }, Colors.LOSE)
		return
	end

	data.TimeLeft -= cost
	data.ClickPower += 1

	-- Joue depuis la zone, pas dans la tete de l'acheteur : les autres joueurs
	-- entendent quelqu'un monter d'un cran, et la note grimpe avec le niveau.
	Sounds.PlayAt("upgrade_bought", zone, { pitch = 1 + math.min(data.ClickPower, 12) * 0.05 })

	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	Remotes.ClickPowerUpdated:FireClient(player, data.ClickPower)
	Remotes.Notify:FireClient(
		player,
		"notify_upgrade_done",
		{ level = data.ClickPower, bonus = Config.CLICKER_REWARD * data.ClickPower },
		Colors.WIN
	)

	-- on renvoie une popup a jour (nouveau niveau/cout) plutot que de la fermer,
	-- pour que le joueur puisse enchainer les achats sans ressortir de la zone
	sendPrompt(player, zone, data)
end

local function setupZone(zone)
	if not zone:IsA("BasePart") or zoneStates[zone] then
		return
	end

	local state = { playersInside = {}, touchCounts = {} }
	zoneStates[zone] = state

	createDecor(zone)
	Sounds.Loop("upgrade_zone_hum", zone)

	zone.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		state.touchCounts[player] = (state.touchCounts[player] or 0) + 1
		if state.touchCounts[player] == 1 then
			state.playersInside[player] = true

			local data = PlayerData.Get(player)
			if data then
				sendPrompt(player, zone, data)
			end
		end
	end)

	zone.TouchEnded:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		state.touchCounts[player] = math.max(0, (state.touchCounts[player] or 1) - 1)
		if state.touchCounts[player] == 0 then
			state.playersInside[player] = nil
			Remotes.UpgradePromptHide:FireClient(player, zone)
		end
	end)
end

function ClickUpgrade.Start()
	for _, zone in CollectionService:GetTagged(Config.UPGRADE_TAG) do
		setupZone(zone)
	end

	CollectionService:GetInstanceAddedSignal(Config.UPGRADE_TAG):Connect(setupZone)

	Remotes.UpgradeAccept.OnServerEvent:Connect(function(player, zone)
		local state = zoneStates[zone]
		if not state then
			return
		end

		tryAcceptUpgrade(player, zone, state)
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, state in zoneStates do
			state.playersInside[player] = nil
			state.touchCounts[player] = nil
		end
	end)
end

return ClickUpgrade
