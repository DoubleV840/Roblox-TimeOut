local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage.Shared.Remotes) -- s'assure que les Remotes existent avant tout le reste

local Config = require(ReplicatedStorage.Shared.Config)

-- Publie les textes dans une LocalizationTable : ils deviennent visibles depuis le
-- portail de traduction du Creator Hub, qui peut completer les langues non couvertes.
local Locale = require(ReplicatedStorage.Shared.Locale)
Locale.BuildTable()

-- Le decor se construit en premier : c'est lui qui pose les tags de gameplay
-- (classement, horloge, guichets, cabines) que les systemes suivants reprennent.
if Config.BUILD_TERMINAL then
	local Terminal = require(script.Terminal)
	Terminal.Build()
end

local Movement = require(script.Movement)
Movement.Start()

-- Les paliers demarrent tot : les barrieres, les groupes de collision et le
-- point de reapparition doivent etre en place avant qu'un joueur n'arrive, et
-- tout ce qui rapporte du temps (cookie, orbes, paris) lit le multiplicateur.
local TierService = require(script.TierService)
TierService.Start()

-- Les effets a duree de vie (pluie d'orbes, pieds legers, pacte, frenesie).
-- Avant tout ce qui les lit -- le drain du chrono en fait partie.
local Boons = require(script.Boons)
Boons.Start()

-- Les mini-jeux demarrent avant le chrono : c'est TimeService qui leur demande
-- si une mise est engagee avant de declarer un joueur mort.
local MiniGames = require(script.MiniGames)
MiniGames.Start()

local TimeService = require(script.TimeService)
TimeService.Start()

-- Rend public le palier et le chrono de chaque joueur, pour que les panneaux
-- au-dessus des tetes puissent les lire chez les AUTRES (lot 2, etape 11).
local Presence = require(script.Presence)
Presence.Start()

local TimeOrb = require(script.TimeOrb)
TimeOrb.Start()

local HallOfFameBoard = require(script.HallOfFameBoard)
HallOfFameBoard.Start()

local ClickUpgrade = require(script.ClickUpgrade)
ClickUpgrade.Start()

local AutoClicker = require(script.AutoClicker)
AutoClicker.Start()

-- Les zones d'achat des power-ups du cookie (lot 5). Elles VENDENT ; ce sont
-- TimeCookie et AutoClicker qui appliquent les effets, en relisant les niveaux
-- dans PlayerData a chaque clic. L'ordre de demarrage n'a donc aucune
-- importance entre les trois -- seul compte que les zones soient equipees avant
-- qu'un joueur ne marche dessus.
local PowerUpZones = require(script.PowerUpZones)
PowerUpZones.Start()

local TimeCookie = require(script.TimeCookie)
TimeCookie.Start()

local ClickChampion = require(script.ClickChampion)
ClickChampion.Start()

-- Les packs (lot 3). Ils s'accrochent a la montee de palier par un crochet
-- plutot que par un require : TierService a demarre bien avant, et les deux se
-- demanderaient l'un l'autre au chargement.
local Packs = require(script.Packs)
Packs.Start()

local Tiers = require(ReplicatedStorage.Shared.Tiers)

TierService.OnTierUp(function(player, target)
	local rarity = Tiers.Get(target).packRarity
	if rarity then
		Packs.Grant(player, rarity, "notify_pack_tier")
	end
end)

-- Les cadeaux de survie (lot 7). En dernier : ils paient en temps, en carburant,
-- en Chrono Boost, en Frenesie et en packs -- donc tout doit deja tourner.
local Rewards = require(script.Rewards)
Rewards.Start()

local Shop = require(script.Shop)
Shop.Start()

print("TimeOut: serveur demarre")
