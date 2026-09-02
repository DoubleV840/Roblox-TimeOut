-- Les cadeaux de survie (etape 32) : la seule chose du jeu qui se gagne en
-- TENANT, quand tout le reste se paie.
--
-- LE SEUIL SE LIT SUR LE PLUS HAUT TEMPS JAMAIS POSSEDE (data.MaxTime), jamais
-- sur le temps courant. C'est la regle qui gouverne ce module : sur le temps
-- courant, un joueur monterait et redescendrait en boucle pour reencaisser les
-- memes cadeaux, et l'echelle entiere ne vaudrait plus rien.
--
-- A RECLAMER, PAS A RECEVOIR. Une icone pulse, le joueur clique, ca s'ouvre. Un
-- cadeau encaisse sans qu'on le remarque n'a rien recompense du tout -- c'est la
-- meme raison qui fait que les grosses recompenses passent par un pack plutot
-- que par un versement.
--
-- Et un cadeau reste reclamable INDEFINIMENT : un joueur deconnecte au mauvais
-- moment ne perd rien, et rien ne se reclame deux fois. C'est data.Claimed qui
-- le garantit, et il est ecrit AVANT que le cadeau ne parte.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Colors = require(ReplicatedStorage.Shared.Colors)
local RewardList = require(ReplicatedStorage.Shared.Rewards)
local PowerUps = require(ReplicatedStorage.Shared.PowerUps)
local PlayerData = require(script.Parent.PlayerData)
local TimeService = require(script.Parent.TimeService)
local AutoClicker = require(script.Parent.AutoClicker)
local Packs = require(script.Parent.Packs)
local PowerUpZones = require(script.Parent.PowerUpZones)
local Presence = require(script.Parent.Presence)

local Rewards = {}

-- La cle de data.Claimed est un TEXTE, jamais un nombre, et c'est important : un
-- DataStore reserialise en JSON, et une table a cles entieres non contigues
-- ({[3] = true}) revient avec des cles texte ({["3"] = true}). Un cadeau marque
-- reclame sous 3 se serait retrouve reclamable sous "3" a la session suivante --
-- soit exactement la chose que ce module promet de ne jamais faire.
local function claimKey(index)
	return tostring(index)
end

--------------------------------------------------------------------------------
-- Etat cote client
--------------------------------------------------------------------------------

-- Le client a l'echelle (src/shared/Rewards.luau) : il sait dessiner un cadeau a
-- partir de son seul indice. On ne lui envoie donc que ce qu'il ne peut pas
-- savoir -- ce qui est mur chez CE joueur, et ou il en est du prochain palier.
local function stateOf(data)
	local ready = {}
	local maxTime = math.max(data.MaxTime or 0, data.TimeLeft or 0)

	for _, reward in RewardList.List do
		if maxTime >= reward.at and not data.Claimed[claimKey(reward.index)] then
			table.insert(ready, reward.index)
		end
	end

	local next_ = RewardList.Next(maxTime)

	return {
		ready = ready,
		maxTime = math.floor(maxTime),
		nextAt = next_ and next_.at or nil,
		nextIndex = next_ and next_.index or nil,
	}
end

function Rewards.Announce(player, data)
	Remotes.RewardUpdated:FireClient(player, stateOf(data))
end

--------------------------------------------------------------------------------
-- Les cadeaux
--------------------------------------------------------------------------------

-- Un cadeau par sorte. Chacun renvoie la table de parametres a citer dans la
-- notification : le texte annonce donc EXACTEMENT ce qui a ete pose, jamais une
-- promesse ecrite ailleurs.
--
-- Aucun ne donne de niveau d'auto-cliqueur -- meme regle que les packs. Le
-- carburant depanne, le NIVEAU reste ce qu'on ne peut obtenir qu'en Robux.
local givers = {}

givers[RewardList.KIND_TIME] = function(player, reward)
	TimeService.GrantTime(player, reward.amount)
	return { amount = reward.amount }
end

givers[RewardList.KIND_FUEL] = function(player, _, data)
	data.AutoClickFuel = (data.AutoClickFuel or 0) + Config.AUTOCLICK_FUEL_BASE
	AutoClicker.Announce(player, data)
	return { amount = Config.AUTOCLICK_FUEL_BASE }
end

givers[RewardList.KIND_BOOST] = function(player, reward, data)
	data.ClickPower += reward.amount
	Remotes.ClickPowerUpdated:FireClient(player, data.ClickPower, data.ClickBase)
	return { level = data.ClickPower }
end

