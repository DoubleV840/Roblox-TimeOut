-- Le pool des cartes de pack : 21 cartes, 3 familles, 4 raretes.
--
-- Un pack propose TROIS cartes -- une par famille -- et le joueur en garde une.
-- L'interet n'est pas la recompense, c'est le choix : un cadeau qui tombe se
-- subit, trois cartes obligent le joueur a lire sa propre situation.
--
-- TROIS REGLES DE FOND, et elles sont dans ce fichier plutot que dans le code
-- qui tire, parce que ce sont des proprietes des cartes :
--
-- 1. LES TROIS CARTES VIENNENT DE TROIS FAMILLES DIFFERENTES. Un choix entre
--    trois choses semblables n'est pas un choix. "Immediat" sauve la peau,
--    "Moteur" construit, "Joker" tord une regle -- le joueur choisit donc en
--    fait entre survivre, investir et parier.
--
-- 2. AUCUNE CARTE MORTE. "available" dit si la carte a un sens pour CE joueur a
--    CET instant ; une carte qui ne peut rien lui apporter n'est jamais
--    proposee. Une carte inutile, c'est un pack a deux choix.
--
-- 3. TOUTE VALEUR DE TEMPS EST UN POURCENTAGE DU PRIX D'ENTREE DU PALIER, jamais
--    un nombre de secondes fixe. Un "+2 min" est decisif au palier 2 et risible
--    au palier 7 : une carte a valeur fixe devient un dechet en fin de partie et
--    pourrit le tirage jusqu'a la fin.
--
-- Ce fichier ne fait qu'ECRIRE les cartes ; c'est src/server/Packs.luau qui
-- tire, applique et sauvegarde. Le client le lit aussi, pour dessiner les cartes
-- dans la langue du joueur sans que le serveur ait a lui envoyer du texte.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local PowerUps = require(ReplicatedStorage.Shared.PowerUps)

local Cards = {}

Cards.FAMILY_IMMEDIATE = "Immediate"
Cards.FAMILY_ENGINE = "Engine"
Cards.FAMILY_JOKER = "Joker"

-- L'ordre est celui de l'affichage : on lit toujours les trois cartes dans le
-- meme sens, ce qui rend deux packs comparables d'un coup d'oeil.
Cards.FAMILIES = { Cards.FAMILY_IMMEDIATE, Cards.FAMILY_ENGINE, Cards.FAMILY_JOKER }

-- L'echelle des raretes, du plus commun au plus rare. Elle sert a deux choses :
-- plafonner ce qu'un pack peut tirer, et garantir un plancher (un pack
-- Legendaire promet au moins une Epique).
Cards.RARITY_ORDER = {
	[Tiers.RARITY_COMMON] = 1,
	[Tiers.RARITY_RARE] = 2,
	[Tiers.RARITY_EPIC] = 3,
	[Tiers.RARITY_LEGENDARY] = 4,
}

Cards.RARITY_COLOR = {
	[Tiers.RARITY_COMMON] = Color3.fromRGB(190, 195, 205),
	[Tiers.RARITY_RARE] = Color3.fromRGB(80, 175, 255),
	[Tiers.RARITY_EPIC] = Color3.fromRGB(190, 110, 255),
	[Tiers.RARITY_LEGENDARY] = Color3.fromRGB(255, 200, 60),
}

Cards.FAMILY_COLOR = {
	[Cards.FAMILY_IMMEDIATE] = Color3.fromRGB(255, 120, 90),
	[Cards.FAMILY_ENGINE] = Color3.fromRGB(120, 220, 160),
	[Cards.FAMILY_JOKER] = Color3.fromRGB(255, 170, 60),
}

-- Ce que peut tirer un pack, selon sa rarete : un plafond, et un plancher
-- garanti sur au moins une des trois cartes. C'est ce qui fait qu'un pack
-- Legendaire au palier 8 se voit tout de suite mieux qu'un Commun au palier 2.
Cards.PACK_RULES = {
	[Tiers.RARITY_COMMON] = { cap = Tiers.RARITY_COMMON, floor = nil },
	[Tiers.RARITY_RARE] = { cap = Tiers.RARITY_RARE, floor = nil },
	[Tiers.RARITY_EPIC] = { cap = Tiers.RARITY_EPIC, floor = Tiers.RARITY_RARE },
	[Tiers.RARITY_LEGENDARY] = { cap = Tiers.RARITY_LEGENDARY, floor = Tiers.RARITY_EPIC },
}

