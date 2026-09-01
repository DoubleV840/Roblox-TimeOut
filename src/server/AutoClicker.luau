-- Auto-cliqueur : source de temps passive, achetee en Robux au guichet "AutoClick"
-- (voir Shop.luau). Cinq donnees persistantes :
--   data.AutoClickers    -- nombre d'achats (0 = il ne possede pas l'engin)
--   data.AutoClickPower  -- crans de Puissance pris, qui commandent le debit
--   data.AutoClickFuel   -- carburant restant, en secondes de fonctionnement
--   data.AutoClickTokens -- jetons de choix pas encore depenses
--   data.AutoClickSeenAt -- derniere seconde ou on l'a vu tourner (os.time)
--
-- Il est volontairement INDEPENDANT du reste : ni Config.CLICKER_REWARD, ni le
-- Chrono Boost (ClickPower), ni le palier de salle n'entrent dans son debit.
-- C'est la seule source de temps du jeu qui ne demande aucun geste ; la
-- multiplier par autre chose ferait que le jeu se joue tout seul.
--
-- UN ACHAT = UN PLEIN + UN JETON. Le jeton se depense dans l'une des deux
-- branches, Puissance ou Autonomie, et c'est le joueur qui tranche -- un cadeau
-- qui tombe se subit, un choix oblige a lire sa propre situation.
--
-- Le jeton attend dans la sauvegarde au lieu d'etre consomme a l'achat : le flux
-- Roblox va du prompt a ProcessReceipt, et une intention notee avant le prompt
-- serait perdue si le joueur se deconnecte entre les deux. La meme mecanique
-- servira aux packs du lot 3.
--
-- Il tourne AUSSI hors ligne : le carburant brule pendant l'absence et le temps
-- est credite au retour -- sauf devant l'ecran de mort, ou tout est en pause.
--
-- Le rattrapage hors ligne se fait a partir de AutoClickSeenAt, marque a chaque
-- tour de boucle plutot qu'au depart du joueur : un serveur qui tombe n'emet
-- aucun PlayerRemoving, et on ne veut pas offrir des heures de carburant a
-- quelqu'un que le jeu a lui-meme ejecte.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Colors = require(ReplicatedStorage.Shared.Colors)
local PlayerData = require(script.Parent.PlayerData)
local TimeService = require(script.Parent.TimeService)

local AutoClicker = {}

-- Debit, en secondes gagnees par seconde, pour un nombre de crans de Puissance.
-- Lineaire et non exponentiel : un debit qui double face a un prix fixe finit
-- par rendre tous les paquets de temps ridicules.
--
-- Le client refait ce calcul de son cote pour afficher ce que donnerait le
-- prochain cran : rien a faire transiter.
function AutoClicker.RateFor(power)
	return Config.AUTOCLICK_BASE_RATE + Config.AUTOCLICK_POWER_STEP * math.max(0, power)
end

-- Debit reel d'un joueur : nul tant qu'il n'a rien achete.
function AutoClicker.Rate(data)
	if (data.AutoClickers or 0) <= 0 then
		return 0
	end

	return AutoClicker.RateFor(data.AutoClickPower or 0)
end

-- Ce que pose un achat : le plein de base, et un jeton a depenser.
function AutoClicker.Grant(data)
	data.AutoClickers = (data.AutoClickers or 0) + 1
	data.AutoClickFuel = (data.AutoClickFuel or 0) + Config.AUTOCLICK_FUEL_BASE
	data.AutoClickTokens = (data.AutoClickTokens or 0) + 1
end

-- Tout ce que le client a besoin de savoir, en une table : il n'a pas les
-- donnees du joueur, mais il a Config, donc il refait les calculs qu'il veut a
-- partir de la.
function AutoClicker.State(data)
	return {
		owned = data.AutoClickers or 0,
		power = data.AutoClickPower or 0,
		fuel = data.AutoClickFuel or 0,
		tokens = data.AutoClickTokens or 0,
		rate = AutoClicker.Rate(data),
	}
end

-- Un seul endroit pour annoncer l'etat au client : il commande la jauge, le
-- bourdonnement, le guichet et l'icone du choix en attente.
function AutoClicker.Announce(player, data)
	Remotes.AutoClickUpdated:FireClient(player, AutoClicker.State(data))
end

