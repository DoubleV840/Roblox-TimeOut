# TimeOut — ce qu'il faut faire dans Roblox Studio

`plan2.md` dit **ce que le jeu doit faire**. Ce fichier dit **ce que tu dois poser à la main** pour que le code livré serve à quelque chose.

La règle qui vaut partout : **une Part nue et taguée suffit**. Les portiques, les auras, les panneaux, les cadenas sont construits par le jeu à partir du tag. Il n'y a jamais rien à décorer autour d'une zone — et ce qui est décoré à la main risque d'être écrasé.

Les sections sont dans l'ordre où le code arrive. Une section marquée *« pas encore »* décrit un travail dont le code n'existe pas : le faire maintenant ne servirait à rien.

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

## Hors Studio, après chaque livraison

Les textes du jeu vivent dans `src/shared/Translations.luau` (11 langues), et sont exportés dans `localization/TimeOut.csv`.

Le lot 1 a ajouté 22 clés et supprimé les 8 rangs ; le lot 4 en a ajouté 4 de plus. Le CSV est déjà regénéré — il reste à l'importer : *Creator Dashboard → ton jeu → Localization → Table Management → Import*.

Ce n'est pas bloquant pour tester : le jeu lit `Translations.luau` directement. L'import ne sert qu'au portail de traduction de Roblox, qui peut compléter les langues qu'on ne couvre pas.

---

## Pas encore — lot 2, donner envie de monter

Le code des panneaux d'appel, des panneaux au-dessus des joueurs et des annonces n'est pas écrit. Le décor, lui, peut se construire dès maintenant si tu en as envie : il ne dépend d'aucun code.

**Le Quai doit être franchement laid** — béton fissuré, carrelage manquant, flaques, sacs poubelle, affiches décollées, graffitis, néons verdâtres. C'est le seul étage que tout le monde voit ; s'il est joli, plus rien au-dessus ne fait envie.

Puis chaque étage plus soigné que le précédent :

| Palier | Sol et murs | Lumière | Détails |
|---|---|---|---|
| 2–3 | Carrelage entier mais terne, peinture écaillée | Blanc froid, stable | Bancs dépareillés, machine à café en panne |
| 4–5 | Marbre, boiseries | Doré chaud, verrière | Plantes, tapis, horloges qui marchent |
| 6–7 | Laiton poli, verre | Ambre profond, projecteurs | Mécanismes d'horlogerie visibles, dorures |
| 8 | Or, obsidienne | Lumière propre, sans source visible | Le train est là, à quai, moteur allumé |

À poser quand le code arrivera :

- Tag **`FlickerLight`** sur chaque lumière du bas de l'immeuble (`PointLight`, `SurfaceLight`, ou la Part `Neon` qui la porte). Le grésillement est géré par le jeu. **Aucun au-dessus du palier 3** : c'est la signature du sous-sol.
- Tag **`TierWindow`** + attribut nombre **`TargetTier`** sur chaque mur vitré, avec l'étage qu'on voit à travers.

Deux contraintes de construction à anticiper :

- **Les salles doivent être mitoyennes**, pas dispersées. Un escalier vitré qui longe les étages est la disposition la plus simple à tenir.
- Si les salles hautes disparaissent quand on les regarde d'en bas, c'est le chargement progressif : dans *Workspace*, augmente `StreamingTargetRadius`, ou décoche `StreamingEnabled`. Une vitre qui donne sur le vide annule tout l'intérêt de l'étape.

---

## Pas encore — lot 3, les packs

- Une Part au sol, tag **`ShopZone`**, attribut **texte** **`ShopKind`** = **`Pack`**. Au moins à partir du Buffet.
- Dans le *Creator Dashboard → Monetization → Developer Products* : deux produits (pack Rare, pack Légendaire). Leurs identifiants seront à recopier dans `Config.luau`, comme les paquets de temps.

## Pas encore — lot 5, les power-ups

Une Part plate au sol par power-up, tag **`PowerUpZone`**, attribut **texte** **`PowerUp`** :

| Salle | `PowerUp` |
|---|---|
| Le Buffet (3) | `Critique` |
| Le Salon 1re classe (4) | `Echo` |
| La Verrière (5) | `Frenesie` |
| La Tour de l'horloge (6) | `PoidsDuTemps` |
| Les Coulisses (7) | `Rouages` |

## Pas encore — lot 6, les mini-jeux

Une Part plate au sol, tag **`MiniGameZone`**, plus trois attributs : **texte** `Game`, **nombre** `BetAmount` (la mise en secondes), **nombre** `MinTier` (le palier requis). Certains jeux demandent un décor propre en plus (une grille de dalles, une roue, une plateforme isolée, un coffre, le train) — le détail est dans `plan2.md`, étapes 25 à 31.

---

## Récapitulatif des tags et attributs

| Tag | Sur quoi | Attributs | Utilisable |
|---|---|---|---|
| `TierGate` | La barrière transparente d'un passage | `TargetTier` *(nombre)* — l'étage desservi | **oui** |
| *(aucun)* | La SpawnLocation du Quai | `TargetTier` *(nombre)* = `1`, facultatif | **oui** |
| `TierWindow` | Un mur vitré | `TargetTier` *(nombre)* — l'étage qu'on voit | pas encore |
| `FlickerLight` | Une lumière du bas de l'immeuble | — | pas encore |
| `ShopZone` | Le guichet à packs | `ShopKind` *(texte)* = `Pack` | pas encore |
| `PowerUpZone` | Une zone d'achat de power-up | `PowerUp` *(texte)* | pas encore |
| `MiniGameZone` | Une zone de mini-jeu | `Game`, `BetAmount`, `MinTier` | pas encore |

Déjà en place et inchangés : `TimeCookie`, `ClickUpgrade`, `BetZone`, `TimeOrb`, `HallOfFameBoard`, `ShopZone` (`Time` et `AutoClick`).
