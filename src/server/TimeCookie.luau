-- Objet cliquable facon "cookie clicker" : chaque clic donne Config.CLICKER_REWARD * ClickPower
-- secondes, avec un petit rebond et un "+Xs" flottant pour le feedback.
-- Pose n'importe quelle Part taguee Config.CLICKER_TAG au centre du lobby.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PlayerData = require(script.Parent.PlayerData)
local ClickChampion = require(script.Parent.ClickChampion)
local TierService = require(script.Parent.TierService)

local TimeCookie = {}

local function popFeedback(part, amount)
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

	-- Plus le clic rapporte, plus le "+Xs" part en vrille (sature vers +20s/clic).
	local punch = math.clamp(amount / 20, 0, 1)
	TextFx.Mark(label, punch, Color3.fromRGB(255, 221, 0):Lerp(Color3.fromRGB(255, 90, 200), punch))

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

		-- Le palier multiplie ce que rapporte le GESTE, pas le chrono : c'est
		-- toute la difference entre monter d'etage et acheter un auto-cliqueur.
		-- Arrondi a la seconde, avec un plancher a 1 : un clic ne rapporte
		-- jamais rien.
		local amount = math.max(
			1,
			math.round(Config.CLICKER_REWARD * data.ClickPower * TierService.Multiplier(player))
		)
		data.TimeLeft += amount
		PlayerData.NoteTime(data)
		Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
		ClickChampion.NoteClick(player, amount)

		bounce(part)
		popFeedback(part, amount)

		Sounds.PlayAt("cookie_click", part, { pitch = comboPitch(part) })

		-- Couche grave ajoutee par-dessus le "tic" quand le clic rapporte gros.
		if amount >= Config.SOUND_BIG_CLICK then
			Sounds.PlayAt("cookie_click_big", part)
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
