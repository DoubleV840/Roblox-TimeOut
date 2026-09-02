-- Les cadeaux de survie : ce qu'on recoit pour avoir TENU, par opposition a tout
-- le reste du jeu, qui se paie.
--
-- LE SEUIL SE LIT SUR LE PLUS HAUT TEMPS JAMAIS POSSEDE (data.MaxTime), jamais
-- sur le temps courant. C'est la seule regle qui compte ici : sur le temps
-- courant, un joueur monterait et redescendrait en boucle pour reencaisser les
-- memes cadeaux, et l'echelle entiere ne vaudrait plus rien.
--
-- L'echelle monte jusqu'a 50 jours parce que c'est l'ordre de grandeur du cumul
-- a payer pour atteindre le Terminus : le dernier cadeau tombe donc pile au
-- moment ou un joueur vise le palier 8.
--
-- Les GROS cadeaux paient en packs, les petits en nature. Un pack demande un
-- geste (l'ouvrir, lire trois cartes, choisir) : il vaut pour une grosse
-- recompense et serait penible toutes les dix minutes.
--
-- A RECLAMER, PAS A RECEVOIR. Une icone pulse, le joueur clique, ca s'ouvre. Un
-- cadeau encaisse sans qu'on le remarque n'a rien recompense du tout. Et il
-- reste reclamable indefiniment : un joueur deconnecte au mauvais moment ne perd
-- rien.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tiers = require(ReplicatedStorage.Shared.Tiers)

local Rewards = {}

Rewards.KIND_TIME = "Time" -- du temps, tout de suite
Rewards.KIND_FUEL = "Fuel" -- une recharge de carburant
Rewards.KIND_BOOST = "Boost" -- des niveaux de Chrono Boost
Rewards.KIND_FRENZY = "Frenzy" -- une Frenesie gratuite, sans attendre la recharge
Rewards.KIND_PACK = "Pack" -- un pack, de la rarete indiquee
Rewards.KIND_CROWN = "Crown" -- le badge cosmetique du bout de l'echelle

-- "at" est le seuil, en secondes de plus haut temps jamais tenu. La liste doit
-- rester triee : le code s'en sert pour trouver le prochain palier a viser.
Rewards.List = {
	{ at = 10 * 60, kind = Rewards.KIND_TIME, amount = 2 * 60 },
	{ at = 30 * 60, kind = Rewards.KIND_FUEL },
	{ at = 3600, kind = Rewards.KIND_TIME, amount = 15 * 60 },
	{ at = 3 * 3600, kind = Rewards.KIND_BOOST, amount = 1 },
	{ at = 6 * 3600, kind = Rewards.KIND_TIME, amount = 3600 },
	{ at = 12 * 3600, kind = Rewards.KIND_FRENZY },
	{ at = 24 * 3600, kind = Rewards.KIND_TIME, amount = 4 * 3600 },
	{ at = 3 * 86400, kind = Rewards.KIND_PACK, rarity = Tiers.RARITY_RARE },
	{ at = 7 * 86400, kind = Rewards.KIND_TIME, amount = 86400 },
	{ at = 20 * 86400, kind = Rewards.KIND_PACK, rarity = Tiers.RARITY_EPIC },
	{ at = 50 * 86400, kind = Rewards.KIND_PACK, rarity = Tiers.RARITY_LEGENDARY, crown = true },
}

for index, reward in Rewards.List do
	reward.index = index
end

-- Le prochain seuil non atteint : c'est lui que le HUD affiche comme objectif.
-- nil quand toute l'echelle est derriere le joueur.
function Rewards.Next(maxTime)
	for _, reward in Rewards.List do
		if maxTime < reward.at then
			return reward
		end
	end

	return nil
end

return Rewards
