-- Fait tourner sur eux-memes les objets tagues (le cookie de temps).
-- La vitesse est dans Config.SPIN_DEGREES_PER_SECOND.
--
-- Cote client, comme TextFx : une rotation continue pilotee par le serveur
-- repliquerait un CFrame a chaque frame pour chaque objet. Ici ca ne coute rien
-- en reseau, et l'angle etant calcule a partir du temps ecoule, la rotation ne
-- derive jamais meme si des frames sautent.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Spin = {}

-- [part] = son CFrame d'origine, autour duquel on tourne.
local spinning = {}

local function add(part)
	if spinning[part] or not part:IsA("BasePart") then
		return
	end

	spinning[part] = part.CFrame
end

local function remove(part)
	spinning[part] = nil
end

local loop = nil

-- Accepte plusieurs tags (le cookie, et le panneau du maitre du clic pose
-- au-dessus de lui). Tout tourne du meme angle, calcule a partir de la meme
-- horloge : les objets restent donc rigoureusement en phase.
function Spin.Bind(...)
	for _, tag in { ... } do
		for _, part in CollectionService:GetTagged(tag) do
			add(part)
		end

		CollectionService:GetInstanceAddedSignal(tag):Connect(add)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
	end

	-- Une seule boucle, quel que soit le nombre de tags.
	if loop then
		return
	end

	loop = RunService.RenderStepped:Connect(function()
		local angle = math.rad(Config.SPIN_DEGREES_PER_SECOND) * os.clock()

		for part, base in spinning do
			if part.Parent then
				-- Rotation autour de l'axe Y de l'objet. Pour un disque qui fait face
				-- au joueur, mettre l'angle sur le 3e argument (axe Z) a la place.
				part.CFrame = base * CFrame.Angles(0, angle, 0)
			else
				spinning[part] = nil
			end
		end
	end)
end

return Spin
