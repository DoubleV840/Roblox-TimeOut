-- Charge et sauvegarde les donnees persistantes de chaque joueur (temps restant, record).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerData = {}

local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)

-- cache[player] = tout ce qui survit a une deconnexion :
--
--   TimeLeft, BestSurvival, MaxTime, Tier   -- le socle (plan.md et lot 1)
--   ClickPower                              -- Chrono Boost
--   AutoClickers, AutoClickPower,
--   AutoClickFuel, AutoClickTokens,
--   AutoClickSeenAt                         -- auto-cliqueur (lot 4)
--   Packs                                   -- packs en attente, TIRAGE COMPRIS (lot 3)
--   PowerUps, PowerUpKeys, FrenzyAt         -- power-ups du cookie (lot 5)
--   OrbBonus, OrbSpeed, ClickBase,
--   TierBonus, TierDiscount, Stakes,
--   Insurance, SecondWind, Crown            -- effets permanents des cartes (lot 3)
--   Claimed                                 -- cadeaux deja reclames (lot 7)
--
-- Les effets a duree de vie (pluie d'orbes, pieds legers, pacte, frenesie) ne
-- sont PAS ici : ils se comptent en minutes et vivent en memoire, voir Boons.
local cache = {}

-- Valeurs neutres de tout ce que les lots 3, 5 et 7 ont ajoute. Une seule table,
-- utilisee aux deux endroits qui en ont besoin : la creation d'un compte neuf,
-- et le rattrapage d'une sauvegarde plus ancienne que la fonctionnalite.
--
-- Les tables sont recreees a chaque appel : une valeur par defaut partagee
-- serait la MEME table pour tous les joueurs du serveur, et le premier a
-- acheter un power-up l'offrirait a tout le monde.
local function defaults()
	return {
		-- Lot 3 -- packs en attente. Chaque entree porte SON TIRAGE : trois
		-- cartes decidees une fois pour toutes, pour que se deconnecter en plein
		-- choix ne serve pas a relancer les des.
		Packs = {},

		-- Lot 5 -- niveau par power-up, et les cles debloquees en avance par une
		-- carte "Plan vole".
		PowerUps = {},
		PowerUpKeys = {},
		FrenzyAt = 0,

		-- Lot 3 -- ce que les cartes changent pour de bon. Toutes neutres :
		-- multiplicateurs a 1, compteurs a 0.
		OrbBonus = 1, -- Orbes bonifiees : ce que vaut une orbe, en facteur
		OrbSpeed = 1, -- Orbes accelerees : facteur sur le temps de retour
		ClickBase = Config.CLICKER_REWARD, -- Bielle : le gain de base par clic
		TierBonus = 0, -- Eclat de palier : crans de multiplicateur en plus
		TierDiscount = 0, -- Billet coupe-file : remise sur la PROCHAINE entree
		Stakes = 0, -- Poignee de jetons : mises de mini-jeu offertes
		Insurance = 0, -- Assurance : mises perdues encore remboursables
		SecondWind = false, -- Second souffle : la prochaine mort est amortie
		Crown = false, -- Couronne : pseudo dore au classement et sur la tete

		-- Lot 7 -- seuils de cadeau deja encaisses. La cle est l'indice du seuil
		-- ecrit en TEXTE : un DataStore reserialise en JSON, et une table a cles
		-- entieres non contigues revient avec des cles texte (voir Rewards).
		Claimed = {},
	}
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

function PlayerData.Load(player)
	local ok, result = pcall(function()
		return store:GetAsync(keyFor(player))
	end)

	local data
	if ok and result then
		data = result
		-- Valeurs par defaut pour les sauvegardes anterieures a ces fonctionnalites.
		if data.ClickPower == nil then
			data.ClickPower = 1
		end
		if data.AutoClickers == nil then
			data.AutoClickers = 0
		end
		-- Sans historique, on credite au joueur ce qu'il possede aujourd'hui :
		-- ca lui laisse les paris qu'il pouvait deja se payer, jamais moins.
		if data.MaxTime == nil then
			data.MaxTime = math.max(data.TimeLeft or 0, Config.BASE_TIME)
		end
		-- Les joueurs d'avant les paliers repartent du Quai : ils n'ont jamais
		-- paye d'etage, et le Quai est ouvert a tout le monde.
		if data.Tier == nil then
			data.Tier = 1
		end
		-- Ceux qui possedent deja un auto-cliqueur avaient paye pour de l'infini :
		-- on ne leur reprend pas sans contrepartie, ils recoivent un plein par
		-- achat deja fait.
		if data.AutoClickFuel == nil then
			data.AutoClickFuel = (data.AutoClickers or 0) * Config.AUTOCLICK_FUEL_BASE
		end
		-- Le debit ne double plus, il monte par crans de Puissance. On convertit
		-- un achat en un cran : les anciens acheteurs gardent au minimum le debit
		-- qu'ils avaient (2 s/sec au 1er achat, 4 au 2e), et rien ne leur est
		-- repris au-dela du 2e -- le jeu n'etait pas encore ouvert.
		if data.AutoClickPower == nil then
			data.AutoClickPower = math.max(0, (data.AutoClickers or 0) - 1)
		end
		-- Aucun jeton retroactif : les achats d'avant ont deja ete honores.
		if data.AutoClickTokens == nil then
			data.AutoClickTokens = 0
		end

		-- Lots 3, 5 et 7. Une sauvegarde d'avant ces fonctionnalites n'a aucun
		-- de ces champs : on pose la valeur neutre, jamais un cadeau de
		-- rattrapage -- personne n'a "manque" un power-up qui n'existait pas.
		--
		-- Le test porte sur chaque champ separement, et non sur un numero de
		-- version : c'est ce qui permet d'ajouter un champ plus tard sans avoir a
		-- se demander qui a deja migre.
		for name, value in defaults() do
			if data[name] == nil then
				data[name] = value
			end
		end
	else
		data = defaults()

		data.TimeLeft = Config.BASE_TIME
		data.BestSurvival = 0
		data.ClickPower = 1
		data.AutoClickers = 0
		data.AutoClickPower = 0
		data.AutoClickFuel = 0
		data.AutoClickTokens = 0
		data.MaxTime = Config.BASE_TIME
		data.Tier = 1
	end

	cache[player] = data
	return data
end

-- Retient le plus haut temps jamais possede : c'est lui qui deverrouille les
-- zones de pari, definitivement. A appeler apres chaque gain de temps notable.
function PlayerData.NoteTime(data)
	if data and data.TimeLeft > data.MaxTime then
		data.MaxTime = data.TimeLeft
	end
end

function PlayerData.Get(player)
	return cache[player]
end

function PlayerData.Save(player)
	local data = cache[player]
	if not data then
		return
	end

	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), data)
	end)

	if not ok then
		warn("TimeOut: echec de sauvegarde pour " .. player.Name .. " -> " .. tostring(err))
	end
end

function PlayerData.Release(player)
	PlayerData.Save(player)
	cache[player] = nil
end

function PlayerData.SaveAll()
	for player in pairs(cache) do
		PlayerData.Save(player)
	end
end

return PlayerData