--------------------------------------------------------------------------------
-- La valeur de reference
--------------------------------------------------------------------------------

-- Le prix d'entree du palier COURANT : c'est l'unite dans laquelle sont
-- exprimees toutes les cartes qui donnent du temps.
--
-- Le Quai est gratuit, donc sa reference vaut zero et toutes les cartes de temps
-- y seraient vides. On prend alors le prix du palier 2 : un joueur qui ouvre un
-- pack achete en boutique avant d'etre monte doit recevoir quelque chose.
function Cards.Reference(tierIndex)
	return math.max(Tiers.Cost(tierIndex), Tiers.Cost(Tiers.FIRST + 1))
end

--------------------------------------------------------------------------------
-- Les 21 cartes
--------------------------------------------------------------------------------
--
-- Champs d'une carte :
--   id        cle unique, aussi utilisee pour les traductions (card_<id>_name,
--             card_<id>_info)
--   family    Immediate / Engine / Joker
--   rarity    une des quatre raretes de Tiers
--   share     part du prix d'entree du palier, pour les cartes qui donnent du temps
--   params    ce que la carte annonce au joueur ET ce que le serveur applique --
--             une seule source, pour qu'un texte ne puisse jamais mentir sur
--             l'effet
--   available fonction(data, tierIndex) -> bool ; absente = toujours proposable

local function alwaysTrue()
	return true
end

