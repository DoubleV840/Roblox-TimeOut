-- Ambiance lumineuse pilotee par le temps qu'il reste au joueur.
--
-- Tout est fait COTE CLIENT : Lighting est local a chaque joueur, donc chacun voit
-- sa propre ambiance sans que ca affecte les autres (et sans un octet de reseau).
--
-- On reste dans la journee d'un bout a l'autre : le soleil ne se couche jamais
-- vraiment, il descend.
--
-- Beaucoup de temps -> plein midi, lumiere neutre, aucun effet marque : c'est
--   l'etat "normal", il ne doit pas attirer l'oeil.
-- Presque plus de temps -> soir, soleil rasant, l'air se charge, tout se teinte
--   d'orange et l'image bat comme un coeur.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Ambience = {}

-- Midi franc. Volontairement fade : pas de teinte, pas de contraste ajoute, bloom
-- discret -- avoir du temps, c'est juste "rien de special".
local CALM = {
	clockTime = 12,
	brightness = 2.8,
	ambient = Color3.fromRGB(105, 108, 115),
	outdoorAmbient = Color3.fromRGB(150, 152, 158),
	fogEnd = 1200,
	fogColor = Color3.fromRGB(200, 212, 228),
	atmosphereDensity = 0.2,
	atmosphereHaze = 0.9,
	atmosphereColor = Color3.fromRGB(210, 222, 238),
	tint = Color3.fromRGB(255, 255, 255),
	saturation = 0.02,
	contrast = 0,
	bloomIntensity = 0.3,
	bloomThreshold = 1.2,
}

-- Fin de journee : 17.6 garde le soleil au-dessus de l'horizon (il se couche a 18),
-- donc on a la lumiere rasante et les ombres longues sans jamais basculer dans la nuit.
local PANIC = {
	clockTime = 17.6,
	brightness = 2,
	ambient = Color3.fromRGB(72, 58, 58),
	outdoorAmbient = Color3.fromRGB(112, 84, 74),
	fogEnd = 380,
	fogColor = Color3.fromRGB(150, 96, 70),
	atmosphereDensity = 0.4,
	atmosphereHaze = 2.4,
	atmosphereColor = Color3.fromRGB(190, 120, 85),
	tint = Color3.fromRGB(255, 218, 205),
	saturation = -0.12,
	contrast = 0.18,
	bloomIntensity = 1,
	bloomThreshold = 0.9,
}

-- En dessous de ce ratio de temps, l'image se met a battre comme un coeur.
local PULSE_THRESHOLD = 0.2
local TRANSITION_SPEED = 1.8 -- vitesse de rattrapage vers la cible (par seconde)

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Parent = Lighting

local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
colorCorrection.Parent = Lighting

local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Parent = Lighting

-- 1 = plein de temps, 0 = a sec. On garde une valeur courante distincte de la cible
-- pour que gagner un pari fasse un fondu au lieu d'un saut brutal.
local targetFactor = 1
local currentFactor = 1

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function apply(factor, pulse)
	Lighting.ClockTime = lerp(PANIC.clockTime, CALM.clockTime, factor)
	Lighting.Brightness = lerp(PANIC.brightness, CALM.brightness, factor)
	Lighting.Ambient = PANIC.ambient:Lerp(CALM.ambient, factor)
	Lighting.OutdoorAmbient = PANIC.outdoorAmbient:Lerp(CALM.outdoorAmbient, factor)
	Lighting.FogEnd = lerp(PANIC.fogEnd, CALM.fogEnd, factor)
	Lighting.FogColor = PANIC.fogColor:Lerp(CALM.fogColor, factor)

	atmosphere.Density = lerp(PANIC.atmosphereDensity, CALM.atmosphereDensity, factor)
	atmosphere.Haze = lerp(PANIC.atmosphereHaze, CALM.atmosphereHaze, factor)
	atmosphere.Color = PANIC.atmosphereColor:Lerp(CALM.atmosphereColor, factor)

	colorCorrection.TintColor = PANIC.tint:Lerp(CALM.tint, factor)
	colorCorrection.Saturation = lerp(PANIC.saturation, CALM.saturation, factor)
	colorCorrection.Contrast = lerp(PANIC.contrast, CALM.contrast, factor) + pulse * 0.16
	colorCorrection.Brightness = pulse * 0.07

	bloom.Intensity = lerp(PANIC.bloomIntensity, CALM.bloomIntensity, factor) + pulse * 0.5
	bloom.Threshold = lerp(PANIC.bloomThreshold, CALM.bloomThreshold, factor)
end

-- factor : 0 (plus de temps) a 1 (temps confortable)
function Ambience.SetTimeFactor(factor)
	targetFactor = math.clamp(factor, 0, 1)
end

function Ambience.Start()
	apply(currentFactor, 0)

	RunService.RenderStepped:Connect(function(deltaTime)
		currentFactor = lerp(currentFactor, targetFactor, math.min(1, deltaTime * TRANSITION_SPEED))

		-- Battement de coeur : d'autant plus rapide et marque qu'on est proche de 0.
		local pulse = 0
		if currentFactor < PULSE_THRESHOLD then
			local urgency = 1 - currentFactor / PULSE_THRESHOLD
			local beat = math.sin(os.clock() * (7 + urgency * 7))
			pulse = math.max(0, beat) ^ 3 * urgency
		end

		apply(currentFactor, pulse)
	end)
end

return Ambience
