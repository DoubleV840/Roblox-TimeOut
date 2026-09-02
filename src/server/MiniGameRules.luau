-- Les huit regles de mini-jeu. Une regle designe un GAGNANT, rien de plus.
--
-- Tout le reste -- entrer dans la zone, prendre la mise, decompter, rembourser
-- si personne ne vient, payer, notifier, sauvegarder, verrouiller par palier --
-- est fait une seule fois par le cadre (src/server/MiniGames.luau). C'est
-- l'etape 24, et c'est pour ca que ce fichier tient en huit petits blocs plutot
-- qu'en huit systemes.
--
-- CE QU'UNE REGLE PEUT DEFINIR, toutes facultatives :
--   Setup(state)                appele une fois par zone, au demarrage
--   Join(state, player, data)   ce que le joueur choisit en s'inscrivant
--   Resolve(state) -> parts     resultat immediat (jeux SOLO et DRAW)
--   Run(state, finish)          phase active (jeux ARENA) ; finish(parts)
--   Action(state, player, ...)  un geste pendant la partie
--
-- "parts" est une table joueur -> part de la cagnotte. La somme peut valoir
-- moins de 1 (la maison garde le reste) ou plus (les hauts paliers multiplient
-- deja par le palier du gagnant, le cadre s'en charge).
--
-- SUR LE DECOR. Les jeux qui ont besoin d'un objet dans le monde (des dalles,
-- une roue, une plateforme, un coffre) le trouvent dans state.decor -- ou ne le
-- trouvent pas. AUCUN ne depend de sa presence : sans decor, ils se rabattent
-- sur la zone elle-meme et restent jouables. C'est ce qui permet de tester les
-- huit jeux avant que la map n'existe, ce qui est exactement la situation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local MiniGameRules = {}

local MiniGames -- pose par MiniGameRules.Register, pour eviter la boucle de require

--------------------------------------------------------------------------------
-- Outils communs
--------------------------------------------------------------------------------

local function stage(state, key, params, endsAt)
	MiniGames.Stage(state, { key = key, params = params, endsAt = endsAt })
end

-- Les joueurs encore en course. Un participant qui s'est deconnecte en cours de
-- partie ne peut plus gagner : sa mise reste dans la cagnotte pour les autres.
local function alive(state, eliminated)
	local list = {}

	for _, player in state.participants do
		if player.Parent and not eliminated[player] then
			table.insert(list, player)
		end
	end

	return list
end

-- Le socle d'une part egale entre plusieurs gagnants.
local function split(winners, total)
	local parts = {}

	if #winners == 0 then
		return parts
	end

	for _, player in winners do
		parts[player] = (total or 1) / #winners
	end

	return parts
end

-- Le personnage d'un joueur, ou nil. Les jeux d'arene en ont besoin a chaque
-- tour : un joueur qui meurt en pleine partie est simplement elimine.
local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Vrai quand le joueur est au-dessus de l'empreinte au sol d'une Part. Sert aux
-- deux jeux de plateforme (chaises, wagon) : c'est le seul test qui marche aussi
-- bien sur une dalle de 4 studs que sur un wagon de 40.
local function standingOn(player, part, margin)
	local root = rootOf(player)
	if not root or not part or not part.Parent then
		return false
	end

	local local_ = part.CFrame:PointToObjectSpace(root.Position)
	local half = part.Size / 2
	local slack = margin or 0

	return math.abs(local_.X) <= half.X + slack and math.abs(local_.Z) <= half.Z + slack
end

--------------------------------------------------------------------------------
-- Palier 1 -- Le pari
--------------------------------------------------------------------------------
-- Le mini-jeu d'origine (plan.md), devenu le mini-jeu du Quai. Un tirage au
-- sort, le gagnant rafle tout. Sa regle tient en trois lignes : c'est la preuve
-- que le cadre porte bien tout le reste.

local Pari = {}

