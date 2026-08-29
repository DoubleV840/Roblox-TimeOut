-- Cadre lumineux qui suit le perimetre d'une zone (les 4 bords du dessus), avec
-- des particules qui montent le long de chaque bord. Sert a rendre visible de loin
-- une zone au sol sur laquelle il se passe quelque chose : paris, guichets.
--
-- L'intensite (0..1) commande la hauteur des bords, la taille et le debit des
-- particules -- une petite zone reste sage, une grosse hurle de loin.

local TweenService = game:GetService("TweenService")

local ZoneAura = {}

local BORDER_THICKNESS = 0.3
local BORDER_MIN_HEIGHT = 0.3
local BORDER_MAX_HEIGHT = 2.5

local function createBorderPart(zone, offset, size, color)
	local part = Instance.new("Part")
	part.Name = "AuraBorder"
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.CFrame = zone.CFrame * offset
	part.Parent = zone
	return part
end

function ZoneAura.Create(zone, color, intensity)
	local factor = math.clamp(intensity, 0, 1)
	local borderHeight = BORDER_MIN_HEIGHT + (BORDER_MAX_HEIGHT - BORDER_MIN_HEIGHT) * factor

	local halfX = zone.Size.X / 2
	local halfZ = zone.Size.Z / 2
	local topY = zone.Size.Y / 2 + borderHeight / 2

	local borders = {
		createBorderPart(zone, CFrame.new(0, topY, -halfZ), Vector3.new(zone.Size.X, borderHeight, BORDER_THICKNESS), color),
		createBorderPart(zone, CFrame.new(0, topY, halfZ), Vector3.new(zone.Size.X, borderHeight, BORDER_THICKNESS), color),
		createBorderPart(zone, CFrame.new(-halfX, topY, 0), Vector3.new(BORDER_THICKNESS, borderHeight, zone.Size.Z), color),
		createBorderPart(zone, CFrame.new(halfX, topY, 0), Vector3.new(BORDER_THICKNESS, borderHeight, zone.Size.Z), color),
	}

	for _, border in borders do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(color)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3 + factor * 0.4),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(2 + factor * 3, 4 + factor * 4)
		emitter.Rate = 10 + factor * 40
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-30, 30)
		emitter.Acceleration = Vector3.new(0, 2, 0)
		emitter.LightEmission = 1
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Parent = border

		TweenService:Create(
			border,
			TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.5 }
		):Play()
	end

	return borders
end

return ZoneAura
