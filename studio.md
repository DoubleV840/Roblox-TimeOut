# TimeOut — ce qu'il faut faire dans Roblox Studio

`plan2.md` dit **ce que le jeu doit faire**. Ce fichier dit **ce que tu dois poser à la main** pour que le code livré serve à quelque chose.

La règle qui vaut partout : **une Part nue et taguée suffit**. Les portiques, les auras, les panneaux, les cadenas sont construits par le jeu à partir du tag. Il n'y a jamais rien à décorer autour d'une zone — et ce qui est décoré à la main risque d'être écrasé.

Les sections sont dans l'ordre où le code est arrivé. **Tout le code des plans 1 et 2 est livré** : il n'y a plus de section « pas encore ». Ce qui reste à faire ici est du bâtiment, quelques tags, et deux identifiants de produit à recopier.

---

## Avant tout — brancher Rojo

Le code vit dans `src/`, pas dans la place. Sans ce branchement, tu construis dans une place vide de scripts et rien de ce qui suit ne réagit.

**Une fois pour toutes, dans un terminal, à la racine du projet :**

```bash
aftman install    # installe Rojo, StyLua et Selene aux versions du projet
rojo serve        # laisse tourner tant que tu travailles
```

**Puis dans Studio :** onglet *Rojo* → **Connect**. La sync est active tant que le terminal tourne.

Ce que Rojo gère, et **rien d'autre** : `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayerScripts.Client`, et `Workspace.Baseplate`. Tout ce que tu poses toi-même dans *Workspace* lui est invisible — **tes salles ne risquent rien**, tant que tu n'appelles pas une Part `Baseplate`.

**Si le menu *Plugins* affiche deux fois « Rojo »** : c'est un doublon d'affichage, laissé quand le fichier du plugin a été remplacé pendant que Studio tournait. Quitte Studio par `Cmd+Q` — fermer la fenêtre ne suffit pas — et rouvre. S'il persiste, une seconde copie vient du Creator Store : *Plugins → Manage Plugins*, désinstalle celle-là et garde celle du dossier local, que `rojo plugin install` tient alignée sur le CLI.

**Après avoir mis à jour Rojo**, réinstalle le plugin pour qu'il ait la même version que le CLI, sinon la connexion est refusée :

```bash
rojo plugin install
```

---

## Les deux gestes de base

**Poser un tag** — *View → Tag Editor*. Créer le tag une fois (bouton `+`), puis sélectionner la Part et cliquer le tag pour l'appliquer. Un tag mal orthographié est invisible : le jeu ignore simplement la Part, sans erreur.

**Poser un attribut** — panneau *Properties*, tout en bas : *Attributes → Add Attribute*. Le **type compte** : un `TargetTier` créé en `string` au lieu de `number` ne sera pas lu.

**Vérifier que ça a pris** — lance le jeu et regarde la console (*View → Output*). Une barrière mal réglée s'y plaint : `TimeOut: barriere sans attribut TargetTier valide`.

---

## À faire maintenant — lot 1, la verticalité

De quoi tester la mécanique. **Deux salles suffisent** pour valider le tout ; les six autres viennent après, une fois qu'on sait que ça marche.

### 1. Deux salles superposées

Le Quai en bas, une salle au-dessus. Un seul passage entre les deux — une porte, une cage d'escalier, une ouverture dans le plafond. Pas de décor pour l'instant : des murs gris font l'affaire.

**Le point le plus important de tout ce fichier** : il ne doit exister **aucun autre chemin** entre les deux salles. Pas de rebord à longer, pas de saut possible, pas de trou dans le plafond, pas de mur escaladable. La barrière est le seul passage — sinon toute l'échelle des paliers se contourne à pied et le jeu n'a plus d'objet.

### 2. La barrière

Une **Part** qui bouche **entièrement** l'ouverture : toute la largeur, toute la hauteur. Un joueur passe par un interstice de deux studs.

