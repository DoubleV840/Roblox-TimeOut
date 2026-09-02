-- Les zones d'achat de power-up : une Part plate au sol, taguee
-- Config.POWERUP_TAG, avec un attribut texte "PowerUp" qui dit lequel elle vend.
--
-- Le modele est celui de la zone de Chrono Boost (ClickUpgrade) : on entre, une
-- fenetre s'ouvre, un niveau monte, un prix grimpe. La difference tient en deux
-- points, et ce sont eux qui font le lot 5 :
--
--   * UNE ZONE PAR SALLE. Chaque etage ajoute une maniere de cliquer -- c'est ca,
--     "des salles plus riches avec plus de fonctionnalites". Une zone dont le
--     palier n'est pas atteint affiche un cadenas et dit ce qu'il faut atteindre,
--     exactement comme un mini-jeu verrouille.
--
--   * TOUT SE PAIE EN TEMPS. Les Robux restent au guichet ; le cookie reste un
--     jeu de patience. Un power-up achetable en Robux ferait du clic un
--     distributeur, plus un jeu.
--
-- Ce module VEND ; il n'applique rien. Les effets sont lus la ou ils se jouent :
-- TimeCookie pour les quatre power-ups de clic, AutoClicker pour le carburant
-- des Rouages. Les valeurs, elles, sont calculees une seule fois, dans
-- src/shared/PowerUps.luau, pour que la fenetre d'achat ne puisse pas annoncer
-- autre chose que ce qui sera applique.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Colors = require(ReplicatedStorage.Shared.Colors)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local ZoneAura = require(ReplicatedStorage.Shared.ZoneAura)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PowerUps = require(ReplicatedStorage.Shared.PowerUps)
local PlayerData = require(script.Parent.PlayerData)
local TierService = require(script.Parent.TierService)
local Boons = require(script.Parent.Boons)

local PowerUpZones = {}

local zoneStates = {}

--------------------------------------------------------------------------------
-- Le decor
--------------------------------------------------------------------------------

-- Une Part nue et taguee suffit : le portique, l'aura et le panneau sont poses
-- ici. C'est la regle de toutes les zones du jeu -- ce qui est decore a la main
-- autour d'une zone risque d'etre ecrase.
--
-- Le panneau est PARTAGE (il vit dans le Workspace, donc tous les joueurs le
-- voient) : il ne peut donc porter que ce qui est vrai pour tout le monde -- le
-- nom du power-up. Le niveau, le prix et le cadenas sont propres a chacun et
-- passent par la fenetre, cote client.

local METAL = Color3.fromRGB(46, 44, 46)
local POST_THICKNESS = 0.6

