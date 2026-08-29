-- Sauvegarde periodiquement le temps courant de chaque joueur, pour que le classement
-- puisse encore afficher (en pause) les joueurs qui se sont deconnectes.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TimeBalance = {}

local store = DataStoreService:GetOrderedDataStore(Config.TIME_BALANCE_DATASTORE_NAME)

function TimeBalance.Submit(player, timeLeft)
	local ok, err = pcall(function()
		store:SetAsync("Player_" .. player.UserId, math.max(0, math.floor(timeLeft)))
	end)

	if not ok then
		warn("TimeOut: echec sync classement temps pour " .. player.Name .. " -> " .. tostring(err))
	end
end

-- Renvoie jusqu'a `count` entrees { userId, name, timeLeft }, triees du plus grand au plus petit.
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

		table.insert(results, { userId = userId, name = name, timeLeft = entry.value })
	end

	return results
end

return TimeBalance
