-- Cree/maintient le dossier "leaderstats" affiche automatiquement par Roblox
-- dans le tableau des joueurs en jeu.

local PlayerData = require(script.Parent.PlayerData)

local Leaderstats = {}

local timeValues = {}
local recordValues = {}

function Leaderstats.Setup(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player

	local timeValue = Instance.new("IntValue")
	timeValue.Name = "Temps restant"
	timeValue.Value = math.floor(data.TimeLeft)
	timeValue.Parent = folder

	local recordValue = Instance.new("IntValue")
	recordValue.Name = "Record"
	recordValue.Value = math.floor(data.BestSurvival)
	recordValue.Parent = folder

	timeValues[player] = timeValue
	recordValues[player] = recordValue
end

function Leaderstats.Refresh(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local timeValue = timeValues[player]
	if timeValue then
		timeValue.Value = math.floor(data.TimeLeft)
	end

	local recordValue = recordValues[player]
	if recordValue then
		recordValue.Value = math.floor(data.BestSurvival)
	end
end

function Leaderstats.Remove(player)
	timeValues[player] = nil
	recordValues[player] = nil
end

return Leaderstats