| Propriété | Valeur |
|---|---|
| `Anchored` | coché |
| `CanCollide` | coché — elle bloque vraiment |
| `Transparency` | ≈ `0.6` — on voit ce qu'on rate |
| `Material` | `Glass` ou `ForceField` |
| `Color` | la teinte de l'étage visé (tableau plus bas) |

Puis :

- Tag **`TierGate`**
- Attribut **nombre** **`TargetTier`** = `2`

Ne touche pas à `CollisionGroup` : le jeu la réassigne au démarrage. Les groupes `TierGate_2`…`TierGate_8` et `TierPlayer_1`…`TierPlayer_8` sont créés par le serveur — il n'y a rien à faire dans *Model → Collision Groups*.

### 3. La SurfaceGui de la barrière

Ajoute une **SurfaceGui** dans la Part, et règle sa `Face` sur le côté **d'où arrivent les joueurs** (celui du bas).

**Laisse-la vide.** Elle ne sert qu'à indiquer cette face : le panneau lui-même est construit par le jeu, dans l'interface de chaque joueur, parce que trois joueurs devant la même barrière n'y lisent pas la même chose — « OUVERT », le prix, ou ce qu'il leur manque encore.

Si tu n'en mets pas, le panneau se pose quand même, sur la face avant de la Part — probablement du mauvais côté.

### 4. Les points de réapparition

Une **SpawnLocation** par salle, `Neutral` coché.

Sur celle du **Quai**, ajoute l'attribut **nombre** **`TargetTier`** = `1`. C'est là qu'on revient après une mort. Sans cet attribut, le jeu prend la SpawnLocation la plus basse de la map — ce qui marche aussi, tant que le Quai est bien l'étage du bas.

### 5. Les six barrières suivantes

Exactement le même modèle que l'étape 2, une par passage, avec son `TargetTier` :

| `TargetTier` | Étage | Prix d'entrée | Couleur (RGB) |
|---|---|---|---|
| — | Le Quai | — | `165, 165, 172` |
| `2` | La Salle des pas perdus | 5 min | `235, 235, 235` |
| `3` | Le Buffet | 20 min | `90, 220, 120` |
| `4` | Le Salon 1re classe | 1 h 30 | `80, 205, 235` |
| `5` | La Verrière | 6 h | `95, 145, 255` |
| `6` | La Tour de l'horloge | 30 h | `175, 110, 255` |
| `7` | Les Coulisses | 150 h | `255, 175, 55` |
| `8` | Le Terminus | 1000 h | `255, 225, 90` |

Une seule barrière par passage suffit : elle s'ouvre dans les deux sens pour qui a déjà l'étage.

Les prix sont affichés par le jeu, tu n'as rien à écrire dessus. Ils se règlent tous dans `src/shared/Tiers.luau`, pas ici.

### 6. Le test

Avec **un** client (*Test → Play*) :

- [ ] Le badge en bas à gauche montre le symbole du Quai, et le nom « Le Quai » à droite du chrono.
- [ ] La barre sous le chrono se remplit quand on clique le cookie, et affiche ce qu'il manque.
- [ ] La barrière se voit de loin et bourdonne ; on lit le nom de l'étage et son prix dessus.
- [ ] On se cogne dedans.
- [ ] Avec moins de 6 min au chrono, le panneau dit ce qu'il manque et ne propose rien.
- [ ] Au-dessus de 6 min, le bouton apparaît ; cliquer ouvre la confirmation ; valider retire 5 min.
- [ ] La barrière ne bloque plus, dans les deux sens, et son panneau dit « OUVERT ».
- [ ] Le badge et le nom ont changé ; la barre s'est vidée et vise l'étage suivant.
- [ ] Un clic sur le cookie rapporte plus qu'avant.
- [ ] Le chrono descend toujours à la même vitesse.
- [ ] Tomber à zéro renvoie au Quai, et la barrière reste ouverte.

Avec **deux** clients (*Test → Clients and Servers*, 2 joueurs) :

