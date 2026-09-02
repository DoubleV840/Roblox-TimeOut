-- Les cinq power-ups du cookie : ce que chaque etage ajoute a la facon de
-- cliquer. C'est ca, "des salles plus riches avec plus de fonctionnalites".
--
-- Le Chrono Boost (ClickPower) reste la progression de fond, achetee partout ;
-- ceux-ci s'achetent chacun sur UNE zone, dans UNE salle, et ne s'ouvrent qu'a
-- partir de son palier. Tous se paient en TEMPS -- les Robux restent au guichet,
-- le cookie reste un jeu de patience.
--
-- C'est le tableau d'equilibrage du lot 5 : prix, croissance et puissance de
-- chaque niveau se reglent ici et nulle part ailleurs.
--
-- POURQUOI LES COUTS SE DERIVENT DU PALIER. Un power-up qui s'ouvre au palier 7
-- s'achete avec l'argent du palier 7 : ecrire ses prix a la main obligerait a
-- les reprendre tous a chaque retouche de l'echelle des paliers. "costShare" dit
-- ce que coute le premier niveau, en part du prix d'entree de la salle -- le
-- rapport reste juste quoi qu'on fasse du tableau des paliers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tiers = require(ReplicatedStorage.Shared.Tiers)

local PowerUps = {}

-- Les cles telles qu'elles s'ecrivent dans l'attribut "PowerUp" de la Part, dans
-- Studio. Sans accent et sans espace : un attribut se tape a la main.
PowerUps.CRIT = "Critique"
PowerUps.ECHO = "Echo"
PowerUps.FRENZY = "Frenesie"
PowerUps.WEIGHT = "PoidsDuTemps"
PowerUps.GEARS = "Rouages"

-- Un power-up dont le niveau ne changerait plus rien serait un puits a temps :
-- tous plafonnent.
local MAX_LEVEL = 10

PowerUps.MAX_LEVEL = MAX_LEVEL

PowerUps.List = {
	{
		key = PowerUps.CRIT,
		minTier = 3,
		costShare = 0.12,
		growth = 1.55,
		color = Color3.fromRGB(255, 215, 70),
		-- Chance qu'un clic rapporte x10, +2 points par niveau.
		chancePerLevel = 0.02,
		multiplier = 10,
	},
	{
		key = PowerUps.ECHO,
		minTier = 4,
		costShare = 0.1,
		growth = 1.55,
		color = Color3.fromRGB(120, 210, 255),
		-- Chaque clic se repete DELAY secondes plus tard, a une fraction de sa
		-- valeur : la moitie au niveau 1, jusqu'a l'integralite au plafond.
		delay = 0.4,
		shareBase = 0.4,
		sharePerLevel = 0.1,
	},
	{
		key = PowerUps.FRENZY,
		minTier = 5,
		costShare = 0.09,
		growth = 1.6,
		color = Color3.fromRGB(255, 110, 60),
		-- Le seul consommable : x5 sur tous les clics, a declencher au bon
		-- moment. Les niveaux allongent la fenetre et raccourcissent l'attente.
		multiplier = 5,
		durationBase = 20,
		durationPerLevel = 2,
		cooldownBase = 180,
		cooldownPerLevel = 10,
		cooldownFloor = 60,
	},
	{
		key = PowerUps.WEIGHT,
		minTier = 6,
		costShare = 0.08,
		growth = 1.6,
		color = Color3.fromRGB(190, 130, 255),
		-- Riche quand on est riche, nul quand on agonise : le gain par clic monte
		-- avec le chrono possede, et retombe exactement a 1 quand il ne reste
		-- plus rien. C'est la carte des joueurs qui n'ont plus peur de mourir --
		-- donc, structurellement, celle du haut de l'echelle.
		perLevel = 0.05,
	},
	{
		key = PowerUps.GEARS,
		minTier = 7,
		costShare = 0.07,
		growth = 1.6,
		color = Color3.fromRGB(255, 150, 215),
		-- Le clic a la main finance la source passive, sans jamais l'offrir : le
		-- NIVEAU de l'auto-cliqueur reste ce qu'on ne peut obtenir qu'en Robux,
		-- seul son carburant se gagne ici. Volontairement maigre par clic : de
		-- quoi soulager un reservoir, pas de quoi rendre l'achat inutile.
		fuelPerLevel = 0.05,
	},
}

local byKey = {}
for index, power in PowerUps.List do
	power.index = index
	byKey[power.key] = power
end

function PowerUps.Get(key)
	return byKey[key]
end

--------------------------------------------------------------------------------
-- Niveaux et prix
--------------------------------------------------------------------------------

