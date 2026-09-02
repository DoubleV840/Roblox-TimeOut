-- Les packs : trois cartes, le joueur en garde une.
--
-- C'est la recompense de fin de palier (lot 3) et un produit de boutique. Mais
-- l'interet n'est PAS la recompense : c'est le choix. Un cadeau qui tombe se
-- subit ; trois cartes obligent le joueur a lire sa propre situation -- suis-je
-- en train de mourir, en train de construire, ou d'humeur a tenter un coup ?
-- Deux joueurs arrives au meme palier ne jouent alors plus la meme partie.
--
-- TROIS REGLES DE FOND, et c'est ce module qui les tient :
--
-- 1. TROIS FAMILLES DIFFERENTES. Un choix entre trois choses semblables n'est
--    pas un choix. Le tirage prend exactement une carte par famille.
--
-- 2. LE TIRAGE EST DECIDE UNE FOIS POUR TOUTES, a la creation du pack, et il est
--    SAUVEGARDE. Se deconnecter en plein choix et revenir retrouve les memes
--    trois cartes -- sinon le bon reflexe serait de quitter le jeu jusqu'a
--    tomber sur la bonne main, et le choix ne voudrait plus rien dire.
--
-- 3. AUCUNE CARTE MORTE. Une carte dont les conditions ne sont pas reunies n'est
--    jamais proposee (voir Cards.available). Une carte inutile, c'est un pack a
--    deux choix.
--
-- LE PALIER EST FIGE A LA CREATION du pack, lui aussi. Les cartes valent un
-- pourcentage du prix d'entree : sans ca, garder ses packs fermes jusqu'au
-- Terminus serait toujours le bon calcul, et personne n'en ouvrirait un seul
-- avant la fin de l'echelle.
--
-- La mecanique de fond -- une recompense qui attend dans la sauvegarde, une
-- icone qui pulse, une fenetre qu'on peut refermer -- est celle du jeton
-- d'auto-cliqueur (lot 4). Elle avait ete construite la-bas pour deux cartes ;
-- elle se remplit ici avec les siennes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Colors = require(ReplicatedStorage.Shared.Colors)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Cards = require(ReplicatedStorage.Shared.Cards)
local PowerUps = require(ReplicatedStorage.Shared.PowerUps)
local PlayerData = require(script.Parent.PlayerData)
local TimeService = require(script.Parent.TimeService)
local AutoClicker = require(script.Parent.AutoClicker)
local Presence = require(script.Parent.Presence)
local Boons = require(script.Parent.Boons)

local Packs = {}

--------------------------------------------------------------------------------
-- Le tirage
--------------------------------------------------------------------------------

local function weightOf(card)
	return Config.PACK_WEIGHTS[card.rarity] or 1
end

-- Les cartes d'une famille que CE joueur peut recevoir : sous le plafond de
-- rarete du pack, et dont les conditions sont reunies.
local function candidates(data, tierIndex, family, cap, floor)
	local list = {}

	for _, card in Cards.List do
		if card.family == family then
			local order = Cards.RARITY_ORDER[card.rarity]

			if order <= cap and (not floor or order >= floor) then
				if Cards.IsAvailable(card, data, tierIndex) then
					table.insert(list, card)
				end
			end
		end
	end

	return list
end

