-- Charge et sauvegarde les donnees persistantes de chaque joueur (temps restant, record).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerData = {}

local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)

-- cache[player] = { TimeLeft, BestSurvival, ClickPower, MaxTime, Tier,
--                   AutoClickers, AutoClickPower, AutoClickFuel, AutoClickTokens,
--                   AutoClickSeenAt }
local cache = {}

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
	else
		data = {
			TimeLeft = Config.BASE_TIME,
			BestSurvival = 0,
			ClickPower = 1,
			AutoClickers = 0,
			AutoClickPower = 0,
			AutoClickFuel = 0,
			AutoClickTokens = 0,
			MaxTime = Config.BASE_TIME,
			Tier = 1,
		}
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