- [ ] Quand l'un monte, l'autre voit passer une annonce et l'entend.
- [ ] Le panneau de classement montre le badge du palier de chacun.

### Un piège de test

Le palier est **sauvegardé**. Une fois le palier 2 acheté, tu ne peux plus retester le premier achat avec ton compte.

Pour repartir de zéro : dans `src/shared/Config.luau`, change `Config.DATASTORE_NAME` (`"TimeOutPlayerData_v1"` → `"..._test1"`, `"..._test2"`…). Chaque nom donne une sauvegarde neuve. **Remets la bonne valeur avant de publier**, sinon tous les joueurs perdent leur progression.

---

## À faire maintenant — lot 4, le prix de l'auto-cliqueur

**Une seule chose, et elle est urgente : le prix affiché ne correspond plus à ce qui est facturé.**

L'auto-cliqueur ne vend plus une possession définitive mais **2 h de carburant + un choix** — Puissance (+2 s/s définitif) ou Autonomie (+4 h de carburant) — et il tourne aussi hors ligne. Le prix retenu est **99 R$**, et le jeu l'affiche déjà — mais le champ `robux` de `Config.luau` ne sert qu'à l'affichage : le vrai prix est celui du Dashboard.

*Creator Dashboard → ton jeu → Monetization → Developer Products* → le produit **`3710399391`** → prix **999 → 99 R$**.

Tant que ce n'est pas fait, un joueur qui lit « 99 R$ » se voit facturer 999 R$.

Rien d'autre à poser : le carburant, la jauge et le premier cran supprimé sont entièrement dans le code.

### Le test

Pour ne pas attendre deux heures, baisse temporairement `Config.AUTOCLICK_FUEL_BASE` à `120` (deux minutes), `Config.AUTOCLICK_FUEL_STEP` à `240` et `Config.AUTOCLICK_LOW_FUEL` à `20`. **Remets `2 * 3600`, `4 * 3600` et `60` ensuite.**

- [ ] Le tout premier achat fait **remonter** le chrono, visiblement.
- [ ] La fenêtre de choix s'ouvre toute seule après l'achat, et les deux cartes annoncent des chiffres justes (« 2 → 4 s/sec »).
- [ ] La fermer sans choisir laisse l'icône « choix en attente » en haut à gauche ; se reconnecter la retrouve.
- [ ] Prendre **Puissance** augmente le débit et ne touche pas au carburant.
- [ ] Prendre **Autonomie** rallonge la jauge et ne touche pas au débit.
- [ ] Le bandeau en haut à droite affiche le compte à rebours et se vide.
- [ ] Dans les 20 dernières secondes, il passe au rouge et pulse.
- [ ] À zéro : le bourdonnement se coupe, le chrono se remet à descendre, le bandeau dit « à sec ».
- [ ] Un rachat le relance, et le débit a doublé.
- [ ] Mourir fige le compte à rebours : il ne se vide pas pendant l'écran de mort.
- [ ] Le guichet affiche le carburant restant et ce que donne le prochain achat.
- [ ] Quitter le jeu carburant en cours, revenir : une notification annonce ce que l'auto-cliqueur a produit pendant l'absence, et la jauge a baissé d'autant.
- [ ] Mourir, quitter en étant mort, revenir : **rien** n'a été produit pendant cette absence-là.

---

## À faire maintenant — lot 2, donner envie de monter

Le code est livré : les panneaux d'appel, les panneaux au-dessus des joueurs et les annonces de montée fonctionnent dès que le décor existe. Ce qui reste est du bâtiment, et deux tags à poser.

**Le Quai doit être franchement laid** — béton fissuré, carrelage manquant, flaques, sacs poubelle, affiches décollées, graffitis, néons verdâtres. C'est le seul étage que tout le monde voit ; s'il est joli, plus rien au-dessus ne fait envie.

Puis chaque étage plus soigné que le précédent :

