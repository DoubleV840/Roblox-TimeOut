-- Catalogue des sons du jeu : une entree par evenement, avec l'ID de l'asset et
-- son reglage. C'est le SEUL endroit a toucher pour changer un son -- le code de
-- jeu ne connait que le nom de l'evenement ("cookie_click"), jamais un ID.
--
-- Champs d'une entree (tous facultatifs sauf id) :
--   id     : "rbxassetid://123..." (Creator Store) ou un son livre avec le
--            moteur ("rbxasset://sounds/..."). Chaine VIDE = evenement muet :
--            le jeu tourne normalement, il ne joue simplement rien.
--   volume : 0..1 AVANT le multiplicateur global (Config.SFX_VOLUME ou
--            Config.MUSIC_VOLUME). Defaut 0.5.
--   pitch  : PlaybackSpeed. Defaut 1.
--   jitter : variation aleatoire du pitch (0.05 = +/- 5%), pour qu'un son repete
--            en rafale ne sonne pas comme un copier-coller. Defaut 0.
--   range  : portee en studs d'un son 3D (RollOffMaxDistance). Defaut 80.
--   looped : vrai pour les nappes (bourdonnement de zone, musique).
--   music  : vrai pour passer par Config.MUSIC_VOLUME au lieu de SFX_VOLUME.
--
-- Tous les ID par defaut sont des sons livres avec Roblox
-- (rbxasset://sounds/...) : ils marchent tout de suite, sans rien uploader.
-- Aucun evenement n'est muet -- mais ce sont des bouche-trous, a remplacer par
-- de vrais assets du Creator Store quand tu en auras choisi.
--
-- Cas particulier des NAPPES (les entrees looped = true : musiques,
-- bourdonnements de zone, auto-cliqueur). Le moteur ne livre aucune musique ni
-- aucun drone, et boucler un echantillon court donnerait un hoquet a la
-- mitraillette. Elles utilisent donc toutes le meme son de vent
-- (action_falling.mp3, le souffle de chute -- celui-la boucle proprement), a des
-- hauteurs et des volumes differents : ca tient le role d'un lit sonore, ce
-- n'est pas de la musique. C'est le premier endroit ou mettre de vrais assets.

local SoundLibrary = {}

SoundLibrary.List = {
	----------------------------------------------------------------------------
	-- Interface : popups, boutons, notifications
	----------------------------------------------------------------------------

	ui_popup_open = { id = "rbxasset://sounds/switch3.wav", volume = 0.35, pitch = 1.15 },
	ui_popup_close = { id = "rbxasset://sounds/switch.wav", volume = 0.22, pitch = 0.9 },
	ui_hover = { id = "rbxasset://sounds/switch.wav", volume = 0.1, pitch = 1.7 },
	ui_click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.35 },

	-- Action refusee (pas assez de temps, zone verrouillee) : un son sec et bas,
	-- volontairement desagreable.
	ui_denied = { id = "rbxasset://sounds/hit.wav", volume = 0.45, pitch = 0.5 },

	-- Les trois couleurs de notification ont chacune leur timbre : on sait si on
	-- a gagne ou perdu avant meme d'avoir lu le texte.
	ui_notify_info = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.28 },
	ui_notify_win = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 1.45 },
	ui_notify_lose = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 0.6 },

	----------------------------------------------------------------------------
	-- Achats (Robux)
	----------------------------------------------------------------------------

	-- Au clic sur une ligne du guichet, juste avant que Roblox ouvre son prompt.
	ui_purchase_prompt = { id = "rbxasset://sounds/switch3.wav", volume = 0.4, pitch = 1.3 },
	-- Tiroir-caisse : le tintement metallique s'en approche le mieux. Merite un
	-- vrai asset -- c'est le son du joueur qui paie.
	ui_purchase_success = { id = "rbxasset://sounds/metal.ogg", volume = 0.6, pitch = 1.5 },
	ui_purchase_failed = { id = "rbxasset://sounds/hit.wav", volume = 0.45, pitch = 0.45 },

	----------------------------------------------------------------------------
	-- Progression : rangs, temps gagne ou depense
	----------------------------------------------------------------------------

	rank_up = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 1.6 },
	rank_down = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 0.5 },

	-- Temps depense (mise, amelioration) : le chrono qui recule.
	--
	-- Il n'y a volontairement PAS de son symetrique pour le temps qui rentre :
	-- chaque source a deja le sien la ou elle se produit (orbe, clic, jackpot,
	-- tiroir-caisse), et un bip de plus sur le HUD n'apprendrait rien.
	time_loss = { id = "rbxasset://sounds/switch.wav", volume = 0.3, pitch = 0.55 },

	----------------------------------------------------------------------------
	-- Mort et retour en jeu
	----------------------------------------------------------------------------

	-- Le coup au moment ou le chrono touche zero. (.mp3 et non .wav : c'est le
	-- son de mort par defaut du personnage Roblox, et son extension compte.)
	death_impact = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.7, pitch = 0.85 },
	-- La nappe grave qui accompagne l'apparition de "TU ES MORT".
	death_stinger = { id = "rbxasset://sounds/bass.wav", volume = 0.6, pitch = 0.5 },
	restart = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.6 },
	-- Rachat de temps devant l'ecran de mort : on repart sans passer par la case
	-- "Recommencer", ca doit sonner comme une resurrection.
	revive = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.75, pitch = 1.8 },

	----------------------------------------------------------------------------
	-- Chrono : alertes, compte a rebours, coeur
	----------------------------------------------------------------------------
	--
	-- Pas de tic-tac de fond : un son qui revient chaque seconde pendant des
	-- minutes, on ne l'entend plus -- il ne reste que l'agacement. Le chrono se
	-- tait donc jusqu'aux paliers d'alerte, puis compte a rebours sur la fin.

	-- Franchissement d'un palier d'alerte (Config.SOUND_WARNING_THRESHOLDS).
	clock_warning = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 0.75 },
	-- Une par seconde sur les dernieres secondes : le pitch monte a l'approche de 0.
	countdown_beep = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 1.2 },
	-- Battement de coeur, cale sur la pulsation de l'image (voir Ambience).
	heartbeat = { id = "rbxasset://sounds/bass.wav", volume = 0.35, pitch = 1.4 },

	-- La musique n'est pas un evenement mais une playlist : voir
	-- SoundLibrary.Playlist, tout en bas de ce fichier.

	----------------------------------------------------------------------------
	-- Cookie de temps (3D, pose sur l'objet : tout le monde entend)
	----------------------------------------------------------------------------

	-- MUET, VOULU : cliquer le cookie ne fait aucun bruit. Aucun des sons livres
	-- avec le moteur ne convenait -- ils sonnent tous plus ou moins metallique, et
	-- c'est le geste le plus repete du jeu : mieux vaut le silence qu'un tic qui
	-- agace au bout de dix minutes.
	--
	-- Pour lui redonner une voix, il suffit de remettre un id ci-dessous (idealement
	-- un vrai asset du Creator Store, importe comme les musiques -- voir la marche a
	-- suivre en bas de ce fichier). Tout le reste est deja en place : le pitch monte
	-- avec la cadence de clic (Config.SOUND_COMBO_BASE_PITCH + le combo, voir
	-- TimeCookie), donc marteler le cookie ferait monter la gamme tout seul.
	cookie_click = { id = "", volume = 0.5, jitter = 0.04, range = 70 },
	-- Couche grave qui s'ajoutait quand un clic rapportait gros : muette aussi,
	-- sans quoi les gros clics seraient les seuls a sonner.
	cookie_click_big = { id = "", volume = 0.4, pitch = 0.7, range = 70 },
	cookie_idle = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.15, pitch = 1.6, looped = true, range = 45 },
	-- Le panneau du maitre du clic change de nom.
	champion_change = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.5, range = 90 },

	----------------------------------------------------------------------------
	-- Orbes de temps (3D)
	----------------------------------------------------------------------------

	orb_collect = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.55, pitch = 1.7, range = 60 },
	orb_respawn = { id = "rbxasset://sounds/switch3.wav", volume = 0.3, pitch = 1.5, range = 45 },
	orb_idle = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.12, pitch = 2, looped = true, range = 35 },

	----------------------------------------------------------------------------
	-- Zones de pari (3D)
	----------------------------------------------------------------------------

	-- Le bourdonnement de la zone : son pitch descend quand la mise monte, donc
	-- une zone a 1000h gronde plus grave qu'une zone a 10s.
	-- Le pitch est impose par la zone (voir BettingGame), celui d'ici ne sert pas.
	bet_zone_hum = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.18, looped = true, range = 70 },
	bet_placed = { id = "rbxasset://sounds/snap.wav", volume = 0.45, pitch = 1.2, range = 60 },
	-- Le tirage (un souffle qui monte, faute de roulement de tambour), puis le
	-- tintement du jackpot -- le meme metal que le tiroir-caisse, en plus haut.
	bet_draw = { id = "rbxasset://sounds/unsheath.wav", volume = 0.6, pitch = 0.8, range = 80 },
	bet_win_zone = { id = "rbxasset://sounds/metal.ogg", volume = 0.7, pitch = 2.2, range = 90 },
	-- Le cadenas d'une zone verrouillee qui saute, definitivement.
	bet_unlocked = { id = "rbxasset://sounds/unsheath.wav", volume = 0.5, pitch = 0.9 },

	----------------------------------------------------------------------------
	-- Guichets et amelioration (3D)
	----------------------------------------------------------------------------

	shop_hum_time = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.16, pitch = 0.8, looped = true, range = 60 },
	shop_hum_auto = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.16, pitch = 1.35, looped = true, range = 60 },
	upgrade_zone_hum = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.15, pitch = 1.1, looped = true, range = 55 },
	-- Achat de Chrono Boost : le pitch monte d'un cran a chaque niveau, on entend
	-- l'echelle grimper.
	upgrade_bought = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, range = 70 },
	-- Le bourdonnement de l'auto-cliqueur, joue en 2D chez son proprietaire :
	-- son pitch monte a chaque palier achete.
	-- Celui-ci est en 2D et tourne EN PERMANENCE dans l'oreille du proprietaire :
	-- il est volontairement le plus discret de tous. Son pitch est impose par le
	-- niveau (voir Soundscape), celui d'ici ne sert pas.
	autoclick_hum = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.12, looped = true },
	autoclick_bought = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.65, pitch = 1.3 },
	-- Panne seche : un lourd declic de machine qui s'arrete, tres grave. Il
	-- arrive en meme temps que le bourdonnement qui se coupe -- c'est le silence
	-- qui suit qui doit se remarquer, pas le bruit.
	autoclick_dry = { id = "rbxasset://sounds/switch.wav", volume = 0.5, pitch = 0.35 },

	----------------------------------------------------------------------------
	-- Paliers (3D, sauf annonce)
	----------------------------------------------------------------------------

	-- Une barriere fermee ronronne : c'est ce qui attire l'oeil vers l'etage du
	-- dessus avant meme d'avoir lu le panneau.
	tier_gate_hum = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.14, pitch = 0.7, looped = true, range = 55 },
	-- Le portique qui s'ouvre : le pitch monte avec l'etage paye, donc une
	-- montee au Terminus s'entend plus haut qu'une montee au Buffet.
	tier_gate_open = { id = "rbxasset://sounds/unsheath.wav", volume = 0.75, range = 120 },
	-- Refus sec quand le chrono ne suffit pas (marge de securite comprise).
	tier_denied = { id = "rbxasset://sounds/hit.wav", volume = 0.5, pitch = 0.45 },
	-- L'annonce entendue par TOUT le serveur quand quelqu'un monte : en 2D, dans
	-- la tete de chacun, y compris a l'autre bout de la map.
	tier_announce = { id = "rbxasset://sounds/metal.ogg", volume = 0.55, pitch = 1.9 },
	-- Ajoute SOUS l'annonce a partir des hauts paliers : la montee au Terminus
	-- doit s'entendre autrement qu'une montee au Buffet, pas seulement plus fort.
	tier_announce_big = { id = "rbxasset://sounds/bass.wav", volume = 0.7, pitch = 0.65 },

	----------------------------------------------------------------------------
	-- Decor du bas de l'immeuble (3D)
	----------------------------------------------------------------------------

	-- Le bourdonnement d'un neon fatigue. Tres discret et de courte portee : il
	-- y en a un par tube, et le Quai en est couvert -- ils doivent s'additionner
	-- en ambiance, pas en vacarme. Le volume et le pitch suivent le clignotement
	-- (voir src/client/Flicker), donc un tube au ras de l'extinction crachote.
	neon_buzz = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.06, pitch = 2.6, looped = true, range = 22 },

	----------------------------------------------------------------------------
	-- Panneau de classement (3D)
	----------------------------------------------------------------------------

	-- Uniquement quand la premiere place change de main -- pas a chaque
	-- rafraichissement, sinon le panneau bipperait toutes les 3 secondes.
	board_new_leader = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 1.15, range = 80 },
}

