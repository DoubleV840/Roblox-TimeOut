-- Resolution des textes selon la langue du joueur.
--
-- Deux usages :
--
-- 1. Textes de l'interface du joueur (client) -> Locale.Text(cle, params).
--
-- 2. Panneaux du monde (SurfaceGui / BillboardGui crees par le serveur et donc
--    PARTAGES par tous les joueurs). Le serveur ne peut pas les ecrire dans dix
--    langues a la fois : il pose seulement une cle et ses parametres en attributs
--    (Locale.Mark), et chaque client reecrit le .Text dans sa langue (Locale.Bind).
--    Une propriete changee par un client ne remonte pas au serveur, donc chacun
--    voit le panneau dans sa langue sans rien casser pour les autres.

local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")

local TimeFormat = require(script.Parent.TimeFormat)
local Translations = require(script.Parent.Translations)

local Locale = {}

Locale.TAG = "LocalizedText"

local KEY_ATTRIBUTE = "LocKey"
local PARAM_PREFIX = "LocParam_"

local SOURCE = Translations.Locales[Translations.SOURCE_LOCALE]

-- "en" -> table de "en-us", pour que en-gb ou fr-ca retombent sur la bonne langue.
local byLanguage = {}
for localeId, strings in Translations.Locales do
	local language = string.match(localeId, "^(%a+)")
	if language and not byLanguage[language] then
		byLanguage[language] = strings
	end
end

local function stringsFor(localeId)
	if not localeId then
		return SOURCE
	end

	local lowered = string.lower(localeId)
	local exact = Translations.Locales[lowered]
	if exact then
		return exact
	end

	local language = string.match(lowered, "^(%a+)")
	return (language and byLanguage[language]) or SOURCE
end

-- Suffixes de duree dans la langue du texte en cours ("2h 30min" / "2時間 30分").
-- Sans ca le serveur, qui met en forme pour tout le monde a la fois, imposerait
-- les unites francaises a chaque joueur.
local function unitsFor(strings)
	return {
		hour = strings.unit_hour or SOURCE.unit_hour,
		minute = strings.unit_minute or SOURCE.unit_minute,
		second = strings.unit_second or SOURCE.unit_second,
	}
end

-- Un marqueur s'ecrit :
--   {nom}           la valeur telle quelle
--   {nom:duration}  le parametre porte un NOMBRE DE SECONDES, mis en forme ici
--   {nom:text}      le parametre porte une AUTRE CLE de traduction, resolue ici
--
-- C'est ce qui permet au serveur de n'envoyer que des nombres et des cles : la
-- langue est choisie a l'affichage, par le client qui regarde.
--
-- ":text" evite d'ecrire une phrase par carte, par power-up et par mini-jeu. Une
-- seule notification "Carte prise : {card:text}" sert les 21 cartes, chacune
-- apportant son propre nom deja traduit -- sinon il faudrait 21 phrases en 11
-- langues pour dire la meme chose 21 fois.
local function substitute(strings, text, params)
	if not params then
		return text
	end

	-- On laisse le marqueur en place si le parametre manque : un "{amount}" visible
	-- a l'ecran se remarque tout de suite, contrairement a un trou silencieux.
	return (string.gsub(text, "{(%w+):?(%a*)}", function(name, format)
		local value = params[name]
		if value == nil then
			return "{" .. name .. "}"
		end

		if format == "duration" then
			return TimeFormat.Duration(tonumber(value) or 0, unitsFor(strings))
		end

		if format == "text" then
			-- Resolution a un seul niveau, volontairement : une cle qui en citerait
			-- une autre qui en citerait une troisieme serait impossible a relire, et
			-- deux cles qui se citeraient l'une l'autre boucleraient sans fin.
			local key = tostring(value)
			return strings[key] or SOURCE[key] or key
		end

		return tostring(value)
	end))
end

--------------------------------------------------------------------------------
-- Lecture (client)
--------------------------------------------------------------------------------

local clientStrings = nil

function Locale.Text(key, params)
	if not clientStrings then
		local player = Players.LocalPlayer
		clientStrings = stringsFor(player and player.LocaleId)
	end

	local text = clientStrings[key] or SOURCE[key]
	if not text then
		warn("Locale: cle inconnue -> " .. tostring(key))
		return key
	end

	return substitute(clientStrings, text, params)
