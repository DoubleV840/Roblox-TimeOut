-- Le cadre commun a tous les mini-jeux (etape 24).
--
-- C'EST LE VRAI TRAVAIL DU LOT 6. Sept jeux ecrits chacun dans leur coin, ce
-- sont sept facons de prendre une mise, sept remboursements a ne pas oublier,
-- sept HUD et sept verrous. Ce module fait tout ca UNE fois :
--
--   entrer dans la zone -> confirmer sa mise -> voir le decompte -> voir qui
--   participe -> etre rembourse si personne ne vient -> voir le resultat,
--   et trouver la zone verrouillee si le palier manque.
--
-- Une regle de jeu (src/server/MiniGameRules.luau) n'a plus alors qu'a designer
-- le gagnant. Ecrire le deuxieme mini-jeu sans avoir unifie le premier, c'etait
-- s'engager a en maintenir huit.
--
-- LE PARI D'ORIGINE EST LE PREMIER CLIENT DE CE CADRE. Les zones deja posees
-- dans Studio (tag Config.BET_TAG) sont reprises telles quelles, avec leur
-- attribut BetAmount et leur deverrouillage au plus haut temps tenu : elles
-- continuent de fonctionner exactement comme avant, sans etre retouchees.
--
-- CE QU'UNE REGLE DOIT FOURNIR (toutes les entrees sont facultatives) :
--   Resolve(state) -> parts     designe le resultat d'un tirage
--   Run(state, finish)          phase active ; appelle finish(parts) a la fin
--   Action(state, player, ...)  un geste du joueur pendant la partie
--
-- "parts" est une table joueur -> PART DE LA CAGNOTTE (0.5 = la moitie). Le
-- cadre s'occupe du reste : multiplicateur de palier, remboursement des perdants
-- assures, dime du Train de minuit, notifications, sauvegarde.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Colors = require(ReplicatedStorage.Shared.Colors)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local ZoneAura = require(ReplicatedStorage.Shared.ZoneAura)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local MiniGameList = require(ReplicatedStorage.Shared.MiniGameList)
local PlayerData = require(script.Parent.PlayerData)
local TierService = require(script.Parent.TierService)

local MiniGames = {}

-- Les regles sont branchees apres coup (MiniGames.Register) : sans ca, ce module
-- et MiniGameRules se demanderaient l'un l'autre au chargement.
local rules = {}

-- Echelle de l'aura : du plus petit palier (10 s) au plus gros (1000 h), en log
-- parce que l'ecart est enorme (facteur 360 000).
local AURA_MIN_AMOUNT = 10
local AURA_MAX_AMOUNT = 3600000
local AURA_COLOR_LOW = Color3.fromRGB(80, 200, 120) -- vert : petite mise
local AURA_COLOR_HIGH = Color3.fromRGB(220, 40, 40) -- rouge : grosse mise

local zoneStates = {}

-- La cagnotte du Train de minuit, alimentee par une dime prelevee sur chaque
-- cagnotte de mini-jeu : c'est ca, "une cagnotte alimentee par tous les
-- paliers". Elle vit en memoire, le temps d'une session de serveur.
local trainPot = Config.TRAIN_BASE_POT

function MiniGames.Register(key, rule)
	rules[key] = rule
end

function MiniGames.TrainPot()
	return trainPot
end

--------------------------------------------------------------------------------
-- Lecture d'une zone
--------------------------------------------------------------------------------

local function gameOf(zone)
	local key = zone:GetAttribute(Config.MINIGAME_GAME_ATTRIBUTE)
	return (key and MiniGameList.Get(key)) or MiniGameList.DEFAULT
end

local function amountOf(zone, game)
	-- Config.BET_AMOUNT reste la valeur de repli des zones de pari d'origine :
	-- une BetZone posee avant le lot 6 n'a pas d'autre reglage.
	return zone:GetAttribute(Config.MINIGAME_BET_ATTRIBUTE) or game.bet or Config.BET_AMOUNT
end

local function minTierOf(zone, game)
	return Tiers.Clamp(zone:GetAttribute(Config.MINIGAME_TIER_ATTRIBUTE) or game.minTier)
