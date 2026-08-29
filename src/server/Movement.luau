-- Vitesse de deplacement des joueurs. Le jeu est une course contre le chrono :
-- traverser le terminal pour aller d'une orbe a un guichet ne doit pas couter
-- des secondes de marche.
--
-- On regle StarterPlayer plutot que chaque Humanoid : Roblox recopie ces valeurs
-- a chaque apparition de personnage, donc la vitesse survit aux morts, aux
-- reapparitions apres un achat, et a un LoadCharacter force.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)

local Movement = {}

function Movement.Start()
	StarterPlayer.CharacterWalkSpeed = Config.WALK_SPEED

	-- Les personnages deja en jeu (rejeu d'un script en Studio, ou joueur entre
	-- avant le demarrage du serveur) ne repassent pas par StarterPlayer.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = Config.WALK_SPEED
		end
	end
end

return Movement
