-- Les huit mini-jeux, un par palier : ce que chaque etage ajoute a jouer.
--
-- Ce fichier ne contient AUCUNE regle -- seulement ce que le serveur et le
-- client doivent savoir tous les deux : le nom, le palier requis, la mise par
-- defaut, la couleur, et la forme de la partie. Les regles (qui gagne, comment)
-- vivent dans src/server/MiniGameRules.luau ; le cadre commun (entrer, miser,
-- decompter, rembourser, payer) dans src/server/MiniGames.luau.
--
-- POURQUOI UN CADRE COMMUN. Sept jeux ecrits chacun dans leur coin, ce sont sept
-- facons de gerer une mise, sept remboursements a ne pas oublier, sept HUD. Le
-- cadre fait tout ca une fois ; une regle n'a plus qu'a designer un gagnant.
-- C'est l'etape 24, et c'est le vrai travail du lot.
--
-- Les valeurs "bet" sont des ordres de grandeur, reglables zone par zone avec
-- l'attribut BetAmount dans Studio -- le plan les veut croissantes avec l'etage,
-- parce que c'est en haut de l'echelle que la peur de mourir doit se rejouer :
-- le drain d'1 s/s ne fait plus peur a personne au Terminus.

local MiniGameList = {}

-- La forme d'une partie. Le cadre en deduit tout le reste.
--   SOLO   -- le joueur mise et le sort tranche aussitot ; personne a attendre
--   DRAW   -- on s'inscrit, un decompte tourne, puis un tirage designe le gagnant
--   ARENA  -- meme inscription, puis une PHASE ACTIVE ou l'on joue vraiment
MiniGameList.KIND_SOLO = "Solo"
MiniGameList.KIND_DRAW = "Draw"
MiniGameList.KIND_ARENA = "Arena"

MiniGameList.List = {
	{
		-- Le pari d'origine (plan.md). Il devient le mini-jeu du Quai et le
		-- premier client du cadre commun : les zones deja posees dans Studio
		-- (tag BetZone) continuent de marcher sans etre retouchees.
		key = "Pari",
		minTier = 1,
		bet = 20,
		kind = MiniGameList.KIND_DRAW,
		minPlayers = 2,
		color = Color3.fromRGB(255, 150, 60),
	},
	{
		-- Machine a sous SOLO : pas de synchronisation entre joueurs, donc c'est
		-- lui qui valide le cadre avant les six autres.
		key = "Distributeur",
		minTier = 2,
		bet = 60,
		kind = MiniGameList.KIND_SOLO,
		minPlayers = 1,
		color = Color3.fromRGB(235, 235, 235),
	},
	{
		key = "Chaises",
		minTier = 3,
		bet = 5 * 60,
		kind = MiniGameList.KIND_ARENA,
		minPlayers = 2,
		color = Color3.fromRGB(90, 220, 120),
	},
	{
		key = "Roue",
		minTier = 4,
		bet = 30 * 60,
		kind = MiniGameList.KIND_DRAW,
		minPlayers = 1,
		-- Chacun mise sur un secteur avant le lancer : c'est le seul jeu ou l'on
		-- choisit quelque chose au moment de s'inscrire.
		sectors = true,
		color = Color3.fromRGB(80, 205, 235),
	},
	{
		key = "Wagon",
		minTier = 5,
		bet = 3 * 3600,
		kind = MiniGameList.KIND_ARENA,
		minPlayers = 2,
		color = Color3.fromRGB(95, 145, 255),
	},
	{
		key = "Duel",
		minTier = 6,
		bet = 6 * 3600,
		kind = MiniGameList.KIND_ARENA,
		minPlayers = 2,
		-- Un contre un : au-dela de deux inscrits, les autres attendent le tour
		-- suivant plutot que de faire un duel a cinq.
		maxPlayers = 2,
		clicks = true,
		color = Color3.fromRGB(175, 110, 255),
	},
	{
		key = "Braquage",
		minTier = 7,
		bet = 30 * 3600,
		kind = MiniGameList.KIND_ARENA,
		minPlayers = 2,
		-- Cooperatif : le groupe reussit ensemble ou perd tout. C'est le seul jeu
		-- ou les participants ne jouent pas les uns contre les autres.
		coop = true,
		clicks = true,
		color = Color3.fromRGB(255, 175, 55),
	},
	{
		-- Le sommet du jeu. Il ne s'ouvre pas quand on entre dans la zone : il
		-- part tout seul, une fois par heure, et sa cagnotte est alimentee par
		-- une dime prelevee sur tous les autres mini-jeux.
		key = "TrainDeMinuit",
		minTier = 8,
		bet = 0,
		kind = MiniGameList.KIND_DRAW,
		minPlayers = 1,
		scheduled = true,
		color = Color3.fromRGB(255, 225, 90),
	},
}

local byKey = {}
for index, game in MiniGameList.List do
	game.index = index
	byKey[game.key] = game
end

function MiniGameList.Get(key)
	return byKey[key]
end

-- Le jeu du Quai, celui que portent les zones BetZone deja posees dans Studio.
MiniGameList.DEFAULT = MiniGameList.List[1]

return MiniGameList
