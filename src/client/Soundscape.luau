-- Bande-son continue, pilotee par le temps qu'il reste au joueur -- le pendant
-- sonore d'Ambience, avec la meme logique : tout est local, chacun entend son
-- propre chrono, et rien ne transite par le reseau.
--
-- Deux couches commandees par le temps restant (1 = plein, 0 = a sec) :
--   alertes : une alarme au franchissement de chaque palier, puis un vrai
--             compte a rebours sur les dernieres secondes ;
--   coeur   : un battement de plus en plus rapide, cale sur le meme seuil que
--             la pulsation de l'image.
--
-- Volontairement pas de tic-tac permanent : le chrono ne se rappelle a l'oreille
-- qu'aux paliers et sur la fin. Entre les deux, c'est l'image qui parle.
--
-- Ce module tient aussi la playlist (voir Music.luau), mais sans la piloter : la
-- musique tourne pour elle-meme, il ne lui transmet que la mort et la reprise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Music = require(script.Parent.Music)

local Soundscape = {}

-- Vitesse a laquelle le facteur courant rattrape sa cible (par seconde). C'est
-- lui qui evite qu'un gros gain de temps fasse sauter le coeur d'un coup.
local FACTOR_FADE_SPEED = 1.75
local AUTOCLICK_FADE_SPEED = 1.5

-- Le pitch du bip de compte a rebours monte a l'approche de zero.
local COUNTDOWN_PITCH_LOW = 1.05
local COUNTDOWN_PITCH_HIGH = 1.8

-- 1 = plein de temps, 0 = a sec. Comme dans Ambience, on garde une valeur
-- courante distincte de la cible pour que tout se fasse en fondu.
local targetFactor = 1
local currentFactor = 1

local displayTime = Config.BASE_TIME
local lastWholeSecond = math.floor(Config.BASE_TIME)
local dead = false

-- Paliers deja franchis pour cette vie. Un palier se "rearme" tout seul des que
-- le joueur repasse au-dessus : reprendre du temps puis le reperdre resonne.
local firedWarnings = {}

local heartbeatClock = 0

local autoClickHum
local autoClickHumBase = 0
local autoClickTarget = 0
local autoClickCurrent = 0

local function lerp(a, b, t)
	return a + (b - a) * t
end

--------------------------------------------------------------------------------
-- Alertes et compte a rebours
--------------------------------------------------------------------------------

-- Un palier ne sonne que si on l'a franchi en s'ecoulant. Un saut brutal (une
-- arrivee en jeu, un pari perdu) traverserait plusieurs paliers d'un coup et
-- declencherait une rafale d'alarmes : on se contente alors de les armer.
local WARNING_MAX_STEP = 2

local function updateWarnings(timeLeft, previous)
	local flowed = previous - timeLeft < WARNING_MAX_STEP

	for _, threshold in Config.SOUND_WARNING_THRESHOLDS do
		if timeLeft > threshold then
			firedWarnings[threshold] = nil
		elseif not firedWarnings[threshold] then
			firedWarnings[threshold] = true

			if flowed and previous > threshold then
				Sounds.Play("clock_warning")
			end
		end
	end
end

-- Un bip par seconde entiere franchie, mais UNIQUEMENT sur la toute fin. Pas de
-- tic-tac de fond le reste du temps : un son qui revient chaque seconde pendant
-- des minutes, on cesse de l'entendre et il ne reste que l'agacement.
local function onSecondPassed(timeLeft)
	if timeLeft <= 0 or timeLeft > Config.SOUND_COUNTDOWN_FROM then
		return
	end

	local closeness = 1 - timeLeft / Config.SOUND_COUNTDOWN_FROM
	Sounds.Play("countdown_beep", { pitch = lerp(COUNTDOWN_PITCH_LOW, COUNTDOWN_PITCH_HIGH, closeness) })
end

--------------------------------------------------------------------------------
-- Battement de coeur
--------------------------------------------------------------------------------

local function updateHeartbeat(deltaTime)
	if dead or currentFactor >= Config.SOUND_HEARTBEAT_FACTOR then
		heartbeatClock = 0
		return
	end

	local urgency = 1 - currentFactor / Config.SOUND_HEARTBEAT_FACTOR
	local interval = lerp(Config.SOUND_HEARTBEAT_SLOW, Config.SOUND_HEARTBEAT_FAST, urgency)

	heartbeatClock += deltaTime
	if heartbeatClock < interval then
		return
	end

	heartbeatClock = 0
	Sounds.Play("heartbeat", {
		volume = 0.12 + urgency * 0.3,
		pitch = 1.25 + urgency * 0.35,
	})
end

--------------------------------------------------------------------------------
-- Nappes
--------------------------------------------------------------------------------

local function updateAutoClickHum(deltaTime)
	if not autoClickHum then
		return
	end

	autoClickCurrent = lerp(autoClickCurrent, dead and 0 or autoClickTarget, math.min(1, deltaTime * AUTOCLICK_FADE_SPEED))
	autoClickHum.Volume = autoClickHumBase * autoClickCurrent
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

-- Appele a chaque frame par le HUD, avec le temps interpole localement.
function Soundscape.SetTime(timeLeft, factor)
	targetFactor = math.clamp(factor, 0, 1)

	local previous = displayTime
	displayTime = timeLeft

	if dead then
		return
	end

	updateWarnings(timeLeft, previous)

	local whole = math.floor(timeLeft)
	if whole < lastWholeSecond then
		-- Le chrono peut sauter de plusieurs secondes (gain, remise a zero) :
		-- on ne joue qu'un seul tic, pas une rafale.
		onSecondPassed(timeLeft)
	end
	lastWholeSecond = whole
end

-- Mort : on coupe tout ce qui suit le chrono. La reprise (Recommencer, ou du
-- temps rachete) rearme les paliers d'alerte pour la vie suivante.
function Soundscape.SetDead(isDead)
	dead = isDead

	-- La playlist s'estompe puis se met en pause. Elle reprend au meme endroit du
	-- meme morceau au retour en jeu : mourir ne relance pas la musique a zero.
	Music.SetDead(isDead)

	if isDead then
		heartbeatClock = 0
		return
	end

	firedWarnings = {}
	lastWholeSecond = math.floor(displayTime)
end

-- Niveau d'auto-cliqueur possede : le bourdonnement monte d'un cran a chaque
-- palier, et se fait entendre d'autant plus fort qu'on en a achete.
function Soundscape.SetAutoClickLevel(level)
	if level <= 0 then
		autoClickTarget = 0
		return
	end

	if not autoClickHum then
		autoClickHum = Sounds.Loop("autoclick_hum", SoundService)
		if not autoClickHum then
			return
		end

		autoClickHumBase = autoClickHum.Volume
		autoClickHum.Volume = 0
	end

	autoClickTarget = math.min(1, level / 4)
	autoClickHum.PlaybackSpeed = 1 + math.min(level, 10) * 0.09
end

function Soundscape.Start()
	Music.Start()

	RunService.RenderStepped:Connect(function(deltaTime)
		currentFactor = lerp(currentFactor, targetFactor, math.min(1, deltaTime * FACTOR_FADE_SPEED))

		updateAutoClickHum(deltaTime)
		updateHeartbeat(deltaTime)
	end)
end

return Soundscape
