-- Sauvegarde periodiquement le temps courant de chaque joueur, pour que le classement
-- puisse encore afficher (en pause) les joueurs qui se sont deconnectes.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TimeBalance = {}

local store = DataStoreService:GetOrderedDataStore(Config.TIME_BALANCE_DATASTORE_NAME)

-- Un OrderedDataStore ne stocke qu'un entier, et le classement a besoin de DEUX
-- informations : le temps (qui donne l'ordre) et le palier (qui donne le badge).
-- On les met dans le meme nombre -- le temps en secondes, le palier dans le
-- chiffre des unites. Le tri reste exact : le palier ne pese qu'une unite sur
-- des secondes multipliees par dix.
--
-- Aller chercher le palier dans le DataStore des joueurs demanderait une lecture
-- par ligne toutes les 3 secondes : hors de question.
local TIER_BASE = 10

local function encode(timeLeft, tier)
	local seconds = math.max(0, math.floor(timeLeft))
	local slot = math.clamp(math.floor(tier or 1), 1, TIER_BASE) - 1

	return seconds * TIER_BASE + slot
end

local function decode(value)
	return math.floor(value / TIER_BASE), (value % TIER_BASE) + 1
end

function TimeBalance.Submit(player, timeLeft, tier)
	local ok, err = pcall(function()
		store:SetAsync("Player_" .. player.UserId, encode(timeLeft, tier))
	end)

	if not ok then
		warn("TimeOut: echec sync classement temps pour " .. player.Name .. " -> " .. tostring(err))
	end
end

-- Renvoie jusqu'a `count` entrees { userId, name, timeLeft, tier }, triees du plus grand au plus petit.
function TimeBalance.GetTop(count)
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, count)
	end)

	if not ok then
		warn("TimeOut: echec lecture classement temps -> " .. tostring(pages))
		return {}
	end

	local results = {}

	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key:match("Player_(%d+)"))
		local name = "???"

		if userId then
			local nameOk, playerName = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if nameOk then
				name = playerName
			end
		end

		local timeLeft, tier = decode(entry.value)
		table.insert(results, { userId = userId, name = name, timeLeft = timeLeft, tier = tier })
	end

	return results
end

return TimeBalance
