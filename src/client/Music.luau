-- Playlist : les morceaux du jeu, enchaines en boucle et dans un ordre aleatoire.
--
-- IMPORTANT -- Roblox ne lit AUCUN fichier local. Les .mp3 poses a la racine du
-- projet ne sont pas jouables tels quels, et Rojo ne les synchronise pas : il ne
-- transporte que du code. Chaque piste doit d'abord etre importee dans Roblox
-- (Studio -> vue Asset Manager -> Audio -> clic droit -> Add Audio, ou bien
-- creator.roblox.com -> Creations -> Audio). L'import passe par une moderation,
-- puis Roblox te rend un ID -- c'est cet ID qui va dans SoundLibrary.Playlist.
--
-- Tant qu'une piste n'a pas d'ID, elle est simplement ignoree : la playlist joue
-- ce qu'elle a, et ne joue rien du tout si elle n'a rien. Aucune erreur.
--
-- Ordre de lecture : un melange complet (Fisher-Yates), puis toutes les pistes
-- s'enchainent avant qu'on remelange. C'est ce qu'un auditeur appelle "au
-- hasard" -- un vrai tirage independant a chaque fois rejouerait la meme piste
-- deux fois de suite assez souvent pour qu'on croie a un bug. On evite meme le
-- doublon a la couture entre deux melanges.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundLibrary = require(ReplicatedStorage.Shared.SoundLibrary)

local Music = {}

local FADE_SPEED = 1.2 -- vitesse du fondu au volume (par seconde)

-- Un asset qui ne charge pas (ID faux, moderation en cours, reseau coupe) ne
-- declenche jamais Ended. Sans ce delai de garde, la playlist se figerait
-- dessus pour toujours au lieu de passer au morceau suivant.
local LOAD_TIMEOUT = 10
local POLL_INTERVAL = 0.25

local sound
local queue = {}
local lastPlayed = nil

local currentVolume = 0
local targetVolume = 0
local trackVolume = 1 -- volume propre au morceau en cours, avant fondu

local dead = false

-- Vrai entre le lancement d'un morceau et sa fin. C'est l'intention de la
-- playlist, pas l'etat du Sound : pendant l'ecran de mort le morceau est en
-- pause alors que playing reste vrai, et c'est ce qui permet de le reprendre.
-- Sans ce drapeau, le fondu relancerait le morceau qui vient de se terminer,
-- dans le court intervalle avant que le suivant demarre.
local playing = false

local function lerp(a, b, t)
	return a + (b - a) * t
end

--------------------------------------------------------------------------------
-- Ordre de lecture
--------------------------------------------------------------------------------

local function refillQueue()
	queue = {}

	for _, track in SoundLibrary.Playlist do
		if track.id ~= "" then
			table.insert(queue, track)
		end
	end

	for i = #queue, 2, -1 do
		local j = math.random(i)
		queue[i], queue[j] = queue[j], queue[i]
	end

	-- On tire par la fin (table.remove sans index), donc la derniere case est la
	-- prochaine jouee : si c'est celle qui vient de passer, on l'echange. Sans
	-- ca, la couture entre deux melanges pourrait doubler un morceau.
	if #queue > 1 and queue[#queue] == lastPlayed then
		queue[#queue], queue[1] = queue[1], queue[#queue]
	end
end

local function nextTrack()
	if #queue == 0 then
		refillQueue()
	end

	local track = table.remove(queue)
	lastPlayed = track
	return track
end

--------------------------------------------------------------------------------
-- Lecture
--------------------------------------------------------------------------------

-- Attend la fin du morceau. Rend la main aussi si le morceau ne demarre jamais
-- (voir LOAD_TIMEOUT). Un morceau en pause n'avance pas : sa fin est repoussee
-- aussi longtemps qu'il reste en pause, ce qui est exactement le comportement
-- voulu pendant l'ecran de mort.
--
-- Renvoie false quand on est sorti par le delai de garde, c'est-a-dire quand le
-- morceau n'a jamais joue.
local function waitForEnd()
	local ended = false
	local connection = sound.Ended:Once(function()
		-- Des la fin reelle, et non a la sortie de la boucle : le fondu tourne en
		-- parallele et ne doit pas voir un morceau fini comme un morceau a relancer.
		playing = false
		ended = true
	end)

	local deadline = os.clock() + LOAD_TIMEOUT

	repeat
		task.wait(POLL_INTERVAL)

		if sound.IsLoaded and sound.TimeLength > 0 then
			deadline = os.clock() + (sound.TimeLength - sound.TimePosition) + 1
		end
	until ended or os.clock() > deadline

	connection:Disconnect()
	playing = false

	return ended
end

function Music.Start()
	if not Config.SOUND_ENABLED or not Config.MUSIC_ENABLED then
		return
	end

	sound = Instance.new("Sound")
	sound.Name = "Music"
	-- Pas de Looped : c'est la fin d'un morceau qui appelle le suivant. La
	-- "boucle" est celle de la playlist entiere, pas celle d'une piste.
	sound.Looped = false
	sound.Volume = 0
	sound.Parent = SoundService

	-- Le fondu tourne a part : il doit continuer a lisser le volume pendant que
	-- la boucle de lecture, elle, attend la fin du morceau.
	RunService.Heartbeat:Connect(function(deltaTime)
		currentVolume = lerp(currentVolume, targetVolume, math.min(1, deltaTime * FADE_SPEED))
		sound.Volume = currentVolume

		-- On ne coupe vraiment le son qu'une fois le fondu arrive au bout, sinon
		-- la mort claquerait au lieu de s'estomper.
		if dead and currentVolume < 0.005 and sound.IsPlaying then
			sound:Pause()
		elseif not dead and playing and not sound.IsPlaying then
			sound:Resume()
		end
	end)

	task.spawn(function()
		while true do
			local track = nextTrack()

			if not track then
				-- Aucune piste renseignee : inutile de tourner dans le vide.
				warn("TimeOut: aucune musique dans SoundLibrary.Playlist -- importe tes .mp3 dans Roblox et colle leurs ID")
				return
			end

			trackVolume = track.volume or 1
			targetVolume = dead and 0 or trackVolume * Config.MUSIC_VOLUME

			sound.SoundId = track.id
			sound:Play()
			playing = true

			-- Le nom, pas seulement l'ID : quand une piste refuse de jouer, on veut
			-- savoir laquelle sans avoir a decoder un nombre a quinze chiffres.
			if not waitForEnd() then
				warn(string.format("TimeOut: musique injouable, on passe -- %s (%s)", track.name, track.id))
			end
		end
	end)
end

-- Mort : le morceau s'estompe puis se met en pause, il ne redemarre pas de zero
-- au retour en jeu -- on reprend la ou on en etait.
function Music.SetDead(isDead)
	dead = isDead
	targetVolume = isDead and 0 or trackVolume * Config.MUSIC_VOLUME
end

return Music