end

-- Le deverrouillage du pari d'origine : un temps qu'il faut avoir POSSEDE au
-- moins une fois. Il ne s'applique qu'aux zones qui le portent -- les nouvelles
-- se verrouillent par palier, ce qui est la regle du lot 6.
local function unlockAtOf(zone, game, amount)
	if game == MiniGameList.DEFAULT then
		return zone:GetAttribute(Config.BET_UNLOCK_ATTRIBUTE) or amount
	end

	return zone:GetAttribute(Config.BET_UNLOCK_ATTRIBUTE)
end

-- Le decor propre a certains jeux (les dalles des chaises musicales, la roue, la
-- plateforme du wagon, le coffre du braquage). On le cherche a trois endroits,
-- du plus explicite au plus commode -- et a defaut on se rabat sur la zone
-- elle-meme, pour qu'un jeu reste JOUABLE avant que la map n'existe.
local function decorOf(zone, game)
	local named = zone:GetAttribute(Config.MINIGAME_DECOR_ATTRIBUTE)

	if named then
		local found = zone:FindFirstChild(named, true)
			or (zone.Parent and zone.Parent:FindFirstChild(named, true))
		if found then
			return found
		end
	end

	return zone:FindFirstChild(game.key)
		or (zone.Parent and zone.Parent:FindFirstChild(game.key))
		or nil
end

--------------------------------------------------------------------------------
-- Verrous
--------------------------------------------------------------------------------

-- Une zone est fermee tant que le palier n'est pas atteint. Le verrou du pari
-- d'origine (avoir possede la mise au moins une fois) reste en plus, la ou il
-- s'applique : les deux se cumulent, et le plus exigeant l'emporte.
--
-- Le deverrouillage est DEFINITIF dans les deux cas -- il regarde le plus haut
-- temps jamais possede et le palier atteint, jamais le temps courant. Tomber a
-- zero ne referme jamais une zone.
local function lockReason(data, state)
	if not data then
		return { tier = state.minTier }
	end

	if Tiers.Clamp(data.Tier) < state.minTier then
		return { tier = state.minTier }
	end

	if state.unlockAt and math.max(data.MaxTime, data.TimeLeft) < state.unlockAt then
		return { amount = state.unlockAt }
	end

	return nil
end

--------------------------------------------------------------------------------
-- Le panneau de la zone
--------------------------------------------------------------------------------

local function amountFactor(amount)
	local clamped = math.clamp(math.max(amount, 1), AURA_MIN_AMOUNT, AURA_MAX_AMOUNT)
	local logMin, logMax = math.log(AURA_MIN_AMOUNT), math.log(AURA_MAX_AMOUNT)
	return (math.log(clamped) - logMin) / (logMax - logMin)
end