local function newDecorPart(zone, name, size, offset, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = zone.CFrame * offset
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = zone

	return part
end

local function createDecor(zone, power)
	ZoneAura.Create(zone, power.color, 0.75)

	local halfX = zone.Size.X / 2
	local top = zone.Size.Y / 2
	local height = math.clamp(math.max(zone.Size.X, zone.Size.Z) * 0.7, 4, 10)

	for _, side in { -1, 1 } do
		newDecorPart(
			zone,
			"PowerUpPost",
			Vector3.new(POST_THICKNESS, height, POST_THICKNESS),
			CFrame.new(side * (halfX - POST_THICKNESS / 2), top + height / 2, 0),
			METAL
		)
	end

	local arch = newDecorPart(
		zone,
		"PowerUpArch",
		Vector3.new(zone.Size.X, 0.5, 0.8),
		CFrame.new(0, top + height, 0),
		power.color,
		Enum.Material.Neon
	)

	local glow = Instance.new("PointLight")
	glow.Color = power.color
	glow.Brightness = 1.5
	glow.Range = math.max(zone.Size.X, zone.Size.Z) + 12
	glow.Parent = arch

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PowerUpSign"
	billboard.Size = UDim2.new(11, 0, 3, 0) -- en studs : taille fixe dans le monde
	billboard.StudsOffset = Vector3.new(0, top + height + 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.Parent = billboard

	-- Panneau partage : le serveur pose la cle, chaque client l'ecrit dans sa
	-- langue (voir Locale).
	Locale.Mark(title, "powerup_" .. power.key .. "_name")
	TextFx.Mark(title, 0.55, power.color)
end

--------------------------------------------------------------------------------
-- La fenetre
--------------------------------------------------------------------------------

-- Le client a PowerUps.luau : il sait mettre en forme un niveau et un effet tout
-- seul. On ne lui envoie donc que ce qu'il ne peut pas savoir -- ou en est CE
-- joueur, et si la zone lui est ouverte.
local function sendPrompt(player, zone, power)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local tierIndex = TierService.Get(player)
	local level = PowerUps.Level(data, power.key)
	local unlocked = PowerUps.IsUnlocked(data, tierIndex, power.key)

	Remotes.PowerUpPrompt:FireClient(player, zone, {
		key = power.key,
		level = level,
		cost = PowerUps.Cost(power, level),
		locked = not unlocked and power.minTier or nil,
		maxed = level >= PowerUps.MAX_LEVEL,
		timeLeft = data.TimeLeft,
	})
end

local function tryBuy(player, zone)
	local state = zoneStates[zone]
	if not state or not state.playersInside[player] then
		return
	end

	local power = state.power
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	-- Revalide cote serveur : le client ne voit qu'un cadenas dessine, rien ne
	-- l'empeche d'envoyer quand meme un PowerUpBuy.
	if not PowerUps.IsUnlocked(data, TierService.Get(player), power.key) then
		return
	end

	local level = PowerUps.Level(data, power.key)
	if level >= PowerUps.MAX_LEVEL then
		return
	end

	local cost = PowerUps.Cost(power, level)

	if data.TimeLeft < cost then
		Remotes.Notify:FireClient(player, "notify_powerup_poor", { amount = cost }, Colors.LOSE)
		return
	end

	data.TimeLeft -= cost
	data.PowerUps[power.key] = level + 1

	-- Joue depuis la zone, pas dans la tete de l'acheteur : les autres joueurs
	-- entendent quelqu'un monter d'un cran, et la note grimpe avec le niveau.
	Sounds.PlayAt("powerup_bought", zone, { pitch = 1 + math.min(level + 1, 10) * 0.05 })

	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	PowerUpZones.Announce(player, data)
	Remotes.Notify:FireClient(player, "notify_powerup_done", {
		name = "powerup_" .. power.key .. "_name",
		level = level + 1,
	}, Colors.WIN)

	-- On renvoie une fenetre a jour plutot que de la fermer : le joueur enchaine
	-- les niveaux sans avoir a ressortir de la zone (comme le Chrono Boost).
	sendPrompt(player, zone, power)

	PlayerData.Save(player)
end

--------------------------------------------------------------------------------
-- Etat du joueur
--------------------------------------------------------------------------------

-- Ce que le HUD affiche en permanence : les niveaux possedes, et l'etat du seul
-- power-up qui se declenche a la main.
function PowerUpZones.State(player, data)
	local levels = {}

	for _, power in PowerUps.List do
		local level = PowerUps.Level(data, power.key)
		if level > 0 then
			levels[power.key] = level
		end
	end

	local frenzyLevel = PowerUps.Level(data, PowerUps.FRENZY)
	local ready = 0

	if frenzyLevel > 0 then
		-- Le temps qu'il reste a attendre. Il descend chez le client, image par
		-- image : le serveur ne renvoie l'etat qu'aux changements.
		ready = math.max(0, (data.FrenzyAt or 0) + PowerUps.FrenzyCooldown(frenzyLevel) - os.time())
	end

	return {
		levels = levels,
		frenzyCooldown = ready,
		frenzyActive = Boons.Remaining(player, Config.BOON_FRENZY),
	}
end

function PowerUpZones.Announce(player, data)
	Remotes.PowerUpUpdated:FireClient(player, PowerUpZones.State(player, data))
end

--------------------------------------------------------------------------------
-- Frenesie
--------------------------------------------------------------------------------

-- Le seul power-up consommable du jeu : un pic de puissance a declencher au bon
-- moment, et donc un geste actif de plus a repeter. Tout le reste du lot 5 est
-- passif ; sans lui, cinq power-ups ne changeraient rien a la facon de JOUER.
--
-- "free" saute la recharge : c'est la Frenesie offerte par les cadeaux de survie
-- (lot 7), qui n'a pas a attendre trois minutes pour etre utilisable.
function PowerUpZones.Frenzy(player, free)
	local data = PlayerData.Get(player)
	if not data then
		return false
	end

	local level = PowerUps.Level(data, PowerUps.FRENZY)
	if level <= 0 then
		return false
	end

	if not free then
		local ready = (data.FrenzyAt or 0) + PowerUps.FrenzyCooldown(level)
		if os.time() < ready then
			return false
		end

		data.FrenzyAt = os.time()
	end

	local duration = PowerUps.FrenzyDuration(level)
	Boons.Grant(player, Config.BOON_FRENZY, duration)
	PowerUpZones.Announce(player, data)

	Remotes.Notify:FireClient(player, "notify_frenzy", {
		seconds = duration,
		multiplier = PowerUps.Get(PowerUps.FRENZY).multiplier,
	}, Colors.WIN)

	return true
end

--------------------------------------------------------------------------------

local function setupZone(zone)
	if not zone:IsA("BasePart") or zoneStates[zone] then
		return
	end

	local key = zone:GetAttribute(Config.POWERUP_ATTRIBUTE)
	local power = key and PowerUps.Get(key)

	if not power then
		warn(
			"TimeOut: zone de power-up sans attribut "
				.. Config.POWERUP_ATTRIBUTE
				.. " valide -> "
				.. zone:GetFullName()
		)
		return
	end

	local state = { power = power, playersInside = {}, touchCounts = {} }
	zoneStates[zone] = state

	createDecor(zone, power)
	Sounds.Loop("powerup_zone_hum", zone, { pitch = 0.8 + power.index * 0.12 })

	zone.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		state.touchCounts[player] = (state.touchCounts[player] or 0) + 1
		if state.touchCounts[player] == 1 then
			state.playersInside[player] = true
			sendPrompt(player, zone, power)
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
			Remotes.PowerUpPromptHide:FireClient(player, zone)
		end
	end)
end

function PowerUpZones.Start()
	for _, zone in CollectionService:GetTagged(Config.POWERUP_TAG) do
		setupZone(zone)
	end

	CollectionService:GetInstanceAddedSignal(Config.POWERUP_TAG):Connect(setupZone)

	Remotes.PowerUpBuy.OnServerEvent:Connect(tryBuy)

	Remotes.PowerUpUse.OnServerEvent:Connect(function(player)
		PowerUpZones.Frenzy(player, false)
	end)

	-- Le client reclame son etat quand il est pret (meme raison que partout
	-- ailleurs : ses Remotes ne sont pas branches a PlayerAdded).
	Remotes.PowerUpUpdated.OnServerEvent:Connect(function(player)
		local data = PlayerData.Get(player)
		if data then
			PowerUpZones.Announce(player, data)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, state in zoneStates do
			state.playersInside[player] = nil
			state.touchCounts[player] = nil
		end
	end)

	-- La recharge de la Frenesie descend chez le client ; ce balayage ne sert
	-- qu'a le prevenir quand elle est revenue a zero, pour que le bouton
	-- s'allume sans qu'il ait a rouvrir quoi que ce soit.
	task.spawn(function()
		local ready = {}

		while true do
			task.wait(1)

			for _, player in Players:GetPlayers() do
				local data = PlayerData.Get(player)

				if data and PowerUps.Level(data, PowerUps.FRENZY) > 0 then
					local state = PowerUpZones.State(player, data)
					local now = state.frenzyCooldown <= 0

					if ready[player] ~= now then
						ready[player] = now
						Remotes.PowerUpUpdated:FireClient(player, state)
					end
				else
					ready[player] = nil
				end
			end
		end
	end)
end

return PowerUpZones