-- Rattrapage de l'absence, au premier tour de boucle qui suit l'arrivee.
--
-- Le chrono d'un joueur deconnecte est GELE (la boucle de TimeService n'itere
-- que sur les connectes) : une heure hors ligne rapporte donc le debit plein, la
-- ou une heure de jeu rapporte le debit moins le drain. C'est assume, et
-- Config.AUTOCLICK_OFFLINE_RATIO est la pour le corriger sans toucher au code.
local function catchUp(player, data)
	local seenAt = data.AutoClickSeenAt
	if not seenAt then
		return
	end

	-- Une horloge qui recule (changement d'heure serveur, donnees bricolees) ne
	-- doit rien crediter du tout.
	local away = os.time() - seenAt
	if away <= 0 then
		return
	end

	if Config.AUTOCLICK_OFFLINE_MAX > 0 then
		away = math.min(away, Config.AUTOCLICK_OFFLINE_MAX)
	end

	local burned = math.min(away, data.AutoClickFuel or 0)
	if burned <= 0 then
		return
	end

	local gained = AutoClicker.Rate(data) * burned * Config.AUTOCLICK_OFFLINE_RATIO

	data.AutoClickFuel -= burned
	data.TimeLeft += gained
	PlayerData.NoteTime(data)

	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	Remotes.Notify:FireClient(player, "notify_autoclick_offline", {
		away = burned,
		amount = gained,
	}, Colors.WIN)
end

-- Depense d'un jeton. Le client demande, le serveur decide : c'est lui qui tient
-- le compte des jetons, et une branche inconnue ne consomme rien.
local function spendToken(player, choice)
	local data = PlayerData.Get(player)
	if not data or (data.AutoClickTokens or 0) <= 0 then
		return
	end

	if choice == Config.AUTOCLICK_CHOICE_POWER then
		data.AutoClickPower = (data.AutoClickPower or 0) + 1
		data.AutoClickTokens -= 1

		Remotes.Notify:FireClient(player, "notify_autoclick_power", {
			rate = Config.AUTOCLICK_POWER_STEP,
			total = AutoClicker.Rate(data),
		}, Colors.WIN)
	elseif choice == Config.AUTOCLICK_CHOICE_FUEL then
		data.AutoClickFuel = (data.AutoClickFuel or 0) + Config.AUTOCLICK_FUEL_STEP
		data.AutoClickTokens -= 1

		Remotes.Notify:FireClient(player, "notify_autoclick_fuel", {
			amount = Config.AUTOCLICK_FUEL_STEP,
		}, Colors.WIN)
	else
		return
	end

	AutoClicker.Announce(player, data)

	-- Sauvegarde immediate : un choix fait puis perdu dans un crash serveur
	-- rendrait le jeton, mais le joueur croirait avoir deja decide.
	PlayerData.Save(player)
end

function AutoClicker.Start()
	Remotes.AutoClickChoose.OnServerEvent:Connect(function(player, choice)
		if typeof(choice) ~= "string" then
			return
		end

		spendToken(player, choice)
	end)

	-- Joueurs a qui on a deja annonce leur etat -- et pour qui l'absence a deja
	-- ete rattrapee. Le client a besoin de cet etat des son arrivee pour regler
	-- la jauge, le bourdonnement et l'icone du choix en attente, sans quoi il
	-- resterait muet jusqu'au premier passage au guichet. L'annonce ne peut pas
	-- partir de PlayerAdded : a cet instant le LocalScript du joueur n'a pas
	-- encore branche ses Remotes, et le message se perdrait. On la fait donc au
	-- premier tour de boucle, une seconde plus tard -- le client est alors debout
	-- depuis longtemps, et ses donnees sont chargees.
	local announced = {}

	-- Prochain recalage de la jauge, par joueur (os.clock).
	local nextSync = {}

	Players.PlayerRemoving:Connect(function(player)
		announced[player] = nil
		nextSync[player] = nil
	end)

	task.spawn(function()
		while true do
			-- On credite le delai reellement ecoule, comme la boucle principale :
			-- un tick en retard ne doit ni voler ni offrir de temps.
			local elapsed = task.wait(Config.AUTOCLICK_INTERVAL)
			local now = os.clock()

			for _, player in Players:GetPlayers() do
				local data = PlayerData.Get(player)

				if data and (data.AutoClickers or 0) > 0 then
					if not announced[player] then
						announced[player] = true
						catchUp(player, data)
						AutoClicker.Announce(player, data)
						nextSync[player] = now + Config.AUTOCLICK_SYNC_INTERVAL
					end

					-- La marque de presence avance a chaque tour, y compris quand
					-- le reservoir est vide ou le joueur mort : ce qu'elle date,
					-- c'est le dernier instant ou le jeu avait la main sur ce
					-- joueur. Sans ca, un mort qui se deconnecte reviendrait avec
					-- son ecran de mort compte comme du hors-ligne.
					data.AutoClickSeenAt = os.time()

					-- Un joueur devant l'ecran de mort ne gagne rien et ne brule
					-- rien : son auto-cliqueur est en pause, pas en train de se
					-- vider pendant qu'il lit "TU ES MORT".
					local fuel = data.AutoClickFuel or 0

					if fuel > 0 and not TimeService.IsWaitingForRestart(player) then
						-- Si le reservoir se vide en cours de tick, on ne credite
						-- que ce qui a reellement brule.
						local burned = math.min(elapsed, fuel)

						data.AutoClickFuel = fuel - burned
						data.TimeLeft += AutoClicker.Rate(data) * burned
						PlayerData.NoteTime(data)
						Remotes.TimeUpdated:FireClient(player, data.TimeLeft)

						if data.AutoClickFuel <= 0 then
							data.AutoClickFuel = 0
							AutoClicker.Announce(player, data)
							nextSync[player] = nil
							Remotes.Notify:FireClient(player, "notify_autoclick_dry", nil, Colors.LOSE)
						elseif now >= (nextSync[player] or 0) then
							-- La jauge du client descend toute seule ; ce recalage
							-- l'empeche seulement de deriver.
							nextSync[player] = now + Config.AUTOCLICK_SYNC_INTERVAL
							AutoClicker.Announce(player, data)
						end
					end
				end
			end
		end
	end)
end

return AutoClicker
