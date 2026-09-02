-- Gere les "orbes de temps" : n'importe quelle Part taguee Config.ORB_TAG redonne
-- du temps au contact, puis passe en fantome et revient Config.ORB_COOLDOWN
-- secondes plus tard, exactement a l'endroit ou elle a ete posee.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PlayerData = require(script.Parent.PlayerData)
local TierService = require(script.Parent.TierService)
local Boons = require(script.Parent.Boons)

local TimeOrb = {}

-- L'orbe en cooldown devient un fantome, pas un trou : on doit voir d'ou elle va
-- revenir, et compter les secondes.
local HIDDEN_TRANSPARENCY = 0.8

local orbs = {}

local function setupOrb(orb)
	if not orb:IsA("BasePart") or orbs[orb] then
		return
	end

	-- L'etat d'origine est releve AVANT qu'on y touche : une orbe peut avoir ete
	-- posee traversable, ou deja semi-transparente, et doit revenir exactement
	-- comme elle etait -- pas "collision activee" par defaut.
	local origin = {
		cframe = orb.CFrame,
		transparency = orb.Transparency,
		canCollide = orb.CanCollide,
	}

	orbs[orb] = origin

	-- Une orbe non ancree tombe a l'instant ou on lui retire sa collision, et ne
	-- remonte jamais : elle finissait le cooldown quelque part sous la map. On
	-- l'ancre donc une fois pour toutes la ou elle a ete posee.
	orb.Anchored = true

	local available = true

	-- Nappe qui signale l'orbe a l'oreille quand on passe a cote. Elle se tait
	-- pendant le cooldown : une orbe qu'on entend est une orbe a prendre.
	local idle = Sounds.Loop("orb_idle", orb)

	local function hide()
		available = false
		orb.Transparency = HIDDEN_TRANSPARENCY
		orb.CanCollide = false
		orb.CanTouch = false

		if idle then
			idle:Pause()
		end
	end

	-- Le joueur qui campe sur l'orbe ne declenche PAS de nouveau Touched quand
	-- elle revient : le moteur n'emet un contact qu'a l'entree. Sans ce
	-- rattrapage, attendre sur place donnerait l'impression qu'elle ne revient
	-- jamais -- alors qu'elle est bien la, mais muette.
	local function playerOnOrb()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { orb }

		for _, part in Workspace:GetPartsInPart(orb, params) do
			local player = Players:GetPlayerFromCharacter(part.Parent)
			if player then
				return player
			end
		end

		return nil
	end

	-- Declaree ici : respawn la rappelle, et elle rappelle respawn.
	local take

	local function respawn()
		-- Remise en place au passage : si l'orbe a ete deplacee (chute d'une
		-- partie precedente, retouche dans Studio), elle revient a son poste.
		orb.CFrame = origin.cframe
		orb.Transparency = origin.transparency
		orb.CanCollide = origin.canCollide
		orb.CanTouch = true
		available = true

		Sounds.PlayAt("orb_respawn", orb)

		if idle then
			idle:Resume()
		end

		local camper = playerOnOrb()
		if camper then
			take(camper)
		end
	end

	function take(player)
		if not available then
			return
		end

		local data = PlayerData.Get(player)
		if not data then
			return
		end

		-- Aller chercher une orbe est un geste : le palier le multiplie, comme un
		-- clic sur le cookie.
		--
		-- Deux cartes de pack entrent ici, et nulle part ailleurs :
		--   "Orbes bonifiees" (data.OrbBonus)  -- definitif, un facteur de plus
		--   "Pluie d'orbes"   (Boons)          -- 60 s, et le retour est immediat
		local amount = Config.ORB_TIME_BONUS * TierService.Multiplier(player) * (data.OrbBonus or 1)

		if Boons.Active(player, Config.BOON_ORB_RAIN) then
			amount *= Config.BOON_ORB_RAIN_MULTIPLIER
		end

		amount = math.max(1, math.round(amount))

		data.TimeLeft += amount
		PlayerData.NoteTime(data)
		Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
		Sounds.PlayAt("orb_collect", orb)

		hide()

		-- Le temps de retour est propre au joueur qui l'a prise : "Orbes
		-- accelerees" le raccourcit definitivement, la "Pluie d'orbes" le
		-- supprime pendant 60 s. Une orbe est donc plus ou moins genereuse selon
		-- QUI vient de la ramasser -- c'est ce que valent ces cartes.
		local cooldown = Config.ORB_COOLDOWN * (data.OrbSpeed or 1)

		if Boons.Active(player, Config.BOON_ORB_RAIN) then
			cooldown = 0
		end

		-- Un fil a part, et non un task.wait dans le gestionnaire de contact : le
		-- retour de l'orbe ne depend plus de ce qui arrive au contact qui l'a
		-- consommee.
		task.delay(cooldown, respawn)
	end

	orb.Touched:Connect(function(hit)
		if not available then
			return
		end

		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			take(player)
		end
	end)
end

function TimeOrb.Start()
	for _, orb in CollectionService:GetTagged(Config.ORB_TAG) do
		setupOrb(orb)
	end

	CollectionService:GetInstanceAddedSignal(Config.ORB_TAG):Connect(setupOrb)
end

return TimeOrb
