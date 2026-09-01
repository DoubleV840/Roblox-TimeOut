-- Mini-jeu de pari : entrer dans une Part taguee Config.BET_TAG ouvre une popup de
-- confirmation. Si le joueur valide (et est toujours dans la zone, et a assez de
-- temps), sa mise est prelevee et il rejoint le tour en cours. Apres le delai
-- d'inscription, un gagnant tire au sort remporte toute la cagnotte.
--
-- Le montant de la mise est propre a chaque zone : mets un attribut numerique
-- "BetAmount" (en secondes) sur la Part. Sans attribut, Config.BET_AMOUNT sert de valeur par defaut.
--
-- Limitation connue (v1) : si un participant se deconnecte avant le tirage, sa mise
-- ne peut plus lui etre rendue ni gagnee -- elle est simplement perdue pour tout le monde.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Colors = require(ReplicatedStorage.Shared.Colors)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local ZoneAura = require(ReplicatedStorage.Shared.ZoneAura)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PlayerData = require(script.Parent.PlayerData)
local TierService = require(script.Parent.TierService)

local BettingGame = {}

local COLOR_INFO = Colors.INFO
local COLOR_WIN = Colors.WIN
local COLOR_LOSE = Colors.LOSE

-- echelle de l'aura : du plus petit palier (10s) au plus gros (1000h),
-- en log car l'ecart est enorme (facteur 360 000)
local AURA_MIN_AMOUNT = 10
local AURA_MAX_AMOUNT = 3600000
local AURA_COLOR_LOW = Color3.fromRGB(80, 200, 120) -- vert : petite mise
local AURA_COLOR_HIGH = Color3.fromRGB(220, 40, 40) -- rouge : grosse mise

local zoneStates = {}

local function getAmount(zone)
	return zone:GetAttribute("BetAmount") or Config.BET_AMOUNT
end

-- Temps qu'il faut avoir possede, au moins une fois, pour que cette zone s'ouvre.
-- Par defaut c'est la mise elle-meme : on ne parie 10 min qu'apres avoir tenu 10
-- min sur son propre chrono.
local function getUnlockAt(zone)
	return zone:GetAttribute(Config.BET_UNLOCK_ATTRIBUTE) or getAmount(zone)
end

-- Le deverrouillage est definitif : il regarde le plus haut temps jamais possede
-- (data.MaxTime), pas le temps courant. Tomber a zero ne referme jamais une zone.
local function isUnlocked(data, zone)
	if not data then
		return false
	end

	return math.max(data.MaxTime, data.TimeLeft) >= getUnlockAt(zone)
end

local function amountFactor(amount)
	local clamped = math.clamp(amount, AURA_MIN_AMOUNT, AURA_MAX_AMOUNT)
	local logMin, logMax = math.log(AURA_MIN_AMOUNT), math.log(AURA_MAX_AMOUNT)
	return (math.log(clamped) - logMin) / (logMax - logMin)
end