Cards.List = {
	----------------------------------------------------------------------------
	-- Immediat -- du temps, tout de suite. Le joueur qui la prend est en danger.
	----------------------------------------------------------------------------

	{
		id = "lingot",
		family = Cards.FAMILY_IMMEDIATE,
		rarity = Tiers.RARITY_COMMON,
		share = 0.25,
	},
	{
		id = "bidon",
		family = Cards.FAMILY_IMMEDIATE,
		rarity = Tiers.RARITY_COMMON,
		params = { fuel = Config.AUTOCLICK_FUEL_BASE },
		-- Du carburant pour une machine qu'on ne possede pas ne vaut rien. Les
		-- packs donnent du carburant et JAMAIS un cran de debit : le niveau reste
		-- la seule chose qui ne s'obtienne qu'en Robux.
		available = function(data)
			return (data.AutoClickers or 0) > 0
		end,
	},
	{
		id = "jetons",
		family = Cards.FAMILY_IMMEDIATE,
		rarity = Tiers.RARITY_COMMON,
		params = { count = 3 },
	},
	{
		id = "coffre",
		family = Cards.FAMILY_IMMEDIATE,
		rarity = Tiers.RARITY_RARE,
		share = 0.5,
	},
	{
		id = "pluie",
		family = Cards.FAMILY_IMMEDIATE,
		rarity = Tiers.RARITY_RARE,
		params = { multiplier = Config.BOON_ORB_RAIN_MULTIPLIER, seconds = 60 },
	},
	{
		id = "wagon",
		family = Cards.FAMILY_IMMEDIATE,
		rarity = Tiers.RARITY_EPIC,
		share = 1,
	},
	{
		id = "magot",
		family = Cards.FAMILY_IMMEDIATE,
		rarity = Tiers.RARITY_LEGENDARY,
		share = 2,
	},

	----------------------------------------------------------------------------
	-- Moteur -- une amelioration permanente. Le joueur qui la prend construit.
	----------------------------------------------------------------------------

	{
		id = "rouage",
		family = Cards.FAMILY_ENGINE,
		rarity = Tiers.RARITY_COMMON,
		params = { levels = 2 },
	},
	{
		id = "orbes_plus",
		family = Cards.FAMILY_ENGINE,
		rarity = Tiers.RARITY_COMMON,
		-- "percent" ne sert qu'au texte, "bonus" a l'effet. Les deux sortent de la
		-- meme table pour qu'une retouche de l'un ne puisse pas laisser l'autre
		-- mentir au joueur.
		params = { bonus = 0.5, percent = 50 },
	},
	{
		id = "orbes_vite",
		family = Cards.FAMILY_ENGINE,
		rarity = Tiers.RARITY_RARE,
		params = { factor = 0.6, percent = 40 },
		-- Une orbe qui revient deja instantanement ne peut pas revenir plus vite.
		available = function(data)
			return (data.OrbSpeed or 1) > 0.15
		end,
	},
	{
		id = "bielle",
		family = Cards.FAMILY_ENGINE,
		rarity = Tiers.RARITY_RARE,
		params = { from = Config.CLICKER_REWARD, to = Config.CLICKER_REWARD * 2 },
		-- Elle ne se prend qu'une fois : le gain de base passe de 1 s a 2 s, pas
		-- de 2 a 4. Une deuxieme serait une carte morte.
		available = function(data)
			return (data.ClickBase or Config.CLICKER_REWARD) < Config.CLICKER_REWARD * 2
		end,
	},
	{
		id = "plan_vole",
		family = Cards.FAMILY_ENGINE,
		rarity = Tiers.RARITY_RARE,
		-- Debloque en avance un power-up du palier suivant : elle n'a de sens que
		-- s'il en reste un a voler au-dessus.
		available = function(data, tierIndex)
			return PowerUps.NextLocked(data, tierIndex) ~= nil
		end,
	},
	{
		id = "eclat",
		family = Cards.FAMILY_ENGINE,
		rarity = Tiers.RARITY_EPIC,
		params = { steps = 1 },
	},
	{
		id = "horloge",
		family = Cards.FAMILY_ENGINE,
		rarity = Tiers.RARITY_LEGENDARY,
		params = { levels = 1 },
		-- +1 niveau sur TOUS les power-ups possedes : sans power-up, elle ne
		-- donne rien du tout.
		available = function(data)
			return PowerUps.OwnedCount(data) > 0
		end,
	},

	----------------------------------------------------------------------------
	-- Joker -- une regle tordue. Le joueur qui la prend s'amuse ou tente un coup.
	----------------------------------------------------------------------------

	{
		id = "coupe_file",
		family = Cards.FAMILY_JOKER,
		rarity = Tiers.RARITY_COMMON,
		params = { percent = 40 },
		-- Rien a couper au Terminus : il n'y a plus d'entree a payer.
		available = function(data, tierIndex)
			return tierIndex < Tiers.LAST
		end,
	},
	{
		id = "assurance",
		family = Cards.FAMILY_JOKER,
		rarity = Tiers.RARITY_COMMON,
		params = { count = 3 },
	},
	{
		id = "quitte",
		family = Cards.FAMILY_JOKER,
		rarity = Tiers.RARITY_RARE,
		share = 1.5,
		params = { percent = 50 },
	},
	{
		id = "pieds_legers",
		family = Cards.FAMILY_JOKER,
		rarity = Tiers.RARITY_RARE,
		params = {
			speed = math.floor((Config.BOON_LIGHT_FEET_SPEED - 1) * 100),
			reach = Config.BOON_LIGHT_FEET_REACH,
			seconds = 15 * 60,
		},
	},
	{
		id = "second_souffle",
		family = Cards.FAMILY_JOKER,
		rarity = Tiers.RARITY_EPIC,
		share = 0.5,
		-- Au Quai, "ne pas etre renvoye au Quai" ne veut rien dire.
		available = function(data, tierIndex)
			return tierIndex > Tiers.FIRST and not data.SecondWind
		end,
	},
	{
		id = "pacte",
		family = Cards.FAMILY_JOKER,
		rarity = Tiers.RARITY_EPIC,
		share = 3,
		params = { drain = Config.BOON_PACT_DRAIN, seconds = 10 * 60 },
	},
	{
		id = "couronne",
		family = Cards.FAMILY_JOKER,
		rarity = Tiers.RARITY_LEGENDARY,
		available = function(data)
			return not data.Crown
		end,
	},
}

local byId = {}
for _, card in Cards.List do
	byId[card.id] = card
end

function Cards.Get(id)
	return byId[id]
end

-- Le temps que rapporte une carte, au palier ou elle est ouverte. Zero pour les
-- cartes qui ne donnent pas de temps -- l'appelant n'a pas a savoir lesquelles.
function Cards.Amount(card, tierIndex)
	if not card or not card.share then
		return 0
	end

	return math.floor(Cards.Reference(tierIndex) * card.share)
end

-- Tout ce qu'un texte de carte peut avoir a citer, en une table. Le serveur ne
-- transmet donc que l'identifiant de la carte : le client refait la phrase dans
-- sa langue, avec les memes chiffres que ceux appliques.
function Cards.Params(card, tierIndex)
	local params = { amount = Cards.Amount(card, tierIndex) }

	if card.params then
		for name, value in card.params do
			params[name] = value
		end
	end

	return params
end

function Cards.IsAvailable(card, data, tierIndex)
	return (card.available or alwaysTrue)(data, tierIndex)
end

return Cards