givers[RewardList.KIND_FRENZY] = function(player)
	-- Une Frenesie offerte saute la recharge -- sinon le cadeau consisterait a
	-- attendre trois minutes. Elle ne s'atteint qu'apres avoir refuse la
	-- reclamation d'un joueur qui n'a pas encore le power-up (voir deliverable).
	PowerUpZones.Frenzy(player, true)
	return nil
end

-- Un cadeau qui ne peut PAS etre livre ne doit pas etre consomme.
--
-- Le seul cas est la Frenesie offerte a 12 h : elle ne veut rien dire tant que le
-- power-up n'est pas achete (palier 5). Le cadeau reste alors en attente au lieu
-- de disparaitre -- c'est la promesse du lot 7, "reclamable indefiniment", et
-- elle ne souffre pas d'exception.
local function deliverable(reward, data)
	if reward.kind ~= RewardList.KIND_FRENZY then
		return true
	end

	return PowerUps.Level(data, PowerUps.FRENZY) > 0
end

givers[RewardList.KIND_PACK] = function(player, reward, data)
	Packs.Grant(player, reward.rarity, "notify_reward_pack")

	-- Le dernier cadeau de l'echelle paie en Legendaire ET en couronne : c'est le
	-- seul badge cosmetique que le jeu donne pour avoir tenu, la ou la carte
	-- Couronne se gagne au hasard d'un pack.
	if reward.crown and not data.Crown then
		data.Crown = true
		Presence.Publish(player)
	end

	return nil
end

--------------------------------------------------------------------------------
-- Reclamation
--------------------------------------------------------------------------------

local function claim(player, index)
	if typeof(index) ~= "number" then
		return
	end

	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local reward = RewardList.List[math.floor(index)]
	if not reward or data.Claimed[claimKey(reward.index)] then
		return
	end

	if math.max(data.MaxTime or 0, data.TimeLeft or 0) < reward.at then
		return
	end

	if not deliverable(reward, data) then
		Remotes.Notify:FireClient(player, "notify_reward_frenzy_locked", nil, Colors.INFO)
		return
	end

	-- La marque AVANT le cadeau : un giver qui yield (GrantTime peut recharger un
	-- personnage) laisserait sinon la porte ouverte a un second RewardClaim sur
	-- le meme seuil, donc a deux cadeaux pour un.
	data.Claimed[claimKey(reward.index)] = true

	local params = givers[reward.kind] and givers[reward.kind](player, reward, data)

	Rewards.Announce(player, data)

	if params then
		Remotes.Notify:FireClient(player, "notify_reward_" .. string.lower(reward.kind), params, Colors.WIN)
	end

	-- Sauvegarde immediate : un cadeau reclame puis perdu dans un crash serveur
	-- serait rendu -- mais le joueur, lui, croirait l'avoir deja pris.
	PlayerData.Save(player)
end

--------------------------------------------------------------------------------

function Rewards.Start()
	Remotes.RewardClaim.OnServerEvent:Connect(claim)

	-- Le client reclame son etat quand il est pret : ses Remotes ne sont pas
	-- branches a PlayerAdded, un envoi spontane se perdrait.
	Remotes.RewardUpdated.OnServerEvent:Connect(function(player)
		local data = PlayerData.Get(player)
		if data then
			Rewards.Announce(player, data)
		end
	end)

	-- Un balayage periodique plutot qu'un signal a chaque gain de temps : le
	-- temps arrive de partout (clics, orbes, auto-cliqueur, mini-jeux, packs,
	-- achats) et un seuil franchi n'a pas besoin d'etre annonce a la
	-- milliseconde. On ne parle au client que quand la liste des cadeaux murs
	-- CHANGE, pas a chaque tour.
	task.spawn(function()
		-- La signature du dernier etat envoye, par joueur. Un joueur parti sort
		-- de Players:GetPlayers() au tour suivant : sa ligne cesse d'etre lue et
		-- ne coute rien, il n'y a donc rien a nettoyer a son depart.
		local known = {}

		while true do
			task.wait(Config.REWARD_REFRESH_INTERVAL)

			for _, player in Players:GetPlayers() do
				local data = PlayerData.Get(player)

				if data then
					local state = stateOf(data)
					local signature = #state.ready .. ":" .. (state.nextIndex or 0)

					if known[player] ~= signature then
						local isFirstPass = known[player] == nil
						known[player] = signature

						Remotes.RewardUpdated:FireClient(player, state)

						if not isFirstPass and #state.ready > 0 then
							Remotes.Notify:FireClient(player, "notify_reward_ready", nil, Colors.WIN)
						end
					end
				end
			end
		end
	end)
end

return Rewards