| Palier | Sol et murs | Lumière | Détails |
|---|---|---|---|
| 2–3 | Carrelage entier mais terne, peinture écaillée | Blanc froid, stable | Bancs dépareillés, machine à café en panne |
| 4–5 | Marbre, boiseries | Doré chaud, verrière | Plantes, tapis, horloges qui marchent |
| 6–7 | Laiton poli, verre | Ambre profond, projecteurs | Mécanismes d'horlogerie visibles, dorures |
| 8 | Or, obsidienne | Lumière propre, sans source visible | Le train est là, à quai, moteur allumé |

### Les tags à poser

- Tag **`FlickerLight`** sur chaque lumière du bas de l'immeuble (`PointLight`, `SurfaceLight`, ou la Part `Neon` qui la porte). Le grésillement est géré par le jeu. **Aucun au-dessus du palier 3** : c'est la signature du sous-sol.
- Tag **`TierWindow`** + attribut nombre **`TargetTier`** sur chaque mur vitré, avec l'étage qu'on voit à travers.

Comme sur les barrières, ajoute une **SurfaceGui vide** dans la vitre et règle sa `Face` sur le côté d'où arrivent les joueurs. Sans elle, le panneau se pose sur la face avant de la Part — probablement du mauvais côté.

### Deux contraintes de construction

- **Les salles doivent être mitoyennes**, pas dispersées. Un escalier vitré qui longe les étages est la disposition la plus simple à tenir.
- Si les salles hautes disparaissent quand on les regarde d'en bas, c'est le chargement progressif : dans *Workspace*, augmente `StreamingTargetRadius`, ou décoche `StreamingEnabled`. Une vitre qui donne sur le vide annule tout l'intérêt de l'étape.

### Le test

Avec **un** client :

- [ ] Devant une vitre, un panneau annonce le nom de l'étage d'en face, son prix et ce qu'il débloque, dans la couleur de cet étage.
- [ ] Une fois cet étage acheté, le panneau se tait : on est chez soi.
- [ ] Les néons du Quai grésillent ; aucun ne grésille au-dessus du palier 3.

Avec **deux** clients (*Test → Clients and Servers*, 2 joueurs) :

- [ ] Depuis le Quai, on voit bouger l'autre joueur à l'étage au-dessus, à travers la vitre.
- [ ] Chacun voit au-dessus de la tête de l'autre son pseudo, son badge de palier et son chrono qui défile — et **pas le sien**.
- [ ] Le chrono du panneau vire au vert→rouge comme le HUD : on repère d'un coup d'œil qui est en train de mourir.
- [ ] En s'éloignant, le panneau de l'autre s'efface, puis disparaît.
- [ ] Quand l'autre achète un étage, un bandeau le nomme, son personnage s'éclaire à la couleur de l'étage, et un son passe.
- [ ] Une montée au palier 6 ou au-dessus est visiblement plus spectaculaire qu'une montée au palier 2 : bandeau plus large, plus long, son plus grave, et l'écran s'embrase.

---

## À faire maintenant — lot 3, les packs

Le code est livré : monter d'un palier donne déjà un pack, l'icône pulse, la cérémonie tourne. Il ne manque que le **guichet** et ses deux produits.

### Le guichet

- Une Part au sol, comme les guichets existants, tag **`ShopZone`**
- Attribut **texte** **`ShopKind`** = **`Pack`**
- Rien à décorer : l'aura, le bourdonnement et le panneau sont posés par le jeu

Au moins un, à partir du Buffet (palier 3).

### Les deux produits

*Creator Dashboard → ton jeu → Monetization → Developer Products* : créer **deux** produits, un pack Rare et un pack Légendaire. Puis recopier leurs identifiants dans `src/shared/Config.luau`, dans `Config.PACK_PRODUCTS` :

```lua
Config.PACK_PRODUCTS = {
	{ productId = 0, rarity = "Rare", robux = 149 },        -- ← remplacer le 0
	{ productId = 0, rarity = "Legendary", robux = 799 },   -- ← remplacer le 0
}
```