-- data.PowerUps[key] = niveau possede. Absent = pas achete.
function PowerUps.Level(data, key)
	local owned = data and data.PowerUps
	return (owned and owned[key]) or 0
end

function PowerUps.OwnedCount(data)
	local count = 0

	for _, power in PowerUps.List do
		if PowerUps.Level(data, power.key) > 0 then
			count += 1
		end
	end

	return count
end

-- Cout du passage du niveau courant au suivant. Le premier niveau vaut
-- costShare du prix d'entree de sa salle, puis chaque niveau multiplie par
-- growth -- meme forme que le Chrono Boost, a une echelle propre a l'etage.
function PowerUps.Cost(power, level)
	local base = math.max(1, math.floor(Tiers.Cost(power.minTier) * power.costShare))
	return math.floor(base * (power.growth ^ math.max(0, level)))
end

-- Un power-up s'ouvre par le palier ATTEINT, ou par une carte "Plan vole" qui
-- l'a debloque en avance (data.PowerUpKeys[key] = true).
function PowerUps.IsUnlocked(data, tierIndex, key)
	local power = byKey[key]
	if not power then
		return false
	end

	if tierIndex >= power.minTier then
		return true
	end

	local early = data and data.PowerUpKeys
	return (early and early[key]) == true
end

-- Le premier power-up encore ferme AU-DESSUS du palier courant : c'est ce que
-- vole la carte "Plan vole". Renvoie nil quand il n'y a plus rien a voler --
-- c'est ce nil qui empeche la carte d'etre proposee pour rien.
function PowerUps.NextLocked(data, tierIndex)
	for _, power in PowerUps.List do
		if power.minTier > tierIndex and not PowerUps.IsUnlocked(data, tierIndex, power.key) then
			return power
		end
	end

	return nil
end

--------------------------------------------------------------------------------
-- Effets
--------------------------------------------------------------------------------
-- Un seul endroit calcule ce que vaut un niveau : le serveur l'applique, le
-- client l'annonce dans la fenetre d'achat, et les deux ne peuvent pas diverger.

function PowerUps.CritChance(level)
	return math.min(1, level * byKey[PowerUps.CRIT].chancePerLevel)
end

function PowerUps.EchoShare(level)
	local power = byKey[PowerUps.ECHO]
	return math.min(1, power.shareBase + level * power.sharePerLevel)
end

function PowerUps.FrenzyDuration(level)
	local power = byKey[PowerUps.FRENZY]
	return power.durationBase + (level - 1) * power.durationPerLevel
end

function PowerUps.FrenzyCooldown(level)
	local power = byKey[PowerUps.FRENZY]
	return math.max(power.cooldownFloor, power.cooldownBase - (level - 1) * power.cooldownPerLevel)
end

-- Le multiplicateur du "Poids du temps". Il suit le LOGARITHME du chrono, pas le
-- chrono : lineaire, un joueur a 1000 h aurait un clic douze mille fois plus
-- fort qu'un joueur a 5 min, ce qui n'est plus un power-up mais une autre partie.
--
-- Le repere est le temps de depart : a 5 min pile, chaque niveau vaut perLevel.
function PowerUps.WeightFactor(level, timeLeft)
	if level <= 0 then
		return 1
	end

	local power = byKey[PowerUps.WEIGHT]
	local ratio = math.max(0, timeLeft) / Config.BASE_TIME
	local scale = math.log(1 + ratio) / math.log(2)

	return 1 + level * power.perLevel * scale
end

function PowerUps.GearsFuel(level)
	return level * byKey[PowerUps.GEARS].fuelPerLevel
end

-- Ce que la fenetre d'achat annonce, pour un niveau donne : la valeur brute que
-- le texte de traduction met en forme. Un seul chiffre par power-up -- c'est ce
-- qui rend les cinq fenetres lisibles de la meme facon.
function PowerUps.Value(power, level, timeLeft)
	if power.key == PowerUps.CRIT then
		return math.floor(PowerUps.CritChance(level) * 100)
	elseif power.key == PowerUps.ECHO then
		return math.floor(PowerUps.EchoShare(level) * 100)
	elseif power.key == PowerUps.FRENZY then
		return PowerUps.FrenzyCooldown(math.max(1, level))
	elseif power.key == PowerUps.WEIGHT then
		return math.floor((PowerUps.WeightFactor(level, timeLeft or Config.BASE_TIME) - 1) * 100)
	elseif power.key == PowerUps.GEARS then
		return PowerUps.GearsFuel(level)
	end

	return level
end

return PowerUps
