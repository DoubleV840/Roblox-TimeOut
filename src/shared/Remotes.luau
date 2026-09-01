-- Cree (cote serveur) ou attend (cote client) les RemoteEvents partages
-- utilises pour que le serveur envoie des infos au client (temps restant, etc.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"TimeUpdated",
	"PlayerTimedOut",
	"Notify",
	"BetPrompt",
	"BetPromptHide",
	"BetAccept",
	"RequestRestart",
	"UpgradePrompt",
	"UpgradePromptHide",
	"UpgradeAccept",
	"ClickPowerUpdated",
	"ShopPrompt",
	"ShopPromptHide",
	"ShopBuy",
	"Revived",
	"AutoClickUpdated",
	"BetLockUpdated",
	"BetRoundsUpdated",
	"TierUpdated",
	"TierBuy",
	"TierAnnounce",
	"AutoClickChoose",
}

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage

	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
