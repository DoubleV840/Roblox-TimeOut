-- Anime le texte des panneaux : la couleur ondule, le label se balance et son
-- contour respire. L'intensite (0..1) dit a quel point l'effet est marque, pour
-- qu'une grosse mise ou un joueur bien classe bouge beaucoup plus qu'une valeur
-- insignifiante.
--
-- Le serveur se contente de MARQUER les labels (TextFx.Mark) ; toute l'animation
-- tourne cote client sur les instances repliquees. Les proprietes changees par un
-- client ne remontent jamais au serveur, donc ca ne coute rien en reseau et chaque
-- joueur voit l'animation tourner de son cote.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TextFx = {}

TextFx.TAG = "AnimatedText"
TextFx.INTENSITY_ATTRIBUTE = "FxIntensity"
TextFx.COLOR_ATTRIBUTE = "FxColor"

local BASE_STROKE = 1.6
local MAX_SWAY_DEGREES = 2.5

local states = {}
local loop = nil

local function updateState(state, clock)
	local label = state.label
	local intensity = math.clamp(label:GetAttribute(TextFx.INTENSITY_ATTRIBUTE) or 0, 0, 1)
	local base = label:GetAttribute(TextFx.COLOR_ATTRIBUTE) or label.TextColor3

	-- Le seed decale chaque label : sans lui tout le panneau ondulerait a l'unisson.
	local phase = clock * (1.2 + intensity * 3.5) + state.seed
	local wave = math.sin(phase)
	local swell = wave * 0.5 + 0.5

	local hue, saturation, value = base:ToHSV()
	label.TextColor3 = Color3.fromHSV(
		(hue + wave * 0.12 * intensity) % 1,
		math.clamp(saturation - wave * 0.1 * intensity, 0, 1),
		math.clamp(value + swell * 0.25 * intensity, 0, 1)
	)

	label.Rotation = state.baseRotation + math.sin(phase * 0.6) * MAX_SWAY_DEGREES * intensity
	state.stroke.Thickness = BASE_STROKE + swell * 1.4 * intensity
end

function TextFx.Detach(label)
	local state = states[label]
	if not state then
		return
	end

	state.label.Rotation = state.baseRotation
	states[label] = nil
end

local function attach(label)
	if states[label] then
		return
	end

	if not (label:IsA("TextLabel") or label:IsA("TextButton")) then
		return
	end

	local stroke = label:FindFirstChild("FxStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "FxStroke"
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 0.3
		stroke.Thickness = BASE_STROKE
		stroke.Parent = label
	end

	states[label] = {
		label = label,
		stroke = stroke,
		baseRotation = label.Rotation,
		seed = math.random() * 100,
	}
end

local function startLoop()
	if loop then
		return
	end

	loop = RunService.Heartbeat:Connect(function()
		local clock = os.clock()

		for label, state in states do
			if label.Parent then
				updateState(state, clock)
			else
				TextFx.Detach(label)
			end
		end
	end)
end

-- A appeler une fois cote client : reprend tous les labels marques, presents ou a venir.
function TextFx.Bind()
	for _, label in CollectionService:GetTagged(TextFx.TAG) do
		attach(label)
	end

	CollectionService:GetInstanceAddedSignal(TextFx.TAG):Connect(attach)
	CollectionService:GetInstanceRemovedSignal(TextFx.TAG):Connect(TextFx.Detach)

	startLoop()
end

-- Marque un label comme anime. Appelable des deux cotes ; reappeler avec les memes
-- valeurs ne declenche aucune replication, donc c'est sans risque dans un refresh.
function TextFx.Mark(label, intensity, color)
	label:SetAttribute(TextFx.INTENSITY_ATTRIBUTE, math.clamp(intensity, 0, 1))

	if color then
		label:SetAttribute(TextFx.COLOR_ATTRIBUTE, color)
		label.TextColor3 = color
	end

	CollectionService:AddTag(label, TextFx.TAG)
end

return TextFx