end

--------------------------------------------------------------------------------
-- Panneaux du monde
--------------------------------------------------------------------------------

-- Cote serveur (ou client) : dit quoi afficher, sans choisir la langue.
function Locale.Mark(label, key, params)
	label:SetAttribute(KEY_ATTRIBUTE, key)

	if params then
		for name, value in params do
			label:SetAttribute(PARAM_PREFIX .. name, value)
		end
	end

	CollectionService:AddTag(label, Locale.TAG)
end

-- Rend le label muet : le client cesse de le reecrire, et l'appelant peut poser
-- le texte qu'il veut. Sans ca, un label deja marque garderait sa derniere
-- traduction -- rendre le controle ne se fait pas en effacant le .Text, qui
-- serait reecrit au prochain rendu.
function Locale.Unmark(label)
	CollectionService:RemoveTag(label, Locale.TAG)

	for name in label:GetAttributes() do
		if name == KEY_ATTRIBUTE or string.match(name, "^" .. PARAM_PREFIX) then
			label:SetAttribute(name, nil)
		end
	end
end

local function render(label)
	local key = label:GetAttribute(KEY_ATTRIBUTE)
	if not key then
		return
	end

	local params = {}
	for name, value in label:GetAttributes() do
		local paramName = string.match(name, "^" .. PARAM_PREFIX .. "(.+)$")
		if paramName then
			params[paramName] = value
		end
	end

	label.Text = Locale.Text(key, params)
end

local watched = {}

local function watch(label)
	if watched[label] then
		return
	end

	-- Les parametres changent en cours de partie (nombre de parieurs, montant) :
	-- on re-affiche a chaque fois que le serveur met un attribut a jour.
	watched[label] = label.AttributeChanged:Connect(function()
		render(label)
	end)

	render(label)
end

local function unwatch(label)
	local connection = watched[label]
	if connection then
		connection:Disconnect()
		watched[label] = nil
	end
end

-- A appeler une fois cote client.
function Locale.Bind()
	for _, label in CollectionService:GetTagged(Locale.TAG) do
		watch(label)
	end

	CollectionService:GetInstanceAddedSignal(Locale.TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(Locale.TAG):Connect(unwatch)
end

--------------------------------------------------------------------------------
-- LocalizationTable : rend les textes visibles depuis le portail de traduction
-- du Creator Hub, pour que Roblox puisse completer les langues non couvertes ici.
--------------------------------------------------------------------------------

-- ":duration" et ":text" sont des conventions internes a ce module. Roblox ne
-- connait pas ces specificateurs et REFUSE l'entree ("Unknown format
-- specifier"), donc on ne publie vers le portail que "{nom}" : c'est tout ce dont un traducteur a
-- besoin, la mise en forme restant faite ici au moment de l'affichage.
local function forPortal(text)
	return (string.gsub(text, "{(%w+):%a+}", "{%1}"))
end

function Locale.BuildTable()
	local localizationTable = Instance.new("LocalizationTable")
	localizationTable.Name = "TimeOutStrings"
	localizationTable.SourceLocaleId = Translations.SOURCE_LOCALE

	local entries = {}

	for key, sourceText in SOURCE do
		local values = {}

		for localeId, strings in Translations.Locales do
			if localeId ~= Translations.SOURCE_LOCALE and strings[key] then
				values[localeId] = forPortal(strings[key])
			end
		end

		table.insert(entries, {
			Key = key,
			Source = forPortal(sourceText),
			Context = "",
			Example = "",
			Values = values,
		})
	end

	-- Le portail de traduction est un confort : le jeu, lui, lit Translations
	-- directement. Une entree refusee par Roblox ne doit pas emporter avec elle
	-- tout le script serveur -- SetEntries leve, et plus rien ne demarrait.
	local ok, err = pcall(localizationTable.SetEntries, localizationTable, entries)
	if not ok then
		warn("Locale: LocalizationTable refusee par Roblox -> " .. tostring(err))
		localizationTable:Destroy()
		return
	end

	localizationTable.Parent = LocalizationService
end

return Locale