function Pari.Resolve(state)
	local runners = alive(state, {})
	if #runners == 0 then
		return nil
	end

	return { [runners[math.random(1, #runners)]] = 1 }
end

--------------------------------------------------------------------------------
-- Palier 2 -- Le Distributeur detraque
--------------------------------------------------------------------------------
-- Machine a sous SOLO : on mise, on tire, on recupere entre 0 et 10 fois la
-- mise. Aucune synchronisation entre joueurs -- c'est pour ca qu'il vient en
-- premier, il valide le cadre sans rien lui demander de difficile.
--
-- L'esperance est volontairement SOUS 1 (environ 0,88) : une machine a sous
-- rentable serait une imprimante a temps, et le joueur y passerait la partie.
-- Elle reste attirante parce que le x10 existe et se voit.

local Distributeur = {}

-- { part de la cagnotte, poids }. La cagnotte d'un jeu solo, c'est sa propre
-- mise : une part de 10 rend donc dix fois la mise.
local REELS = {
	{ share = 0, weight = 42 },
	{ share = 0.5, weight = 24 },
	{ share = 1, weight = 16 },
	{ share = 2, weight = 11 },
	{ share = 5, weight = 5 },
	{ share = 10, weight = 2 },
}

function Distributeur.Resolve(state)
	local player = state.participants[1]
	if not player then
		return nil
	end

	local total = 0
	for _, reel in REELS do
		total += reel.weight
	end

	local roll = math.random() * total

	for _, reel in REELS do
		roll -= reel.weight
		if roll <= 0 then
			if reel.share >= 5 then
				Sounds.PlayAt("minigame_jackpot", state.zone)
			end

			return reel.share > 0 and { [player] = reel.share } or nil
		end
	end

	return nil
end

--------------------------------------------------------------------------------
-- Palier 3 -- Les Chaises musicales
--------------------------------------------------------------------------------
-- Des dalles s'eteignent une a une ; le dernier joueur debout remporte la
-- cagnotte. Le premier jeu du lot qui demande une PHASE ACTIVE : c'est lui qui
-- valide Run().
--
-- Le decor attendu est un dossier de Parts-dalles a cote de la zone. Sans lui,
-- la partie se joue quand meme -- une elimination au hasard par tour, avec le
-- meme rythme et les memes annonces. Le jeu est donc testable aujourd'hui, et
-- deviendra physique le jour ou les dalles existeront.

local Chaises = {}

local CHAISES_ROUND = 4 -- secondes par tour

local function platesOf(state)
	local plates = {}

	if state.decor then
		for _, child in state.decor:GetDescendants() do
			if child:IsA("BasePart") then
				table.insert(plates, child)
			end
		end
	end

	return plates
end

function Chaises.Run(state, finish)
	local plates = platesOf(state)
	local eliminated = {}
	local restore = {}

	for _, plate in plates do
		restore[plate] = { transparency = plate.Transparency, collide = plate.CanCollide }
	end

	while true do
		local runners = alive(state, eliminated)
		if #runners <= 1 then
			break
		end

		stage(state, "minigame_stage_chaises", { count = #runners }, Workspace:GetServerTimeNow() + CHAISES_ROUND)
		Sounds.PlayAt("minigame_tick", state.zone)

		task.wait(CHAISES_ROUND)

		runners = alive(state, eliminated)
		if #runners <= 1 then
			break
		end

		-- Une dalle s'eteint : qui etait dessus tombe. Sans dalles, le sort
		-- tranche -- le rythme et la tension restent, seule la raison change.
		local victim = nil

		if #plates > 0 then
			local plate = table.remove(plates, math.random(1, #plates))

			plate.CanCollide = false
			TweenService:Create(plate, TweenInfo.new(0.4), { Transparency = 0.85 }):Play()

			for _, player in runners do
				if standingOn(player, plate) then
					victim = player
					break
				end
			end
		end

		-- Personne sur la dalle eteinte (ou pas de dalles du tout) : on elimine
		-- le joueur le plus loin du centre de la zone. C'est la regle la moins
		-- arbitraire qu'on puisse tenir sans decor -- rester au milieu paie.
		if not victim then
			local worst, worstDistance = nil, -1

			for _, player in runners do
				local root = rootOf(player)
				local distance = root and (root.Position - state.zone.Position).Magnitude or math.huge

				if distance > worstDistance then
					worst, worstDistance = player, distance
				end
			end

			victim = worst or runners[math.random(1, #runners)]
		end

		eliminated[victim] = true
		Sounds.PlayAt("minigame_eliminated", state.zone)
		stage(state, "minigame_stage_out", { count = #runners - 1 })
	end

	for plate, saved in restore do
		if plate.Parent then
			plate.Transparency = saved.transparency
			plate.CanCollide = saved.collide
		end
	end

	finish(split(alive(state, eliminated)))
end

--------------------------------------------------------------------------------
-- Palier 4 -- La Roue
--------------------------------------------------------------------------------
-- Une roue partagee : chacun mise sur un secteur avant le lancer, et tous les
-- joueurs du secteur sortant se partagent la cagnotte.
--
-- C'est le seul jeu ou l'on CHOISIT quelque chose en s'inscrivant, et le seul ou
-- deux joueurs peuvent gagner ensemble sans etre allies. Il tourne meme a un
-- seul joueur : la roue n'a besoin de personne pour tourner.

local Roue = {}

Roue.SECTORS = 6

function Roue.Join(state, player, payload)
	local sector = tonumber(payload)

	-- Un secteur absent ou fantaisiste (client bricole) est ramene a un tirage
	-- au sort plutot que refuse : la mise est deja prise, elle doit jouer.
	if not sector or sector < 1 or sector > Roue.SECTORS then
		sector = math.random(1, Roue.SECTORS)
	end

	state.scratch[player] = math.floor(sector)
end

function Roue.Resolve(state)
	local winning = math.random(1, Roue.SECTORS)

	-- La roue du decor tourne pour de vrai, si elle existe : un tour complet par
	-- secteur, plus la part qui s'arrete sur le bon. Purement cosmetique -- le
	-- resultat est deja tire.
	if state.decor and state.decor:IsA("BasePart") then
		local turns = 4 + winning / Roue.SECTORS
		TweenService:Create(
			state.decor,
			TweenInfo.new(2.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ CFrame = state.decor.CFrame * CFrame.Angles(0, math.rad(360 * turns), 0) }
		):Play()
	end

	stage(state, "minigame_stage_roue", { sector = winning })
	Sounds.PlayAt("minigame_wheel", state.zone)
	task.wait(2.4)

	local winners = {}
	for _, player in state.participants do
		if player.Parent and state.scratch[player] == winning then
			table.insert(winners, player)
		end
	end

	return split(winners)
end

--------------------------------------------------------------------------------
-- Palier 5 -- Le Wagon
--------------------------------------------------------------------------------
-- Une plateforme qui retrecit ; on gagne en tenant jusqu'au bout. Le decor
-- attendu est une plateforme isolee au-dessus du vide -- a defaut, la zone
-- elle-meme fait l'affaire, et c'est tres bien : on joue sur ce qu'il y a.

local Wagon = {}

local WAGON_STEPS = 8
local WAGON_STEP_TIME = 2.5
local WAGON_FINAL_SCALE = 0.25

function Wagon.Run(state, finish)
	local platform = (state.decor and state.decor:IsA("BasePart") and state.decor) or state.zone
	local originalSize = platform.Size
	local eliminated = {}

	for step = 1, WAGON_STEPS do
		local ratio = 1 - (1 - WAGON_FINAL_SCALE) * (step / WAGON_STEPS)

		TweenService:Create(platform, TweenInfo.new(WAGON_STEP_TIME * 0.6), {
			Size = Vector3.new(originalSize.X * ratio, originalSize.Y, originalSize.Z * ratio),
		}):Play()

		stage(
			state,
			"minigame_stage_wagon",
			{ count = #alive(state, eliminated), step = step, total = WAGON_STEPS },
			Workspace:GetServerTimeNow() + WAGON_STEP_TIME
		)

		Sounds.PlayAt("minigame_tick", state.zone, { pitch = 1 + step * 0.06 })
		task.wait(WAGON_STEP_TIME)

		-- La marge de tolerance evite d'eliminer un joueur pour un pied qui
		-- depasse pendant que la plateforme retrecit sous lui.
		for _, player in alive(state, eliminated) do
			if not standingOn(player, platform, Config.MINIGAME_ARENA_GRACE) then
				eliminated[player] = true
				Sounds.PlayAt("minigame_eliminated", state.zone)
			end
		end

		if #alive(state, eliminated) <= 1 then
			break
		end
	end

	-- La plateforme revient a sa taille : la partie suivante doit trouver le
	-- wagon comme la premiere l'a trouve.
	TweenService:Create(platform, TweenInfo.new(0.8), { Size = originalSize }):Play()

	finish(split(alive(state, eliminated)))
end

--------------------------------------------------------------------------------
-- Palier 6 -- Le Duel
--------------------------------------------------------------------------------
-- Un contre un, le plus rapide au clic sur 15 secondes. Le premier jeu ou le
-- joueur AGIT pendant la partie plutot que d'attendre un tirage.
--
-- Les clics sont comptes cote SERVEUR, et plafonnes : un client bricole qui
-- enverrait mille clics par seconde ne gagnerait rien de plus qu'un joueur qui
-- martele vite. Le plafond est genereux -- il ecarte la triche grossiere sans
-- penaliser personne.

local Duel = {}

local DUEL_TIME = 15
local DUEL_MAX_RATE = 22 -- clics par seconde retenus au maximum

-- Le client envoie des PAQUETS de clics, pas un message par clic : a quinze
-- clics par seconde et par duelliste, un message par clic saturerait le reseau
-- pour un compteur que le serveur peut additionner.
--
-- Le plafond se calcule sur le temps ecoule DEPUIS LE DEBUT, pas entre deux
-- paquets : une rafale ponctuelle passe, un flux constant impossible est coupe.
local function addClicks(score, payload, rate)
	if not score then
		return
	end

	local count = math.clamp(math.floor(tonumber(payload) or 1), 1, 16)
	local allowed = math.floor((os.clock() - score.startedAt) * rate) + 5

	score.count = math.min(score.count + count, allowed)

	return score.count
end

function Duel.Action(state, player, payload)
	addClicks(state.scratch[player], payload, DUEL_MAX_RATE)
end

function Duel.Run(state, finish)
	local startedAt = os.clock()

	for _, player in state.participants do
		state.scratch[player] = { count = 0, startedAt = startedAt }
	end

	local endsAt = Workspace:GetServerTimeNow() + DUEL_TIME
	stage(state, "minigame_stage_duel", nil, endsAt)
	Sounds.PlayAt("minigame_start", state.zone)

	-- On rafraichit le score une fois par seconde : les deux duellistes doivent
	-- voir l'ecart se creuser, sinon ils cliquent dans le vide.
	local deadline = os.clock() + DUEL_TIME

	while os.clock() < deadline do
		task.wait(1)

		local best = 0
		for _, score in state.scratch do
			best = math.max(best, score.count)
		end

		stage(state, "minigame_stage_duel", { best = best }, endsAt)
	end

	local winners, bestScore = {}, -1

	for _, player in state.participants do
		local score = state.scratch[player]
		local count = (player.Parent and score and score.count) or -1

		if count > bestScore then
			winners, bestScore = { player }, count
		elseif count == bestScore and count >= 0 then
			-- Egalite parfaite : les deux se partagent. Departager au hasard un
			-- duel ou personne n'a ete le meilleur serait une punition gratuite.
			table.insert(winners, player)
		end
	end

	finish(bestScore >= 0 and split(winners) or nil)
end

--------------------------------------------------------------------------------
-- Palier 7 -- Le Braquage
--------------------------------------------------------------------------------
-- Cooperatif : le groupe reussit ensemble ou perd tout. C'est le seul jeu du lot
-- ou les participants ne jouent pas les uns contre les autres -- et c'est ce qui
-- en fait le bon jeu du palier 7, la ou tout le monde est deja riche et ou seule
-- une perte collective fait encore peur.
--
-- L'objectif monte avec le nombre de braqueurs, mais MOINS vite qu'eux : venir
-- a plusieurs aide vraiment. Sinon personne n'irait chercher les autres.

local Braquage = {}

local BRAQUAGE_TIME = 20
local BRAQUAGE_TARGET_BASE = 120 -- coups a porter, pour le premier braqueur
local BRAQUAGE_TARGET_STEP = 70 -- ... et pour chacun des suivants
local BRAQUAGE_REWARD = 1.6 -- part de la cagnotte rendue a chacun en cas de succes
local BRAQUAGE_MAX_RATE = 22

function Braquage.Action(state, player, payload)
	local personal = state.scratch[player]
	if not personal or not state.scratch.progress then
		return
	end

	-- On compte ce qui a REELLEMENT ete retenu apres plafonnement, et non ce que
	-- le client a annonce : sinon un client bricole ferait avancer le coffre sans
	-- que son propre compteur ne bouge.
	local before = personal.count
	addClicks(personal, payload, BRAQUAGE_MAX_RATE)

	state.scratch.progress += personal.count - before
end

function Braquage.Run(state, finish)
	local crew = alive(state, {})
	local target = BRAQUAGE_TARGET_BASE + BRAQUAGE_TARGET_STEP * math.max(0, #crew - 1)

	state.scratch.progress = 0
	state.scratch.startedAt = os.clock()

	for _, player in crew do
		state.scratch[player] = { count = 0, startedAt = state.scratch.startedAt }
	end

	local endsAt = Workspace:GetServerTimeNow() + BRAQUAGE_TIME
	Sounds.PlayAt("minigame_start", state.zone)

	local deadline = os.clock() + BRAQUAGE_TIME

	while os.clock() < deadline and state.scratch.progress < target do
		stage(state, "minigame_stage_braquage", {
			progress = state.scratch.progress,
			target = target,
		}, endsAt)

		task.wait(0.5)
	end

	local won = state.scratch.progress >= target

	if won then
		Sounds.PlayAt("minigame_jackpot", state.zone)

		-- Le coffre s'ouvre, si le decor en a un.
		if state.decor and state.decor:IsA("BasePart") then
			TweenService:Create(state.decor, TweenInfo.new(0.6), {
				CFrame = state.decor.CFrame * CFrame.Angles(math.rad(-70), 0, 0),
			}):Play()

			task.delay(4, function()
				if state.decor.Parent then
					TweenService:Create(state.decor, TweenInfo.new(0.6), {
						CFrame = state.decor.CFrame * CFrame.Angles(math.rad(70), 0, 0),
					}):Play()
				end
			end)
		end

		-- Tout le monde touche, et plus que sa mise : la cagnotte n'est pas
		-- partagee entre les braqueurs, elle est multipliee pour chacun. C'est
		-- ce qui rend le braquage rentable a plusieurs -- et ruineux rate.
		local parts = {}
		for _, player in crew do
			parts[player] = BRAQUAGE_REWARD / #crew
		end

		finish(parts)
		return
	end

	stage(state, "minigame_stage_braquage_lost", { progress = state.scratch.progress, target = target })
	task.wait(1.5)
	finish(nil)
end

--------------------------------------------------------------------------------
-- Palier 8 -- Le Train de minuit
--------------------------------------------------------------------------------
-- Le sommet du jeu. Il ne se mise pas : l'embarquement est gratuit, et la
-- cagnotte est faite de la dime prelevee sur tout ce qui s'est joue aux autres
-- paliers (voir MiniGames). Un joueur du Terminus n'y paie rien -- il encaisse
-- ce que le serveur entier a produit depuis une heure.
--
-- Le tirage est pondere par le nombre de passagers : a deux, chacun a une
-- chance sur deux de tout rafler. C'est le seul endroit du jeu ou une somme
-- pareille se joue sur un coup de des, et c'est voulu -- en haut de l'echelle,
-- le drain d'1 s/s ne fait plus peur a personne, il faut que quelque chose
-- reprenne le role.

local Train = {}

function Train.Resolve(state)
	local passengers = alive(state, {})
	if #passengers == 0 then
		return nil
	end

	local winner = passengers[math.random(1, #passengers)]

	stage(state, "minigame_stage_train", { count = #passengers })
	Sounds.PlayAt("train_depart", state.zone)
	task.wait(2)

	-- L'embarquement etant gratuit, la cagnotte des mises vaut zero : on impose
	-- au cadre celle que la dime a remplie depuis une heure. C'est la seule
	-- regle du lot qui pose son propre pot, et la seule qui en ait besoin.
	state.pot = MiniGames.TrainPot()

	return { [winner] = 1 }
end

--------------------------------------------------------------------------------

function MiniGameRules.Register(framework)
	MiniGames = framework

	framework.Register("Pari", Pari)
	framework.Register("Distributeur", Distributeur)
	framework.Register("Chaises", Chaises)
	framework.Register("Roue", Roue)
	framework.Register("Wagon", Wagon)
	framework.Register("Duel", Duel)
	framework.Register("Braquage", Braquage)
	framework.Register("TrainDeMinuit", Train)
end

return MiniGameRules
