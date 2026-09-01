local TimeFormat = {}

-- Unites par defaut, utilisees quand l'appelant n'en fournit pas (les modules qui
-- affichent du texte au joueur passent celles de sa langue -- voir Locale).
local DEFAULT_UNITS = { hour = "h", minute = "min", second = "s" }

-- Format "0000:05:00.000" (heures sur 4 chiffres, pour montrer que ca peut monter
-- tres haut ; millisecondes pour que le chrono ait l'air de vraiment s'ecouler).
function TimeFormat.Clock(seconds)
	seconds = math.max(0, seconds)

	local whole = math.floor(seconds)
	local millis = math.floor((seconds - whole) * 1000)
	local hours = math.floor(whole / 3600)
	local minutes = math.floor((whole % 3600) / 60)
	local secs = whole % 60

	return string.format("%04d:%02d:%02d.%03d", hours, minutes, secs, millis)
end

-- Format court "1:23:45" / "23:45" : le chrono d'un AUTRE joueur, lu au-dessus
-- de sa tete. Les millisecondes de TimeFormat.Clock y seraient illisibles, et les
-- suffixes de TimeFormat.Duration changent de largeur a chaque seconde -- le
-- panneau danserait.
function TimeFormat.Short(seconds)
	seconds = math.max(0, math.floor(seconds))

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end

	return string.format("%02d:%02d", minutes, secs)
end

-- Format compact "2h 30min 5s" (jamais en jours) utilise pour les mises et les grandes durees.
--
-- "units" (facultatif) porte les suffixes dans la langue du joueur : { hour, minute,
-- second }. Le tri des textes vers Translations s'arrete la -- les nombres, eux,
-- s'ecrivent pareil partout dans les langues qu'on couvre.
function TimeFormat.Duration(seconds, units)
	seconds = math.max(0, math.floor(seconds))
	units = units or DEFAULT_UNITS

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	local parts = {}
	if hours > 0 then
		table.insert(parts, hours .. units.hour)
	end
	if minutes > 0 then
		table.insert(parts, minutes .. units.minute)
	end
	if secs > 0 or #parts == 0 then
		table.insert(parts, secs .. units.second)
	end

	return table.concat(parts, " ")
end

return TimeFormat
