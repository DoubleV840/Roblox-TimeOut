-- Charge et sauvegarde les donnees persistantes de chaque joueur (temps restant, record).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerData = {}

local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)

-- cache[player] = { TimeLeft, BestSurvival, ClickPower, AutoClickers, MaxTime }
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
	else
		data = { TimeLeft = Config.BASE_TIME, BestSurvival = 0, ClickPower = 1, AutoClickers = 0, MaxTime = Config.BASE_TIME }
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
