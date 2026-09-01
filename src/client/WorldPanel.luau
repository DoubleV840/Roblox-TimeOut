-- La SurfaceGui plaquee sur une Part du monde, cote CLIENT.
--
-- Deux systemes en ont besoin -- les barrieres (etape 4) et les vitres (etape
-- 10) -- et pour la meme raison : ce qui est ecrit dessus n'est pas le meme
-- pour deux joueurs cote a cote. L'un lit "OUVERT", l'autre le prix, le
-- troisieme ce qui lui manque. Un panneau ecrit par le serveur serait partage
-- par tout le monde, ne pourrait dire qu'une seule de ces choses, et l'ecrirait
-- dans une seule langue.
--
-- La SurfaceGui posee dans Studio, elle, ne sert qu'a UNE chose : dire quelle
-- FACE de la Part regarde les joueurs. On l'eteint et on adopte sa face. Sans
-- elle, le panneau se pose sur la face avant -- mal oriente peut-etre, mais une
-- Part muette serait pire.
--
-- Le panneau vit dans le PlayerGui, pas dans le Workspace : une SurfaceGui
-- laissee dans le Workspace ne recoit pas les clics. C'est Adornee qui la
-- recolle sur la Part.

local Players = game:GetService("Players")

local WorldPanel = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local DEFAULT_PIXELS_PER_STUD = 40
local DEFAULT_MAX_DISTANCE = 200

function WorldPanel.Surface(part, name, options)
	options = options or {}

	local face = Enum.NormalId.Front
	local placed = part:FindFirstChildOfClass("SurfaceGui")
	if placed then
		face = placed.Face
		placed.Enabled = false
	end

	local surface = Instance.new("SurfaceGui")
	-- Le DebugId distingue deux panneaux du meme systeme sans avoir a compter.
	surface.Name = name .. "_" .. part:GetDebugId()
	surface.Adornee = part
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = options.pixelsPerStud or DEFAULT_PIXELS_PER_STUD
	surface.LightInfluence = 0
	surface.AlwaysOnTop = false
	surface.ResetOnSpawn = false
	surface.MaxDistance = options.maxDistance or DEFAULT_MAX_DISTANCE
	surface.Parent = playerGui

	return surface
end

return WorldPanel
