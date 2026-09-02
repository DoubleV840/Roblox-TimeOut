-- Objet cliquable facon "cookie clicker" : chaque clic donne du temps, avec un
-- petit rebond et un "+Xs" flottant pour le feedback. Pose n'importe quelle Part
-- taguee Config.CLICKER_TAG au centre du lobby.
--
-- CE QUI ENTRE DANS UN CLIC, dans cet ordre (voir clickValue) :
--
--   data.ClickBase        1 s, ou 2 s avec la carte "Bielle" (lot 3)
--   x data.ClickPower     le Chrono Boost, la progression de fond
--   x le palier            le multiplicateur de gains ACTIFS (lot 1)
--   x Poids du temps       power-up du palier 6 : riche quand on est riche
--   x Frenesie             power-up du palier 5 : x5 pendant 20 s
--   x Critique             power-up du palier 3 : x10, une fois de temps en temps
--
-- Puis deux effets qui ne changent pas la valeur du clic mais ce qu'il declenche :
--   Echo (palier 4)      le clic se REPETE 0,4 s plus tard, a une fraction
--   Rouages (palier 7)   le clic ajoute du carburant a l'auto-cliqueur
--
-- L'ordre n'a aucune importance (ce sont des facteurs), mais la LISTE en a une :
-- c'est la seule facon de voir d'un coup d'oeil tout ce qui touche au geste le
-- plus repete du jeu. Rien d'autre ne doit s'y ajouter sans passer par ici.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PowerUps = require(ReplicatedStorage.Shared.PowerUps)
local PlayerData = require(script.Parent.PlayerData)
local ClickChampion = require(script.Parent.ClickChampion)
local TierService = require(script.Parent.TierService)
local Boons = require(script.Parent.Boons)

local TimeCookie = {}

local CRITICAL_COLOR = Color3.fromRGB(255, 215, 70)

local function popFeedback(part, amount, critical)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(4, 0, 2, 0) -- en studs : taille fixe dans le monde
	billboard.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Fonts.Main
	label.TextScaled = true
	label.Text = "+" .. amount .. "s"
	label.Parent = billboard

	if critical then
		-- Un clic critique doit se VOIR : c'est le seul retour que le joueur ait
		-- sur un power-up dont l'effet est, par nature, intermittent. Dore, plus
		-- gros, et agite au maximum.
		billboard.Size = UDim2.new(6.5, 0, 3.2, 0)
		label.Text = "+" .. amount .. "s !"
		TextFx.Mark(label, 1, CRITICAL_COLOR)
	else
		-- Plus le clic rapporte, plus le "+Xs" part en vrille (sature vers +20s).
		local punch = math.clamp(amount / 20, 0, 1)
		TextFx.Mark(label, punch, Color3.fromRGB(255, 221, 0):Lerp(Color3.fromRGB(255, 90, 200), punch))
	end

	TweenService:Create(billboard, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = billboard.StudsOffset + Vector3.new(0, 2, 0),
	}):Play()

	TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
	}):Play()

	task.delay(0.6, function()
		billboard:Destroy()
	end)
end

-- [part] = { target = Instance, property = string, original = Vector3 }
local bounceTargets = {}

-- Une Part qui porte un Mesh (accessoire, modele importe) ignore Part.Size au
-- rendu : c'est Mesh.Scale qui commande. On repere donc, une fois pour toutes,
-- la propriete qui fait vraiment bouger l'objet a l'ecran.
local function registerBounce(part)
	local mesh = part:FindFirstChildWhichIsA("DataModelMesh")

	if mesh then
		bounceTargets[part] = { target = mesh, property = "Scale", original = mesh.Scale }
	else
		bounceTargets[part] = { target = part, property = "Size", original = part.Size }
	end
end

local function bounce(part)
	local info = bounceTargets[part]
	if not info then
		return
	end

	TweenService:Create(info.target, TweenInfo.new(0.08), { [info.property] = info.original * 0.9 }):Play()

	task.delay(0.08, function()
		TweenService:Create(
			info.target,
			TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ [info.property] = info.original }
		):Play()
	end)
end

-- [part] = { count = clics enchaines, at = os.clock() du dernier }
--
-- La cadence est celle de la PART, pas d'un joueur : trois personnes qui
-- martelent le meme cookie font monter la gamme ensemble, ce qui est exactement
-- l'effet recherche autour d'un objet partage.
local combos = {}

local function comboPitch(part)
	local combo = combos[part]
	local now = os.clock()

	if not combo or now - combo.at > Config.SOUND_COMBO_RESET then
		combo = { count = 0, at = now }
		combos[part] = combo
	end

	combo.at = now
	combo.count = math.min(combo.count + 1, Config.SOUND_COMBO_MAX)

	return Config.SOUND_COMBO_BASE_PITCH + combo.count * Config.SOUND_COMBO_STEP