Tant qu'ils valent `0`, **le guichet ne s'ouvre pas et le serveur refuse de vendre**. C'est voulu — mieux vaut un guichet muet qu'un achat impossible. Les packs offerts par les montées de palier, eux, fonctionnent déjà sans rien.

Le champ `robux` ne sert **qu'à l'affichage**, comme partout ailleurs : le vrai prix est celui du Dashboard.

### Le test

- [ ] Franchir une barrière fait apparaître l'icône « PACK À OUVRIR » en haut à gauche, et la fenêtre s'ouvre toute seule.
- [ ] Les trois cartes se retournent **une par une**, pas ensemble.
- [ ] On ne peut cliquer une carte qu'après le dernier retournement.
- [ ] Les trois cartes viennent de trois familles différentes (IMMÉDIAT / MOTEUR / JOKER).
- [ ] Choisir une carte applique son effet et la notification cite son nom.
- [ ] Refermer sans choisir laisse l'icône ; se reconnecter retrouve **exactement les mêmes trois cartes**.
- [ ] Un pack Légendaire (palier 8) propose visiblement mieux qu'un Commun (palier 2).
- [ ] Au guichet : acheter un pack le met en attente, et un rachat après reconnexion ne le crédite pas deux fois.

**Piège de test** : les cartes valent un pourcentage du prix d'entrée du palier, et ce palier est **figé à la création du pack**. Un pack gagné au Quai ne vaudra pas davantage parce qu'on l'ouvre au Terminus — c'est voulu, sinon garder ses packs fermés serait toujours le bon calcul.

---

## À faire maintenant — lot 5, les power-ups

Cinq Parts plates au sol, une par salle. Le portique, l'aura et le panneau sont construits par le jeu.

| Salle | Palier | Tag | Attribut **texte** `PowerUp` |
|---|---|---|---|
| Le Buffet | 3 | `PowerUpZone` | `Critique` |
| Le Salon 1re classe | 4 | `PowerUpZone` | `Echo` |
| La Verrière | 5 | `PowerUpZone` | `Frenesie` |
| La Tour de l'horloge | 6 | `PowerUpZone` | `PoidsDuTemps` |
| Les Coulisses | 7 | `PowerUpZone` | `Rouages` |

**L'orthographe compte** : `Frenesie` sans accent, `PoidsDuTemps` en un seul mot. Une valeur inconnue se plaint dans la console (`zone de power-up sans attribut PowerUp valide`) et la zone est ignorée.

Rien n'empêche de poser une zone dans la mauvaise salle : le jeu ne vérifie que le **palier du joueur**, pas l'endroit. Une zone `Rouages` posée au Quai afficherait simplement « Palier 7 requis » à tout le monde.

### Le test

- [ ] Marcher sur une zone dont le palier n'est pas atteint : cadenas, et le panneau dit quel palier il faut.
- [ ] Une fois le palier atteint : la fenêtre annonce le niveau, l'effet actuel → suivant, et le prix.
- [ ] Acheter enchaîne sans ressortir de la zone ; le prix grimpe à chaque niveau.
- [ ] **Critique** : des « +Xs ! » dorés et plus gros passent de temps en temps.
- [ ] **Écho** : chaque clic est suivi d'un second gain, plus petit, ~0,4 s plus tard.
- [ ] **Frénésie** : un bouton apparaît en bas de l'écran ; le déclencher change le rythme pendant 20 s, puis la recharge descend.
- [ ] **Poids du temps** : le gain par clic est nettement plus gros à 10 h qu'à 2 min.
- [ ] **Rouages** : cliquer fait monter la jauge de carburant (il faut posséder un auto-cliqueur).

Pour tester sans farmer, baisse temporairement les `costShare` dans `src/shared/PowerUps.luau`. **Remets-les ensuite.**

---

## À faire maintenant — lot 6, les mini-jeux

**Les zones de pari existantes n'ont rien à changer.** Elles sont reprises telles quelles par le cadre commun et gardent leur `BetAmount` et leur déverrouillage.

