local Config = {}

Config.BASE_TIME = 300 -- temps de depart, en secondes (5 minutes)
Config.TICK_RATE = 1 -- periode de la boucle serveur (le temps retire est le delai reellement ecoule ; le client interpole les millisecondes entre deux ticks)
Config.DATASTORE_NAME = "TimeOutPlayerData_v1"
Config.AUTOSAVE_INTERVAL = 60 -- sauvegarde automatique toutes les 60 secondes

-- Vitesse de marche des joueurs, en studs/seconde (defaut Roblox : 16).
-- Appliquee au demarrage du serveur par src/server/Movement.luau.
Config.WALK_SPEED = 24

Config.ORB_TAG = "TimeOrb" -- nom du tag CollectionService a mettre sur les parts en jeu
Config.ORB_TIME_BONUS = 10 -- secondes gagnees au contact
Config.ORB_COOLDOWN = 10 -- secondes entre la prise d'une orbe et sa reapparition

Config.LEADERBOARD_DATASTORE_NAME = "TimeOutLeaderboard_v1"
Config.LEADERBOARD_SIZE = 10 -- nombre de joueurs affiches sur le panneau
Config.LEADERBOARD_REFRESH_INTERVAL = 60 -- secondes entre rafraichissements (classement all-time, DataStore)
Config.LIVE_BOARD_REFRESH_INTERVAL = 3 -- secondes entre rafraichissements (classement en direct, en memoire)
Config.BOARD_TAG = "HallOfFameBoard" -- tag a mettre sur la Part qui affiche le classement

Config.TIME_BALANCE_DATASTORE_NAME = "TimeOutTimeBalance_v1"
Config.TIME_BALANCE_SYNC_INTERVAL = 5 -- secondes entre chaque sauvegarde du temps courant (pour les joueurs deco)

Config.BET_TAG = "BetZone" -- tag a mettre sur la Part qui sert de zone de pari
Config.BET_AMOUNT = 20 -- secondes misees par joueur pour participer
Config.BET_JOIN_WINDOW = 15 -- secondes d'attente avant le tirage, une fois le 1er parieur inscrit
Config.BET_MIN_PLAYERS = 2 -- minimum de parieurs pour lancer le tirage (sinon tout le monde est rembourse)

Config.CLICKER_TAG = "TimeCookie" -- tag a mettre sur l'objet cliquable du lobby
Config.CLICKER_REWARD = 1 -- secondes gagnees par clic (avant multiplicateur ClickPower)
Config.CLICKER_MAX_DISTANCE = 16 -- distance max (studs) pour pouvoir cliquer dessus

Config.UPGRADE_TAG = "ClickUpgrade" -- tag a mettre sur l'objet d'amelioration

-- Panneau du "maitre du clic", pose au-dessus de chaque TimeCookie.
-- SPIN_TAG marque ce que le client doit faire tourner en phase avec le cookie ;
-- le panneau se le pose lui-meme, il n'y a rien a taguer a la main.
Config.SPIN_TAG = "SpinsWithCookie"
Config.SPIN_DEGREES_PER_SECOND = 90 -- vitesse de rotation du cookie (un tour toutes les 4 secondes)
Config.CHAMPION_REFRESH_INTERVAL = 2 -- secondes entre deux mises a jour du panneau
Config.CHAMPION_CLICK_WINDOW = 8 -- fenetre (secondes) sur laquelle on mesure la cadence de clic a la main

-- Decor "Le Terminal" genere en code (voir src/server/Terminal.luau).
-- Desactive : la map se construit a la main dans Studio. Repasse a true pour
-- regenerer le decor de reference (il ecrase le dossier Workspace.Terminal).
Config.BUILD_TERMINAL = false
Config.UPGRADE_BASE_COST = 30 -- cout (en secondes) du 1er niveau d'amelioration
Config.UPGRADE_GROWTH = 1.5 -- multiplicateur de cout a chaque niveau achete

Config.SHOP_TAG = "ShopZone" -- tag a mettre sur la Part qui sert de guichet (achats Robux)
Config.PURCHASE_DATASTORE_NAME = "TimeOutPurchases_v1" -- receipts deja honores (anti double-credit)

-- Un guichet vend soit du temps, soit des auto-cliqueurs. Mets un attribut texte
-- "ShopKind" sur la Part : "Time" (defaut) ou "AutoClick".
Config.SHOP_KIND_ATTRIBUTE = "ShopKind"
Config.SHOP_KIND_TIME = "Time"
Config.SHOP_KIND_AUTOCLICK = "AutoClick"

