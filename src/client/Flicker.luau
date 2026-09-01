-- Les neons qui gresillent, au bas de l'immeuble.
--
-- C'est la signature sonore et visuelle du Quai : le palier 1 doit etre
-- franchement laid, et rien ne dit "sous-sol mal entretenu" comme un tube qui
-- n'arrive pas a s'allumer. Le tag ne se pose donc JAMAIS au-dessus du palier 3
-- (voir studio.md) -- un immeuble qui clignote partout ne dit plus rien.
--
-- Le tag se pose au choix sur la lumiere (PointLight, SurfaceLight, SpotLight)
-- ou sur la Part Neon qui la porte : dans Studio on selectionne ce qu'on voit,
-- et ce qu'on voit est tantot l'un tantot l'autre. Le module prend l'instance
-- taguee, ramasse la Part et les lumieres qui vont avec, et fait clignoter les
-- deux ensemble -- une Part Neon qui reste allumee pendant que sa lumiere
-- s'eteint ne trompe personne.
--
-- Tout est LOCAL. Le clignotement est un effet, pas un etat de jeu : le faire
-- calculer par le serveur couterait une replication par tube et par battement,
-- pour que tout le monde voie exactement le meme scintillement -- ce que
-- personne ne remarquerait jamais.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Flicker = {}

-- Un tube passe son temps ALLUME (c'est un neon fatigue, pas un stroboscope) et
-- decroche par salves courtes. C'est l'irregularite qui fait le sale : un
-- clignotement regulier se lit comme une intention de decor.
local ON_MIN, ON_MAX = 0.7, 4.5 -- duree d'une periode allumee
local BLINK_MIN, BLINK_MAX = 0.03, 0.11 -- duree d'un battement de salve
local BURST_MIN, BURST_MAX = 2, 7 -- nombre de battements dans une salve

-- Meme allume, le tube n'est pas franc : il respire un peu.
local ON_LEVEL_MIN, ON_LEVEL_MAX = 0.82, 1
local OFF_LEVEL_MIN, OFF_LEVEL_MAX = 0, 0.22

local LIGHT_CLASSES = {
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
}

local states = {}
local loop = nil

local function isLight(instance)
	return LIGHT_CLASSES[instance.ClassName] == true
end

-- Ce que l'instance taguee commande vraiment : la Part visible (si elle existe)
-- et toutes les lumieres attachees, qu'on ait tague l'une ou les autres.
local function collect(instance)
	local part, lights = nil, {}

	if instance:IsA("BasePart") then
		part = instance
		for _, child in instance:GetDescendants() do
			if isLight(child) then
				table.insert(lights, child)
			end
		end
	elseif isLight(instance) then
		table.insert(lights, instance)

		local parent = instance.Parent
		if parent and parent:IsA("BasePart") then
			part = parent
		end
	end

	return part, lights
end

local function apply(state, level)
	if state.part then
		-- Un Neon eteint est un tube gris, pas un tube noir : on eteint la
		-- couleur sans jamais toucher au materiau, que le decorateur a choisi.
		state.part.Color = state.partColorOff:Lerp(state.partColor, level)
	end

	for index, light in state.lights do
		if light.Parent then
			light.Brightness = state.brightness[index] * level
		end
	end

	if state.buzz then
		-- Le bourdonnement suit la lumiere : un tube au ras de l'extinction
		-- crachote, un tube allume ronronne.
		state.buzz.Volume = state.buzzVolume * (0.35 + level * 0.65)
		state.buzz.PlaybackSpeed = state.buzzPitch * (0.85 + level * 0.3)
	end
end

local function schedule(state, clock)
	if state.blinksLeft > 0 then
		-- On est dans une salve : on alterne battement eteint / battement faible
		-- jusqu'a epuisement, ce qui donne le crachotement.
		state.blinksLeft -= 1
		state.on = not state.on
		state.until_ = clock + BLINK_MIN + math.random() * (BLINK_MAX - BLINK_MIN)
	else
		state.on = true
		state.until_ = clock + ON_MIN + math.random() * (ON_MAX - ON_MIN)
		state.blinksLeft = math.random(BURST_MIN, BURST_MAX)
	end

	if state.on then
		state.level = ON_LEVEL_MIN + math.random() * (ON_LEVEL_MAX - ON_LEVEL_MIN)
	else
		state.level = OFF_LEVEL_MIN + math.random() * (OFF_LEVEL_MAX - OFF_LEVEL_MIN)
	end
end

local function detach(instance)
	local state = states[instance]
	if not state then
		return
	end

	states[instance] = nil

	if state.buzz then
		state.buzz:Destroy()
	end

	-- On rend le tube tel qu'on l'a trouve : le tag peut se retirer en direct
	-- depuis Studio, et laisser un neon eteint pour toujours serait un piege.
	apply(state, 1)
end

local function attach(instance)
	if states[instance] then
		return
	end

	local part, lights = collect(instance)
	if not part and #lights == 0 then
		return
	end

	local state = {
		part = part,
		lights = lights,
		brightness = {},
		on = true,
		level = 1,
		until_ = 0,
		blinksLeft = 0,
	}

	if part then
		state.partColor = part.Color
		state.partColorOff = part.Color:Lerp(Color3.fromRGB(28, 30, 30), 0.85)
		state.buzz = Sounds.Loop("neon_buzz", part)

		if state.buzz then
			state.buzzVolume = state.buzz.Volume
			state.buzzPitch = state.buzz.PlaybackSpeed
		end
	end

	for index, light in lights do
		state.brightness[index] = light.Brightness
	end

	states[instance] = state
	schedule(state, os.clock())
end

local function startLoop()
	if loop then
		return
	end

	loop = RunService.Heartbeat:Connect(function()
		local clock = os.clock()

		for instance, state in states do
			if not instance.Parent then
				detach(instance)
			else
				if clock >= state.until_ then
					schedule(state, clock)
				end

				apply(state, state.level)
			end
		end
	end)
end

function Flicker.Start()
	for _, instance in CollectionService:GetTagged(Config.FLICKER_TAG) do
		attach(instance)
	end

	CollectionService:GetInstanceAddedSignal(Config.FLICKER_TAG):Connect(attach)
	CollectionService:GetInstanceRemovedSignal(Config.FLICKER_TAG):Connect(detach)

	startLoop()
end

return Flicker
