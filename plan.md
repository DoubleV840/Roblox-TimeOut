# TimeOut — Plan de développement

Jeu Roblox : chaque joueur a un temps de survie qui s'écoule en continu (lobby compris). Il doit farmer, acheter ou parier du temps pour ne jamais tomber à zéro. Classement des meilleurs survivants.

Décisions prises :
- Le temps s'écoule partout, tout le temps qu'on est en jeu (pas de zone à 0 drain).
- Il ne s'écoule QUE pendant que le joueur est connecté (pas de calcul hors-ligne).
- À 0 : le joueur "perd" et repart avec le temps de base par défaut.
- Le jeu a été publié une première fois en Private : ça débloque les Developer Products sans rendre le jeu visible.
- Abandonné : les « zones à risque » (drain accéléré ou ralenti selon la zone) — écartées volontairement, le jeu garde un drain uniforme partout.

## Étapes

- [x] **Étape 0 — Setup** : Rojo (CLI + plugin Studio) installé et connecté, projet initialisé.
- [x] **Étape 1 — Boucle de temps minimale** : chaque joueur a un timer qui descend d'1 seconde par seconde, affiché à l'écran (format HH:MM:SS, couleur vert→rouge). À 0, une popup "TIME OUT !" propose de recommencer avec le temps de base (le joueur reste à 0 tant qu'il n'a pas cliqué). Limitation connue v1 : orbes/paris restent utilisables pendant cette attente. Validé en jeu.
- [x] **Étape 2 — Sauvegarde persistante** : le temps et le meilleur record de survie sont sauvegardés (DataStore), pour qu'ils survivent à une reconnexion. Validé en jeu.
- [x] **Étape 3 — Gagner du temps** : une "orbe de temps" posée dans la map redonne des secondes au contact. Validé en jeu. Réapparition toutes les 10 s (`Config.ORB_COOLDOWN`) : l'orbe est ancrée au démarrage (sans collision, une orbe libre tombait sous la map et ne revenait jamais), son état d'origine est relevé avant d'y toucher et restauré tel quel, le retour passe par un `task.delay` plutôt qu'un `task.wait` dans le gestionnaire de contact, et un joueur resté dessus la ramasse dès son retour (le moteur n'émet pas de nouveau `Touched` pour un contact déjà en place).
- [x] **Étape 4 — Classement** : `leaderstats` (tableau des joueurs en jeu, natif Roblox) + panneau physique avec classement EN DIRECT des joueurs connectés triés par temps restant (les déconnectés restent affichés, en pause). Validé en jeu (test 2 clients).
- [ ] **Étape 5 — Achats Robux (temps + auto-cliqueurs)** : deux guichets vendant contre des Robux. Jeu publié, code écrit — **il ne manque que les IDs de produits**.

  *Reste à faire, dans le Creator Dashboard :* Monetization → Developer Products → créer un produit par ligne du tableau ci-dessous, plus celui de l’auto-cliqueur (des *Developer Products*, rachetables à l'infini, pas des Game Passes), puis recopier chaque ID dans `Config.TIME_PRODUCTS` et `Config.AUTOCLICK_PRODUCT`. Tant qu'un `productId` vaut `0`, le produit est ignoré partout : le guichet ne l'affiche pas et le serveur refuse de le vendre — on peut donc n'en créer qu'un pour tester.

  | Paquet de temps | Prix |
  |---|---|
  | 30 min | 25 R$ |
  | 2 h | 79 R$ |
  | 10 h | 299 R$ |
  | 24 h | 599 R$ |
  | 100 h | 1999 R$ |
  | 500 h | 7999 R$ |
  | 1000 h | 13999 R$ |

  Plus **un seul produit auto-cliqueur** (`Config.AUTOCLICK_PRODUCT`), à 999 R$, rachetable à l’infini : chaque achat double le débit. Un produit à prix fixe suffit, il n’y a pas d’échelle à créer.

  Le prix à la seconde s'améliore à chaque palier (~72 s/R$ à 30 min, ~257 s/R$ à 1000 h) : acheter gros doit rester le bon calcul.

  *Ce qui est en place :*
  - `src/server/Shop.luau` : zone taguée `ShopZone`, `PromptProductPurchase` déclenché par le serveur, et **`ProcessReceipt`** — assigné une seule fois dans tout le jeu, sous peine de perdre des achats.
  - L'attribut **`ShopKind`** sur la Part choisit le guichet : `"Time"` (défaut) ou `"AutoClick"`.
  - Anti double-crédit en deux temps : le receipt est d'abord *réservé* (`granted = false`) dans un DataStore, puis marqué *honoré* une fois l'achat posé. Un crash entre les deux laisse une réservation incomplète, que la reprise crédite — au lieu de croire à tort que le joueur a déjà été servi. Un cache mémoire couvre les rappels de Roblox dans la même session.
  - Le crédit d’un auto-cliqueur est un simple +1 : c’est la réservation par `PurchaseId` qui garantit qu’un même receipt ne repasse jamais par là.
  - `TimeService.GrantTime` : crédite le temps et, si le joueur était devant l'écran de mort, le remet en jeu directement (Remote `Revived`) — le faire cliquer sur « Recommencer » repartirait au temps de base et effacerait ce qu'il vient de payer.
  - Sauvegarde immédiate après achat, sans attendre l'autosave.

  *À poser dans Studio :* deux Parts taguées `ShopZone`, l'une sans attribut (guichet à temps), l'autre avec `ShopKind = "AutoClick"`.

  *Test :* le prompt s'affiche en Studio, mais l'achat ne se valide que dans le jeu publié. Vérifier surtout qu'un rejoin immédiat après achat ne crédite pas une seconde fois.

- [x] **Étape 6 — Mini-jeu de pari** : mise en commun de temps entre joueurs, le(s) gagnant(s) remportent la cagnotte. Revu : entrer dans la zone ouvre une popup de confirmation (Valider/Annuler), la vérification du temps se fait à la validation, et chaque zone a son propre montant (attribut `BetAmount` en secondes sur la Part). Validé en jeu. Limitation connue v1 : un participant déconnecté avant le tirage perd sa mise sans recours. Ajouté : un HUD en haut à droite liste les tours ouverts (mise, nombre de parieurs, compte à rebours du tirage au dixième de seconde), ceux du joueur en doré, les autres en gris pour donner envie d'y courir. Le serveur envoie une échéance sur son horloge (`Workspace:GetServerTimeNow`) à chaque changement de tour, le client fait descendre le décompte tout seul.
- [x] **Étape 8 — Cookie clicker + améliorations** : objet cliquable au centre du lobby (+1s/clic). L'amélioration du gain par clic se fait via une zone tactile (comme les paris) : popup affichant niveau actuel, prochain niveau et coût, avec bouton Améliorer/Fermer. Coût croissant : `UPGRADE_BASE_COST * UPGRADE_GROWTH^niveau`. Validé en jeu. Décor du Chrono Boost généré en code (`createDecor` dans `src/server/ClickUpgrade.luau`) : aura magenta au sol, portique néon à l'échelle de la zone et rotor à deux pales qui tourne en phase avec le cookie — rien à décorer à la main dans Studio, le tag suffit. Le cookie tourne sur lui-même à `Config.SPIN_DEGREES_PER_SECOND` (90°/s, un tour toutes les 4 s). Le clic est muet (`cookie_click` et `cookie_click_big` à `id = ""`) : aucun son livré avec le moteur ne convenait pour le geste le plus répété du jeu. La montée de gamme selon la cadence reste câblée, il suffit de remettre un id pour la réentendre. Correctif : cette fanfare sonnait à chaque reprise de clic après une accalmie (le titre retombait sur « personne » au bout de 8 s, et le clic suivant comptait comme un changement de titulaire) — `ClickChampion` ne retient plus que les titulaires réels.
- [x] **Étape 9 — Écran de mort + rangs** : à 0, un écran plein écran (fondu noir, "TIME OUT" puis "TU ES MORT" en serif rouge, style écran de défaite type Dark Souls) remplace la popup, avec bouton Recommencer qui apparaît après l'animation. Système de rangs basé sur le temps possédé (`src/shared/Ranks.luau`, 8 paliers d'Éphémère à Seigneur Temporel), affiché en badge coloré à côté du chrono en bas et sur chaque ligne du panneau de classement. Validé en jeu. Correctif : le badge des lignes du panneau était invisible (`UIAspectRatioConstraint` en `DominantAxis = Width` avec une largeur 0) — passé en `DominantAxis = Height` dans `Ranks.NewBadge`, à retester.
- [x] **Étape 10 — Chrono en millisecondes + sursis de pari** : le chrono affiche `HHHH:MM:SS.mmm`. Le serveur retire le temps réellement écoulé (au lieu d'exactement 1s par tick, ce qui dérivait) et n'envoie toujours qu'une valeur par seconde ; le client fait descendre le compteur localement à chaque frame entre deux messages. Si le joueur tombe à 0 alors qu'un pari est engagé, il ne meurt pas : il reste bloqué à 0 jusqu'au tirage, qui peut encore le renflouer (`BettingGame.HasPendingBet`). Validé en jeu.

- [x] **Étape 11 — Ambiance dynamique + panneaux vivants** : l'éclairage réagit au temps restant (`src/client/Ambience.luau`, côté client donc propre à chaque joueur). Les panneaux perdent leur fond noir : liseré néon, textes colorés et animés dont l'agitation dépend de leur valeur (`src/shared/TextFx.luau`). Validé en jeu.

- [x] **Étape 12 — Décor du Terminal généré en code** : `src/server/Terminal.luau` construit le hall (sol en damier, murs, colonnes, verrière, quai et voie) et pose lui-même les tags de gameplay, donc la map est jouable sans rien placer à la main. Reconstruit à chaque démarrage dans `Workspace.Terminal`. **Désactivé par défaut** (`Config.BUILD_TERMINAL = false`) : la map se construit à la main dans Studio. Le module reste comme décor de référence / point de départ.

- [x] **Étape 13 — Traductions** : tous les textes vus par les joueurs vivent dans `src/shared/Translations.luau` (61 clés × 11 langues : fr, en, es, pt-BR, de, it, ru, tr, ja, ko, zh-CN). `src/shared/Locale.luau` résout la langue du joueur et alimente une `LocalizationTable` exposée au portail du Creator Hub. Deux changements structurels : les Remotes transportent une **clé + paramètres** au lieu de phrases finies, et les panneaux du monde (partagés par tous) sont marqués par le serveur puis réécrits localement par chaque client dans sa langue. Code fait, test en jeu en cours.

- [x] **Étape 14 — Auto-cliqueur** : source de temps passive, **totalement indépendante du clic à la main** (`src/server/AutoClicker.luau`). Ni `CLICKER_REWARD` ni le Chrono Boost n'entrent dans son débit : les deux progressions avancent chacune de leur côté. Un **seul Developer Product, à prix fixe et rachetable à l'infini** — chaque achat **double** le débit : 1er → 1 s/sec, 2e → 2 s/sec, 3e → 4 s/sec, etc. Persistant (`data.AutoClickers`), gelé tant que le joueur est devant l'écran de mort, et il crédite le délai réellement écoulé (pas de dérive). **Équilibrage à surveiller** : le chrono descend d'1 s/s, donc dès le *premier* achat le joueur ne perd plus de temps du tout — le prix (999 R$ pour l'instant) devrait se situer vers le haut de l'échelle des paquets, pas vers le bas. Code fait, en attente de test en jeu.

- [x] **Étape 15 — Paris déverrouillables** : une zone de pari reste fermée tant que le joueur n'a jamais possédé sa mise sur son propre chrono ; une fois atteinte, elle est ouverte **pour toujours** (`data.MaxTime`, le plus haut temps jamais tenu — tomber à zéro ne referme rien). Le seuil vaut la mise de la zone, un attribut `UnlockAt` (secondes) permet d'en imposer un autre. Une zone fermée affiche un cadenas 🔒 et « Débloqué à {temps} », et sa popup explique quoi atteindre au lieu de proposer de miser. Le cadenas est dessiné **côté client** : le verrou est propre à chaque joueur alors que le panneau de la zone est partagé. Le serveur revalide à l'acceptation. Code fait, en attente de test en jeu.

- [x] **Étape 16 — Panneau du maître du clic** : au-dessus de chaque objet tagué `TimeCookie`, le nom du joueur qui produit le plus de temps par seconde, en gros et coloré (`src/server/ClickChampion.luau`). Le débit additionne les **deux** sources : le clic à la main, mesuré sur une fenêtre glissante de `CHAMPION_CLICK_WINDOW` secondes (`CLICKER_REWARD * ClickPower` par clic), et l'auto-cliqueur, dont le débit est déjà une valeur par seconde. La couleur et l'agitation du nom montent avec le débit (or → magenta).

  C'est une vraie **Part** et non un `BillboardGui` : un BillboardGui fait toujours face à la caméra et ne tournerait donc jamais. Elle porte le tag `Config.SPIN_TAG`, que le client fait tourner du même angle que le cookie — les deux restent rigoureusement en phase puisque l'angle vient de la même horloge. Texte sur les deux faces, pour rester lisible pendant tout le tour. `Spin.Bind` accepte maintenant plusieurs tags et ne branche qu'une seule boucle de rendu.

  Rien à poser à la main : le panneau se crée et se tague tout seul sur chaque `TimeCookie`. Code fait, en attente de test en jeu.

- [x] **Étape 17 — Panneaux des guichets** : chaque `ShopZone` reçoit la même aura néon que les zones de pari (cadre lumineux + particules) et un panneau flottant à deux lignes, dont le texte ondule et change de couleur (`TextFx`). Une couleur par sorte : cyan pour le guichet à temps, magenta pour les auto-cliqueurs, pour qu'on distingue les deux comptoirs de loin. L'aura vit maintenant dans `src/shared/ZoneAura.luau`, extraite de `BettingGame` pour être partagée. Rien à poser en plus : le panneau se crée sur chaque Part taguée. Code fait, en attente de test en jeu.

## Direction artistique — « Le Terminal »

Une gare de correspondance art-déco décrépite où tout le monde attend un train qui ne vient jamais, et où le temps sert de monnaie. Le thème colle aux mécaniques existantes :

| Élément du jeu | Dans le décor |
|---|---|
| Panneau de classement | Le tableau des départs (split-flap) — les joueurs sont les destinations |
| Zones de pari | Les guichets / le bureau de change clandestin |
| Cookie clicker | L'horloge monumentale du hall, qu'on frappe pour gagner des secondes |
| Zones Chrono Boost | Les cabines de contrôle des aiguilleurs |
| Écran de mort | Le train est parti sans toi |

Verrière au-dessus du hall (justifie la lumière dorée quand on a du temps), néons et horloges partout, carrelage et laiton. Quand le temps baisse, l'éclairage de secours rouge prend le relais et le brouillard avale le quai — la gare se referme sur le joueur.

## À faire avant publication

Actions manuelles qui ne peuvent pas se faire depuis le code — à reprendre quand le jeu approchera de la sortie.

- [ ] **Tester le rendu en russe et en japonais.** C'est le point le plus risqué : `LuckiestGuy` n'a ni cyrillique, ni CJK. Roblox fait un repli glyphe par glyphe, mais ça peut être incohérent voire vide. Si c'est cassé, corriger dans `src/shared/Fonts.luau` (basculer sur `Gotham` ou `SourceSans` pour ces locales).
- [ ] **Importer `localization/TimeOut.csv`** dans Creator Dashboard → Localization → Table Management. Les 10 langues passeront de 0% à 100% dans le portail. Sans ça le jeu s'affiche quand même traduit (`Locale.Text` lit les tables Lua) : l'import sert au portail, aux traducteurs humains, et à ce que Roblox sache que le jeu est localisé.
- [ ] **Activer Auto Translation → Experience Information** (nom et description du jeu sur le site Roblox : pure découvrabilité).
- [ ] **Activer Auto Translation → Experience Strings & Products** *après* l'import du CSV. Il ne remplit que les entrées vides, donc il sert de filet pour un texte oublié sans jamais écraser les traductions manuelles.
- [ ] **Créer les 8 Developer Products** (7 paquets de temps + 1 auto-cliqueur) et recopier leurs IDs dans `Config.TIME_PRODUCTS` et `Config.AUTOCLICK_PRODUCT` (étape 5). Le jeu est publié, le code attend les IDs.

Déjà fait : langue source réglée sur français, et les 10 langues ajoutées dans Supported Languages.

## Notes techniques
- Le code (scripts) vit dans `src/` et est synchronisé en live avec Studio via Rojo (`rojo serve`).
- La construction physique de la map (parties, décor) se fait à la main dans Studio — ça ne touche pas aux fichiers de `src/`.
- Typo : tout le texte passe par `src/shared/Fonts.luau` (une seule police pour tout le jeu). Roblox ne peut pas charger une police Google Fonts (ni URL, ni `.ttf` uploadé pour un jeu publié) : seules les polices intégrées `Enum.Font` et les assets du Creator Store marchent. « Honk » n'existe dans aucune des deux, donc on utilise `LuckiestGuy` (l'intégrée la plus proche) ; si un asset Honk apparaît, coller son ID dans `HONK_ASSET_ID` suffit à basculer tout le jeu.
- Traductions : `src/shared/Translations.luau` est **la source de vérité** — c'est lui que le jeu lit à l'exécution. `localization/TimeOut.csv` n'en est qu'un export pour le portail Roblox. Après toute modification de traduction, relancer `perl localization/generate-csv.pl` puis réimporter, sinon les deux divergent en silence.
- **Format du CSV : ne pas se fier à la doc Roblox.** Elle décrit un ordre de colonnes et des codes de langue qui font échouer l'import avec « Language(s) not supported ». Le format réel a été relevé sur un export de la table depuis le Dashboard : BOM UTF-8, colonnes `Key,Example,Source,Context,Game Locations`, puis chaque langue suivie d'une colonne `<code> translator type`. Surtout, **les codes du portail ne sont pas ceux de `Translations.luau`** : Roblox attend le code nu (`de`, `it`, `ru`, `tr`, `ja`, `ko`) là où la langue n'a pas de variante régionale, et `zh-hans` pour le chinois simplifié — `de-de` ou `zh-cn` sont refusés. La correspondance vit dans `@COLUMNS`, en tête de `generate-csv.pl`. Si l'import recommence à échouer, réexporter la table depuis le Dashboard et comparer l'en-tête : c'est lui la vérité, pas la documentation.
- `en-gb`, `es-mx`, `pt-pt`, `fr-fr` et `fr-ca` sont laissés vides : les trois premiers retombent sur `en`/`es`/`pt` plutôt que de recevoir un texte écrit pour une autre région, et le français est la langue source (colonne `Source`). Ajouter une langue = copier le bloc `en-us`, traduire ; `Locale.luau` la reprend automatiquement (une langue absente retombe sur le français).
- Les durées sont traduites elles aussi (`2h 30min 5s` / `2時間 30分 5秒`). Un texte peut écrire `{amount:duration}` : le paramètre porte alors un **nombre de secondes**, mis en forme par `Locale` au moment de l'affichage, avec les clés `unit_hour` / `unit_minute` / `unit_second` de la langue du joueur. C'est ce qui permet au serveur — qui écrit pour tout le monde à la fois — de n'envoyer qu'un nombre au lieu d'une phrase déjà en français. Seul « CHRONO BOOST » reste tel quel dans toutes les langues, comme nom de fonctionnalité.
- Fichiers clés : `src/shared/Config.luau` (réglages comme le temps de base), `src/shared/Remotes.luau` (communication client/serveur), `src/server/TimeService.luau` (la boucle de jeu), `src/client/init.client.luau` (affichage à l'écran).