--------------------------------------------------------------------------------
-- Playlist
--------------------------------------------------------------------------------
-- Les morceaux du jeu, enchaines en boucle et dans un ordre aleatoire (voir
-- src/client/Music.luau). L'ordre de cette liste n'a aucune importance : elle
-- est melangee a chaque tour.
--
-- COMMENT REMPLIR LES ID
--
-- Roblox ne lit pas de fichier local, et Rojo ne synchronise que du code : les
-- .mp3 poses a la racine du projet ne sont, pour le moteur, que des fichiers sur
-- ton disque. Il faut les importer une fois :
--
--   1. Dans Studio, ouvre la vue Asset Manager (menu View).
--   2. Clic droit sur le dossier Audio -> Add Audio, choisis le .mp3.
--      (Ou passe par creator.roblox.com -> Creations -> Audio -> Upload.)
--      ATTENTION : l'import prend le NOM DU FICHIER comme nom d'asset, et
--      Roblox le refuse au-dela de 50 caracteres ("Asset name length is
--      invalid"). Les fichiers a la racine sont deja nommes court pour ca --
--      si tu en ajoutes un, verifie sa longueur avant de l'importer.
--   3. L'import passe par une moderation -- compte quelques minutes.
--   4. Une fois valide, clic droit sur l'asset -> Copy Asset ID.
--   5. Colle-le ci-dessous sous la forme "rbxassetid://TON_ID".
--
-- Une piste dont l'id reste vide est simplement sautee : la playlist joue ce
-- qu'elle a. Tu peux donc en activer une seule pour tester.
--
-- volume : facultatif, 0..1, appliique AVANT Config.MUSIC_VOLUME. Il sert a
--   rattraper les ecarts de niveau entre morceaux -- si l'un sort plus fort que
--   les autres, baisse-le ici plutot que de toucher au volume general.

SoundLibrary.Playlist = {
	{ id = "rbxassetid://125594270629952", name = "escape-your-love-412230" },
	{ id = "rbxassetid://105721180089359", name = "electric-summer-fun-516076" },
	{ id = "rbxassetid://80443650479588", name = "elegant-fashion-summer-deep-house-534033" },
	{ id = "rbxassetid://138123751087114", name = "supercars-action-gaming-cyberpunk-534031" },
	{ id = "rbxassetid://130932638416721", name = "upbeat-energetic-commercial-431746" },
}

return SoundLibrary
