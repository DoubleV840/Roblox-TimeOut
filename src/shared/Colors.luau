local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Colors = {}

Colors.INFO = Color3.fromRGB(255, 221, 0)
Colors.WIN = Color3.fromRGB(60, 220, 60)
Colors.LOSE = Color3.fromRGB(220, 60, 60)

-- Le degrade du chrono : rouge quand la mort approche, vert quand on respire.
--
-- Le HUD du joueur et le panneau au-dessus des AUTRES joueurs doivent lire la
-- meme echelle -- c'est ce qui permet de reperer d'un coup d'oeil qui est en
-- train de mourir dans un hall plein. Deux degrades voisins mais differents
-- rendraient la lecture inutilisable.
Colors.TIME_LOW = Color3.fromRGB(220, 50, 50)
Colors.TIME_HIGH = Color3.fromRGB(80, 220, 120)

-- 0 = a l'agonie, 1 = confortable. Le reperage se fait sur le temps de depart :
-- au-dela, tout est vert, et c'est tres bien -- un joueur a 40 h n'est pas
-- "moins en danger" qu'un joueur a 20 h, ils sont tous les deux hors de danger.
function Colors.TimeFactor(seconds)
	return math.clamp(seconds / Config.BASE_TIME, 0, 1)
end

function Colors.ForTime(seconds)
	return Colors.TIME_LOW:Lerp(Colors.TIME_HIGH, Colors.TimeFactor(seconds))
end

return Colors