-- Paquets de temps vendus contre des Robux, dans l'ordre d'affichage.
--
-- productId : l'ID du Developer Product cree dans le Creator Dashboard
--   (Monetization -> Developer Products). Tant qu'il vaut 0, le paquet est
--   ignore : le guichet ne l'affiche pas et le serveur refuse de le vendre.
-- robux : uniquement pour l'affichage. Le vrai prix est celui du Dashboard ;
--   si tu le changes la-bas, pense a le recopier ici.
--
-- Le prix a la seconde s'ameliore a chaque palier (de ~72 s/R$ a ~257 s/R$) :
-- acheter gros doit rester le bon calcul, sinon personne ne monte l'echelle.
Config.TIME_PRODUCTS = {
	{ productId = 3710398713, seconds = 30 * 60, robux = 25 },
	{ productId = 3710398861, seconds = 2 * 3600, robux = 79 },
	{ productId = 3710399067, seconds = 10 * 3600, robux = 299 },
	{ productId = 3710399112, seconds = 24 * 3600, robux = 599 },
	{ productId = 3710399143, seconds = 100 * 3600, robux = 1999 },
	{ productId = 3710399196, seconds = 500 * 3600, robux = 7999 },
	{ productId = 3710399229, seconds = 1000 * 3600, robux = 13999 },
}

-- Auto-cliqueur : source de temps passive, TOTALEMENT independante du clic a la
-- main. Ni Config.CLICKER_REWARD ni le Chrono Boost (ClickPower) n'y touchent --
-- ameliorer ses clics n'ameliore pas l'auto-cliqueur, et inversement.
--
-- Un seul Developer Product, rachetable a l'infini et a prix fixe : chaque achat
-- DOUBLE le debit.
--   1er achat -> AUTOCLICK_BASE_RATE      (1 s/sec)
--   2e        -> x2                       (2 s/sec)
--   3e        -> x4                       (4 s/sec)   et ainsi de suite.
--
-- Equilibrage a garder en tete : le chrono descend d'1 seconde par seconde, donc
-- des le PREMIER achat le joueur ne perd plus de temps du tout. Le prix devrait
-- donc se situer vers le haut de l'echelle des paquets, pas vers le bas.
Config.AUTOCLICK_PRODUCT = { productId = 3710399391, robux = 999 }
Config.AUTOCLICK_BASE_RATE = 1 -- secondes gagnees par seconde, au 1er achat
Config.AUTOCLICK_GROWTH = 2 -- multiplicateur du debit a chaque achat suivant
Config.AUTOCLICK_INTERVAL = 1 -- periode de la boucle (le temps credite suit le delai reellement ecoule)

-- Paris verrouilles : une zone ne s'ouvre au joueur qu'une fois qu'il a possede
-- au moins sa mise sur son propre chrono -- et elle reste ouverte pour toujours.
-- Le seuil vaut la mise de la zone ; un attribut numerique "UnlockAt" (en
-- secondes) sur la Part permet d'en imposer un autre.
Config.BET_UNLOCK_ATTRIBUTE = "UnlockAt"
Config.BET_LOCK_REFRESH_INTERVAL = 2 -- secondes entre deux verifications de deverrouillage

--------------------------------------------------------------------------------
-- Son
--------------------------------------------------------------------------------
-- Ici, uniquement les interrupteurs et les seuils. Les sons eux-memes (ID des
-- assets, volume, pitch de chaque evenement) vivent dans src/shared/SoundLibrary.

Config.SOUND_ENABLED = true -- false coupe TOUT le son, bruitages compris
Config.MUSIC_ENABLED = true -- false ne coupe que les nappes musicales
Config.SFX_VOLUME = 1 -- multiplicateur global des bruitages (0..1)
Config.MUSIC_VOLUME = 0.35 -- multiplicateur global des musiques (0..1)

-- Paliers d'alerte, en secondes : une alarme sonne quand le chrono passe sous
-- chacun d'eux, une seule fois par palier et par vie.
Config.SOUND_WARNING_THRESHOLDS = { 120, 60, 30 }

-- Sous ce seuil (en secondes), le tic-tac devient un vrai compte a rebours :
-- un bip par seconde, de plus en plus aigu.
Config.SOUND_COUNTDOWN_FROM = 10

-- Le battement de coeur suit la pulsation de l'image (voir Ambience) : il
-- demarre au meme seuil, et son intervalle va du plus lent au plus rapide selon
-- l'urgence.
Config.SOUND_HEARTBEAT_FACTOR = 0.2
Config.SOUND_HEARTBEAT_SLOW = 1.05 -- secondes entre deux battements, au seuil
Config.SOUND_HEARTBEAT_FAST = 0.38 -- secondes entre deux battements, a zero

-- Cadence de clic. Le "tic" du cookie part deja tres haut (son aigu, voulu :
-- c'est le son le plus entendu du jeu), et la cadence le fait monter encore --
-- mais pas indefiniment, sinon on finirait dans les ultrasons.
Config.SOUND_COMBO_BASE_PITCH = 1.8 -- pitch de base du tic, avant tout enchainement
Config.SOUND_COMBO_MAX = 12 -- clics enchaines au-dela desquels le pitch ne monte plus
Config.SOUND_COMBO_STEP = 0.04 -- pitch gagne par clic enchaine (jusqu'a 2.28 au plafond)
Config.SOUND_COMBO_RESET = 1.1 -- secondes sans clic avant que la gamme retombe

-- Au-dela de ce gain (en secondes), un clic ajoute une couche grave : on entend
-- la difference entre un joueur nu et un joueur bien ameliore.
Config.SOUND_BIG_CLICK = 10

return Config