-- Tirage pondere : une carte rare reste rare A L'INTERIEUR MEME d'un pack qui
-- l'autorise. Sans ces poids, la rarete du pack serait la seule chose qui
-- compte, et un pack Legendaire donnerait une Legendaire trois fois sur quatre.
local function pick(list)
	if #list == 0 then
		return nil
	end

	local total = 0
	for _, card in list do
		total += weightOf(card)
	end

	local roll = math.random() * total

	for _, card in list do
		roll -= weightOf(card)
		if roll <= 0 then
			return card
		end
	end

	return list[#list]
end

-- Un pack Epique promet au moins une Rare, un Legendaire au moins une Epique.
-- La garantie s'applique APRES le tirage normal : on ne force une famille que si
-- le hasard n'a pas deja tenu la promesse, sinon le plancher deviendrait un
-- plafond et tous les packs Legendaires se ressembleraient.
local function enforceFloor(data, tierIndex, drawn, cap, floor)
	for _, card in drawn do
		if Cards.RARITY_ORDER[card.rarity] >= floor then
			return
		end
	end

	-- Les familles qui ont de quoi tenir la promesse. Une seule est refaite, au
	-- hasard : forcer la premiere ferait toujours sortir la meme famille.
	local eligible = {}

	for index, family in Cards.FAMILIES do
		local list = candidates(data, tierIndex, family, cap, floor)
		if #list > 0 then
			table.insert(eligible, { index = index, list = list })
		end
	end

	if #eligible == 0 then
		return
	end

	local chosen = eligible[math.random(1, #eligible)]
	drawn[chosen.index] = pick(chosen.list)
end

local function draw(data, tierIndex, rarity)
	local rules = Cards.PACK_RULES[rarity] or Cards.PACK_RULES[Tiers.RARITY_COMMON]
	local cap = Cards.RARITY_ORDER[rules.cap]
	local floor = rules.floor and Cards.RARITY_ORDER[rules.floor]

	local drawn = {}

	for index, family in Cards.FAMILIES do
		drawn[index] = pick(candidates(data, tierIndex, family, cap, nil))
	end

	if floor then
		enforceFloor(data, tierIndex, drawn, cap, floor)
	end

	local ids = {}
	for _, card in drawn do
		if card then
			table.insert(ids, card.id)
		end
	end

	return ids
end

--------------------------------------------------------------------------------
-- Etat cote client
--------------------------------------------------------------------------------

-- Le client a Cards.luau : il sait dessiner une carte a partir de son seul
-- identifiant. On ne lui envoie donc que le strict minimum -- les trois
-- identifiants, la rarete du pack, et le palier fige a la creation, qui donne
-- leur valeur aux cartes de temps.
--
-- Un seul pack est detaille : celui du dessus de la pile. Les autres attendent
-- leur tour, et le compteur suffit a dire qu'ils sont la.
function Packs.State(data)
	local pending = data.Packs or {}
	local top = pending[1]

	return {
		count = #pending,
		rarity = top and top.rarity or nil,
		tier = top and top.tier or nil,
		cards = top and top.cards or nil,
	}
end

function Packs.Announce(player, data)
	Remotes.PackUpdated:FireClient(player, Packs.State(data))
end

--------------------------------------------------------------------------------
-- Distribution
--------------------------------------------------------------------------------

-- Un pack de plus sur la pile. Appele par la montee de palier (le pack offert),
-- par le guichet (achat Robux) et par les cadeaux de survie du lot 7.
function Packs.Grant(player, rarity, reason)
	local data = PlayerData.Get(player)
	if not data then
		return false
	end

	if not data.Packs then
		data.Packs = {}
	end

	local tierIndex = Tiers.Clamp(data.Tier)

	table.insert(data.Packs, {
		rarity = rarity,
		tier = tierIndex,
		cards = draw(data, tierIndex, rarity),
	})

	Packs.Announce(player, data)

	Remotes.Notify:FireClient(player, reason or "notify_pack_granted", {
		rarity = rarity,
	}, Colors.WIN)

	-- Sauvegarde immediate : un pack obtenu puis perdu dans un crash serveur
	-- serait exactement ce que le joueur retiendrait du jeu.
	PlayerData.Save(player)

	return true
end

--------------------------------------------------------------------------------
-- Les effets
--------------------------------------------------------------------------------

-- Un effet par carte. Chacun renvoie ses parametres, et facultativement la cle
-- de notification a employer -- pour que le texte annonce EXACTEMENT ce qui a
-- ete applique, et pas une promesse ecrite ailleurs.
--
-- TROIS NOTIFICATIONS pour vingt-et-une cartes, et pas vingt-et-une :
--   notify_card_taken    le nom de la carte, rien de plus
--   notify_card_time     le nom, plus le temps effectivement pose
--   notify_card_nothing  la carte n'a rien donne (quitte ou double perdu)
--
-- Le nom de la carte voyage comme une CLE et se resout dans la langue du lecteur
-- (voir le specificateur ":text" de Locale). Ecrire une phrase par carte aurait
-- coute 21 textes en 11 langues pour dire 21 fois la meme chose -- et le detail
-- de l'effet, le joueur vient de le lire sur la carte qu'il a choisie.
--
-- Le temps passe par TimeService.GrantTime et non par data.TimeLeft : un joueur
-- peut ouvrir un pack devant l'ecran de mort, et c'est cette fonction-la qui
-- sait le remettre en jeu au lieu de le laisser regarder un chrono a zero.

local NOTIFY_DEFAULT = "notify_card_taken"
local NOTIFY_TIME = "notify_card_time"
local NOTIFY_NOTHING = "notify_card_nothing"

local effects = {}

local function grantTime(player, card, tierIndex)
	local amount = Cards.Amount(card, tierIndex)
	TimeService.GrantTime(player, amount)
	return { amount = amount }, NOTIFY_TIME
end

effects.lingot = grantTime
effects.coffre = grantTime
effects.wagon = grantTime
effects.magot = grantTime

effects.bidon = function(player, card, _, data)
	data.AutoClickFuel = (data.AutoClickFuel or 0) + card.params.fuel
	AutoClicker.Announce(player, data)
	return { amount = card.params.fuel }, NOTIFY_TIME
end

effects.jetons = function(_, card, _, data)
	data.Stakes = (data.Stakes or 0) + card.params.count
	return { count = data.Stakes }
end

effects.pluie = function(player, card)
	local remaining = Boons.Grant(player, Config.BOON_ORB_RAIN, card.params.seconds)
	return { seconds = math.floor(remaining), multiplier = card.params.multiplier }
end

effects.rouage = function(player, card, _, data)
	data.ClickPower += card.params.levels
	Remotes.ClickPowerUpdated:FireClient(player, data.ClickPower, data.ClickBase)
	return { level = data.ClickPower }
end

effects.orbes_plus = function(_, card, _, data)
	data.OrbBonus = (data.OrbBonus or 1) + card.params.bonus
	return { percent = math.floor((data.OrbBonus - 1) * 100) }
end

effects.orbes_vite = function(_, card, _, data)
	data.OrbSpeed = (data.OrbSpeed or 1) * card.params.factor
	return { percent = math.floor((1 - data.OrbSpeed) * 100) }
end

effects.bielle = function(player, card, _, data)
	data.ClickBase = card.params.to
	Remotes.ClickPowerUpdated:FireClient(player, data.ClickPower, data.ClickBase)
	return { amount = data.ClickBase }
end

effects.plan_vole = function(_, _, tierIndex, data)
	-- La carte n'est proposee que s'il reste quelque chose a voler (voir
	-- Cards.available) ; ce nil-la ne peut donc arriver que si le joueur a monte
	-- d'un palier entre le tirage et le choix.
	local power = PowerUps.NextLocked(data, tierIndex)
	if not power then
		-- Rien a voler : la carte est bien consommee, mais elle n'annonce que son
		-- nom. Mieux vaut ca qu'un silence -- le joueur a vu son pack disparaitre.
		return {}
	end

	data.PowerUpKeys[power.key] = true
	return { name = "powerup_" .. power.key .. "_name", tier = power.minTier }
end

effects.eclat = function(_, card, _, data)
	data.TierBonus = (data.TierBonus or 0) + card.params.steps
	return { steps = data.TierBonus }
end

effects.horloge = function(_, card, _, data)
	local touched = 0

	for _, power in PowerUps.List do
		local level = PowerUps.Level(data, power.key)
		if level > 0 and level < PowerUps.MAX_LEVEL then
			data.PowerUps[power.key] = level + card.params.levels
			touched += 1
		end
	end

	return { count = touched }
end

effects.coupe_file = function(player, card, _, data)
	-- Elle ne se cumule pas : deux billets ne font pas -80 %. Le second remplace
	-- le premier s'il est meilleur, sinon il ne se perd pas non plus -- la
	-- remise en cours reste.
	data.TierDiscount = math.max(data.TierDiscount or 0, card.params.percent / 100)

	-- Le panneau de la barriere et la barre du HUD affichent le prix remise :
	-- ils doivent l'apprendre tout de suite, pas a la prochaine montee.
	Remotes.TierUpdated:FireClient(player, Tiers.Clamp(data.Tier), data.TierDiscount)

	return { percent = math.floor(data.TierDiscount * 100) }
end

effects.assurance = function(_, card, _, data)
	data.Insurance = (data.Insurance or 0) + card.params.count
	return { count = data.Insurance }
end

effects.quitte = function(player, card, tierIndex)
	-- Quitte ou double : une carte sur deux ne donne rien du tout, et c'est le
	-- seul endroit d'un pack ou le joueur peut repartir les mains vides. C'est
	-- assume -- sans risque reel, ce n'est plus un joker, c'est un lingot.
	if math.random() * 100 >= card.params.percent then
		return {}, NOTIFY_NOTHING
	end

	local amount = Cards.Amount(card, tierIndex)
	TimeService.GrantTime(player, amount)
	return { amount = amount }, NOTIFY_TIME
end

effects.pieds_legers = function(player, card)
	local remaining = Boons.Grant(player, Config.BOON_LIGHT_FEET, card.params.seconds)
	Boons.ApplySpeed(player)
	return { seconds = math.floor(remaining) }
end

effects.second_souffle = function(_, _, _, data)
	data.SecondWind = true
	return {}
end

effects.pacte = function(player, card, tierIndex)
	local amount = Cards.Amount(card, tierIndex)
	TimeService.GrantTime(player, amount)

	local remaining = Boons.Grant(player, Config.BOON_PACT, card.params.seconds)
	return { amount = amount, seconds = math.floor(remaining) }, NOTIFY_TIME
end

effects.couronne = function(player, _, _, data)
	data.Crown = true

	-- Le pseudo dore se lit au-dessus de la tete et au classement : les deux
	-- passent par l'attribut publie sur l'instance Player.
	Presence.Publish(player)
	return {}
end

--------------------------------------------------------------------------------
-- Ouverture
--------------------------------------------------------------------------------

local function choose(player, index)
	if typeof(index) ~= "number" then
		return
	end

	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local pack = (data.Packs or {})[1]
	if not pack then
		return
	end

	local cardId = pack.cards[math.floor(index)]
	if not cardId then
		return
	end

	local card = Cards.Get(cardId)
	if not card then
		return
	end

	-- Le pack est retire AVANT que l'effet ne s'applique : un effet qui yield
	-- (GrantTime peut recharger un personnage) laisserait sinon la porte ouverte
	-- a un second PackChoose sur le meme pack, donc a deux cartes pour un pack.
	table.remove(data.Packs, 1)

	local params, notifyKey

	if effects[cardId] then
		params, notifyKey = effects[cardId](player, card, pack.tier, data)
	end

	Packs.Announce(player, data)

	-- Le nom de la carte part comme une CLE : c'est le client qui l'ecrit dans sa
	-- langue (specificateur ":text" de Locale).
	params = params or {}
	params.card = "card_" .. cardId .. "_name"

	Remotes.Notify:FireClient(player, notifyKey or NOTIFY_DEFAULT, params, Colors.WIN)

	-- Sauvegarde immediate, pour la meme raison qu'a l'attribution : une carte
	-- choisie puis perdue serait pire que pas de pack du tout.
	PlayerData.Save(player)
end

--------------------------------------------------------------------------------

function Packs.Start()
	Remotes.PackChoose.OnServerEvent:Connect(choose)

	-- Le client reclame son etat quand il est pret : on ne peut pas le lui
	-- pousser sur PlayerAdded, ses Remotes ne sont pas encore branches.
	Remotes.PackUpdated.OnServerEvent:Connect(function(player)
		local data = PlayerData.Get(player)
		if data then
			Packs.Announce(player, data)
		end
	end)

	-- Rien a nettoyer au depart d'un joueur : un pack vit dans la sauvegarde, pas
	-- dans une table de ce module -- c'est ce qui lui permet d'attendre la
	-- session suivante.
end

return Packs
