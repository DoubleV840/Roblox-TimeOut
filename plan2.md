# TimeOut — Plan 2 : les paliers

`plan.md` a construit la boucle de survie : le temps s'écoule, on le farme, on le mise, on l'achète. Elle tourne, mais elle est **plate** — au bout de dix minutes le joueur a tout vu, et rien ne lui dit pourquoi rester.

Plan 2 lui donne une **verticalité**. Le Terminal devient un bâtiment à étages : le palier 1 est un sous-sol crasseux, et chaque palier au-dessus est plus propre, plus riche, plus rentable. On paie son billet **en temps**, on voit à travers les vitres ce qu'on est en train de rater, et chaque montée débloque de quoi financer la suivante.

La règle qui gouverne tout le reste : **le premier palier se franchit en une minute, le dernier en une semaine — mais aucun ne doit jamais paraître impossible.** Un joueur qui décroche parce qu'il ne voit plus le prochain palier est un joueur perdu.

> Les étapes de ce plan sont numérotées **à partir de 1** et n'ont rien à voir avec celles de `plan.md` (0 à 17). Quand ce document renvoie à une étape de l'autre plan, il le dit explicitement.

## Décisions prises

- **Le chrono descend toujours, à 1 s/s, à tous les paliers.** `plan.md` avait écarté les zones à drain variable ; on n'y revient pas par la fenêtre, et les paliers n'y touchent pas non plus. Un joueur immobile perd du temps au Terminus exactement comme sur le Quai.
- **L'auto-cliqueur est la seule source passive du jeu.** C'est le seul moyen de stabiliser ou de faire remonter le chrono sans rien faire — et il s'achète en Robux. Tout le reste demande un geste : cliquer, aller chercher une orbe, entrer dans un mini-jeu. **Aucune fonctionnalité de ce plan ne doit produire du temps toute seule.**
- **Le bonus de palier multiplie les gains actifs, pas le chrono.** Un palier supérieur ne ralentit pas l'hémorragie et ne verse rien tout seul : il augmente ce que rapporte chaque action — un clic, une orbe, un gain de mini-jeu.
- **Le palier est permanent.** Il se paie une fois, il ne se reperd jamais — même en mourant. Comme le déverrouillage des paris (étape 15 de `plan.md`) : ce qui est gagné est acquis.
- **Mourir renvoie au Quai.** Le joueur qui tombe à 0 réapparaît en bas (le train est parti sans lui), mais toutes ses barrières restent franchissables gratuitement. La mort coûte le trajet, pas la progression.
- **Les paliers remplacent les rangs.** Les 8 rangs existants (d'Éphémère à Seigneur Temporel) deviennent le vocabulaire visuel des 8 paliers : même symbole, même couleur, même badge. Mais le badge ne se calcule plus à partir du temps possédé — il affiche le palier atteint. Deux échelles parallèles, une gratuite et une payante, embrouilleraient tout le monde pour rien.
- **On monte en payant, on redescend gratuitement.** Un joueur palier 5 circule librement entre 1 et 5. Seul le pas vers le palier suivant est payant, et il ne peut pas se sauter.
- **Payer ne peut pas tuer.** Une entrée qui laisserait le joueur au ras de zéro est refusée. Se suicider en achetant un étage serait la pire première impression possible.
- **L'auto-cliqueur cesse d'être éternel.** Il se vend désormais par tranches de temps de fonctionnement, et son premier cran disparaît (lot 4).
- **Toute grosse récompense passe par un pack à trois choix**, jamais par un don direct. Un cadeau qui tombe tout seul se subit ; trois cartes forcent le joueur à lire sa propre situation et à décider.

## Le tableau des paliers

C'est **le** point à arbitrer, et tout le reste en découle. Le sommet est fixé : **le Terminus coûte 1000 h.** Le reste de l'échelle descend de là, en gardant un rapport qui s'aggrave à chaque marche — ×4 en bas, ×6,67 en haut. C'est ça, « simple au début puis de plus en plus dur » : ce n'est pas seulement le montant qui grossit, c'est le *saut*.

| # | Nom | Coût d'entrée | Cumul payé | Ratio | × gains actifs | Pack offert | Ce que le palier ouvre |
|---|---|---|---|---|---|---|---|
| 1 | Le Quai | — | — | — | ×1 | — | Cookie, orbes, pari 20 s |
| 2 | La Salle des pas perdus | 5 min | 5 min | — | ×1,5 | Commun | Chrono Boost, machine à sous |
| 3 | Le Buffet | 20 min | 25 min | ×4 | ×2 | Commun | Power-up *Critique*, chaises musicales |
| 4 | Le Salon 1re classe | 1 h 30 | 1 h 55 | ×4,5 | ×3 | Rare | Power-up *Écho*, roue de la fortune |
| 5 | La Verrière | 6 h | 7 h 55 | ×4 | ×5 | Rare | Power-up *Frénésie*, le Wagon |
| 6 | La Tour de l'horloge | 30 h | 1 j 14 h | ×5 | ×8 | Épique | Power-up *Poids du temps*, duel de clic |
| 7 | Les Coulisses | 150 h | 7 j 20 h | ×5 | ×13 | Épique | Power-up *Rouages*, le braquage |
| 8 | Le Terminus | **1000 h** | 49 j 12 h | ×6,67 | ×21 | Légendaire | Le Train de minuit |

Cinq choses à lire dans ce tableau :

- **« × gains actifs » n'est pas un revenu.** C'est un multiplicateur sur ce que rapporte **chaque action** : un clic sur le cookie, une orbe ramassée, un gain de mini-jeu, une carte de pack. Un joueur qui ne fait rien à la Verrière voit son chrono descendre à 1 s/s comme partout ailleurs. Concrètement, avec un Chrono Boost à 10 : un clic vaut 10 s au Quai, 50 s à la Verrière, 210 s au Terminus. C'est ce qui rend la montée rentable au lieu d'être une pure dépense, sans jamais créer de source passive.
- **Les coûts grimpent ×4 à ×6,67 par palier, les multiplicateurs seulement ×1,5 à ×1,6.** L'écart se comble par la progression parallèle du Chrono Boost, qui compose avec le multiplicateur — mais c'est **le risque d'équilibrage principal** : le dernier saut vaut à lui seul 6,7 fois le précédent et 84 % du cumul de toute la partie. Leviers de correction, par ordre de préférence : monter la fin de la suite des multiplicateurs, enrichir les packs des paliers 6-7, augmenter les gains des mini-jeux hauts. Baisser le 1000 h est le dernier recours — c'est lui qui donne son poids au Terminus.
- **Chaque montée offre un pack à ouvrir** (lot 3), dont la valeur attendue vaut ~40 % du coût d'entrée. Il amortit le choc de la dépense — on arrive dans une salle neuve avec de quoi respirer, pas avec un chrono à sec — mais surtout il transforme la récompense en décision.
- **Le cumul est indicatif.** Le joueur ne paie jamais les 49 jours d'un coup : il paie palier par palier, et entre deux paliers il produit avec un multiplicateur déjà amélioré. Il n'a jamais besoin de posséder plus de 1000 h à la fois.
- **1000 h est exactement le plus gros paquet Robux** (1000 h à 13 999 R$, étape 5 de `plan.md`). Un joueur peut donc s'acheter le Terminus en un seul achat. Argument de vente très fort — mais le contenu final s'ouvre alors sans avoir joué. Voir « Ce qui reste à trancher ».

**Estimation de la montée** — joueur qui clique ~5 fois/seconde et réinvestit au passage dans le Chrono Boost (dont la puissance passe de 1 à ~23 sur l'ensemble du parcours, la croissance de son prix ne permettant pas mieux) :

| Montée | 1→2 | 2→3 | 3→4 | 4→5 | 5→6 | 6→7 | 7→8 |
|---|---|---|---|---|---|---|---|
| Clic soutenu | ~1 min | ~2 min | ~4 min | ~6 min | ~10 min | ~20 min | ~45 min |

Soit **~1 h 30 de clic ininterrompu** pour tout le parcours, et chaque marche à peu près deux fois plus longue que la précédente — c'est la courbe recherchée. En jeu réel il faut compter 4 à 5 fois plus : personne ne clique 5 fois par seconde pendant une heure et demie, et le drain d'1 s/s mord sur tout.

À vérifier en jeu : c'est du calcul sur tableur, pas de la mesure.

**Une conséquence à assumer** : le drain valant 1 s/s partout alors qu'un clic finit par rapporter 200 s, la peur de mourir disparaît en haut de l'échelle. C'est inévitable dès lors que le drain ne suit pas les paliers — et c'est le bon compromis, parce qu'un drain qui accélérerait punirait le joueur d'avoir progressé. La tension **change de nature** : en bas on joue pour ne pas mourir, en haut pour s'offrir l'étage suivant. Les mini-jeux des hauts paliers doivent donc miser gros — c'est là que se rejoue le risque de tout perdre.

---

# Les étapes

Chaque étape est faite pour être livrée et testée **seule**, dans l'ordre. Le « fini quand » est le critère à vérifier en jeu avant de passer à la suivante. Le bloc « Dans Studio » liste ce qu'il faut poser à la main ; les étapes sans ce bloc ne demandent aucune manipulation.

Ces blocs sont repris, détaillés et mis dans l'ordre du chantier dans **`studio.md`** — c'est le fichier à suivre pour construire, celui-ci reste la spécification.

Tous les tags et attributs cités sont récapitulés en fin de document.

## Lot 1 — La verticalité

Le but du lot : que le jeu ait des étages et qu'on puisse y monter. Rien de joli, rien de riche — juste la mécanique, vérifiée de bout en bout sur deux salles avant d'en construire huit.

> **Code livré, en attente de test en jeu.** Rien ne se voit tant que la map n'a pas ses barrières et ses points de réapparition : la marche à suivre est dans `studio.md`.

- [x] **Étape 1 — La première barrière payante.** Deux salles seulement : le Quai, et une salle au-dessus. Entre les deux, une **barrière transparente** qui bouche le passage — on voit à travers, on ne passe pas.

  Sur la barrière, **un panneau plaqué à sa surface** (pas une étiquette flottante) affiche le nom de l'étage, son prix d'entrée, et un bouton. Cliquer le bouton ouvre la confirmation : si le joueur valide et a le temps, on lui retire les 5 minutes et il passe de l'autre côté. S'il n'a pas assez, le panneau le lui dit et ne propose rien.

  La barrière refuse aussi le paiement quand il ne resterait presque rien au joueur : personne ne doit pouvoir se tuer en achetant un étage.

  **Dans Studio**
  - Créer une **Part** qui bouche entièrement l'ouverture entre les deux salles — toute la largeur, toute la hauteur, sinon on la contourne.
  - Propriétés : `Anchored` coché, `CanCollide` **coché** (elle bloque vraiment), `Transparency` vers `0.6`, `Material` = `Glass` ou `ForceField`, `Color` à la teinte de l'étage visé.
  - Lui poser le tag **`TierGate`** (menu *View → Tag Editor*, créer le tag puis l'appliquer à la Part sélectionnée).
  - Lui ajouter un attribut **nombre** nommé **`TargetTier`**, valeur `2` (panneau *Properties*, tout en bas : *Attributes → Add Attribute*, type `number`).
  - Ajouter dans la Part une **SurfaceGui**, avec `Face` réglée sur le côté d'où arrivent les joueurs. C'est elle qui colle le panneau à la barrière au lieu de le faire flotter.
  - Le contenu du panneau (titre, prix, bouton, état verrouillé/ouvert) est écrit par le jeu : il n'y a **rien à mettre dedans à la main**, la SurfaceGui vide suffit.

  *Le bouton est dans le panneau, pas un prompt flottant.* C'est ce qui a été demandé, et c'est plus propre visuellement. La contrepartie : un bouton plaqué sur une surface n'affiche pas d'indice « appuie sur E » et se voit moins de loin. Si les tests montrent que les joueurs ne comprennent pas qu'on peut cliquer, l'ajout d'une **ProximityPrompt** sur la même Part réglera le problème sans rien changer au reste.

  *Fini quand :* on voit l'étage du dessus à travers la barrière, on ne peut pas la traverser, cliquer le panneau propose de payer, et payer fait passer de l'autre côté avec 5 minutes de moins.

  **Livré** — `src/server/TierService.luau` (achat, refus, sauvegarde immédiate), `src/client/TierGates.luau` (panneau + confirmation).

  Le panneau est construit **côté client**, et c'est le point de conception à retenir : trois joueurs devant la même barrière n'y lisent pas la même chose — « OUVERT », le prix, ou ce qu'il leur manque — et chacun dans sa langue. Un panneau écrit par le serveur serait partagé par tous et ne pourrait dire qu'une seule de ces trois choses.

  Conséquence sur la SurfaceGui de Studio : elle ne sert **qu'à dire quelle face** regarde les joueurs. Le panneau lui-même vit dans le PlayerGui avec `Adornee` pointant sur la barrière, parce qu'une SurfaceGui laissée dans le Workspace ne reçoit pas les clics.

  Payer n'éjecte pas de l'autre côté : la barrière **cesse de bloquer** et le joueur avance à pied. Téléporter un personnage à travers un mur dont le code ignore la géométrie était le meilleur moyen de le coincer dans le décor.

- [x] **Étape 2 — Le palier à l'écran.** À côté du chrono, en bas : le badge du palier et son nom. Le badge reprend le symbole et la couleur des rangs existants, mais affiche désormais le **palier atteint** et non plus un rang calculé sur le temps possédé. Le panneau de classement suit la même règle.

  *Fini quand :* le badge change au moment où on franchit la barrière, à l'écran comme sur le panneau de classement, et ne bouge plus quand le chrono monte ou descend.

  **Livré** — `src/shared/Ranks.luau` disparaît. Ce qui en restait d'utile, le badge rond, devient `src/shared/Badge.luau` et ne connaît plus qu'un couple symbole/couleur ; l'échelle vit dans `src/shared/Tiers.luau`. Les 8 clés `rank_*` sont supprimées des 11 langues et remplacées par `tier_1`..`tier_8`, qui portent les noms de salle.

  Un détail coûteux : le panneau de classement affiche aussi les joueurs **déconnectés**, dont on ne connaît pas le palier sans une lecture DataStore par ligne toutes les 3 secondes. Le palier est donc encodé dans le chiffre des unités de la valeur du classement (voir `TimeBalance`), ce qui oblige à passer `TIME_BALANCE_DATASTORE_NAME` en `_v2` — les temps en pause des joueurs hors ligne repartent de zéro une fois.

- [x] **Étape 3 — La barre de progression.** Sous le badge, une barre qui se remplit au fur et à mesure que le chrono approche du prix de l'étage suivant. Elle vire à la couleur du palier visé quand elle est pleine, et pulse.

  C'est le moteur psychologique de tout le plan : elle transforme « j'ai 3 minutes » en « il me manque 2 minutes ». Elle doit être visible en permanence.

  *Fini quand :* en cliquant sur le cookie, on voit la barre monter en direct, et elle se vide d'un coup quand on paie l'étage.

  **Livré** — barre pleine largeur sous le chrono. Elle vise le prix **plus la marge de sécurité** (`Config.TIER_SAFETY_MARGIN`), pas le prix nu : sinon elle serait pleine alors que l'entrée serait encore refusée. Elle disparaît au Terminus, quand il n'y a plus rien à viser.

- [x] **Étape 4 — L'échelle complète.** Les 8 paliers, avec leurs noms, leurs prix et leurs raretés de pack, tels qu'ils figurent dans le tableau plus haut. Une barrière par passage. Toutes les valeurs restent regroupées au même endroit pour qu'un test en jeu puisse tout réajuster.

  **Dans Studio**
  - Six barrières de plus, sur le modèle exact de l'étape 1, entre chaque paire de salles voisines.
  - Sur chacune, l'attribut `TargetTier` vaut l'étage qu'elle dessert : `3`, `4`, `5`, `6`, `7`, `8`.
  - Une seule barrière par passage suffit : elle s'ouvrira dans les deux sens pour qui a déjà l'étage (étape 6).

  *Fini quand :* on peut monter du Quai au Terminus en payant chaque marche, et le prix affiché sur chaque panneau correspond au tableau.

  **Livré** — les 8 paliers dans `src/shared/Tiers.luau` : prix, multiplicateur, rareté du pack, symbole, couleur. C'est le seul fichier à toucher pour réajuster l'échelle après un test.

- [x] **Étape 5 — Le multiplicateur de gains.** Chaque palier atteint multiplie ce que rapporte **chaque action** : un clic sur le cookie, une orbe ramassée, un gain de mini-jeu. Jamais le chrono tout seul, jamais l'auto-cliqueur.

  L'auto-cliqueur est exclu volontairement : c'est la seule source passive du jeu, et la multiplier par le palier ferait grimper un revenu automatique à ×21 en fin de partie — le jeu se jouerait tout seul.

  *Fini quand :* au palier 5, un clic rapporte exactement 5 fois ce qu'il rapportait au Quai, et le chrono continue de descendre à la même vitesse qu'avant.

  **Livré** — appliqué au clic (`TimeCookie`), à l'orbe (`TimeOrb`) et au gain de pari (`BettingGame`). Ni au drain, ni à l'auto-cliqueur.

  **À surveiller** : multiplier le gain de pari fait ressortir la cagnotte plus grosse qu'elle n'est entrée. C'est bien ce que demande ce plan (« un gain de mini-jeu »), et c'est ce qui rendra les mini-jeux des hauts paliers intéressants — mais c'est le seul endroit du jeu où du temps se crée à partir du temps des autres. À revoir quand les mises grossiront, ou si deux comptes complices s'en servent.

- [x] **Étape 6 — Circuler et mourir.** Une barrière d'un étage déjà atteint **cesse de bloquer** : le joueur la traverse à pied, dans les deux sens, sans payer et sans cliquer. Elle continue de bloquer tous les autres. Un joueur qui tombe à zéro réapparaît au Quai, mais garde son palier : ses barrières restent ouvertes pour lui.

  **Dans Studio**
  - Un point de réapparition (**SpawnLocation**) dans chaque salle, `Neutral` coché.
  - Celui du Quai est le seul avec une priorité de réapparition : c'est là qu'on revient après une mort.
  - Vérifier qu'**aucun chemin de marche** ne relie un étage au suivant en contournant sa barrière — pas de rebord, pas de saut possible, pas de trou dans le plafond. La barrière est le seul passage, sinon toute l'échelle se contourne à pied.

  *Fini quand :* un joueur palier 5 traverse ses quatre barrières à pied sans rien payer, un joueur palier 1 se cogne dessus, et mourir renvoie au Quai sans perdre le palier.

  **Livré** — une Part ne peut pas être solide pour un joueur et creuse pour son voisin : ça se joue en **groupes de collision**, un par palier côté joueur, un par étage desservi côté barrière, enregistrés au démarrage du serveur. Il n'y a donc aucun groupe à créer dans Studio.

  Le point de réapparition du Quai est celui qui porte l'attribut `TargetTier` = `1` ; à défaut, le jeu prend la SpawnLocation la plus basse de la map. C'est une convention de plus que le tableau des tags ne prévoyait pas — elle évite d'inventer un tag pour une seule Part.

## Lot 2 — Donner envie de monter

Le lot 1 rend la montée possible ; celui-ci la rend désirable. C'est ici que se joue la rétention : le joueur doit voir ce qu'il n'a pas.

> **Code livré pour les étapes 10 à 12, en attente de test en jeu.** Les étapes 7 à 9 sont du décor : elles se bâtissent à la main dans Studio et ne dépendent d'aucun code. Rien du lot ne se voit tant que les vitres ne sont pas posées — la marche à suivre est dans `studio.md`.

- [ ] **Étape 7 — Le Quai crasseux.** Béton fissuré, carrelage manquant, flaques, sacs poubelle, affiches décollées, graffitis, une fuite au plafond, et des néons verdâtres qui **grésillent**.

  Le palier 1 doit être franchement laid. C'est le seul étage que tout le monde voit ; s'il est joli, plus rien au-dessus ne fait envie.

  **Dans Studio**
  - Décor du Quai à bâtir à la main : matériaux `Concrete`, `CrackedLava` ou `Slate`, couleurs désaturées, quelques Parts volontairement de travers.
  - Poser le tag **`FlickerLight`** sur chaque source lumineuse à faire grésiller (`PointLight`, `SurfaceLight` ou la Part `Neon` qui la porte). Le jeu s'occupe du clignotement irrégulier.
  - Les taches, affiches et graffitis se font avec des **Decals** posés sur les murs et le sol.

  *Fini quand :* un joueur qui arrive dans le jeu a spontanément envie d'en partir.

- [ ] **Étape 8 — La montée en propreté.** Chaque étage est plus soigné que le précédent, selon cette charte :

  | Palier | Sol et murs | Lumière | Détails |
  |---|---|---|---|
  | 2–3 | Carrelage entier mais terne, peinture écaillée | Blanc froid, stable | Bancs dépareillés, machine à café en panne |
  | 4–5 | Marbre, boiseries | Doré chaud, verrière | Plantes, tapis, horloges qui marchent |
  | 6–7 | Laiton poli, verre | Ambre profond, projecteurs | Mécanismes d'horlogerie visibles, dorures |
  | 8 | Or, obsidienne | Lumière propre, sans source visible | Le train est là, à quai, moteur allumé |

  **Dans Studio**
  - Décor de chaque salle à bâtir à la main, en suivant la charte.
  - Ne poser **aucun** tag `FlickerLight` au-dessus du palier 3 : le grésillement est la signature du bas de l'immeuble.

  *Fini quand :* on devine à quel étage on se trouve sans lire un seul chiffre.

- [ ] **Étape 9 — Les vitres.** Un mur vitré entre chaque salle et celle du dessus, pour qu'on voie littéralement les joueurs mieux lotis vivre leur vie.

  Cela impose que les salles soient **mitoyennes**, pas dispersées : un escalier vitré qui longe les étages est la disposition la plus simple à tenir.

  **Dans Studio**
  - Des Parts `Material` = `Glass`, `Transparency` vers `0.5`, `CanCollide` coché, `Reflectance` faible.
  - Si les salles hautes disparaissent quand on les regarde d'en bas, c'est le chargement progressif du terrain : dans *Workspace*, augmenter `StreamingTargetRadius`, ou décocher `StreamingEnabled`. Une vitre qui donne sur le vide annule tout l'intérêt de l'étape.

  *Fini quand :* depuis le Quai, on voit bouger de vrais joueurs à l'étage au-dessus.

- [x] **Étape 10 — Les panneaux d'appel.** Devant chaque vitre, un panneau lumineux annonce ce qu'il y a de l'autre côté : le nom de l'étage, son prix d'entrée, et ce qu'il débloque. Dans la couleur de l'étage visé, avec le texte animé des panneaux existants.

  Pour un joueur qui a déjà l'étage, le panneau se tait : il est chez lui.

  **Dans Studio**
  - Poser le tag **`TierWindow`** sur chaque Part de vitre.
  - Lui ajouter un attribut **nombre** `TargetTier` avec l'étage qu'on voit à travers.
  - Y glisser une **SurfaceGui vide**, `Face` réglée sur le côté d'où arrivent les joueurs — exactement comme sur les barrières. Sans elle le panneau se pose sur la face avant de la Part, probablement du mauvais côté.
  - Rien d'autre : le panneau et son halo sont construits par le jeu à partir du tag.

  *Fini quand :* un nouveau joueur sait, sans qu'on lui explique, ce que coûte l'étage du dessus et ce qu'il y gagnerait.

  **Livré** — `src/client/TierWindows.luau`. Le panneau est construit **côté client**, comme celui des barrières et pour la même raison : deux joueurs devant la même vitre n'y lisent pas la même chose, et celui qui a déjà l'étage ne lit rien du tout. La SurfaceGui posée dans Studio ne sert qu'à dire quelle **face** de la vitre regarde les joueurs — c'est `src/client/WorldPanel.luau`, désormais partagé avec les barrières, qui l'exploite. On ne peut rien acheter ici : une vitre n'est pas un passage, le panneau donne envie et la barrière encaisse.

- [x] **Étape 11 — Le panneau au-dessus des joueurs.** Sur chaque personnage : le pseudo, le badge de son palier, et son chrono en direct, du même dégradé vert→rouge que le HUD — on doit repérer d'un coup d'œil qui est en train de mourir.

  Le joueur ne voit pas son propre panneau : il a déjà le HUD, et un panneau collé à sa nuque gênerait la caméra. Les panneaux s'effacent à distance pour qu'un hall plein n'encombre pas l'écran.

  *Fini quand :* à deux clients, chacun voit le palier et le chrono de l'autre défiler, et pas le sien.

  **Livré** — `src/client/Nameplates.luau`, alimenté par `src/server/Presence.luau`. Le chrono d'un **autre** joueur ne pouvait pas venir de `Remotes.TimeUpdated`, qui ne parle qu'à son propriétaire : il passe par deux **attributs** posés sur l'instance `Player`, qui se répliquent seuls à tous les clients, y compris à ceux qui arriveront plus tard. Le serveur ne publie que des secondes entières une fois par seconde ; les décimales descendent chez le client, image par image, comme celles du HUD. Le dégradé vert→rouge est celui de `Colors`, et nulle part ailleurs : sans ça on ne pourrait pas comparer sa propre couleur à celle des autres.

- [x] **Étape 12 — L'annonce d'une montée.** Quand un joueur franchit un étage, tout le serveur le voit : un message, un son, et son nom mis en avant un instant. Les montées vers les hauts paliers sont plus spectaculaires que les premières.

  C'est ce qui transforme une progression solitaire en événement social — et ce qui donne envie aux autres d'y aller.

  *Fini quand :* un joueur qui monte au palier 6 provoque une réaction visible chez les joueurs restés en bas.

  **Livré** — `src/client/TierAnnounce.luau`, sur `Remotes.TierAnnounce`. **L'ampleur suit l'étage**, et c'est tout le point : durée, largeur du bandeau et hauteur du son s'interpolent entre le palier 2 et le Terminus ; à partir du palier 6 s'ajoutent un coup grave et un embrasement de l'écran. Si les huit paliers s'annonçaient pareil, le dernier ne ferait plus rêver. Le serveur envoie l'**instance** `Player` et non un pseudo : c'est elle qui permet d'aller éclairer le bon personnage dans la salle — `Nameplates.Cheer`, qui grossit son panneau et pose un `Highlight` à la couleur de l'étage, pour qu'on sache **qui** a monté. Le joueur concerné ne voit pas son propre bandeau : il a déjà sa notification et son portique qui s'ouvre. La clé `notify_tier_announce` disparaît, le bandeau la remplace.

## Lot 3 — Les packs

Un pack s'ouvre et propose **trois cartes ; le joueur en garde une**. C'est la récompense de fin de palier, et aussi un produit de boutique. L'intérêt n'est pas la récompense, c'est le **choix** : un cadeau qui tombe se subit, trois cartes obligent à se demander où on en est. Deux joueurs au même palier ne jouent alors plus la même partie.

Le contenu détaillé des cartes est en fin de document, section « Le pool des cartes ».

> **Code livré.** Rien à poser dans Studio pour les étapes 13 à 15 ; l'étape 16 demande une Part taguée et **deux Developer Products à créer au Creator Dashboard**, sans quoi le guichet à packs reste muet.

- [x] **Étape 13 — Le pack minimal.** Monter d'un palier donne un pack. Une icône apparaît à l'écran ; l'ouvrir présente trois cartes ; le joueur en choisit une et l'effet s'applique. Pour cette étape, seules les six cartes Communes existent, et l'habillage reste sommaire.

  Trois règles de fond, à poser dès maintenant :
  - **Les trois cartes viennent de trois familles différentes** — une Immédiate, une Moteur, une Joker. Un choix entre trois choses semblables n'est pas un choix.
  - **Le tirage est décidé une fois pour toutes.** Se déconnecter et revenir ne change pas les trois cartes proposées, et ne fait pas apparaître un second pack.
  - **Aucune carte morte.** Une carte dont les conditions ne sont pas réunies n'est jamais proposée. Une carte inutile, c'est un pack à deux choix.

  *Fini quand :* monter d'un palier donne un pack, l'ouvrir propose trois cartes différentes, en choisir une l'applique — et se reconnecter en plein choix retrouve les mêmes trois cartes.

  **Livré** — `src/shared/Cards.luau` (le pool et ses conditions), `src/server/Packs.luau` (tirage, effets, sauvegarde), `src/client/Packs.luau` (icône et cérémonie). Les étapes 13 et 14 sont livrées ensemble : « seulement les Communes » était une étape de montage, pas un état à faire vivre.

  Le pack s'accroche à la montée par un **crochet** (`TierService.OnTierUp`) et non par un `require` : `Packs` a besoin de `TierService`, les deux se seraient demandés l'un l'autre au chargement.

  **Le palier est figé à la création du pack**, au même titre que le tirage. Les cartes valent un pourcentage du prix d'entrée : sans ça, garder ses packs fermés jusqu'au Terminus serait toujours le bon calcul, et personne n'en ouvrirait un seul avant la fin de l'échelle.

  Le pack est retiré de la pile **avant** que l'effet ne s'applique : un effet qui *yield* (rendre du temps peut recharger un personnage) laisserait sinon la porte ouverte à un second choix sur le même pack.

  **Le compte des Communes** : le plan en annonçait six, il y en a sept (3 Immédiates, 2 Moteur, 2 Joker). C'est le tableau du pool qui fait foi.

- [x] **Étape 14 — Le pool complet.** Les 21 cartes et les quatre raretés. La rareté du pack décide de celle des cartes qu'il peut proposer : un pack Rare tire au mieux des Rares, un Légendaire garantit au moins une Épique. Les raretés offertes par palier suivent la colonne du tableau.

  *Fini quand :* un pack Légendaire au palier 8 propose visiblement mieux qu'un pack Commun au palier 2.

  **Livré** — deux mécanismes, et il fallait les deux. Un **plafond** de rareté par pack, et un **plancher garanti** sur au moins une carte (Épique ≥ une Rare, Légendaire ≥ une Épique). Mais aussi des **poids** (`Config.PACK_WEIGHTS`) : une carte rare reste rare *à l'intérieur même* d'un pack qui l'autorise, sinon la rareté du pack serait la seule chose qui compte et un Légendaire donnerait une Légendaire trois fois sur quatre.

  La garantie ne s'applique qu'**après** le tirage normal, et sur une famille tirée au sort : forcée d'emblée, elle deviendrait un plafond et tous les packs Légendaires se ressembleraient.

- [x] **Étape 15 — La cérémonie d'ouverture.** Trois cartes face cachée, retournement décalé, halo à la couleur de la rareté, texte d'autant plus agité que la carte est rare, et le hall qui s'assombrit autour.

  C'est l'écran que les joueurs mettront dans leurs vidéos — il mérite plus de soin que n'importe quelle autre fenêtre du jeu.

  *Fini quand :* ouvrir un pack donne envie d'en ouvrir un autre.

  **Livré** — voile qui assombrit le hall, trois cartes face cachée, retournement **décalé** (une par une, avec un temps d'arrêt), halo à la couleur de la rareté, agitation du texte proportionnelle à la rareté, et la note du retournement qui monte avec elle : on entend ce qu'on a tiré avant de l'avoir lu.

  Le joueur ne peut cliquer qu'**après** le dernier retournement. Laisser choisir pendant l'animation reviendrait à la rendre facultative, et personne ne la verrait deux fois.

  Le serveur n'envoie que trois identifiants de carte, la rareté et le palier : tout le texte et tous les chiffres sortent de `Cards.luau`, que le client a déjà — donc dans sa langue, sans un octet de texte sur le réseau.

- [x] **Étape 16 — Les packs en boutique.** Un troisième guichet, à côté de celui du temps et de celui de l'auto-cliqueur, vendant des packs contre des Robux. Deux produits : un pack Rare et un pack Légendaire.

  **Dans Studio**
  - Une Part au sol, comme les guichets existants, avec le tag **`ShopZone`**.
  - Lui ajouter l'attribut **texte** `ShopKind` avec la valeur **`Pack`** (les guichets actuels utilisent `Time` et `AutoClick`).
  - L'aura et le panneau du guichet sont posés par le jeu, il n'y a rien à décorer.

  **Hors Studio** — dans le Creator Dashboard, *Monetization → Developer Products* : créer deux produits (pack Rare, pack Légendaire) et reporter leurs identifiants dans les réglages, comme pour les paquets de temps de l'étape 5 de `plan.md`.

  *Fini quand :* on peut acheter un pack, et un rachat immédiat après reconnexion ne le crédite pas deux fois.

  **Livré** — troisième sorte de guichet (`ShopKind` = `Pack`), qui passe par le `ProcessReceipt` existant : l'anti double-crédit par `PurchaseId` couvre les packs sans une ligne de plus.

  **À faire hors du code** : `Config.PACK_PRODUCTS` porte deux `productId` à **`0`**. Tant qu'ils y sont, le guichet n'affiche rien et le serveur refuse de vendre — c'est le comportement voulu, pas une panne. Créer les deux produits au *Creator Dashboard → Monetization → Developer Products* et recopier leurs identifiants.

## Lot 4 — L'auto-cliqueur revu

Deux corrections à ce qui existe. Elles sont indépendantes et se livrent dans cet ordre. Aucune ne demande de manipulation dans Studio.

> **Code livré.** Rien à poser dans Studio, mais **le prix du Developer Product est à changer dans le Creator Dashboard** — voir l'étape 18.

- [x] **Étape 17 — Supprimer le premier cran.** Aujourd'hui le premier achat rapporte exactement 1 seconde par seconde : il annule le drain, et le chrono se **fige**. C'est le pire produit possible — le joueur paie et regarde un compteur immobile, sans savoir si ça marche. Le premier achat doit désormais démarrer au cran du dessus, pour que le chrono **remonte** visiblement dès la première seconde. Les achats suivants continuent de doubler.

  *Fini quand :* le tout premier achat fait monter le chrono, sans ambiguïté, à l'œil nu.

  **Livré** — une seule valeur change : `Config.AUTOCLICK_BASE_RATE`, de `1` à `2`. Le 1er achat donne 2 s/s contre un drain d'1 s/s, donc **+1 s/s net** : le chrono remonte. Les achats suivants doublent toujours. Le client refait le même calcul depuis `Config`, il n'y avait rien à synchroniser.

- [x] **Étape 18 — Le carburant.** Un auto-cliqueur infini tue la boucle du jeu : passé le premier achat, il n'y a plus rien à faire. Il se vend désormais avec une **durée de fonctionnement**. Le niveau acheté reste acquis pour toujours, mais il ne tourne que tant qu'il reste du carburant ; à sec, il s'arrête et attend un rachat. Rien ne se consomme pendant qu'un joueur est devant l'écran de mort.

  Les joueurs qui possèdent déjà un auto-cliqueur reçoivent un plein : ils avaient payé pour de l'infini, on ne leur reprend pas sans contrepartie.

  Le prix est à revoir : le produit vend maintenant une durée, plus une possession définitive.

  *Fini quand :* un auto-cliqueur s'arrête tout seul en fin de durée, et un rachat le relance.

  **Livré** — `data.AutoClickFuel`, en secondes de fonctionnement. Un achat donne **un niveau + un plein**, et le plein s'**ajoute** à ce qui reste : racheter en avance ne gaspille jamais. Rien ne brûle hors ligne, rien ne brûle devant l'écran de mort. Si le réservoir se vide en cours de tick, seul ce qui a réellement brûlé est crédité.

  Les possesseurs actuels reçoivent un plein à leur prochaine connexion : ils avaient payé pour de l'infini, on ne leur reprend pas sans contrepartie.

  **Arbitrages pris** — prix : **99 R$**. Un achat donne **un plein de 2 h + un jeton**, et le jeton se dépense dans l'une des deux branches :

  - **Puissance** — +2 s/s de débit, définitif
  - **Autonomie** — +4 h de carburant

  Et l'auto-cliqueur **tourne hors ligne** : le carburant brûle pendant l'absence, le temps est crédité au retour.

  **Pourquoi un choix plutôt qu'un versement.** C'est la règle des packs du lot 3, appliquée ici : un cadeau qui tombe se subit, deux cartes obligent le joueur à lire sa propre situation. Deux joueurs qui ont dépensé autant n'ont alors plus le même auto-cliqueur — l'un tient longtemps, l'autre frappe fort.

  **Pourquoi le débit ne double plus.** Un débit exponentiel face à un prix fixe rend les paquets de temps ridicules : avec l'ancienne courbe, le 6ᵉ achat rapportait 128 h pour 99 R$, quand le paquet de 100 h en coûte 1999. Le débit monte donc de façon linéaire — 2, 4, 6, 8… — et c'est le choix qui porte la richesse du produit, pas l'explosion des chiffres.

  Ce que valent N achats, selon la branche prise à chaque fois :

  | Achats | Coût | Tout Puissance | Tout Autonomie |
  |---|---|---|---|
  | 1 | 99 R$ | 8 h | 12 h |
  | 2 | 198 R$ | 20 h | 24 h |
  | 3 | 297 R$ | 36 h | 36 h |
  | 4 | 396 R$ | 56 h | 48 h |
  | 5 | 495 R$ | 80 h | 60 h |
  | 6 | 594 R$ | 108 h | 72 h |

  Les deux courbes se croisent au 3ᵉ achat : l'autonomie paie tout de suite, la puissance paie ensuite. Aucune ne domine, ce qui est la seule chose qui rende un choix intéressant.

  À 108 h pour 594 R$, l'auto-cliqueur reste ~2,5 fois plus rentable que le meilleur paquet de temps (1000 h à 13 999 R$). C'est voulu — c'est le produit premium — et c'est tenable, là où le facteur 55 de la version précédente ne l'était pas.

  **Le jeton attend dans la sauvegarde** au lieu d'être consommé à l'achat : le flux Roblox va du prompt à `ProcessReceipt`, et une intention notée avant le prompt serait perdue si le joueur se déconnecte entre les deux. La fenêtre s'ouvre d'elle-même au retour d'un achat, mais une icône reste s'il la referme, et un jeton se retrouve intact à la session suivante. **C'est la mécanique que réclament les packs de l'étape 13** : elle est construite ici pour deux cartes, elle se remplira là-bas avec les siennes.

  Le rattrapage hors ligne se calcule depuis `AutoClickSeenAt`, une marque posée à **chaque tour de boucle** et non au départ du joueur : un serveur qui tombe n'émet aucun `PlayerRemoving`, et il n'est pas question d'offrir des heures de carburant à quelqu'un que le jeu a lui-même éjecté. Rien ne court non plus pendant que le joueur était devant l'écran de mort.

  **Deux points à surveiller** :

  - Hors ligne, le chrono est gelé : une heure d'absence rapporte le débit **plein**, une heure de jeu le débit moins le drain. L'écart ne pèse qu'aux premiers crans ; ensuite le drain ne compte plus. `Config.AUTOCLICK_OFFLINE_RATIO` et `Config.AUTOCLICK_OFFLINE_MAX` sont là, neutres, pour corriger sans toucher au code.
  - Le carburant stocké brûle **au débit du moment** : prendre l'autonomie plusieurs fois puis la puissance rapporte plus qu'alterner. Assumé — avec un débit linéaire l'écart reste dans un facteur 2, là où il aurait explosé avec l'ancien débit qui doublait.

  **À faire hors du code** : le champ `robux` de `Config` ne sert qu'à l'affichage. Le vrai prix se change dans le *Creator Dashboard → Monetization → Developer Products*, sur le produit `3710399391` : **999 → 99 R$**. Tant que ce n'est pas fait, le jeu annonce 99 et facture 999.

- [x] **Étape 19 — La jauge de carburant.** Un compte à rebours à l'écran, qui passe au rouge et pulse dans la dernière minute. Le bourdonnement de l'auto-cliqueur se coupe quand il tombe à sec.

  *Fini quand :* le joueur sait toujours combien de temps il lui reste, sans avoir à le deviner.

  **Livré** — bandeau en haut à droite, au-dessus du HUD des paris : compte à rebours, barre de remplissage, rouge et pulsation dans la dernière minute (`Config.AUTOCLICK_LOW_FUEL`), et un état « à sec » qui reste affiché tant que le joueur possède un niveau — sinon il ne comprendrait pas pourquoi plus rien ne rentre.

  Le compte à rebours descend **côté client**, image par image, exactement comme le chrono : le serveur ne le recale que toutes les 15 s (`Config.AUTOCLICK_SYNC_INTERVAL`), au lieu d'un message par seconde et par joueur. Le bourdonnement se coupe au moment où le réservoir se vide.

  Le guichet affiche aussi le carburant restant et ce que donne le prochain achat.

## Lot 5 — Les power-ups du cookie

Le Chrono Boost reste la progression de fond. Autour de lui, cinq power-ups **débloqués par palier** — c'est ça, « des salles plus riches avec plus de fonctionnalités » : chaque étage ajoute une manière de cliquer. Tous s'achètent en temps, jamais en Robux : les Robux restent au guichet, et le cookie reste un jeu de patience.

Chaque power-up se prend sur une zone au sol, sur le modèle des zones Chrono Boost existantes.

> **Code livré.** Rien ne se voit tant que les cinq Parts ne sont pas posées et taguées dans les bonnes salles — la marche à suivre est dans `studio.md`.

- [x] **Étape 20 — Critique (palier 3).** La première carte du lot, et celle qui pose le modèle : une zone d'achat, une fenêtre, un niveau qui monte, un prix qui grimpe. Effet : chaque clic a une chance de rapporter ×10, la chance augmentant de 2 % par niveau.

  Une fois cette étape faite, les quatre suivantes ne sont que du contenu.

  **Dans Studio**
  - Une Part plate au sol dans **Le Buffet** (palier 3), comme les zones de Chrono Boost.
  - Tag **`PowerUpZone`**, plus un attribut **texte** `PowerUp` valant **`Critique`**.
  - Le portique, l'aura et le panneau sont construits par le jeu : une Part nue taguée suffit.

  *Fini quand :* on achète Critique au Buffet, et on voit passer des clics dorés à ×10.

  **Livré** — `src/shared/PowerUps.luau` (l'échelle : palier requis, prix, effet de chaque niveau), `src/server/PowerUpZones.luau` (la vente), `src/client/PowerUpZones.luau` (la fenêtre et le panneau). Les effets, eux, sont appliqués **là où ils se jouent** : `TimeCookie` pour les quatre power-ups de clic, l'auto-cliqueur pour le carburant des Rouages.

  **Les prix se dérivent du palier** (`costShare`) au lieu d'être écrits à la main : un power-up qui s'ouvre au palier 7 s'achète avec l'argent du palier 7, et une retouche du tableau des paliers n'oblige pas à reprendre les cinq échelles de prix.

  Un seul endroit calcule ce que vaut un niveau — la fenêtre d'achat et le serveur lisent la même fonction, donc l'annonce ne peut pas mentir sur l'effet.

  Le clic critique change de couleur, de taille et de son : un ×10 qui ne se voit pas ne récompense rien, et c'est le seul retour possible sur un power-up dont l'effet est par nature intermittent.

- [x] **Étape 21 — Écho (palier 4) et Poids du temps (palier 6).** Deux passifs. *Écho* : chaque clic se répète 0,4 s plus tard, à moitié de sa valeur. *Poids du temps* : le gain par clic augmente avec le chrono possédé — riche quand on est riche, nul quand on agonise.

  **Dans Studio**
  - Une zone `PowerUpZone` dans **Le Salon 1re classe**, attribut `PowerUp` = `Echo`.
  - Une zone `PowerUpZone` dans **La Tour de l'horloge**, attribut `PowerUp` = `PoidsDuTemps`.

  *Fini quand :* les deux s'achètent, se cumulent avec Critique, et leurs effets se voient à l'écran.

  **Livré** — l'écho **ne se ré-écho pas** : un seul clic rebondirait sinon indéfiniment, chaque niveau rapprochant un peu plus la chaîne de l'infini.

  Le *Poids du temps* suit le **logarithme** du chrono, pas le chrono : linéaire, un joueur à 1000 h aurait un clic douze mille fois plus fort qu'un joueur à 5 min — ce n'est plus un power-up, c'est une autre partie. Il retombe exactement à ×1 quand il ne reste plus rien, ce que le plan demandait.

  Tout ce qui entre dans un clic est désormais listé en tête de `src/server/TimeCookie.luau`. C'est le geste le plus répété du jeu : rien ne doit s'y ajouter sans passer par cette liste.

- [x] **Étape 22 — Frénésie (palier 5).** Le seul consommable : ×5 sur tous les clics pendant 20 secondes, avec 3 minutes de recharge. Ça donne un geste actif à répéter, et un pic de puissance à déclencher au bon moment.

  Retour visuel fort attendu : le cookie s'embrase. C'est le moment le plus spectaculaire du jeu après l'ouverture d'un pack.

  **Dans Studio**
  - Une zone `PowerUpZone` dans **La Verrière**, attribut `PowerUp` = `Frenesie`.

  *Fini quand :* déclencher une Frénésie change visiblement le rythme de la partie pendant 20 secondes.

  **Livré** — c'est le **seul consommable** du lot, et donc le seul qui change quelque chose à la façon de *jouer* : les quatre autres sont passifs. Il lui faut un bouton permanent en bas de l'écran, pas une ligne dans une fenêtre qu'on ouvre en marchant sur une dalle — un pic de puissance ne sert à rien s'il faut traverser la salle pour l'allumer.

  Les niveaux allongent la fenêtre (+2 s) et raccourcissent la recharge (−10 s, plancher à 1 min). La recharge descend **côté client**, image par image ; le serveur ne le recale qu'au moment où elle revient à zéro.

- [x] **Étape 23 — Rouages (palier 7).** Chaque clic ajoute du carburant à l'auto-cliqueur. Dépend du lot 4 : à faire après l'étape 18.

  Le clic manuel finance ainsi la source passive, sans jamais l'offrir : le niveau reste ce qu'on ne peut obtenir qu'en Robux.

  **Dans Studio**
  - Une zone `PowerUpZone` dans **Les Coulisses**, attribut `PowerUp` = `Rouages`.

  *Fini quand :* cliquer fait monter la jauge de carburant.

  **Livré** — volontairement **maigre par clic** (0,05 s de carburant par niveau) : de quoi soulager un réservoir, pas de quoi rendre l'achat inutile. Et il ne remplit rien du tout tant qu'il n'y a pas de machine à alimenter — le **niveau** de l'auto-cliqueur reste la seule chose du jeu qui ne s'obtienne qu'en Robux, seul son carburant se gagne ici.

## Lot 6 — Un mini-jeu par palier

Le pari existant est le mini-jeu du Quai. Sept autres suivent, aux mises croissantes, un par étage. Chacun est verrouillé tant que le palier n'est pas atteint : la zone affiche un cadenas et explique ce qu'il faut atteindre, comme les paris verrouillés de l'étape 15 de `plan.md`.

Toutes les zones de mini-jeu se posent de la même façon dans Studio :

> Une Part plate au sol, tag **`MiniGameZone`**, plus trois attributs : **texte** `Game` (le nom du jeu), **nombre** `BetAmount` (la mise en secondes), **nombre** `MinTier` (le palier requis). Le décor, l'aura, le panneau et le cadenas sont construits par le jeu.

> **Code livré pour les huit jeux.** Les zones `BetZone` déjà posées continuent de fonctionner sans être retouchées ; les sept autres jeux demandent une Part taguée par salle, et quatre d'entre eux un décor propre — la marche à suivre est dans `studio.md`.

- [x] **Étape 24 — Unifier les zones de jeu.** Avant d'en écrire un deuxième : faire en sorte que toutes les zones de mini-jeu se comportent de la même façon — entrer dans la zone, confirmer sa mise, voir le décompte avant le tirage, voir qui participe, être remboursé si personne ne vient, voir le résultat, et trouver la zone verrouillée si le palier manque. Le pari actuel devient le premier client de ce comportement commun.

  **C'est le vrai travail du lot.** Les sept jeux suivants ne sont alors qu'une règle de désignation du gagnant chacun. Écrire le deuxième mini-jeu sans avoir unifié le premier, c'est s'engager à en maintenir huit.

  **Dans Studio**
  - Les zones de pari existantes (`BetZone`) restent en place et continuent de fonctionner. Rien à retoucher pour cette étape.

  *Fini quand :* le pari fonctionne exactement comme avant, mais son comportement est devenu réutilisable tel quel.

  **Livré** — `src/server/MiniGames.luau` porte tout le commun (entrer, miser, décompter, montrer qui participe, rembourser, payer, verrouiller par palier, alimenter le Train), `src/server/MiniGameRules.luau` les huit règles, `src/client/MiniGames.luau` la fenêtre, le cadenas, le HUD et la scène. `src/server/BettingGame.luau` **disparaît** : le pari est devenu une règle de sept lignes parmi huit, ce qui est exactement ce que l'étape demandait.

  Le cadre lit **les deux tags** : une `BetZone` est une `MiniGameZone` dont le jeu est « Pari ». Les zones déjà posées gardent leur `BetAmount` **et** leur déverrouillage au plus haut temps tenu ; les nouvelles se verrouillent par palier, et les deux verrous se cumulent là où ils s'appliquent.

  Une règle ne rend qu'une table **joueur → part de la cagnotte**. Le cadre applique ensuite le multiplicateur de palier, rembourse les perdants assurés, prélève la dîme du Train et sauvegarde. C'est ce contrat-là qui fait tenir les sept jeux suivants en un bloc chacun.

  Trois formes de partie suffisent à les couvrir : **Solo** (on mise, le sort tranche aussitôt), **Tirage** (inscription, décompte, résultat), **Arène** (inscription, puis une phase active où l'on joue vraiment).

  Côté client, la popup de pari, le cadenas et le HUD des tours **quittent `init.client.luau`** : les sept autres jeux les ont eus sans écrire une ligne d'interface.

- [x] **Étape 25 — Le Distributeur détraqué (palier 2).** Machine à sous solo : on mise, on tire, on récupère entre 0 et 10 fois la mise. Le plus simple des sept, sans synchronisation entre joueurs — c'est pour ça qu'il vient en premier, il valide le cadre de l'étape 24.

  **Dans Studio** — une zone `MiniGameZone` dans La Salle des pas perdus : `Game` = `Distributeur`, `BetAmount` = `60`, `MinTier` = `2`.

  *Fini quand :* on peut miser et perdre, miser et gagner gros, et le HUD des tours reste juste.

  **Livré** — l'espérance est volontairement **sous 1** (~0,88) : une machine à sous rentable serait une imprimante à temps, et le joueur y passerait la partie. Elle reste attirante parce que le ×10 existe et se voit — c'est le seul chiffre qu'on retient d'une machine à sous.

- [x] **Étape 26 — Les Chaises musicales (palier 3).** Des dalles s'éteignent une à une, le dernier joueur debout remporte la cagnotte.

  **Dans Studio** — une zone `MiniGameZone` dans Le Buffet (`Game` = `Chaises`, `MinTier` = `3`), plus une grille de Parts-dalles au-dessus d'un vide, groupées dans un même dossier à côté de la zone.

  **Livré** — premier jeu à phase active, donc celui qui valide `Run()`. Une dalle s'éteint par tour ; qui était dessus tombe.

  **Sans dalles, la partie se joue quand même** : on élimine alors le joueur le plus loin du centre de la zone. C'est la règle la moins arbitraire qu'on puisse tenir sans décor — rester au milieu paie — et elle rend le jeu testable aujourd'hui, ce qui est la situation. Les dalles le rendront physique le jour où elles existeront. Toutes leurs propriétés sont relevées avant la partie et rendues après.

- [x] **Étape 27 — La Roue (palier 4).** Une roue partagée, chacun mise sur un secteur avant le lancer.

  **Dans Studio** — une zone `MiniGameZone` dans Le Salon (`Game` = `Roue`, `MinTier` = `4`), plus une Part cylindrique servant de roue, à côté de la zone.

  **Livré** — six secteurs, choisis **au moment de s'inscrire** : c'est le seul jeu où l'on décide de quelque chose en misant, et le seul où deux joueurs peuvent gagner ensemble sans être alliés. Il tourne à un seul joueur — une roue n'a besoin de personne.

  La roue du décor tourne pour de vrai si elle existe, mais c'est **purement cosmétique** : le résultat est déjà tiré quand elle démarre.

- [x] **Étape 28 — Le Wagon (palier 5).** Une plateforme qui rétrécit ; on gagne en tenant jusqu'au bout.

  **Dans Studio** — une zone `MiniGameZone` dans La Verrière (`Game` = `Wagon`, `MinTier` = `5`), plus une plateforme isolée au-dessus du vide.

  **Livré** — la plateforme rétrécit en huit crans jusqu'au quart de sa taille ; qui n'est plus dessus est éliminé, avec une marge de tolérance pour ne pas punir un pied qui dépasse pendant qu'elle rétrécit sous lui. **Sans plateforme, la zone elle-même fait l'affaire** : le jeu est jouable avant que la map n'existe. Elle revient à sa taille à la fin — la partie suivante doit trouver le wagon comme la première l'a trouvé.

- [x] **Étape 29 — Le Duel (palier 6).** Un contre un, le plus rapide au clic sur 15 secondes.

  **Dans Studio** — une zone `MiniGameZone` dans La Tour (`Game` = `Duel`, `MinTier` = `6`), plus deux emplacements face à face.

  **Livré** — premier jeu où le joueur **agit** pendant la partie. Au-delà de deux inscrits les autres attendent le tour suivant, et la place prise, la partie démarre sans attendre la fin du décompte.

  Les clics partent par **paquets**, dix fois par seconde : un message par clic saturerait le réseau pour un compteur que le serveur sait additionner. Ils sont comptés côté serveur et **plafonnés sur le temps écoulé depuis le début**, pas entre deux paquets : une rafale ponctuelle passe, un flux constamment impossible est coupé. Le plafond est généreux — il écarte la triche grossière, il ne pénalise personne.

  Égalité parfaite : les deux se partagent. Départager au hasard un duel où personne n'a été le meilleur serait une punition gratuite.

- [x] **Étape 30 — Le Braquage (palier 7).** Coopératif : le groupe réussit ensemble ou perd tout.

  **Dans Studio** — une zone `MiniGameZone` dans Les Coulisses (`Game` = `Braquage`, `MinTier` = `7`), plus un coffre.

  **Livré** — le seul jeu du lot où les participants **ne jouent pas les uns contre les autres**, et c'est ce qui en fait le bon jeu du palier 7 : tout le monde y est déjà riche, seule une perte collective fait encore peur.

  L'objectif monte avec le nombre de braqueurs mais **moins vite qu'eux** — venir à plusieurs aide vraiment, sinon personne n'irait chercher les autres. En cas de succès, la cagnotte n'est pas partagée entre eux, elle est multipliée pour chacun.

- [x] **Étape 31 — Le Train de minuit (palier 8).** Une fois par heure, un événement de serveur avec une cagnotte alimentée par tous les paliers. C'est le sommet du jeu — il doit s'annoncer longtemps à l'avance et se voir de tous les étages.

  **Dans Studio** — une zone `MiniGameZone` sur le quai du Terminus (`Game` = `TrainDeMinuit`, `MinTier` = `8`), et le train lui-même, visible depuis les vitres des étages inférieurs.

## Lot 7 — Les cadeaux de survie

> **Code livré.** Rien à poser dans Studio : l'échelle, l'icône et la fenêtre sont entièrement dans le code.

  **Livré** — le seul jeu qui **ne s'ouvre pas quand on entre dedans** : il part tout seul une fois par heure, s'annonce cinq minutes à l'avance à tout le serveur, puis reste à quai une minute pendant laquelle on monte en marchant dedans — ce qu'on fait d'un train.

  **L'embarquement est gratuit.** Sa cagnotte n'est pas faite des mises : elle est faite d'une dîme de 5 % prélevée sur *toutes* les autres cagnottes du serveur. C'est ça, « une cagnotte alimentée par tous les paliers » — un joueur du Terminus n'y paie rien, il encaisse ce que le serveur entier a produit depuis une heure. C'est aussi la seule chose qui limite un peu la création de temps des mini-jeux.

  Le tirage se joue sur un coup de dés, et c'est voulu : en haut de l'échelle le drain d'1 s/s ne fait plus peur à personne, il faut que quelque chose reprenne le rôle.

- [x] **Étape 32 — Les paliers de récompense.** Des cadeaux attribués quand le joueur atteint certains totaux de temps — sur le **plus haut temps qu'il ait jamais tenu**, jamais sur son temps courant : sinon il monte et redescend en boucle pour réencaisser.

  | Atteint | Cadeau |
  |---|---|
  | 10 min | +2 min |
  | 30 min | Une recharge de carburant |
  | 1 h | +15 min |
  | 3 h | 1 niveau de Chrono Boost |
  | 6 h | +1 h |
  | 12 h | Une Frénésie gratuite |
  | 1 j | +4 h |
  | 3 j | **Pack Rare** |
  | 7 j | +1 j |
  | 20 j | **Pack Épique** |
  | 50 j | **Pack Légendaire** et un badge cosmétique |

  L'échelle monte jusqu'à 50 jours parce que c'est l'ordre de grandeur du cumul à payer pour atteindre le Terminus. Le dernier cadeau tombe donc pile au moment où un joueur vise le palier 8.

  Les gros cadeaux paient en packs, les petits en nature : un pack demande un geste, il vaut pour une grosse récompense et serait pénible toutes les dix minutes.

  **À réclamer, pas à recevoir.** Une icône pulse à l'écran, le joueur clique, ça s'ouvre avec une animation. Un cadeau encaissé sans qu'on le remarque n'a rien récompensé du tout. Un cadeau reste réclamable indéfiniment : un joueur déconnecté au mauvais moment ne perd rien, et rien ne se réclame deux fois.

  *Fini quand :* atteindre un seuil fait apparaître l'icône, la réclamer donne le cadeau, et se reconnecter ne permet pas de la réclamer à nouveau.

  **Livré** — `src/shared/Rewards.luau` (l'échelle), `src/server/Rewards.luau` (les seuils et les cadeaux), `src/client/Rewards.luau` (l'icône et la fenêtre).

  La fenêtre montre **toute l'échelle**, pas seulement ce qui est mûr : les seuils déjà pris, ceux qui attendent, et ceux qu'il reste à atteindre. C'est ce qui transforme une liste de récompenses en objectif — un joueur qui voit « 3 j : pack Rare » sait pourquoi il tient encore.

  Le seuil est marqué réclamé **avant** que le cadeau ne parte : un donneur qui *yield* (rendre du temps peut recharger un personnage) laisserait sinon la porte ouverte à deux cadeaux pour un.

  **Un piège de sauvegarde qui vaut d'être noté** : un DataStore resérialise en JSON, et une table à clés entières non contiguës (`{[3] = true}`) revient avec des clés **texte** (`{["3"] = true}`). Un cadeau marqué réclamé sous `3` se serait retrouvé réclamable sous `"3"` à la session suivante — soit exactement ce que ce lot promet de ne jamais faire. Les clés sont donc écrites en texte des deux côtés.

  **Un cadeau qui ne peut pas être livré n'est pas consommé.** Le seul cas est la Frénésie offerte à 12 h : elle ne veut rien dire tant que le power-up n'est pas acheté (palier 5). La réclamation est alors refusée avec son motif, et le cadeau reste en attente — « réclamable indéfiniment » ne souffre pas d'exception.

---

# Récapitulatif des tags et attributs

Tout ce qui est à poser à la main dans Studio, en une seule table. Les tags se posent avec l'éditeur de tags (*View → Tag Editor*), les attributs en bas du panneau *Properties* (*Attributes → Add Attribute*).

| Tag | Sur quoi | Attributs | Étape |
|---|---|---|---|
| `TierGate` | La barrière transparente d'un passage | `TargetTier` *(nombre)* — l'étage desservi | 1, 4 |
| `TierWindow` | Un mur vitré | `TargetTier` *(nombre)* — l'étage qu'on voit | 10 |
| `FlickerLight` | Une lumière du bas de l'immeuble | — | 7 |
| `ShopZone` *(existant)* | Le guichet à packs | `ShopKind` *(texte)* = `Pack` | 16 |
| *(aucun tag)* | Le **décor** d'un mini-jeu (dalles, roue, plateforme, coffre) | `Decor` *(texte)* sur la zone — le nom de l'instance à prendre ; facultatif | 26–31 |
| `PowerUpZone` | Une zone d'achat de power-up | `PowerUp` *(texte)* = `Critique`, `Echo`, `Frenesie`, `PoidsDuTemps` ou `Rouages` | 20–23 |
| `MiniGameZone` | Une zone de mini-jeu | `Game` *(texte)*, `BetAmount` *(nombre)*, `MinTier` *(nombre)* | 24–31 |
| *(aucun tag)* | La **SpawnLocation** du Quai | `TargetTier` *(nombre)* = `1` — facultatif, sinon la plus basse fait foi | 6 |

Tags déjà en place et inchangés : `TimeCookie`, `ClickUpgrade`, `BetZone`, `TimeOrb`, `HallOfFameBoard`, `ShopZone`.

**Une règle qui vaut pour tous** : une Part nue et taguée suffit. Le décor — portiques, auras, panneaux, cadenas — est construit par le jeu à partir du tag. Il n'y a jamais rien à décorer à la main autour d'une zone.

---

# Le pool des cartes

Toutes les valeurs de temps s'expriment en **pourcentage du prix d'entrée du palier courant**, jamais en secondes fixes. Un « +2 min » est décisif au palier 2 et risible au palier 7 — une carte à valeur fixe devient un déchet en fin de partie et pourrit le tirage.

Chaque pack propose exactement une carte de chaque famille.

| Famille | Ce qu'elle apporte | Le joueur qui la prend |
|---|---|---|
| **Immédiat** | Du temps, tout de suite | est en danger, il veut survivre |
| **Moteur** | Une amélioration permanente | tient le coup, il construit |
| **Joker** | Une règle tordue, un pari, un consommable | s'amuse ou tente un coup |

**Immédiat**

| Carte | Rareté | Effet |
|---|---|---|
| Lingot de temps | Commun | +25 % du prix d'entrée |
| Bidon de carburant | Commun | Une recharge complète d'auto-cliqueur |
| Poignée de jetons | Commun | 3 mises de mini-jeu offertes |
| Coffre de temps | Rare | +50 % du prix d'entrée |
| Pluie d'orbes | Rare | Les orbes valent ×3 et reviennent instantanément pendant 60 s |
| Wagon-coffre | Épique | +100 % du prix d'entrée |
| Le magot | Légendaire | +200 % du prix d'entrée |

**Moteur**

| Carte | Rareté | Effet |
|---|---|---|
| Rouage neuf | Commun | +2 niveaux de Chrono Boost |
| Orbes bonifiées | Commun | Les orbes rapportent 50 % de plus, définitif |
| Orbes accélérées | Rare | Les orbes reviennent 40 % plus vite, définitif |
| Bielle | Rare | Le gain de base par clic passe de 1 s à 2 s, définitif |
| Plan volé | Rare | Débloque **en avance** un power-up du palier suivant |
| Éclat de palier | Épique | +1 cran de multiplicateur de gains, cumulable, définitif |
| Horloge maîtresse | Légendaire | +1 niveau sur **tous** les power-ups possédés |

**Joker**

| Carte | Rareté | Effet |
|---|---|---|
| Billet coupe-file | Commun | −40 % sur la prochaine entrée de palier |
| Assurance | Commun | Les 3 prochaines mises perdues sont remboursées |
| Quitte ou double | Rare | 50 % : +150 % du prix d'entrée. 50 % : rien |
| Pieds légers | Rare | Vitesse +50 % et portée de clic ×2 pendant 15 min |
| Second souffle | Épique | La prochaine mort ne renvoie pas au Quai et rend 50 % du prix d'entrée |
| Pacte du Terminus | Épique | +300 % du prix d'entrée, mais le chrono descend deux fois plus vite pendant 10 min |
| Couronne | Légendaire | Cosmétique : pseudo doré et badge, visibles sur le panneau de tête et au classement |

**Aucune carte ne donne de niveau d'auto-cliqueur.** Les packs offrent du *carburant*, jamais un cran de débit : le niveau reste la seule chose qu'on ne peut obtenir qu'en Robux. Le carburant se consomme, il dépanne sans remplacer l'achat.

---

# Ce qu'il faut construire dans la map

Vue d'ensemble de la construction manuelle, une fois toutes les étapes faites. La marche à suivre, étape par étape et dans l'ordre, est dans `studio.md`.

- **8 salles mitoyennes**, empilées ou en enfilade le long d'un escalier vitré, chacune dans la charte visuelle du lot 2.
- **7 barrières transparentes**, une par passage, taguées `TierGate` avec leur `TargetTier`.
- **Des murs vitrés** entre chaque salle et celle du dessus, tagués `TierWindow`.
- **Un point de réapparition par salle**, celui du Quai étant celui où l'on revient après une mort.
- **Aucun chemin de marche entre deux étages** : la barrière est le seul passage, sinon toute l'échelle se contourne à pied. C'est le point à vérifier le plus sérieusement.
- **Par salle, à partir du palier concerné** : une zone de mini-jeu, une zone de power-up, un cookie.
- **Un guichet à packs**, au moins à partir du Buffet.

---

# Ce qui reste à trancher

- **Le Terminus s'achète-t-il en un seul paquet Robux ?** 1000 h est exactement le plus gros paquet vendu. C'est un argument de vente très fort, mais le contenu final s'ouvre alors sans avoir joué. Si ce n'est pas voulu, la correction propre n'est pas de bouger le prix du paquet : c'est d'ajouter au palier 8 une condition non monnayable — avoir gagné le Train de minuit, ou avoir tenu un certain nombre de jours.
- **Le multiplicateur suit-il le joueur ou la salle ?** Aujourd'hui il suit le joueur : un palier 5 qui redescend farmer au Quai garde son ×5. L'attacher à la salle forcerait à rester en haut, mais punirait ceux qui redescendent pour un mini-jeu ou pour retrouver des amis.
- ~~**Le prix de l'auto-cliqueur**~~ — tranché : **99 R$**. Reste à répercuter dans le Creator Dashboard (étape 18).
- ~~**La durée d'une recharge de carburant**~~ — tranché : 2 h par achat (`AUTOCLICK_FUEL_BASE`), +4 h par carte Autonomie (`_STEP`), et fonctionnement hors ligne.
- ~~**L'auto-cliqueur cannibalise-t-il les paquets de temps ?**~~ — réglé par le passage à un débit linéaire et au jeton à deux branches : il reste ~2,5 fois plus rentable que le meilleur paquet, ce qui est le bon écart pour un produit premium. À revérifier après le premier test réel.
- **Le gain de pari doit-il vraiment être multiplié ?** Le plan dit oui (« un gain de mini-jeu »), et c'est livré ainsi. Mais la cagnotte ressort alors plus grosse qu'elle n'est entrée : c'est le seul endroit du jeu où du temps se crée. Les corrections possibles, si le test le demande : ne multiplier que la part que le gagnant a lui-même misée, ou plafonner le multiplicateur des mini-jeux.
- **Le bouton du panneau suffit-il ?** Un bouton plaqué sur une barrière n'affiche pas d'indice d'interaction. Si les joueurs ne comprennent pas qu'on peut cliquer, ajouter une ProximityPrompt sur la même Part.
- **Tous les chiffres de ce plan** sont calculés, pas mesurés. Ils sont à revoir après le premier test complet du lot 1.
- **La dîme du Train (5 %) suffit-elle à contenir la création de temps ?** Les mini-jeux font ressortir la cagnotte plus grosse qu'elle n'est entrée (multiplicateur de palier du gagnant), et le Train en reprend une part avant de la redistribuer. C'est un frein, pas une fermeture : à mesurer sur un serveur plein, où huit zones tournent en parallèle.
- **Les identifiants des deux packs Robux** (`Config.PACK_PRODUCTS`) valent `0`. Le guichet à packs reste muet tant qu'ils ne sont pas créés au Creator Dashboard — c'est voulu, pas une panne.

---

# Rappel — obligation de traduction

Tout texte vu par un joueur passe par le système de traductions décrit dans `plan.md` (11 langues), et le fichier d'export doit être régénéré et réimporté après chaque ajout, sous peine de divergence silencieuse.

Ce plan est de loin le plus gros ajout de texte depuis l'étape 13 de `plan.md` : noms des 8 paliers, panneaux de barrière, panneaux d'appel, 21 cartes, 5 power-ups, 7 mini-jeux, 11 cadeaux. **À traduire au fil de l'eau, étape par étape** — jamais en une passe finale.