Pour les sept autres : une Part plate au sol, tag **`MiniGameZone`**, plus trois attributs.

| Salle | `Game` *(texte)* | `BetAmount` *(nombre)* | `MinTier` *(nombre)* | Décor en plus |
|---|---|---|---|---|
| La Salle des pas perdus | `Distributeur` | `60` | `2` | — |
| Le Buffet | `Chaises` | `300` | `3` | une grille de dalles |
| Le Salon 1re classe | `Roue` | `1800` | `4` | une Part cylindrique |
| La Verrière | `Wagon` | `10800` | `5` | une plateforme isolée |
| La Tour de l'horloge | `Duel` | `21600` | `6` | deux emplacements face à face |
| Les Coulisses | `Braquage` | `108000` | `7` | un coffre |
| Le Terminus | `TrainDeMinuit` | `0` | `8` | le train |

`BetAmount` et `MinTier` sont facultatifs : sans eux, le jeu prend les valeurs de `src/shared/MiniGameList.luau` (celles du tableau ci-dessus). L'attribut `Game`, lui, est indispensable — sans lui la zone devient un simple pari.

### Le décor, et pourquoi il n'est pas obligatoire

Quatre jeux savent se servir d'un objet du monde. **Aucun n'en dépend** : sans décor, ils se rabattent sur la zone elle-même et restent jouables. C'est fait exprès — les huit jeux sont testables avant que la map n'existe.

Le jeu cherche le décor à trois endroits, dans cet ordre :

1. l'instance nommée par l'attribut **texte** `Decor` posé sur la zone ;
2. à défaut, un enfant ou un frère portant **le nom du jeu** (`Chaises`, `Roue`, `Wagon`, `Braquage`) ;
3. à défaut, rien — et le jeu se débrouille.

Le plus simple est le point 2 : nomme ton dossier de dalles `Chaises` et pose-le à côté de la zone.

- **Chaises** — un dossier de Parts-dalles au-dessus d'un vide. Une dalle s'éteint par tour ; qui est dessus tombe. Sans dalles, c'est le joueur **le plus loin du centre** de la zone qui sort à chaque tour.
- **Roue** — une Part cylindrique. Elle tourne pour de vrai, mais c'est **purement cosmétique** : le résultat est tiré avant qu'elle démarre.
- **Wagon** — une plateforme isolée au-dessus du vide. Elle **rétrécit vraiment** puis reprend sa taille. Sans elle, c'est la zone qui rétrécit : ça marche, mais pose-la au-dessus d'un vide sinon personne ne tombe.
- **Braquage** — un coffre. Il s'ouvre en pivotant si le braquage réussit.

Le **Train de minuit** ne s'ouvre pas quand on entre dedans : il part tout seul une fois par heure, s'annonce cinq minutes avant à tout le serveur, puis reste à quai une minute pendant laquelle **on monte en marchant dans la zone**. L'embarquement est gratuit — sa cagnotte vient d'une dîme prélevée sur tous les autres mini-jeux.

### Le test

Avec **un** client :

- [ ] Une zone dont le palier manque affiche un cadenas et dit lequel il faut.
- [ ] Le **Distributeur** se joue seul : on mise, on gagne ou on perd tout de suite.
- [ ] La **Roue** demande de choisir un secteur avant de valider.
- [ ] Le HUD en haut à droite liste les parties en cours et fait descendre le décompte.

Avec **deux** clients :

- [ ] Le **Duel** démarre dès que le deuxième joueur mise, sans attendre la fin du décompte ; un bandeau dit de cliquer et le meilleur score s'affiche.
- [ ] Les **Chaises** éliminent un joueur par tour jusqu'au dernier debout.
- [ ] Le **Wagon** rétrécit et élimine qui n'est plus dessus.
- [ ] Le **Braquage** se gagne ou se perd **ensemble**.
- [ ] Une partie où personne ne vient rembourse la mise.
- [ ] Une zone déjà lancée dit « une partie est déjà lancée » au lieu de proposer de miser.

