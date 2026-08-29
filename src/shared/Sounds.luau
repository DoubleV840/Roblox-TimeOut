-- Lecteur de sons partage serveur/client. Le code de jeu ne manipule jamais un
-- Instance.new("Sound") : il demande un NOM d'evenement (voir SoundLibrary) et ce
-- module s'occupe du reste -- reglages, variation de pitch, menage.
--
-- Trois facons de jouer :
--   Sounds.Play(name)          -- 2D, dans la tete du joueur. CLIENT UNIQUEMENT :
--                                 appele sur le serveur, tout le monde l'entendrait.
--   Sounds.PlayAt(name, part)  -- 3D, pose sur un objet du monde. Appele cote
--                                 serveur, tous les joueurs proches l'entendent.
--   Sounds.Loop(name, part)    -- nappe bouclee, rendue a l'appelant pour qu'il
--                                 puisse la regler ou l'arreter plus tard.
--
-- Les trois renvoient nil quand l'evenement est muet (id vide, son coupe dans
-- Config) : c'est un cas NORMAL, pas une erreur -- les appelants s'y attendent.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundLibrary = require(ReplicatedStorage.Shared.SoundLibrary)

local Sounds = {}

local DEFAULT_VOLUME = 0.5
local DEFAULT_RANGE = 80
local MIN_RANGE = 8 -- en deca, le son est a plein volume

-- Filet de securite : un one-shot est detruit au plus tard apres ce delai, meme
-- si l'evenement Ended n'arrive jamais (asset introuvable, son jamais charge).
local CLEANUP_TIMEOUT = 12

local unknownWarned = {}

local function definition(name)
	local def = SoundLibrary.List[name]

	if not def then
		-- Une faute de frappe dans un nom d'evenement ne doit pas casser le jeu,
		-- mais elle doit se voir dans la console. Une seule fois par nom.
		if not unknownWarned[name] then
			unknownWarned[name] = true
			warn("TimeOut: son inconnu -> " .. tostring(name))
		end
		return nil
	end

	if not Config.SOUND_ENABLED or def.id == "" then
		return nil
	end

	if def.music and not Config.MUSIC_ENABLED then
		return nil
	end

	return def
end

-- Cree le Sound configure et le parente, sans le lancer. Sert aux nappes qu'on
-- veut regler avant de les demarrer.
function Sounds.New(name, parent, options)
	local def = definition(name)
	if not def then
		return nil
	end

	options = options or {}

	local sound = Instance.new("Sound")
	sound.Name = "Sfx_" .. name
	sound.SoundId = def.id

	local master = def.music and Config.MUSIC_VOLUME or Config.SFX_VOLUME
	sound.Volume = math.max(0, (options.volume or def.volume or DEFAULT_VOLUME) * master)

	local pitch = options.pitch or def.pitch or 1
	local jitter = options.jitter or def.jitter or 0
	if jitter > 0 then
		pitch *= 1 + (math.random() * 2 - 1) * jitter
	end
	sound.PlaybackSpeed = math.max(0.05, pitch)

	sound.Looped = options.looped or def.looped or false

	-- Reglages 3D. Ignores par le moteur quand le son n'est pas dans une Part
	-- (SoundService), donc rien a conditionner ici.
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = MIN_RANGE
	sound.RollOffMaxDistance = options.range or def.range or DEFAULT_RANGE

	sound.Parent = parent or SoundService

	return sound
end

local function playOnce(sound)
	sound:Play()

	-- On se debarrasse du Sound des qu'il a fini : sans ca, marteler le cookie
	-- laisserait des centaines d'instances mortes accrochees a la Part.
	sound.Ended:Once(function()
		sound:Destroy()
	end)

	Debris:AddItem(sound, CLEANUP_TIMEOUT)

	return sound
end

-- 2D : joue dans SoundService, sans position. A n'appeler que cote client.
function Sounds.Play(name, options)
	local sound = Sounds.New(name, SoundService, options)
	if not sound then
		return nil
	end

	return playOnce(sound)
end

-- 3D : joue depuis un objet du monde. Cote serveur, tous les joueurs a portee
-- l'entendent ; cote client, seulement celui qui le joue.
function Sounds.PlayAt(name, part, options)
	if not part or not part.Parent then
		return nil
	end

	local sound = Sounds.New(name, part, options)
	if not sound then
		return nil
	end

	return playOnce(sound)
end

-- Nappe bouclee. Renvoyee a l'appelant : c'est lui qui la garde, la regle
-- (Volume, PlaybackSpeed) et la detruit le moment venu.
function Sounds.Loop(name, parent, options)
	options = options or {}
	options.looped = true

	local sound = Sounds.New(name, parent, options)
	if not sound then
		return nil
	end

	sound:Play()

	return sound
end

-- Precharge les assets pour que le premier clic ne tombe pas dans le vide, le
-- temps que Roblox telecharge le son. A appeler une fois, cote client.
function Sounds.Preload()
	task.spawn(function()
		local holder = Instance.new("Folder")
		local seen = {}
		local queue = {}

		for _, def in SoundLibrary.List do
			if def.id ~= "" and not seen[def.id] then
				seen[def.id] = true

				local probe = Instance.new("Sound")
				probe.SoundId = def.id
				probe.Parent = holder
				table.insert(queue, probe)
			end
		end

		if #queue > 0 then
			pcall(function()
				ContentProvider:PreloadAsync(queue)
			end)
		end

		holder:Destroy()
	end)
end

return Sounds