-- Renvoie le label du bas, celui qui compte les parieurs en attente.
local function createSign(zone, amount)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(8, 0, 3.2, 0) -- en studs : taille fixe dans le monde
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Size = UDim2.new(1, 0, 0.58, 0)
	amountLabel.BackgroundTransparency = 1
	amountLabel.FontFace = Fonts.Main
	amountLabel.TextScaled = true
	amountLabel.Parent = billboard

	-- Panneau partage par tous les joueurs : le serveur pose la cle, chaque client
	-- l'affiche dans sa langue (voir Locale).
	Locale.Mark(amountLabel, "bet_sign", { amount = amount })

	-- Le panneau reprend la couleur et l'agitation de l'aura de la zone : une zone
	-- a 10s reste sage, une zone a 1000h hurle de loin.
	local factor = amountFactor(amount)
	TextFx.Mark(amountLabel, factor, AURA_COLOR_LOW:Lerp(AURA_COLOR_HIGH, factor))

	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(1, 0, 0.42, 0)
	countLabel.Position = UDim2.new(0, 0, 0.58, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.FontFace = Fonts.Main
	countLabel.TextScaled = true
	countLabel.Text = ""
	countLabel.Parent = billboard

	return countLabel
end

-- L'aura (cadre neon + particules) vit dans ZoneAura : les guichets s'en servent aussi.
local function createAura(zone, amount)
	local factor = amountFactor(amount)
	ZoneAura.Create(zone, AURA_COLOR_LOW:Lerp(AURA_COLOR_HIGH, factor), factor)
end

local WAITING_IDLE_COLOR = Color3.fromRGB(170, 170, 170)
local WAITING_SHORT_COLOR = Color3.fromRGB(255, 170, 60)
local WAITING_READY_COLOR = Color3.fromRGB(90, 220, 120)

-- Compteur de parieurs affiche sous le montant, pour qu'on voie de loin s'il y a
-- deja du monde engage sur cette zone.
local function refreshSign(state)
	local label = state.countLabel
	if not label then
		return
	end

	local count = #state.participants

	if count == 0 then
		Locale.Mark(label, "bet_waiting_none")
		TextFx.Mark(label, 0, WAITING_IDLE_COLOR)
		return
	end

	if count < Config.BET_MIN_PLAYERS then
		-- On affiche l'objectif : sans le minimum, tout le monde sera rembourse.
		Locale.Mark(label, "bet_waiting_short", { count = count, min = Config.BET_MIN_PLAYERS })
		TextFx.Mark(label, 0.45, WAITING_SHORT_COLOR)
	else
		Locale.Mark(label, "bet_waiting_ready", { count = count })
		TextFx.Mark(label, math.min(1, count / (Config.BET_MIN_PLAYERS * 2)), WAITING_READY_COLOR)
	end
end

--------------------------------------------------------------------------------
-- HUD des paris en cours
--------------------------------------------------------------------------------

-- Le panneau de la zone ne se lit que de pres : le HUD, lui, suit le joueur
-- partout. Il lui rappelle qu'un tirage court -- surtout quand sa mise est deja
-- partie et qu'il est reparti farmer ailleurs.
--
-- On envoie une echeance absolue (horloge serveur, la meme des deux cotes) et
-- non un nombre de secondes restantes : le client fait descendre le compte a
-- rebours tout seul, sans qu'on ait a lui parler a chaque seconde.
local function sendRounds(player)
	local rounds = {}

	for zone, state in zoneStates do
		if state.roundOpen then
			table.insert(rounds, {
				amount = getAmount(zone),
				count = #state.participants,
				endsAt = state.deadline,
				joined = state.inRound[player] == true,
			})
		end
	end

	-- L'ordre d'un parcours de table n'est pas stable : sans tri, deux tours
	-- ouverts s'echangeraient de place a chaque envoi. Le tirage le plus proche
	-- passe en tete.
	table.sort(rounds, function(a, b)
		if a.endsAt == b.endsAt then
			return a.amount < b.amount
		end

		return a.endsAt < b.endsAt
	end)

	Remotes.BetRoundsUpdated:FireClient(player, rounds)
end

-- Le drapeau "joined" est propre a chaque joueur, d'ou un envoi par client
-- plutot qu'un FireAllClients -- mais ca ne part qu'aux changements de tour
-- (ouverture, inscription, tirage), jamais en boucle.
local function broadcastRounds()
	for _, player in Players:GetPlayers() do
		sendRounds(player)
	end
end

local function resolveRound(state, amount)
	local pot = #state.participants * amount

	-- Le tirage s'entend depuis la zone, meme pour ceux qui ne jouent pas : c'est
	-- ce qui donne envie de venir voir.
	Sounds.PlayAt("bet_draw", state.zone)

	if #state.participants < Config.BET_MIN_PLAYERS then
		for _, player in state.participants do
			local data = PlayerData.Get(player)
			if data then
				data.TimeLeft += amount
				PlayerData.NoteTime(data)
				Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
				Remotes.Notify:FireClient(player, "notify_bet_refund", nil, COLOR_INFO)
			end
		end
	else
		local winner = state.participants[math.random(1, #state.participants)]

		Sounds.PlayAt("bet_win_zone", state.zone)

		for _, player in state.participants do
			local data = PlayerData.Get(player)
			if data then
				if player == winner then
					-- Un gain de mini-jeu est un gain ACTIF : le palier du
					-- gagnant le multiplie, comme un clic ou une orbe.
					--
					-- Consequence a garder en tete a l'equilibrage : la cagnotte
					-- sort alors plus grosse qu'elle n'est entree. C'est ce que
					-- demande le plan 2 (c'est ce qui rend les mini-jeux des
					-- hauts paliers interessants), mais c'est aussi le seul
					-- endroit du jeu ou du temps se cree a partir du temps des
					-- autres -- a surveiller si les mises deviennent grosses.
					local gain = math.round(pot * TierService.Multiplier(player))

					data.TimeLeft += gain
					PlayerData.NoteTime(data)
					Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
					Remotes.Notify:FireClient(player, "notify_bet_win", { amount = gain }, COLOR_WIN)
				else
					Remotes.Notify:FireClient(player, "notify_bet_lose", nil, COLOR_LOSE)
				end
			end
		end
	end

	state.participants = {}
	state.inRound = {}
	state.roundOpen = false
	state.deadline = nil
	refreshSign(state)
	broadcastRounds()
end

local function tryAcceptBet(player, zone, state, amount)
	if not state.playersInside[player] or state.inRound[player] then
		return
	end

	local data = PlayerData.Get(player)
	if not data then
		return
	end

	-- Revalide cote serveur : le client ne voit qu'une popup de verrou, mais rien
	-- ne l'empeche d'envoyer quand meme un BetAccept.
	if not isUnlocked(data, zone) then
		return
	end

	if data.TimeLeft < amount then
		Remotes.Notify:FireClient(player, "notify_bet_poor", { amount = amount }, COLOR_LOSE)
		return
	end

	if not state.roundOpen then
		state.roundOpen = true
		-- Horloge serveur (et non os.clock) : le client la partage, il peut donc
		-- afficher le meme compte a rebours sans qu'on le lui repete.
		state.deadline = Workspace:GetServerTimeNow() + Config.BET_JOIN_WINDOW
		task.delay(Config.BET_JOIN_WINDOW, function()
			resolveRound(state, amount)
		end)
	end

	state.inRound[player] = true
	table.insert(state.participants, player)
	refreshSign(state)
	broadcastRounds()

	data.TimeLeft -= amount
	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	Remotes.Notify:FireClient(
		player,
		"notify_bet_placed",
		{ amount = amount, seconds = Config.BET_JOIN_WINDOW },
		COLOR_INFO
	)
	Remotes.BetPromptHide:FireClient(player, zone)
	Sounds.PlayAt("bet_placed", zone)
end

local function setupZone(zone)
	if not zone:IsA("BasePart") or zoneStates[zone] then
		return
	end

	local amount = getAmount(zone)
	createAura(zone, amount)

	-- Le bourdonnement suit la meme echelle que la couleur de l'aura, mais a
	-- l'envers : plus la mise est grosse, plus il gronde grave.
	Sounds.Loop("bet_zone_hum", zone, { pitch = 1.25 - amountFactor(amount) * 0.55 })

	local state = {
		zone = zone,
		participants = {},
		inRound = {},
		roundOpen = false,
		playersInside = {},
		touchCounts = {},
		countLabel = createSign(zone, amount),
	}
	zoneStates[zone] = state

	refreshSign(state)

	zone.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		state.touchCounts[player] = (state.touchCounts[player] or 0) + 1
		if state.touchCounts[player] == 1 then
			state.playersInside[player] = true
			if not state.inRound[player] then
				-- Zone verrouillee : on ouvre quand meme une popup, mais celle du
				-- cadenas -- elle dit ce qu'il faut atteindre pour y avoir droit.
				local lockedAt = nil
				if not isUnlocked(PlayerData.Get(player), zone) then
					lockedAt = getUnlockAt(zone)
				end

				Remotes.BetPrompt:FireClient(player, zone, amount, lockedAt)
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
				Remotes.BetPromptHide:FireClient(player, zone)
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Verrous
--------------------------------------------------------------------------------

-- Le cadenas au-dessus d'une zone est propre a chaque joueur, alors que le
-- panneau de la zone est partage : c'est donc le client qui le dessine, et le
-- serveur qui lui dit quelles zones sont encore fermees pour lui.
--
-- lockState[player][zone] = true si la zone etait verrouillee au dernier passage.
-- On ne previent le client que sur changement, pas a chaque tour de boucle.
local lockState = {}

local function refreshLocks(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local known = lockState[player]
	if not known then
		known = {}
		lockState[player] = known
	end

	for zone in zoneStates do
		local locked = not isUnlocked(data, zone)

		if known[zone] ~= locked then
			-- known[zone] == nil au premier passage : c'est l'etat initial qu'on
			-- envoie, pas un deverrouillage -- pas de notification dans ce cas.
			local isFirstPass = known[zone] == nil

			known[zone] = locked
			Remotes.BetLockUpdated:FireClient(player, zone, locked, getUnlockAt(zone))

			if not locked and not isFirstPass then
				Remotes.Notify:FireClient(
					player,
					"notify_bet_unlocked",
					{ amount = getAmount(zone) },
					COLOR_WIN
				)
			end
		end
	end
end


-- Vrai tant que la mise du joueur est engagee dans un tour non encore tire.
-- Sert a lui accorder un sursis s'il tombe a 0 avant le resultat.
function BettingGame.HasPendingBet(player)
	for _, state in zoneStates do
		if state.inRound[player] then
			return true
		end
	end

	return false
end

function BettingGame.Start()
	for _, zone in CollectionService:GetTagged(Config.BET_TAG) do
		setupZone(zone)
	end

	CollectionService:GetInstanceAddedSignal(Config.BET_TAG):Connect(setupZone)

	Remotes.BetAccept.OnServerEvent:Connect(function(player, zone)
		local state = zoneStates[zone]
		if not state then
			return
		end

		tryAcceptBet(player, zone, state, getAmount(zone))
	end)

	-- Le client reclame l'etat courant a son demarrage : un envoi spontane a
	-- l'arrivee du joueur partirait avant qu'il ait branche son ecoute, et son
	-- HUD resterait vide jusqu'au tour suivant.
	Remotes.BetRoundsUpdated.OnServerEvent:Connect(sendRounds)

	Players.PlayerRemoving:Connect(function(player)
		lockState[player] = nil

		for _, state in zoneStates do
			state.playersInside[player] = nil
			state.touchCounts[player] = nil
			-- volontairement pas retire de "participants" si un tour est deja engage
		end
	end)

	-- Un balayage periodique plutot qu'un signal a chaque gain de temps : le temps
	-- arrive de partout (orbes, clics, auto-cliqueurs, paris, achats) et un
	-- deverrouillage n'a pas besoin d'etre instantane a la milliseconde pres.
	task.spawn(function()
		while true do
			task.wait(Config.BET_LOCK_REFRESH_INTERVAL)

			for _, player in Players:GetPlayers() do
				refreshLocks(player)
			end
		end
	end)
end

return BettingGame
