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

-- _v2 : la valeur stockee encode desormais le palier en plus du temps (voir
-- TimeBalance). Les valeurs _v1 se seraient relues comme des temps divises par 10.
Config.TIME_BALANCE_DATASTORE_NAME = "TimeOutTimeBalance_v2"
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
-- main. Ni Config.CLICKER_REWARD ni le Chrono Boost (ClickPower) ni le palier de
-- salle n'y touchent -- ameliorer ses clics n'ameliore pas l'auto-cliqueur, et
-- inversement. C'est la seule chose du jeu qui produit du temps sans geste, et
-- c'est pour ca qu'elle reste la seule chose qui ne s'obtienne qu'en Robux.
--
-- UN ACHAT DONNE TROIS CHOSES :
--   * l'engin lui-meme, au premier achat (AUTOCLICK_BASE_RATE, 2 s/sec)
--   * un plein de AUTOCLICK_FUEL_BASE
--   * un JETON, a depenser dans l'une des deux branches :
--       Puissance -> +AUTOCLICK_POWER_STEP s/sec, definitif
--       Autonomie -> +AUTOCLICK_FUEL_STEP de carburant
--
-- Pourquoi un choix plutot qu'un versement : un cadeau qui tombe se subit, deux
-- cartes obligent le joueur a lire sa propre situation -- il tient longtemps ou
-- il frappe fort. Deux joueurs qui ont depense autant n'ont alors plus le meme
-- auto-cliqueur. C'est la meme regle que les packs du lot 3.
--
-- Le jeton est REMIS AU JOUEUR, pas consomme a l'achat : le flux Roblox va du
-- prompt a ProcessReceipt, et une intention stockee avant le prompt serait
-- perdue si le joueur se deconnecte entre les deux. Le jeton, lui, vit dans la
-- sauvegarde et attend.
--
-- Le debit monte de facon LINEAIRE (2, 4, 6, 8...) et non plus en doublant. Un
-- debit qui double face a un prix fixe finit par rendre les paquets de temps
-- ridicules : au 6e achat, l'ancienne courbe rapportait 128 h pour 99 R$, quand
-- le paquet de 100 h en coute 1999. Voir plan2.md, etape 18.
--
-- Le 1er cran demarre a 2 s/sec et non a 1 (etape 17 du plan 2) : a 1 s/sec le
-- debit annulait exactement le drain, le chrono se figeait, et le joueur payait
-- pour regarder un compteur immobile sans savoir si ca marchait.
--
-- Le carburant (etape 18) : un auto-cliqueur infini tue la boucle du jeu --
-- passe le premier achat, il n'y a plus rien a faire. Le debit reste acquis pour
-- toujours, mais il ne tourne que tant qu'il reste du carburant. A sec, il
-- s'arrete et attend un rachat.
--
-- ATTENTION : le champ "robux" ne sert QU'A L'AFFICHAGE. Le vrai prix est celui
-- du Creator Dashboard ; changer la valeur ici ne change pas ce qui est facture.
Config.AUTOCLICK_PRODUCT = { productId = 3710399391, robux = 99 }
Config.AUTOCLICK_BASE_RATE = 2 -- secondes gagnees par seconde, des le 1er achat
Config.AUTOCLICK_POWER_STEP = 2 -- s/sec ajoutees par jeton depense en Puissance
Config.AUTOCLICK_INTERVAL = 1 -- periode de la boucle (le temps credite suit le delai reellement ecoule)

-- Carburant, en secondes de FONCTIONNEMENT. Un achat en donne toujours BASE ;
-- un jeton depense en Autonomie ajoute STEP par-dessus.
--
-- Le reservoir n'est pas plafonne, et le carburant stocke brule au debit DU
-- MOMENT : prendre l'autonomie plusieurs fois puis la puissance rapporte donc
-- plus qu'alterner. C'est assume -- avec un debit lineaire l'ecart reste dans un
-- facteur 2 ou 3, la ou il aurait explose avec l'ancien debit qui doublait.
Config.AUTOCLICK_FUEL_BASE = 2 * 3600
Config.AUTOCLICK_FUEL_STEP = 4 * 3600

