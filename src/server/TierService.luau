-- Les paliers : les 8 etages du Terminal, achetes en temps et acquis pour
-- toujours (voir src/shared/Tiers.luau pour l'echelle elle-meme).
--
-- Ce module est l'autorite sur trois choses :
--
-- 1. QUI PASSE. Une barriere taguee Config.TIER_GATE_TAG bloque les joueurs qui
--    n'ont pas encore son etage, et laisse passer les autres a pied, dans les
--    deux sens. Une Part ne pouvant pas etre solide pour un joueur et creuse
--    pour son voisin, ca se joue en groupes de collision : un groupe par palier
--    cote joueur, un par etage desservi cote barriere, et une matrice qui dit
--    "le palier 5 traverse les barrieres 2 a 5, pas la 6". Tout est enregistre
--    au demarrage : il n'y a aucun groupe a creer dans Studio.
--
-- 2. QUI PAIE. Le client demande (Remotes.TierBuy), le serveur decide. On ne
--    saute pas de marche, on ne rachete pas un etage possede, et surtout PAYER
--    NE PEUT PAS TUER : une entree qui laisserait le joueur au ras de zero est
--    refusee (voir Config.TIER_SAFETY_MARGIN).
--
-- 3. CE QUE CA RAPPORTE. TierService.Multiplier(player) multiplie les gains
--    ACTIFS -- un clic, une orbe, un gain de mini-jeu. Jamais le chrono, qui
--    descend a 1 s/s a tous les etages, jamais l'auto-cliqueur, qui resterait
--    sinon une source passive a x21 en fin de partie.
--
-- Mourir renvoie au Quai (player.RespawnLocation) mais ne coute jamais un
-- palier : le trajet se repaie, pas la progression.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Colors = require(ReplicatedStorage.Shared.Colors)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PlayerData = require(script.Parent.PlayerData)
local Leaderstats = require(script.Parent.Leaderstats)
local Presence = require(script.Parent.Presence)

local TierService = {}

-- Distance de securite autour d'une barriere : on n'achete pas un etage depuis
-- l'autre bout de la map. Genereuse a dessein -- le but est d'ecarter un client
-- bricole, pas de pinailler sur trois studs.
local BUY_REACH = 24

--------------------------------------------------------------------------------
-- Groupes de collision
--------------------------------------------------------------------------------

local function gateGroup(tier)
	return Config.TIER_GATE_COLLISION_PREFIX .. tier
end

local function playerGroup(tier)
	return Config.TIER_PLAYER_COLLISION_PREFIX .. tier
end

local function registerGroups()
	local existing = {}
	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		existing[group.name] = true
	end

	local function ensure(name)
		if not existing[name] then
			existing[name] = true
			PhysicsService:RegisterCollisionGroup(name)
		end
	end

	for tier = Tiers.FIRST, Tiers.LAST do
		ensure(playerGroup(tier))
	end

	-- Le Quai n'a pas de barriere : on n'entre pas dans le jeu en payant.
	for tier = Tiers.FIRST + 1, Tiers.LAST do
		ensure(gateGroup(tier))
	end

	-- Tout est solide par defaut a l'enregistrement : on ne desactive donc que
	-- les cases ou le joueur a DEJA l'etage. Une barriere reste solide face au
	-- decor, aux orbes et a tout ce qui n'est pas un personnage.
	for playerTier = Tiers.FIRST, Tiers.LAST do
		for gateTier = Tiers.FIRST + 1, Tiers.LAST do
			PhysicsService:CollisionGroupSetCollidable(
				playerGroup(playerTier),
				gateGroup(gateTier),
				playerTier < gateTier
			)
		end
	end
end

--------------------------------------------------------------------------------
-- Personnages
--------------------------------------------------------------------------------

local characterConnections = {}

local function applyCharacterGroup(player)
	local data = PlayerData.Get(player)
	local character = player.Character
	if not data or not character then
		return
	end

	local group = playerGroup(Tiers.Clamp(data.Tier))

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

-- Un personnage peut apparaitre AVANT que ses donnees ne soient chargees (le
-- DataStore prend le temps qu'il prend). Sans ce rattrapage il resterait dans le
-- groupe "Default", qui se cogne dans toutes les barrieres : un joueur palier 5
-- se retrouverait coince au Quai jusqu'a sa mort.
local function ensureCharacterGroup(player)
	if PlayerData.Get(player) then
		applyCharacterGroup(player)
		return
	end

	task.spawn(function()
		while player.Parent and not PlayerData.Get(player) do
			task.wait(0.2)
		end

		if player.Parent then
			applyCharacterGroup(player)
		end
	end)
end

local function onCharacterAdded(player, character)
	ensureCharacterGroup(player)

	-- Un chapeau, un outil ou un membre ajoute apres coup arriverait en groupe
	-- "Default" et se cognerait dans une barriere deja franchie.
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
	end

	characterConnections[player] = character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			local data = PlayerData.Get(player)
			if data then
				descendant.CollisionGroup = playerGroup(Tiers.Clamp(data.Tier))
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Reapparition
--------------------------------------------------------------------------------

-- Le point de reapparition du Quai : celui qui porte l'attribut TargetTier = 1,
-- ou, a defaut, le plus bas de la map -- le Quai est le sous-sol, c'est une
-- convention qui se tient sans rien avoir a taguer.
local quaiSpawn = nil

local function findQuaiSpawn()
	if quaiSpawn and quaiSpawn.Parent then
		return quaiSpawn
	end

	local lowest, lowestY = nil, math.huge

	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("SpawnLocation") then
			if tonumber(instance:GetAttribute(Config.TIER_TARGET_ATTRIBUTE)) == Tiers.FIRST then
				quaiSpawn = instance
				return quaiSpawn
			end

			if instance.Position.Y < lowestY then
				lowest, lowestY = instance, instance.Position.Y
			end
		end
	end

	quaiSpawn = lowest
	return quaiSpawn
end

-- Mourir renvoie en bas : le train est parti sans le joueur. Les barrieres deja
-- payees restent ouvertes, seul le trajet est a refaire.
local function bindRespawn(player)
	player.RespawnLocation = findQuaiSpawn()
end

--------------------------------------------------------------------------------
-- Barrieres
--------------------------------------------------------------------------------

local gates = {}

local function gateTarget(gate)
	local target = tonumber(gate:GetAttribute(Config.TIER_TARGET_ATTRIBUTE))
	if not target then
		return nil
	end

	return Tiers.Clamp(target)
end

local function setupGate(gate)
	if not gate:IsA("BasePart") or gates[gate] then
		return
	end

	local target = gateTarget(gate)
	if not target or target <= Tiers.FIRST then
		warn(
			"TimeOut: barriere sans attribut "
				.. Config.TIER_TARGET_ATTRIBUTE
				.. " valide (2 a "
				.. Tiers.LAST
				.. ") -> "
				.. gate:GetFullName()
		)
		return
	end

	gates[gate] = target

	-- Une barriere qui ne bloque pas n'est qu'une vitre : on impose la solidite
	-- et l'ancrage, quoi qu'ait laisse trainer l'editeur.
	gate.Anchored = true
	gate.CanCollide = true
	gate.CollisionGroup = gateGroup(target)

	-- Le reste de l'apparence (couleur, transparence, materiau) se regle a la
	-- main : c'est la teinte de l'etage vise, elle se choisit dans Studio.
	Sounds.Loop("tier_gate_hum", gate)

	-- L'attribut peut changer en cours de partie (reglage en direct dans Studio) :
	-- la barriere suit sans qu'il faille relancer le serveur.
	gate:GetAttributeChangedSignal(Config.TIER_TARGET_ATTRIBUTE):Connect(function()
		local updated = gateTarget(gate)
		if updated and updated > Tiers.FIRST then
			gates[gate] = updated
			gate.CollisionGroup = gateGroup(updated)
		end
	end)
end

--------------------------------------------------------------------------------
-- Achat
--------------------------------------------------------------------------------

-- Ce qu'il faut POSSEDER pour entrer : le prix, plus de quoi ne pas ressortir
-- mourant de l'autre cote.
function TierService.Required(tier)
	local cost = Tiers.Cost(tier)
	return cost + math.max(Config.TIER_SAFETY_MARGIN, cost * Config.TIER_SAFETY_FRACTION)
end

function TierService.Get(player)
	local data = PlayerData.Get(player)
	return data and Tiers.Clamp(data.Tier) or Tiers.FIRST
end

-- Le multiplicateur des gains ACTIFS. Tout ce qui rapporte du temps a la suite
-- d'un geste du joueur passe par ici ; rien d'autre n'y touche.
function TierService.Multiplier(player)
	return Tiers.Multiplier(TierService.Get(player))
end

local function withinReach(player, gate)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	-- Le rayon suit la taille de la barriere : un passage de 40 studs de large
	-- ne doit pas refuser un joueur debout devant son bord.
	local reach = BUY_REACH + gate.Size.Magnitude / 2
	return (root.Position - gate.Position).Magnitude <= reach
end

local function tryBuy(player, gate)
	if typeof(gate) ~= "Instance" or not gate:IsA("BasePart") then
		return
	end

	local target = gates[gate]
	if not target or not withinReach(player, gate) then
		return
	end

	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local current = Tiers.Clamp(data.Tier)

	-- Deja chez lui : la barriere ne bloque plus, il n'y a rien a vendre.
	if current >= target then
		return
	end

	-- On ne saute pas de marche : le palier 4 s'achete depuis le 3, pas depuis le 1.
	if target ~= current + 1 then
		Remotes.Notify:FireClient(player, "notify_tier_locked", { tier = current + 1 }, Colors.LOSE)
		return
	end

	local required = TierService.Required(target)
	if data.TimeLeft < required then
		Remotes.Notify:FireClient(player, "notify_tier_poor", { amount = required }, Colors.LOSE)
		return
	end

	local tier = Tiers.Get(target)

	data.TimeLeft -= tier.cost
	data.Tier = target

	applyCharacterGroup(player)

	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	Remotes.TierUpdated:FireClient(player, target)
	Leaderstats.Refresh(player)

	-- Les autres joueurs doivent voir le nouveau badge AU MOMENT de l'annonce, pas
	-- au prochain tour de la boucle de Presence.
	Presence.Publish(player)

	Remotes.Notify:FireClient(player, "notify_tier_bought", {
		tier = target,
		multiplier = tier.multiplier,
	}, Colors.WIN)

	-- Tout le serveur le voit : une montee est un evenement social, c'est ce qui
	-- donne envie aux autres d'y aller.
	Remotes.TierAnnounce:FireAllClients(player, target)

	-- Le portique s'ouvre pour tout le monde a portee : la note monte avec l'etage.
	Sounds.PlayAt("tier_gate_open", gate, { pitch = 0.8 + target * 0.06 })

	-- Sauvegarde immediate : un palier paye puis perdu dans un crash serveur
	-- serait la pire chose que ce systeme puisse faire a un joueur.
	PlayerData.Save(player)
end

--------------------------------------------------------------------------------

function TierService.Start()
	registerGroups()

	for _, gate in CollectionService:GetTagged(Config.TIER_GATE_TAG) do
		setupGate(gate)
	end

	CollectionService:GetInstanceAddedSignal(Config.TIER_GATE_TAG):Connect(setupGate)

	CollectionService:GetInstanceRemovedSignal(Config.TIER_GATE_TAG):Connect(function(gate)
		gates[gate] = nil
	end)

	local function watch(player)
		bindRespawn(player)

		player.CharacterAdded:Connect(function(character)
			bindRespawn(player)
			onCharacterAdded(player, character)
		end)

		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(watch)

	for _, player in Players:GetPlayers() do
		watch(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local connection = characterConnections[player]
		if connection then
			connection:Disconnect()
			characterConnections[player] = nil
		end
	end)

	Remotes.TierBuy.OnServerEvent:Connect(tryBuy)

	-- Le client reclame son palier des qu'il est pret. On ne peut pas le lui
	-- pousser sur PlayerAdded : a cet instant son LocalScript n'a pas encore
	-- branche ses Remotes et le message se perdrait.
	Remotes.TierUpdated.OnServerEvent:Connect(function(player)
		Remotes.TierUpdated:FireClient(player, TierService.Get(player))
	end)
end

return TierService