-- Le panneau de la zone est PARTAGE par tous les joueurs : il ne porte donc que
-- ce qui est vrai pour tout le monde -- le nom du jeu, la mise, et combien de
-- monde attend. Le cadenas, lui, est propre a chacun et se dessine cote client.
local function createSign(zone, game, amount)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MiniGameSign"
	billboard.Size = UDim2.new(9, 0, 4.4, 0) -- en studs : taille fixe dans le monde
	billboard.StudsOffset = Vector3.new(0, 3.8, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.34, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.FontFace = Fonts.Main
	nameLabel.TextScaled = true
	nameLabel.Parent = billboard

	Locale.Mark(nameLabel, "minigame_" .. game.key .. "_name")
	TextFx.Mark(nameLabel, 0.5, game.color)

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Size = UDim2.new(1, 0, 0.36, 0)
	amountLabel.Position = UDim2.new(0, 0, 0.34, 0)
	amountLabel.BackgroundTransparency = 1
	amountLabel.FontFace = Fonts.Main
	amountLabel.TextScaled = true
	amountLabel.Parent = billboard

	-- Le panneau reprend la couleur et l'agitation de l'aura : une zone a 20 s
	-- reste sage, une zone a 30 h hurle de loin.
	local factor = amountFactor(amount)

	if amount > 0 then
		Locale.Mark(amountLabel, "bet_sign", { amount = amount })
	else
		-- Le Train de minuit ne se mise pas : on y monte.
		Locale.Mark(amountLabel, "minigame_free")
	end

	TextFx.Mark(amountLabel, factor, AURA_COLOR_LOW:Lerp(AURA_COLOR_HIGH, factor))

	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(1, 0, 0.3, 0)
	countLabel.Position = UDim2.new(0, 0, 0.7, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.FontFace = Fonts.Main
	countLabel.TextScaled = true
	countLabel.Text = ""
	countLabel.Parent = billboard

	return countLabel
end

local WAITING_IDLE_COLOR = Color3.fromRGB(170, 170, 170)
local WAITING_SHORT_COLOR = Color3.fromRGB(255, 170, 60)
local WAITING_READY_COLOR = Color3.fromRGB(90, 220, 120)

local function refreshSign(state)
	local label = state.countLabel
	if not label then
		return
	end

	local count = #state.participants

	if state.phase == "running" then
		Locale.Mark(label, "minigame_running", { count = count })
		TextFx.Mark(label, 0.8, state.game.color)
		return
	end

	if count == 0 then
		Locale.Mark(label, "bet_waiting_none")
		TextFx.Mark(label, 0, WAITING_IDLE_COLOR)
		return
	end

	if count < state.minPlayers then
		-- On affiche l'objectif : sans le minimum, tout le monde sera rembourse.
		Locale.Mark(label, "bet_waiting_short", { count = count, min = state.minPlayers })
		TextFx.Mark(label, 0.45, WAITING_SHORT_COLOR)
	else
		Locale.Mark(label, "bet_waiting_ready", { count = count })
		TextFx.Mark(label, math.min(1, count / (state.minPlayers * 2)), WAITING_READY_COLOR)
	end
end

--------------------------------------------------------------------------------
-- HUD des parties en cours
--------------------------------------------------------------------------------

-- Le panneau de la zone ne se lit que de pres ; le HUD, lui, suit le joueur
-- partout. Il lui rappelle qu'une partie court -- surtout quand sa mise est deja
-- partie et qu'il est reparti farmer ailleurs.
--
-- On envoie une echeance ABSOLUE (horloge serveur, la meme des deux cotes) et
-- non un nombre de secondes restantes : le client fait descendre le compte a
-- rebours tout seul, sans qu'on ait a lui parler a chaque seconde.
local function sendRounds(player)
	local rounds = {}

	for _, state in zoneStates do
		if state.phase ~= "idle" then
			table.insert(rounds, {
				game = state.game.key,
				amount = state.amount,
				count = #state.participants,
				endsAt = state.deadline,
				running = state.phase == "running",
				joined = state.inRound[player] == true,
			})
		end
	end

	-- L'ordre d'un parcours de table n'est pas stable : sans tri, deux parties
	-- ouvertes s'echangeraient de place a chaque envoi. La plus proche de sa fin
	-- passe en tete.
	table.sort(rounds, function(a, b)
		local ea, eb = a.endsAt or math.huge, b.endsAt or math.huge
		if ea == eb then
			return a.amount < b.amount
		end

		return ea < eb
	end)

	Remotes.MiniGameRoundsUpdated:FireClient(player, rounds)
end

-- Le drapeau "joined" est propre a chaque joueur, d'ou un envoi par client
-- plutot qu'un FireAllClients -- mais ca ne part qu'aux changements de partie
-- (ouverture, inscription, resultat), jamais en boucle.
local function broadcastRounds()
	for _, player in Players:GetPlayers() do
		sendRounds(player)
	end
end

--------------------------------------------------------------------------------
-- La scene : ce que voient les participants pendant la phase active
--------------------------------------------------------------------------------

-- Une regle raconte sa partie en appelant MiniGames.Stage. Elle ne connait ni
-- les Remotes ni les langues : elle pose une cle et ses parametres, le client
-- l'ecrit dans la sienne. C'est ce qui permet aux sept jeux de partager le meme
-- bandeau de scene sans que chacun ait a le dessiner.
function MiniGames.Stage(state, info)
	-- La cle du jeu est ajoutee ici plutot que par chaque regle : c'est elle qui
	-- dit au client s'il doit capter les clics (duel, braquage) ou se contenter
	-- d'afficher. Une regle n'a pas a s'en souvenir.
	info.game = state.game.key

	for _, player in state.participants do
		if player.Parent then
			Remotes.MiniGameStage:FireClient(player, state.zone, info)
		end
	end
end

-- Ferme la scene chez tout le monde : la partie est finie, le bandeau doit
-- disparaitre meme chez ceux qui viennent d'etre elimines.
local function clearStage(state, audience)
	for _, player in audience or state.participants do
		if player.Parent then
			Remotes.MiniGameStage:FireClient(player, state.zone, nil)
		end
	end
end

--------------------------------------------------------------------------------
-- Mises
--------------------------------------------------------------------------------

-- Prendre la mise. Elle peut etre payee par un JETON offert (carte "Poignee de
-- jetons") : le joueur joue alors gratuitement, mais sa mise entre quand meme
-- dans la cagnotte -- sinon un jeton vaudrait moins qu'une mise, et personne ne
-- les garderait pour les grosses zones.
local function takeStake(player, data, amount)
	if amount <= 0 then
		return true, false
	end

	if (data.Stakes or 0) > 0 then
		data.Stakes -= 1
		return true, true
	end

	if data.TimeLeft < amount then
		return false, false
	end

	data.TimeLeft -= amount
	return true, false
end

-- Rendre une mise perdue. "Assurance" couvre les trois prochaines : c'est une
-- carte de joker, elle amortit la malchance sans supprimer le risque.
local function refundLoser(player, data, state)
	if state.amount <= 0 or (data.Insurance or 0) <= 0 then
		return false
	end

	data.Insurance -= 1
	data.TimeLeft += state.amount
	PlayerData.NoteTime(data)

	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	Remotes.Notify:FireClient(player, "notify_insurance", {
		amount = state.amount,
		count = data.Insurance,
	}, Colors.INFO)

	return true
end

--------------------------------------------------------------------------------
-- Fin de partie
--------------------------------------------------------------------------------

local function resetRound(state)
	state.participants = {}
	state.inRound = {}
	state.freeStakes = {}
	state.scratch = {}
	state.pot = nil
	state.phase = "idle"
	state.deadline = nil
	refreshSign(state)
	broadcastRounds()
end

-- Le paiement, une fois pour les huit jeux.
--
-- "parts" dit qui touche QUELLE PART de la cagnotte. Le cadre applique ensuite
-- le multiplicateur de palier du gagnant : un gain de mini-jeu est un gain
-- ACTIF, au meme titre qu'un clic ou une orbe.
--
-- Consequence a garder en tete a l'equilibrage : la cagnotte ressort alors plus
-- grosse qu'elle n'est entree. C'est ce que demande le plan 2 -- c'est ce qui
-- rend les mini-jeux des hauts paliers interessants -- mais c'est le seul
-- endroit du jeu ou du temps se cree a partir du temps des autres. La dime du
-- Train en reprend une petite part, ce qui limite un peu la fuite.
local function payout(state, parts)
	local players = state.participants

	-- La cagnotte est faite des mises, SAUF quand une regle en pose une autre :
	-- le Train de minuit ne prend pas de mise du tout, sa cagnotte est celle que
	-- la dime a remplie depuis une heure. Sans cette porte, le seul jeu gratuit
	-- du lot paierait toujours zero.
	local pot = state.pot or (#players * state.amount)

	-- La dime du Train de minuit : une part de chaque cagnotte du serveur, pour
	-- que l'evenement du palier 8 se paie de ce qui s'est joue en dessous.
	local cut = 0
	if not state.game.scheduled then
		cut = math.floor(pot * Config.TRAIN_CUT)
		trainPot += cut
	end

	local distributable = pot - cut
	local anyWinner = false

	for _, player in players do
		local data = PlayerData.Get(player)
		if data then
			local share = parts and parts[player] or 0

			if share > 0 then
				anyWinner = true

				local gain = math.round(distributable * share * TierService.Multiplier(player))

				data.TimeLeft += gain
				PlayerData.NoteTime(data)
				Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
				Remotes.Notify:FireClient(player, "notify_minigame_win", { amount = gain }, Colors.WIN)
			else
				if not refundLoser(player, data, state) then
					Remotes.Notify:FireClient(player, "notify_minigame_lose", nil, Colors.LOSE)
				end
			end
		end
	end

	-- Le tintement du jackpot n'a de sens que si quelqu'un a gagne : une partie
	-- ou tout le monde perd (braquage rate, chaises a un seul survivant parti)
	-- doit se terminer en silence, pas sur un son de victoire.
	if anyWinner then
		Sounds.PlayAt("bet_win_zone", state.zone)
	end

	clearStage(state)
	resetRound(state)
end

-- Personne n'est venu : tout le monde recupere sa mise, y compris les jetons
-- offerts. Une partie qui n'a pas eu lieu ne coute rien.
local function refundAll(state)
	for _, player in state.participants do
		local data = PlayerData.Get(player)
		if data then
			-- Le jeton n'est rendu que s'il a REELLEMENT paye quelque chose : le
			-- Train de minuit s'embarque gratuitement et marque lui aussi ses
			-- passagers comme "gratuits", sans qu'aucun jeton n'ait ete pris.
			if state.amount > 0 and state.freeStakes[player] then
				data.Stakes = (data.Stakes or 0) + 1
			elseif state.amount > 0 then
				data.TimeLeft += state.amount
				PlayerData.NoteTime(data)
				Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
			end

			Remotes.Notify:FireClient(player, "notify_bet_refund", nil, Colors.INFO)
		end
	end

	clearStage(state)
	resetRound(state)
end

--------------------------------------------------------------------------------
-- Deroulement
--------------------------------------------------------------------------------

local function runRound(state)
	local rule = rules[state.game.key]

	if #state.participants < state.minPlayers then
		Sounds.PlayAt("bet_draw", state.zone)
		refundAll(state)
		return
	end

	state.phase = "running"
	state.deadline = nil
	refreshSign(state)
	broadcastRounds()

	-- Le tirage s'entend depuis la zone, meme pour ceux qui ne jouent pas :
	-- c'est ce qui donne envie de venir voir.
	Sounds.PlayAt("bet_draw", state.zone)

	if state.game.kind == MiniGameList.KIND_ARENA and rule and rule.Run then
		-- Phase active : la regle raconte sa partie et rend la main quand elle a
		-- un resultat. Un fil a part, pour qu'un jeu qui dure ne bloque ni la
		-- boucle d'inscription ni les autres zones.
		task.spawn(function()
			rule.Run(state, function(parts)
				payout(state, parts)
			end)
		end)
		return
	end

	payout(state, rule and rule.Resolve and rule.Resolve(state) or nil)
end

local function tryAccept(player, zone, payload)
	local state = zoneStates[zone]
	if not state then
		return
	end

	-- Une partie deja lancee ne prend plus personne : on ne s'inscrit pas a des
	-- chaises musicales pendant que la musique joue.
	if state.phase == "running" then
		return
	end

	if not state.playersInside[player] or state.inRound[player] then
		return
	end

	if state.game.scheduled then
		-- Le Train de minuit ne s'embarque qu'a quai : il n'y a rien a accepter
		-- entre deux departs.
		return
	end

	local data = PlayerData.Get(player)
	if not data then
		return
	end

	-- Revalide cote serveur : le client ne voit qu'un cadenas dessine, rien ne
	-- l'empeche d'envoyer quand meme un MiniGameAccept.
	if lockReason(data, state) then
		return
	end

	if state.game.maxPlayers and #state.participants >= state.game.maxPlayers then
		Remotes.Notify:FireClient(player, "notify_minigame_full", nil, Colors.LOSE)
		return
	end

	local paid, free = takeStake(player, data, state.amount)
	if not paid then
		Remotes.Notify:FireClient(player, "notify_bet_poor", { amount = state.amount }, Colors.LOSE)
		return
	end

	state.inRound[player] = true
	state.freeStakes[player] = free
	table.insert(state.participants, player)

	-- Le seul jeu ou l'on choisit quelque chose en s'inscrivant : la roue. La
	-- regle range le secteur dans son bloc-notes, le cadre n'a pas a savoir ce
	-- que c'est.
	local rule = rules[state.game.key]
	if rule and rule.Join then
		rule.Join(state, player, payload)
	end

	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	Remotes.MiniGamePromptHide:FireClient(player, zone)
	Sounds.PlayAt("bet_placed", zone)

	Remotes.Notify:FireClient(player, free and "notify_stake_free" or "notify_bet_placed", {
		amount = state.amount,
		seconds = state.joinWindow,
		count = data.Stakes or 0,
	}, Colors.INFO)

	-- Un jeu solo n'attend personne : on mise, on tire, c'est fini. C'est ce qui
	-- en fait le bon premier client du cadre -- il n'a rien a synchroniser.
	if state.game.kind == MiniGameList.KIND_SOLO then
		state.phase = "running"
		runRound(state)
		return
	end

	if state.phase == "idle" then
		state.phase = "joining"
		-- Horloge serveur (et non os.clock) : le client la partage, il peut donc
		-- afficher le meme compte a rebours sans qu'on le lui repete.
		state.deadline = Workspace:GetServerTimeNow() + state.joinWindow

		-- Le numero de partie est capture dans la fermeture. Sans lui, le
		-- decompte d'un duel resolu d'avance (deux joueurs, la place est prise)
		-- retomberait dix secondes plus tard sur la partie SUIVANTE et la
		-- tirerait avant l'heure.
		state.round = (state.round or 0) + 1
		local round = state.round

		task.delay(state.joinWindow, function()
			if state.phase == "joining" and state.round == round then
				runRound(state)
			end
		end)
	end

	-- Le duel se joue a deux : des que la place est prise, on n'attend plus la
	-- fin du decompte pour rien.
	if state.game.maxPlayers and #state.participants >= state.game.maxPlayers then
		state.phase = "running"
		runRound(state)
		return
	end

	refreshSign(state)
	broadcastRounds()
end

--------------------------------------------------------------------------------
-- Le Train de minuit
--------------------------------------------------------------------------------

-- Le seul jeu qui ne s'ouvre pas quand on entre dedans : il part tout seul, une
-- fois par heure. Il s'annonce longtemps a l'avance et se voit de tous les
-- etages -- c'est le sommet du jeu, il doit se preparer.
--
-- L'embarquement est GRATUIT : la cagnotte n'est pas faite des mises, elle est
-- faite de la dime prelevee sur tout ce qui s'est joue en dessous. Un joueur du
-- palier 8 ne paie pas pour monter, il encaisse ce que le serveur a produit.
local function boardTrain(state)
	state.phase = "joining"
	state.deadline = Workspace:GetServerTimeNow() + Config.TRAIN_BOARDING
	refreshSign(state)
	broadcastRounds()

	-- Tout le serveur l'entend, y compris les etages du bas : c'est ce qui donne
	-- envie de monter jusqu'au Terminus.
	Remotes.Notify:FireAllClients("notify_train_boarding", {
		amount = trainPot,
		seconds = Config.TRAIN_BOARDING,
	}, Colors.INFO)

	Sounds.PlayAt("train_arrive", state.zone)

	task.wait(Config.TRAIN_BOARDING)

	if #state.participants == 0 then
		resetRound(state)
		return
	end

	state.phase = "running"
	refreshSign(state)

	local rule = rules[state.game.key]
	payout(state, rule and rule.Resolve and rule.Resolve(state) or nil)

	-- La cagnotte repart de son fond : ce qui a ete gagne a ete distribue.
	trainPot = Config.TRAIN_BASE_POT
end

-- Monter dans le train remplace la mise : c'est le seul jeu ou l'inscription ne
-- coute rien, donc le seul qui ne passe pas par tryAccept.
local function boardPlayer(player, state)
	if state.phase ~= "joining" or state.inRound[player] then
		return
	end

	local data = PlayerData.Get(player)
	if not data or lockReason(data, state) then
		return
	end

	state.inRound[player] = true
	state.freeStakes[player] = true
	table.insert(state.participants, player)

	Remotes.MiniGamePromptHide:FireClient(player, state.zone)
	Sounds.PlayAt("bet_placed", state.zone)
	refreshSign(state)
	broadcastRounds()
end

local function startTrainSchedule()
	task.spawn(function()
		while true do
			task.wait(Config.TRAIN_INTERVAL - Config.TRAIN_WARNING)

			local zones = {}
			for _, state in zoneStates do
				if state.game.scheduled and state.phase == "idle" then
					table.insert(zones, state)
				end
			end

			if #zones > 0 then
				Remotes.Notify:FireAllClients("notify_train_soon", {
					seconds = Config.TRAIN_WARNING,
					amount = trainPot,
				}, Colors.INFO)

				task.wait(Config.TRAIN_WARNING)

				for _, state in zones do
					if state.phase == "idle" then
						task.spawn(boardTrain, state)
					end
				end
			else
				-- Aucune zone de Train sur cette map : on laisse passer le cycle
				-- sans rien annoncer, plutot que de promettre un depart qui
				-- n'aura pas lieu.
				task.wait(Config.TRAIN_WARNING)
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Zones
--------------------------------------------------------------------------------

local function sendPrompt(player, state)
	local data = PlayerData.Get(player)
	local locked = lockReason(data, state)

	Remotes.MiniGamePrompt:FireClient(player, state.zone, {
		game = state.game.key,
		amount = state.amount,
		lockedTier = locked and locked.tier or nil,
		lockedAt = locked and locked.amount or nil,
		free = state.game.scheduled or nil,
		pot = state.game.scheduled and trainPot or nil,
		sectors = state.game.sectors or nil,
		stakes = data and data.Stakes or 0,
		open = state.phase ~= "running",
	})
end

local function setupZone(zone)
	if not zone:IsA("BasePart") or zoneStates[zone] then
		return
	end

	local game = gameOf(zone)
	local amount = amountOf(zone, game)

	local state = {
		zone = zone,
		game = game,
		amount = amount,
		minTier = minTierOf(zone, game),
		minPlayers = game.minPlayers or Config.BET_MIN_PLAYERS,
		joinWindow = Config.BET_JOIN_WINDOW,
		unlockAt = unlockAtOf(zone, game, amount),
		decor = decorOf(zone, game),
		participants = {},
		inRound = {},
		freeStakes = {},
		scratch = {},
		phase = "idle",
		playersInside = {},
		touchCounts = {},
	}

	zoneStates[zone] = state

	local factor = amountFactor(amount)
	ZoneAura.Create(zone, AURA_COLOR_LOW:Lerp(AURA_COLOR_HIGH, factor), factor)

	-- Le bourdonnement suit la meme echelle que la couleur de l'aura, mais a
	-- l'envers : plus la mise est grosse, plus il gronde grave.
	Sounds.Loop("bet_zone_hum", zone, { pitch = 1.25 - factor * 0.55 })

	state.countLabel = createSign(zone, game, amount)
	refreshSign(state)

	local rule = rules[game.key]
	if rule and rule.Setup then
		rule.Setup(state)
	end

	zone.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		state.touchCounts[player] = (state.touchCounts[player] or 0) + 1
		if state.touchCounts[player] == 1 then
			state.playersInside[player] = true

			-- Le Train ne se propose pas : on y monte en marchant dedans pendant
			-- l'embarquement, ce qui est exactement ce qu'on fait d'un train.
			if state.game.scheduled and state.phase == "joining" then
				boardPlayer(player, state)
			elseif not state.inRound[player] then
				sendPrompt(player, state)
			end
		end
	end)

	zone.TouchEnded:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		state.touchCounts[player] = math.max(0, (state.touchCounts[player] or 1) - 1)
		if state.touchCounts[player] == 0 then
			state.playersInside[player] = nil
			if not state.inRound[player] then
				Remotes.MiniGamePromptHide:FireClient(player, zone)
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Verrous cote client
--------------------------------------------------------------------------------

-- Le cadenas au-dessus d'une zone est propre a chaque joueur, alors que le
-- panneau de la zone est partage : c'est donc le client qui le dessine, et le
-- serveur qui lui dit quelles zones sont encore fermees pour lui.
--
-- knownLocks[player][zone] = ce qui manquait au dernier passage. On ne previent
-- le client que sur CHANGEMENT, pas a chaque tour de boucle.
local knownLocks = {}

local function refreshLocks(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local known = knownLocks[player]
	if not known then
		known = {}
		knownLocks[player] = known
	end

	for zone, state in zoneStates do
		local locked = lockReason(data, state)
		-- Une signature textuelle plutot que la table elle-meme : deux tables
		-- de meme contenu ne sont jamais egales en Lua, et la zone se
		-- renotifierait a chaque passage.
		local signature = locked and ((locked.tier or "") .. "/" .. (locked.amount or "")) or false

		if known[zone] ~= signature then
			-- known[zone] == nil au premier passage : c'est l'etat initial qu'on
			-- envoie, pas un deverrouillage -- pas de notification dans ce cas.
			local isFirstPass = known[zone] == nil

			known[zone] = signature
			Remotes.MiniGameLockUpdated:FireClient(player, zone, locked, state.game.key)

			if not locked and not isFirstPass then
				Remotes.Notify:FireClient(player, "notify_minigame_unlocked", {
					name = "minigame_" .. state.game.key .. "_name",
				}, Colors.WIN)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Interface publique
--------------------------------------------------------------------------------

-- Vrai tant que la mise du joueur est engagee dans une partie non resolue. Sert
-- a lui accorder un sursis s'il tombe a 0 avant le resultat -- le tirage peut
-- encore le renflouer.
function MiniGames.HasPendingStake(player)
	for _, state in zoneStates do
		if state.inRound[player] then
			return true
		end
	end

	return false
end

function MiniGames.Start()
	local MiniGameRules = require(script.Parent.MiniGameRules)
	MiniGameRules.Register(MiniGames)

	-- Les deux tags : les zones de pari deja posees dans Studio, et les zones du
	-- lot 6. Le cadre ne fait aucune difference entre les deux -- une BetZone est
	-- une MiniGameZone dont le jeu est "Pari".
	for _, tag in { Config.BET_TAG, Config.MINIGAME_TAG } do
		for _, zone in CollectionService:GetTagged(tag) do
			setupZone(zone)
		end

		CollectionService:GetInstanceAddedSignal(tag):Connect(setupZone)
	end

	Remotes.MiniGameAccept.OnServerEvent:Connect(tryAccept)

	-- Le geste d'un joueur PENDANT une partie : un clic de duel, un coup de
	-- braquage. La regle valide ce qu'elle attend ; le cadre ne fait que router.
	Remotes.MiniGameAction.OnServerEvent:Connect(function(player, zone, payload)
		local state = zoneStates[zone]
		if not state or state.phase ~= "running" or not state.inRound[player] then
			return
		end

		local rule = rules[state.game.key]
		if rule and rule.Action then
			rule.Action(state, player, payload)
		end
	end)

	-- Le client reclame l'etat courant a son demarrage : un envoi spontane a
	-- l'arrivee du joueur partirait avant qu'il ait branche son ecoute, et son
	-- HUD resterait vide jusqu'a la partie suivante.
	Remotes.MiniGameRoundsUpdated.OnServerEvent:Connect(sendRounds)

	Players.PlayerRemoving:Connect(function(player)
		knownLocks[player] = nil

		for _, state in zoneStates do
			state.playersInside[player] = nil
			state.touchCounts[player] = nil
			-- Volontairement PAS retire de "participants" si une partie est deja
			-- engagee : sa mise est dans la cagnotte, elle doit y rester.
		end
	end)

	-- Un balayage periodique plutot qu'un signal a chaque gain : le temps arrive
	-- de partout (orbes, clics, auto-cliqueur, mini-jeux, achats) et un
	-- deverrouillage n'a pas besoin d'etre instantane a la milliseconde pres.
	task.spawn(function()
		while true do
			task.wait(Config.BET_LOCK_REFRESH_INTERVAL)

			for _, player in Players:GetPlayers() do
				refreshLocks(player)
			end
		end
	end)

	startTrainSchedule()
end

return MiniGames