-- L'auto-cliqueur tourne AUSSI hors ligne : le carburant brule pendant l'absence
-- et le temps gagne est credite au retour.
--
-- Attention a ce que ca implique : hors ligne, le chrono du joueur est GELE (il
-- ne perd rien, voir TimeService, qui n'itere que sur les joueurs connectes).
-- Une heure hors ligne rapporte donc le debit PLEIN, la ou une heure de jeu ne
-- rapporte que le debit moins le drain d'1 s/s. L'ecart ne pese qu'au debut :
-- passe quelques crans de puissance, le drain ne compte plus.
--
-- Les deux garde-fous ci-dessous sont neutres par defaut. Ils sont la pour
-- pouvoir corriger en une ligne, sans toucher au code, si le test montre que
-- l'auto-cliqueur mange les paquets de temps.
Config.AUTOCLICK_OFFLINE_RATIO = 1 -- part du debit creditee hors ligne (0.5 = moitie)
Config.AUTOCLICK_OFFLINE_MAX = 0 -- plafond de secondes d'absence creditees ; 0 = pas de plafond

-- Les deux branches du jeton, telles qu'elles transitent sur le reseau.
Config.AUTOCLICK_CHOICE_POWER = "Power"
Config.AUTOCLICK_CHOICE_FUEL = "Fuel"

-- La jauge du client fait descendre le compte a rebours toute seule (1 s par
-- seconde, comme le chrono). Le serveur la recale a ce rythme pour que les deux
-- ne divergent pas -- sans envoyer un message par seconde et par joueur.
Config.AUTOCLICK_SYNC_INTERVAL = 15

-- Sous ce seuil (en secondes), la jauge passe au rouge et pulse.
Config.AUTOCLICK_LOW_FUEL = 60

-- Paris verrouilles : une zone ne s'ouvre au joueur qu'une fois qu'il a possede
-- au moins sa mise sur son propre chrono -- et elle reste ouverte pour toujours.
-- Le seuil vaut la mise de la zone ; un attribut numerique "UnlockAt" (en
-- secondes) sur la Part permet d'en imposer un autre.
Config.BET_UNLOCK_ATTRIBUTE = "UnlockAt"
Config.BET_LOCK_REFRESH_INTERVAL = 2 -- secondes entre deux verifications de deverrouillage

--------------------------------------------------------------------------------
-- Paliers (plan 2)
--------------------------------------------------------------------------------
-- L'echelle elle-meme (noms, prix, multiplicateurs, raretes) vit dans
-- src/shared/Tiers.luau. Ici, uniquement ce qui se pose dans Studio et les
-- garde-fous.

Config.TIER_GATE_TAG = "TierGate" -- tag a mettre sur la Part transparente qui bouche un passage
Config.TIER_WINDOW_TAG = "TierWindow" -- tag a mettre sur un mur vitre donnant sur l'etage du dessus
Config.TIER_TARGET_ATTRIBUTE = "TargetTier" -- attribut nombre : l'etage desservi / regarde

-- "Payer ne peut pas tuer." Une entree n'est acceptee que s'il reste au joueur,
-- APRES paiement, au moins ce plancher. Il monte avec le prix du palier : 60 s
-- de rab a l'entree du Buffet, 20 h a l'entree du Terminus -- sinon un joueur
-- pourrait vider un chrono de 1000 h et se retrouver a une minute de la mort.
Config.TIER_SAFETY_MARGIN = 60 -- secondes minimum restantes apres paiement
Config.TIER_SAFETY_FRACTION = 0.02 -- ... ou ce pourcentage du prix paye, si c'est plus

-- Groupes de collision : une barriere ne bloque QUE les joueurs qui n'ont pas
-- encore son etage (voir TierService). Les noms sont construits a partir de ces
-- prefixes, un par palier -- rien a creer a la main dans Studio.
Config.TIER_GATE_COLLISION_PREFIX = "TierGate_"
Config.TIER_PLAYER_COLLISION_PREFIX = "TierPlayer_"

--------------------------------------------------------------------------------
-- Lot 2 -- donner envie de monter
--------------------------------------------------------------------------------

-- Les neons du bas de l'immeuble gresillent. Le tag se pose sur la lumiere
-- (PointLight, SurfaceLight, SpotLight) ou sur la Part Neon qui la porte -- le
-- jeu accepte les deux et fait clignoter ce qu'il trouve.
--
-- RIEN au-dessus du palier 3 : le gresillement est la signature du sous-sol, et
-- il ne veut plus rien dire si tout l'immeuble clignote.
Config.FLICKER_TAG = "FlickerLight"

-- Ce que les AUTRES joueurs lisent d'un joueur : deux attributs poses sur
-- l'instance Player, donc repliques a tout le monde (voir src/server/Presence).
-- Remotes.TimeUpdated ne parle qu'au proprietaire du chrono ; il ne pouvait donc
-- pas alimenter le panneau au-dessus des tetes.
Config.PRESENCE_TIER_ATTRIBUTE = "Tier"
Config.PRESENCE_TIME_ATTRIBUTE = "TimeLeft"
Config.PRESENCE_SYNC_INTERVAL = 1 -- secondes entre deux publications (en secondes entieres)

-- Panneau au-dessus des personnages : pleinement lisible en deca de FADE_START,
-- efface a FADE_END. Un hall plein ne doit pas devenir un mur de texte.
Config.NAMEPLATE_FADE_START = 55 -- studs
Config.NAMEPLATE_FADE_END = 110 -- studs

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
