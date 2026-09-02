-- Ce que les AUTRES joueurs lisent d'un joueur : son palier, son chrono, et sa
-- couronne s'il en a une.
--
-- Pourquoi des ATTRIBUTS et pas un Remote : un attribut pose sur une instance
-- Player se replique tout seul a TOUS les clients, y compris a ceux qui
-- arriveront plus tard. Le panneau au-dessus des tetes (src/client/Nameplates)
-- a besoin exactement de ca -- l'etat de quelqu'un d'autre -- alors que
-- Remotes.TimeUpdated ne parle qu'au proprietaire du chrono, et TierUpdated
-- qu'a celui qui vient de payer.
--
-- On ne publie que des SECONDES ENTIERES, une fois par seconde : les decimales
-- descendent chez le client qui regarde, image par image, exactement comme
-- celles de son propre HUD. Publier plus fin ne montrerait rien de plus et
-- multiplierait les replications par le nombre de joueurs au carre.
--
-- Ce module ne decide de rien : il ne fait que rendre public ce que PlayerData
-- sait deja. C'est pour ca qu'il tourne dans son coin, sans que les modules qui
-- modifient le temps ou le palier aient a penser a le prevenir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local PlayerData = require(script.Parent.PlayerData)

local Presence = {}

-- Reecrire un attribut avec la valeur qu'il porte deja coute une replication
-- pour rien. Le palier, lui, ne bouge que sept fois dans une partie : sans ce
-- test il se repliquerait une fois par seconde et par joueur.
local function publishAttribute(player, name, value)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

-- Appelable a tout moment par qui vient de changer quelque chose d'important
-- (une entree payee) pour ne pas attendre le prochain tour de boucle.
function Presence.Publish(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	publishAttribute(player, Config.PRESENCE_TIER_ATTRIBUTE, Tiers.Clamp(data.Tier))
	publishAttribute(player, Config.PRESENCE_TIME_ATTRIBUTE, math.max(0, math.floor(data.TimeLeft)))

	-- La couronne ne change qu'une fois dans une partie, mais elle passe par le
	-- meme chemin que le reste : c'est ce qui la rend visible au-dessus de la
	-- tete ET au classement sans qu'aucun des deux n'ait a lire la sauvegarde.
	publishAttribute(player, Config.PRESENCE_CROWN_ATTRIBUTE, data.Crown == true)
end

function Presence.Start()
	task.spawn(function()
		while true do
			task.wait(Config.PRESENCE_SYNC_INTERVAL)

			for _, player in Players:GetPlayers() do
				Presence.Publish(player)
			end
		end
	end)
end

return Presence
