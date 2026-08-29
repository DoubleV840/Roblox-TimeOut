-- Classement all-time des meilleurs temps de survie, partage entre tous les serveurs.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Leaderboard = {}

local store = DataStoreService:GetOrderedDataStore(Config.LEADERBOARD_DATASTORE_NAME)

function Leaderboard.SubmitScore(player, score)
	local ok, err = pcall(function()
		store:SetAsync("Player_" .. player.UserId, math.floor(score))
	end)

	if not ok then
		warn("TimeOut: echec envoi classement pour " .. player.Name .. " -> " .. tostring(err))
	end
end

-- Renvoie une liste de { name = string, score = number }, triee du meilleur au moins bon.
function Leaderboard.GetTop(count)
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, count)
	end)

	if not ok then
		warn("TimeOut: echec lecture classement -> " .. tostring(pages))
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

		table.insert(results, { name = name, score = entry.value })
	end

	return results
end

return Leaderboard