end

--------------------------------------------------------------------------------
-- Ce que vaut un clic
--------------------------------------------------------------------------------

-- Renvoie le gain, et si le clic etait CRITIQUE (pour que le retour visuel le
-- montre : un x10 qui ne se voit pas ne recompense rien).
--
-- Arrondi a la seconde, avec un plancher a 1 : un clic ne rapporte jamais rien.
local function clickValue(player, data)
	local base = data.ClickBase or Config.CLICKER_REWARD

	-- Le palier multiplie ce que rapporte le GESTE, pas le chrono : c'est toute
	-- la difference entre monter d'etage et acheter un auto-cliqueur.
	local value = base * data.ClickPower * TierService.Multiplier(player)

	value *= PowerUps.WeightFactor(PowerUps.Level(data, PowerUps.WEIGHT), data.TimeLeft)

	if Boons.Active(player, Config.BOON_FRENZY) then
		value *= PowerUps.Get(PowerUps.FRENZY).multiplier
	end

	local critical = false
	local critLevel = PowerUps.Level(data, PowerUps.CRIT)

	if critLevel > 0 and math.random() < PowerUps.CritChance(critLevel) then
		critical = true
		value *= PowerUps.Get(PowerUps.CRIT).multiplier
	end

	return math.max(1, math.round(value)), critical
end

-- Poser le gain, et tout ce qui va avec. Deux appelants : le clic lui-meme, et
-- l'echo qui le repete -- d'ou une fonction plutot qu'un bloc en ligne.
local function award(player, data, part, amount, critical)
	data.TimeLeft += amount
	PlayerData.NoteTime(data)
	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	ClickChampion.NoteClick(player, amount)

	-- Rouages : le clic a la main finance la source passive. Il ne remplit que
	-- le RESERVOIR, jamais le debit -- le niveau de l'auto-cliqueur reste la
	-- seule chose du jeu qui ne s'obtienne qu'en Robux. Et il ne remplit rien du
	-- tout tant qu'il n'y a pas de machine a alimenter.
	local gearsLevel = PowerUps.Level(data, PowerUps.GEARS)

	if gearsLevel > 0 and (data.AutoClickers or 0) > 0 then
		data.AutoClickFuel = (data.AutoClickFuel or 0) + PowerUps.GearsFuel(gearsLevel)
	end

	bounce(part)
	popFeedback(part, amount, critical)

	Sounds.PlayAt("cookie_click", part, { pitch = comboPitch(part) })

	if critical then
		Sounds.PlayAt("cookie_critical", part)
	end

	-- Couche grave ajoutee par-dessus le "tic" quand le clic rapporte gros.
	if amount >= Config.SOUND_BIG_CLICK then
		Sounds.PlayAt("cookie_click_big", part)
	end
end

local function setupCookie(part)
	if not part:IsA("BasePart") then
		return
	end

	part.Anchored = true
	registerBounce(part)
	Sounds.Loop("cookie_idle", part)

	local clickDetector = part:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = Config.CLICKER_MAX_DISTANCE
	clickDetector.Parent = part

	clickDetector.MouseClick:Connect(function(player)
		local data = PlayerData.Get(player)
		if not data then
			return
		end

		local amount, critical = clickValue(player, data)
		award(player, data, part, amount, critical)

		-- Echo : le clic se repete un instant plus tard, a une fraction de sa
		-- valeur. Le second gain N'EST PAS re-echo -- sans quoi un seul clic
		-- rebondirait indefiniment, chaque niveau du power-up rapprochant un peu
		-- plus la chaine de l'infini.
		local echoLevel = PowerUps.Level(data, PowerUps.ECHO)

		if echoLevel > 0 then
			local echoAmount = math.max(1, math.round(amount * PowerUps.EchoShare(echoLevel)))
			local delay = PowerUps.Get(PowerUps.ECHO).delay

			task.delay(delay, function()
				-- Le joueur a pu partir, ou mourir, entre les deux : on relit ses
				-- donnees plutot que de faire confiance a la fermeture.
				local current = PlayerData.Get(player)
				if current == data and part.Parent then
					award(player, data, part, echoAmount, false)
				end
			end)
		end
	end)
end

function TimeCookie.Start()
	for _, part in CollectionService:GetTagged(Config.CLICKER_TAG) do
		setupCookie(part)
	end

	CollectionService:GetInstanceAddedSignal(Config.CLICKER_TAG):Connect(setupCookie)
end

return TimeCookie
