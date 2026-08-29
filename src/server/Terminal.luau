-- Decor "Le Terminal" : une gare art-deco decrepite ou l'on attend un train qui ne
-- vient jamais, et ou le temps sert de monnaie.
--
-- Tout est genere en code pour rester versionne et reglable depuis les constantes
-- ci-dessous. Le decor est reconstruit a chaque demarrage dans un dossier dedie
-- (Workspace.Terminal), donc modifier ce fichier suffit -- mais toute retouche faite
-- a la main dans Studio DANS ce dossier sera ecrasee. Pour construire par-dessus,
-- pose tes propres Parts ailleurs dans Workspace, ou mets Config.BUILD_TERMINAL a false.
--
-- Le decor pose lui-meme les tags de gameplay : le tableau des departs est le
-- classement, l'horloge du hall est le cookie clicker, les guichets sont les zones
-- de pari et les cabines d'aiguillage les zones d'amelioration.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Terminal = {}

local FOLDER_NAME = "Terminal"

-- Emprise du hall. Le cote +Z est ouvert : c'est le quai et la voie.
local HALL_MIN_X, HALL_MAX_X = -90, 90
local HALL_MIN_Z, HALL_MAX_Z = -60, 45
local WALL_HEIGHT = 48
local WALL_THICKNESS = 4

local PLATFORM_Z_MIN, PLATFORM_Z_MAX = 45, 62
local PLATFORM_HEIGHT = 1.5
local RAIL_Z_MIN, RAIL_Z_MAX = 64, 100

local TILE_SIZE = 15
local TILES_MIN_X, TILES_MAX_X = -45, 45
local TILES_MIN_Z, TILES_MAX_Z = -30, 30

local PALETTE = {
	floor = Color3.fromRGB(78, 74, 72),
	tileLight = Color3.fromRGB(214, 206, 190),
	tileDark = Color3.fromRGB(52, 50, 55),
	wall = Color3.fromRGB(96, 88, 78),
	stone = Color3.fromRGB(198, 190, 176),
	brass = Color3.fromRGB(188, 146, 68),
	darkMetal = Color3.fromRGB(46, 44, 46),
	glass = Color3.fromRGB(188, 214, 234),
	warmNeon = Color3.fromRGB(255, 198, 96),
	signNeon = Color3.fromRGB(120, 220, 255),
	ballast = Color3.fromRGB(64, 60, 56),
}

local root = nil

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	-- Shape d'abord : l'ordre d'iteration d'une table n'est pas garanti, et poser
	-- Shape apres Size re-contraindrait les dimensions d'une sphere ou d'un cylindre.
	if props.Shape then
		part.Shape = props.Shape
	end

	for key, value in props do
		if key ~= "Shape" then
			part[key] = value
		end
	end

	part.Parent = root
	return part
end

-- Raccourci : une Part posee a plat, decrite par son centre et sa taille.
local function block(name, size, position, color, material)
	return newPart({
		Name = name,
		Size = size,
		CFrame = CFrame.new(position),
		Color = color,
		Material = material or Enum.Material.Concrete,
	})
end

--------------------------------------------------------------------------------
-- Sol : dalle unie, damier central, liseres de laiton
--------------------------------------------------------------------------------

local function buildFloor()
	local width = HALL_MAX_X - HALL_MIN_X
	local depth = HALL_MAX_Z - HALL_MIN_Z

	block(
		"Floor",
		Vector3.new(width, 2, depth),
		Vector3.new((HALL_MIN_X + HALL_MAX_X) / 2, -1, (HALL_MIN_Z + HALL_MAX_Z) / 2),
		PALETTE.floor,
		Enum.Material.Slate
	)

	-- Damier du hall central : deux couleurs alternees, comme un vrai dallage de gare.
	local column = 0
	for x = TILES_MIN_X, TILES_MAX_X - TILE_SIZE, TILE_SIZE do
		local row = 0
		for z = TILES_MIN_Z, TILES_MAX_Z - TILE_SIZE, TILE_SIZE do
			local color = PALETTE.tileDark
			if (column + row) % 2 == 0 then
				color = PALETTE.tileLight
			end

			block(
				"Tile",
				Vector3.new(TILE_SIZE, 0.4, TILE_SIZE),
				Vector3.new(x + TILE_SIZE / 2, 0.2, z + TILE_SIZE / 2),
				color,
				Enum.Material.Marble
			)
			row += 1
		end
		column += 1
	end

	-- Lisere de laiton autour du damier.
	local inlayWidth = TILES_MAX_X - TILES_MIN_X
	local inlayDepth = TILES_MAX_Z - TILES_MIN_Z
	local centerX = (TILES_MIN_X + TILES_MAX_X) / 2
	local centerZ = (TILES_MIN_Z + TILES_MAX_Z) / 2

	for _, z in { TILES_MIN_Z - 1, TILES_MAX_Z + 1 } do
		block("Inlay", Vector3.new(inlayWidth + 4, 0.5, 1.2), Vector3.new(centerX, 0.25, z), PALETTE.brass, Enum.Material.Metal)
	end

	for _, x in { TILES_MIN_X - 1, TILES_MAX_X + 1 } do
		block("Inlay", Vector3.new(1.2, 0.5, inlayDepth + 4), Vector3.new(x, 0.25, centerZ), PALETTE.brass, Enum.Material.Metal)
	end