**Pour tester le Train sans attendre une heure** : baisse `Config.TRAIN_INTERVAL` à `120` et `Config.TRAIN_WARNING` à `30`. **Remets `3600` et `300` ensuite.**

---

## À faire maintenant — lot 7, les cadeaux

**Rien à poser.** L'échelle, l'icône et la fenêtre sont entièrement dans le code.

### Le test

- [ ] Atteindre 10 min fait apparaître l'icône « CADEAU À RÉCLAMER » en haut à gauche.
- [ ] La fenêtre montre **toute** l'échelle : ce qui est pris, ce qui est mûr, ce qui reste à atteindre.
- [ ] Réclamer donne le cadeau et la ligne s'éteint.
- [ ] Se reconnecter ne permet pas de réclamer une deuxième fois.
- [ ] Redescendre sous le seuil ne rend pas le cadeau réclamable — il se lit sur le **plus haut temps jamais tenu**.
- [ ] Réclamer la Frénésie de 12 h sans posséder le power-up **ne consomme pas** le cadeau : il reste dans la liste.

**Piège de test** : les seuils vont jusqu'à 50 jours. Pour voir les cadeaux hauts, donne-toi du temps au guichet, ou baisse temporairement les seuils dans `src/shared/Rewards.luau`.

---

## Hors Studio, après chaque livraison

Les textes du jeu vivent dans `src/shared/Translations.luau` (11 langues), et sont exportés dans `localization/TimeOut.csv`.

Le lot 1 a ajouté 22 clés et supprimé les 8 rangs ; le lot 4 en a ajouté 4 de plus ; le lot 2 en ajoute 9 (les panneaux d'appel et l'annonce de montée) et retire `notify_tier_announce`, que le bandeau remplace. Les lots 3, 5, 6 et 7 en ajoutent **129** — 21 cartes, 5 power-ups, 8 mini-jeux, 11 cadeaux et leurs notifications — et retirent les 5 clés du pari devenues sans lecteur (`bet_title`, `bet_hud_title`, `notify_bet_win`, `notify_bet_lose`, `notify_bet_unlocked`), que leurs équivalents `minigame_*` remplacent pour les huit jeux. Le fichier en porte maintenant **233**, identiques dans les 11 langues. Le CSV est déjà regénéré — il reste à l'importer : *Creator Dashboard → ton jeu → Localization → Table Management → Import*.

Ce n'est pas bloquant pour tester : le jeu lit `Translations.luau` directement. L'import ne sert qu'au portail de traduction de Roblox, qui peut compléter les langues qu'on ne couvre pas.

---

---

## Récapitulatif des tags et attributs

| Tag | Sur quoi | Attributs | Utilisable |
|---|---|---|---|
| `TierGate` | La barrière transparente d'un passage | `TargetTier` *(nombre)* — l'étage desservi | **oui** |
| *(aucun)* | La SpawnLocation du Quai | `TargetTier` *(nombre)* = `1`, facultatif | **oui** |
| `TierWindow` | Un mur vitré | `TargetTier` *(nombre)* — l'étage qu'on voit | **oui** |
| `FlickerLight` | Une lumière du bas de l'immeuble | — | **oui** |
| `ShopZone` | Le guichet à packs | `ShopKind` *(texte)* = `Pack` | **oui** |
| `PowerUpZone` | Une zone d'achat de power-up | `PowerUp` *(texte)* | **oui** |
| `MiniGameZone` | Une zone de mini-jeu | `Game` *(texte)*, `BetAmount` *(nombre)*, `MinTier` *(nombre)* | **oui** |
| *(aucun)* | Le décor d'un mini-jeu | `Decor` *(texte)* sur la zone, facultatif | **oui** |

Déjà en place et inchangés : `TimeCookie`, `ClickUpgrade`, `BetZone`, `TimeOrb`, `HallOfFameBoard`, `ShopZone` (`Time` et `AutoClick`).
