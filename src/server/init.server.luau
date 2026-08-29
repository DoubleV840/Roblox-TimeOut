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

local TimeService = require(script.TimeService)
TimeService.Start()

local TimeOrb = require(script.TimeOrb)
TimeOrb.Start()

local HallOfFameBoard = require(script.HallOfFameBoard)
HallOfFameBoard.Start()

local BettingGame = require(script.BettingGame)
BettingGame.Start()

local TimeCookie = require(script.TimeCookie)
TimeCookie.Start()

local ClickUpgrade = require(script.ClickUpgrade)
ClickUpgrade.Start()

local AutoClicker = require(script.AutoClicker)
AutoClicker.Start()

local ClickChampion = require(script.ClickChampion)
ClickChampion.Start()

local Shop = require(script.Shop)
Shop.Start()

print("TimeOut: serveur demarre")