end

--------------------------------------------------------------------------------
-- Murs, pilastres et verriere
--------------------------------------------------------------------------------

local function buildWalls()
	local width = HALL_MAX_X - HALL_MIN_X
	local depth = HALL_MAX_Z - HALL_MIN_Z
	local centerX = (HALL_MIN_X + HALL_MAX_X) / 2
	local centerZ = (HALL_MIN_Z + HALL_MAX_Z) / 2

	-- Mur du fond (cote -Z) : c'est lui qui porte le tableau des departs.
	block(
		"BackWall",
		Vector3.new(width + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(centerX, WALL_HEIGHT / 2, HALL_MIN_Z - WALL_THICKNESS / 2),
		PALETTE.wall,
		Enum.Material.Brick
	)

	-- Murs lateraux.
	for _, x in { HALL_MIN_X - WALL_THICKNESS / 2, HALL_MAX_X + WALL_THICKNESS / 2 } do
		block(
			"SideWall",
			Vector3.new(WALL_THICKNESS, WALL_HEIGHT, depth),
			Vector3.new(x, WALL_HEIGHT / 2, centerZ),
			PALETTE.wall,
			Enum.Material.Brick
		)
	end
end

local function buildPillars()
	-- Colles aux murs : le mobilier (guichets, cabines, lampadaires) occupe la bande
	-- juste en dedans, il ne faut pas que les colonnes viennent s'y encastrer.
	for _, x in { HALL_MIN_X + 12, HALL_MAX_X - 12 } do
		for z = HALL_MIN_Z + 15, HALL_MAX_Z - 5, 24 do
			block("Pillar", Vector3.new(6, WALL_HEIGHT, 6), Vector3.new(x, WALL_HEIGHT / 2, z), PALETTE.stone, Enum.Material.Marble)

			-- Chapiteau + base, pour casser le cote "poteau nu".
			block("PillarCap", Vector3.new(8, 2, 8), Vector3.new(x, WALL_HEIGHT - 1, z), PALETTE.brass, Enum.Material.Metal)
			block("PillarBase", Vector3.new(8, 2.5, 8), Vector3.new(x, 1.25, z), PALETTE.stone, Enum.Material.Marble)
		end
	end
end

-- Verriere : les panneaux ne projettent pas d'ombre (la lumiere inonde le hall),
-- mais les nervures metalliques si -> on obtient des rayures de lumiere au sol.
local function buildRoof()
	local width = HALL_MAX_X - HALL_MIN_X
	local centerX = (HALL_MIN_X + HALL_MAX_X) / 2

	for z = HALL_MIN_Z, HALL_MAX_Z - 15, 15 do
		newPart({
			Name = "GlassPanel",
			Size = Vector3.new(width, 1, 15),
			CFrame = CFrame.new(centerX, WALL_HEIGHT, z + 7.5),
			Color = PALETTE.glass,
			Material = Enum.Material.Glass,
			Transparency = 0.75,
			CastShadow = false,
		})

		block("Rib", Vector3.new(width, 2.5, 1.5), Vector3.new(centerX, WALL_HEIGHT + 0.5, z), PALETTE.darkMetal, Enum.Material.Metal)
	end

	-- Nervures longitudinales.
	for _, x in { -60, -30, 0, 30, 60 } do
		block(
			"RibLong",
			Vector3.new(1.5, 2.5, HALL_MAX_Z - HALL_MIN_Z),
			Vector3.new(x, WALL_HEIGHT + 0.5, (HALL_MIN_Z + HALL_MAX_Z) / 2),
			PALETTE.darkMetal,
			Enum.Material.Metal
		)
	end
end

--------------------------------------------------------------------------------
-- Quai et voie : la ou le train n'arrive jamais
--------------------------------------------------------------------------------

local function buildPlatform()
	local width = HALL_MAX_X - HALL_MIN_X
	local centerX = (HALL_MIN_X + HALL_MAX_X) / 2
	local platformDepth = PLATFORM_Z_MAX - PLATFORM_Z_MIN

	block(
		"Platform",
		Vector3.new(width, PLATFORM_HEIGHT * 2, platformDepth),
		Vector3.new(centerX, 0, (PLATFORM_Z_MIN + PLATFORM_Z_MAX) / 2),
		PALETTE.stone,
		Enum.Material.Concrete
	)

	-- Bande jaune de securite le long du bord.
	block(
		"PlatformEdge",
		Vector3.new(width, 0.3, 2),
		Vector3.new(centerX, PLATFORM_HEIGHT + 0.15, PLATFORM_Z_MAX - 1.5),
		PALETTE.warmNeon,
		Enum.Material.Neon
	)

	-- Ballast + rails qui filent dans le noir.
	block(
		"Ballast",
		Vector3.new(width, 2, RAIL_Z_MAX - RAIL_Z_MIN),
		Vector3.new(centerX, -1, (RAIL_Z_MIN + RAIL_Z_MAX) / 2),
		PALETTE.ballast,
		Enum.Material.Rock
	)

	for _, x in { -8, 8 } do
		block(
			"Rail",
			Vector3.new(1, 1, RAIL_Z_MAX - RAIL_Z_MIN),
			Vector3.new(x, 0.5, (RAIL_Z_MIN + RAIL_Z_MAX) / 2),
			PALETTE.darkMetal,
			Enum.Material.Metal
		)
	end

	for z = RAIL_Z_MIN, RAIL_Z_MAX - 6, 6 do
		block("Sleeper", Vector3.new(24, 0.6, 2), Vector3.new(0, 0.1, z + 3), Color3.fromRGB(70, 54, 42), Enum.Material.Wood)
	end
end

--------------------------------------------------------------------------------
-- Mobilier et lumieres
--------------------------------------------------------------------------------

local function buildBench(position)
	block("BenchSeat", Vector3.new(14, 0.8, 4), position + Vector3.new(0, 2.5, 0), Color3.fromRGB(88, 62, 44), Enum.Material.Wood)
	block("BenchBack", Vector3.new(14, 4, 0.8), position + Vector3.new(0, 4.5, -1.6), Color3.fromRGB(88, 62, 44), Enum.Material.Wood)

	for _, offset in { -6, 6 } do
		block("BenchLeg", Vector3.new(0.8, 2.5, 4), position + Vector3.new(offset, 1.25, 0), PALETTE.darkMetal, Enum.Material.Metal)
	end
end

local function buildLamp(position)
	block("LampPost", Vector3.new(0.8, 14, 0.8), position + Vector3.new(0, 7, 0), PALETTE.brass, Enum.Material.Metal)

	local globe = newPart({
		Name = "LampGlobe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 15, 0)),
		Color = PALETTE.warmNeon,
		Material = Enum.Material.Neon,
	})

	local light = Instance.new("PointLight")
	light.Color = PALETTE.warmNeon
	light.Brightness = 2.5
	light.Range = 34
	light.Parent = globe
end

local function buildFurniture()
	for _, z in { -20, 5, 30 } do
		buildBench(Vector3.new(-30, 0, z))
		buildBench(Vector3.new(30, 0, z))
	end

	for _, x in { -70, -20, 20, 70 } do
		for _, z in { -40, 0, 38 } do
			buildLamp(Vector3.new(x, 0, z))
		end
	end
end

--------------------------------------------------------------------------------
-- Elements de gameplay : le decor porte lui-meme les tags
--------------------------------------------------------------------------------

-- Le tableau des departs = le classement. La face Front d'une Part regarde -Z,
-- donc on la retourne pour qu'elle fasse face au hall.
local function buildDepartureBoard()
	-- Le cadre est place DERRIERE le tableau : devant, il masquerait le SurfaceGui.
	block("BoardFrame", Vector3.new(64, 30, 1), Vector3.new(0, 26, HALL_MIN_Z + 0.5), PALETTE.brass, Enum.Material.Metal)

	local board = newPart({
		Name = "DepartureBoard",
		Size = Vector3.new(60, 26, 1.5),
		CFrame = CFrame.new(0, 26, HALL_MIN_Z + 1.5) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(18, 18, 22),
		Material = Enum.Material.SmoothPlastic,
	})

	CollectionService:AddTag(board, Config.BOARD_TAG)
	return board
end

-- L'horloge monumentale du hall = le cookie clicker. Un cylindre couche sur l'axe Y
-- forme un cadran ; le socle le monte a hauteur de clic (16 studs max).
local function buildCentralClock()
	-- Cadran volontairement bas : le ClickDetector porte a CLICKER_MAX_DISTANCE
	-- (16 studs), donc une horloge perchee en haut d'une colonne serait injouable.
	block("ClockPlinth", Vector3.new(11, 2, 11), Vector3.new(0, 1, 0), PALETTE.stone, Enum.Material.Marble)
	block("ClockColumn", Vector3.new(7, 6, 7), Vector3.new(0, 5, 0), PALETTE.stone, Enum.Material.Marble)

	local ring = newPart({
		Name = "ClockRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 16, 16),
		CFrame = CFrame.new(0, 12, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = PALETTE.warmNeon,
		Material = Enum.Material.Neon,
	})

	local glow = Instance.new("PointLight")
	glow.Color = PALETTE.warmNeon
	glow.Brightness = 3
	glow.Range = 45
	glow.Parent = ring

	local face = newPart({
		Name = "TerminalClock",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 14, 14),
		CFrame = CFrame.new(0, 12, 0.6) * CFrame.Angles(0, math.pi / 2, 0),
		Color = PALETTE.brass,
		Material = Enum.Material.Metal,
	})

	CollectionService:AddTag(face, Config.CLICKER_TAG)
	return face
end

-- Les guichets = les zones de pari. Chaque comptoir a sa mise, du petit change
-- au bureau clandestin du fond.
local function buildTicketBooths()
	local booths = {
		{ z = -30, amount = 20 },
		{ z = 0, amount = 300 },
		{ z = 30, amount = 3600 },
	}

	for _, booth in booths do
		local x = HALL_MIN_X + 34

		block("BoothCounter", Vector3.new(4, 6, 16), Vector3.new(x - 8, 3, booth.z), Color3.fromRGB(74, 52, 38), Enum.Material.Wood)
		block("BoothTop", Vector3.new(6, 0.6, 18), Vector3.new(x - 8, 6.3, booth.z), PALETTE.brass, Enum.Material.Metal)

		local pad = newPart({
			Name = "TicketBooth",
			Size = Vector3.new(12, 0.6, 12),
			CFrame = CFrame.new(x, 0.3, booth.z),
			Color = Color3.fromRGB(32, 30, 34),
			Material = Enum.Material.SmoothPlastic,
		})

		pad:SetAttribute("BetAmount", booth.amount)
		CollectionService:AddTag(pad, Config.BET_TAG)
	end
end

-- Les cabines d'aiguillage = les zones d'amelioration du clic.
local function buildSignalCabins()
	for _, z in { -18, 18 } do
		local x = HALL_MAX_X - 34

		block("CabinBody", Vector3.new(10, 12, 10), Vector3.new(x + 8, 6, z), Color3.fromRGB(60, 70, 62), Enum.Material.Metal)
		block("CabinRoof", Vector3.new(13, 1, 13), Vector3.new(x + 8, 12.5, z), PALETTE.darkMetal, Enum.Material.Metal)
		block("CabinLamp", Vector3.new(2, 2, 2), Vector3.new(x + 8, 14, z), PALETTE.signNeon, Enum.Material.Neon)

		local pad = newPart({
			Name = "SignalCabin",
			Size = Vector3.new(12, 0.6, 12),
			CFrame = CFrame.new(x, 0.3, z),
			Color = Color3.fromRGB(30, 38, 34),
			Material = Enum.Material.SmoothPlastic,
		})

		CollectionService:AddTag(pad, Config.UPGRADE_TAG)
	end
end

local function buildOrbs()
	local spots = {
		Vector3.new(-70, 4, -50),
		Vector3.new(70, 4, -50),
		Vector3.new(-50, 4, 40),
		Vector3.new(50, 4, 40),
		Vector3.new(0, 4, -45),
		Vector3.new(0, 4, 52),
	}

	for _, spot in spots do
		local orb = newPart({
			Name = "TimeOrb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(spot),
			Color = PALETTE.signNeon,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})

		local light = Instance.new("PointLight")
		light.Color = PALETTE.signNeon
		light.Brightness = 2
		light.Range = 18
		light.Parent = orb

		CollectionService:AddTag(orb, Config.ORB_TAG)
	end
end

local function buildSpawn()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TerminalSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, 34)
	spawn.Color = PALETTE.stone
	spawn.Material = Enum.Material.Marble
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Parent = root
end

--------------------------------------------------------------------------------

function Terminal.Build()
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	root = Instance.new("Folder")
	root.Name = FOLDER_NAME
	root.Parent = Workspace

	buildFloor()
	buildWalls()
	buildPillars()
	buildRoof()
	buildPlatform()
	buildFurniture()

	buildDepartureBoard()
	buildCentralClock()
	buildTicketBooths()
	buildSignalCabins()
	buildOrbs()
	buildSpawn()
end

return Terminal
