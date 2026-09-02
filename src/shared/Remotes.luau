-- Cree (cote serveur) ou attend (cote client) les RemoteEvents partages
-- utilises pour que le serveur envoie des infos au client (temps restant, etc.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	-- Chrono, mort, notifications
	"TimeUpdated",
	"PlayerTimedOut",
	"Notify",
	"RequestRestart",
	"Revived",

	-- Chrono Boost (zone d'amelioration du clic)
	"UpgradePrompt",
	"UpgradePromptHide",
	"UpgradeAccept",
	"ClickPowerUpdated",

	-- Guichets (achats Robux)
	"ShopPrompt",
	"ShopPromptHide",
	"ShopBuy",
	"AutoClickUpdated",
	"AutoClickChoose",

	-- Paliers
	"TierUpdated",
	"TierBuy",
	"TierAnnounce",

	-- Mini-jeux (lot 6). Les cinq premiers portaient le prefixe "Bet" tant qu'il
	-- n'y avait qu'un pari : le cadre commun de l'etape 24 les sert tous les
	-- huit, zones BetZone comprises.
	--   MiniGameStage  -- serveur -> client : l'etat d'une partie en cours
	--                     (decompte, phase active, elimination, resultat)
	--   MiniGameAction -- client -> serveur : le geste du joueur PENDANT une
	--                     partie (un clic de duel, un secteur de roue)
	"MiniGamePrompt",
	"MiniGamePromptHide",
	"MiniGameAccept",
	"MiniGameLockUpdated",
	"MiniGameRoundsUpdated",
	"MiniGameStage",
	"MiniGameAction",

	-- Packs (lot 3)
	"PackUpdated",
	"PackOpen",
	"PackChoose",

	-- Power-ups du cookie (lot 5)
	"PowerUpPrompt",
	"PowerUpPromptHide",
	"PowerUpBuy",
	"PowerUpUpdated",
	"PowerUpUse",

	-- Cadeaux de survie (lot 7)
	"RewardUpdated",
	"RewardClaim",

	-- Effets temporaires en cours (pluie d'orbes, pieds legers, pacte, frenesie)
	"BoonUpdated",
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
