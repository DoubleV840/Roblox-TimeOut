# TimeOut — suivi

**Tout le code des plans 1 et 2 est livré.** Ce qui reste est du bâtiment dans Studio, quelques tags, et trois identifiants de produit à recopier.

Ce fichier dit **dans quel ordre avancer**. Le détail de chaque geste est dans `studio.md` ; le pourquoi est dans `plan2.md`. Coche au fur et à mesure.

> **Pour cocher une case** : pose le curseur sur la ligne et fais `Alt+C` (extension *Markdown All in One*). Rien à sélectionner, rien à viser à la souris.

**La règle qui vaut partout : une Part nue et taguée suffit.** Les portiques, auras, panneaux et cadenas sont construits par le jeu à partir du tag. Ne décore jamais l'intérieur d'une zone — ce qui est posé à la main y est écrasé.

---

## Phase 0 — Le poste de travail

*Fait le 2 septembre 2026. Rien à refaire, sauf en cas de problème.*

- [x] Roblox Studio installé
- [x] Rojo 7.7.0 (CLI + plugin Studio, mêmes versions)
- [x] StyLua 2.5.2 et Selene 0.31.0, épinglés dans `aftman.toml`
- [x] VS Code : `rojo`, `luau-lsp`, `stylua`, `selene` + `.vscode/settings.json`
- [ ] **Studio relancé par `Cmd+Q`** — pour faire disparaître le doublon « Rojo » du menu *Plugins*

**Au début de chaque session de travail :**

```bash
rojo serve
```

puis dans Studio, onglet *Rojo* → **Connect**.

> Rojo ne gère que `Shared`, `Server`, `Client` et `Workspace.Baseplate`. **Tes salles ne risquent rien** — sauf si tu nommes une Part `Baseplate`.

---

## Phase 1 — Le prix qui surfacture *(hors Studio, 2 minutes)*

**À faire en premier, avant toute construction.** Le jeu affiche « 99 R$ » pour l'auto-cliqueur, mais le Dashboard facture encore 999 R$.

- [ ] *Creator Dashboard → ton jeu → Monetization → Developer Products*
- [ ] Ouvrir le produit **`3710399391`**
- [ ] Prix : **999 → 99**
- [ ] Enregistrer

Rien à changer dans le code : `Config.AUTOCLICK_PRODUCT` affiche déjà 99. Le champ `robux` n'est qu'un affichage — **le vrai prix est toujours celui du Dashboard**.

---

## Phase 2 — Deux salles, une barrière

Le cœur du jeu. **Deux salles suffisent** pour valider toute la mécanique des paliers ; les six autres attendent que le test passe.

- [ ] **2.1** — Construire le Quai (en bas) et une salle au-dessus. Murs gris, aucun décor.
- [ ] **2.2** — Vérifier qu'il n'existe **aucun autre chemin** entre les deux : pas de rebord à longer, pas de saut possible, pas de trou dans le plafond, pas de mur escaladable.
- [ ] **2.3** — Poser une Part qui bouche **entièrement** l'ouverture (un joueur passe par un interstice de 2 studs) : `Anchored` ✓, `CanCollide` ✓, `Transparency` ≈ `0.6`, `Material` `Glass`, `Color` `235, 235, 235`.
- [ ] **2.4** — Sur cette Part : tag **`TierGate`** + attribut **nombre** **`TargetTier`** = `2`.
- [ ] **2.5** — Ajouter une **SurfaceGui vide** dans la Part, `Face` réglée sur le côté **d'où arrivent les joueurs** (celui du bas).
- [ ] **2.6** — Une **SpawnLocation** par salle, `Neutral` ✓. Sur celle du Quai, attribut **nombre** **`TargetTier`** = `1`.

> L'étape **2.2** est la plus importante du projet. Si l'échelle des paliers se contourne à pied, le jeu n'a plus d'objet.
>
> Ne touche pas à `CollisionGroup` : le serveur réassigne tout au démarrage.

Détail complet : `studio.md`, *lot 1*.

---

## Phase 3 — Le test qui décide de tout

*Test → Play*, un seul client. Si ça passe, la mécanique est bonne et tu peux bâtir les six étages restants sans crainte.

- [ ] Le badge en bas à gauche montre le Quai ; son nom s'affiche à droite du chrono
- [ ] La barre sous le chrono se remplit quand on clique le cookie
- [ ] La barrière se voit de loin et bourdonne ; on lit le nom de l'étage et son prix dessus
- [ ] On se cogne dedans
- [ ] Sous 6 min : le panneau dit ce qu'il manque, sans rien proposer
- [ ] Au-dessus de 6 min : le bouton apparaît, la confirmation s'ouvre, valider retire 5 min
- [ ] La barrière laisse passer **dans les deux sens** et affiche « OUVERT »
- [ ] Le badge change, la barre se vide et vise l'étage suivant
- [ ] Un clic sur le cookie rapporte plus qu'avant
- [ ] Tomber à zéro renvoie au Quai, barrière toujours ouverte

Puis *Test → Clients and Servers*, 2 joueurs :

- [ ] Quand l'un monte, l'autre voit et entend l'annonce
- [ ] Le classement montre le badge de palier de chacun

> **Le piège** : le palier est **sauvegardé**. Une fois le palier 2 acheté, ton compte ne peut plus retester le premier achat. Pour repartir de zéro, change `Config.DATASTORE_NAME` (`"TimeOutPlayerData_v1"` → `"..._test1"`, `_test2`…). Chaque nom donne une sauvegarde neuve. **Voir la phase 10 avant de publier.**

---

## Phase 4 — Les six étages restants

Même recette qu'en phase 2, une barrière par passage. Une seule suffit par passage : elle s'ouvre dans les deux sens pour qui a déjà l'étage.

- [ ] `TargetTier` `3` — Le Buffet — `90, 220, 120`
- [ ] `TargetTier` `4` — Le Salon 1re classe — `80, 205, 235`
- [ ] `TargetTier` `5` — La Verrière — `95, 145, 255`
- [ ] `TargetTier` `6` — La Tour de l'horloge — `175, 110, 255`
- [ ] `TargetTier` `7` — Les Coulisses — `255, 175, 55`
- [ ] `TargetTier` `8` — Le Terminus — `255, 225, 90`

*(Le palier 2, La Salle des pas perdus, `235, 235, 235`, est déjà posé en phase 2.)*

Les prix s'affichent tout seuls — ils se règlent dans `src/shared/Tiers.luau`, jamais dans Studio.

**Contrainte de construction** : les salles doivent être **mitoyennes**, pas dispersées. Un escalier vitré qui longe les étages est la disposition la plus simple à tenir.

---

## Phase 5 — Rendre les étages désirables

- [ ] **5.1** — Rendre le Quai **franchement laid** : béton fissuré, carrelage manquant, flaques, sacs poubelle, affiches décollées, graffitis, néons verdâtres.
- [ ] **5.2** — Soigner chaque étage plus que le précédent (le tableau des matériaux est dans `studio.md`, *lot 2*).
- [ ] **5.3** — Tag **`FlickerLight`** sur chaque lumière du bas de l'immeuble. **Aucun au-dessus du palier 3** — c'est la signature du sous-sol.
- [ ] **5.4** — Sur chaque mur vitré : tag **`TierWindow`** + attribut **nombre** **`TargetTier`** (l'étage qu'on voit à travers) + une **SurfaceGui vide** orientée côté joueurs.
- [ ] **5.5** — Si les salles hautes disparaissent vues d'en bas : dans *Workspace*, augmenter `StreamingTargetRadius` ou décocher `StreamingEnabled`.

> Si le Quai est joli, plus rien au-dessus ne fait envie. C'est le seul étage que tout le monde voit.

**Test** — à deux clients : chacun voit au-dessus de la tête de l'autre son pseudo, son badge et son chrono qui défile, **et pas le sien**. Une montée au palier 6+ est visiblement plus spectaculaire qu'une montée au palier 2.

---

## Phase 6 — Le guichet à packs

- [ ] **6.1** — Une Part au sol, tag **`ShopZone`** + attribut **texte** **`ShopKind`** = **`Pack`**. Au moins une, à partir du Buffet (palier 3). Rien à décorer.
- [ ] **6.2** — *Creator Dashboard → Monetization → Developer Products* : créer **deux** produits, un pack Rare et un pack Légendaire.
- [ ] **6.3** — Recopier leurs identifiants dans `src/shared/Config.luau`, ligne **246**, à la place des deux `0` :

```lua
Config.PACK_PRODUCTS = {
	{ productId = 0, rarity = "Rare", robux = 149 },        -- ← ici
	{ productId = 0, rarity = "Legendary", robux = 799 },   -- ← et ici
}
```

> Tant qu'ils valent `0`, **le guichet reste muet et le serveur refuse de vendre** — c'est voulu. Les packs offerts par les montées de palier, eux, marchent déjà sans rien.

**Test** : les trois cartes se retournent **une par une**, viennent de trois familles différentes (IMMÉDIAT / MOTEUR / JOKER), et refermer sans choisir puis se reconnecter retrouve **exactement les mêmes trois**.

---

## Phase 7 — Les cinq power-ups

Cinq Parts plates au sol, une par salle, tag **`PowerUpZone`** + attribut **texte** `PowerUp` :

- [ ] Le Buffet (3) — `Critique`
- [ ] Le Salon 1re classe (4) — `Echo`
- [ ] La Verrière (5) — `Frenesie`
- [ ] La Tour de l'horloge (6) — `PoidsDuTemps`
- [ ] Les Coulisses (7) — `Rouages`

> **L'orthographe compte** : `Frenesie` sans accent, `PoidsDuTemps` en un seul mot. Une valeur inconnue se plaint dans la console et la zone est ignorée.

Pour tester sans farmer : baisser temporairement les `costShare` dans `src/shared/PowerUps.luau` (**phase 10**).

---

## Phase 8 — Les huit mini-jeux

**Les zones de pari existantes n'ont rien à changer** — elles sont reprises telles quelles.

Pour les sept autres : une Part plate au sol, tag **`MiniGameZone`** + attribut **texte** `Game`.

- [ ] La Salle des pas perdus — `Distributeur`
- [ ] Le Buffet — `Chaises` *(+ un dossier de dalles nommé `Chaises`, au-dessus d'un vide)*
- [ ] Le Salon 1re classe — `Roue` *(+ une Part cylindrique nommée `Roue`)*
- [ ] La Verrière — `Wagon` *(+ une plateforme isolée nommée `Wagon`, au-dessus d'un vide)*
- [ ] La Tour de l'horloge — `Duel`
- [ ] Les Coulisses — `Braquage` *(+ un coffre nommé `Braquage`)*
- [ ] Le Terminus — `TrainDeMinuit`

`BetAmount` et `MinTier` sont **facultatifs** : sans eux, le jeu prend les valeurs de `src/shared/MiniGameList.luau`. L'attribut `Game`, lui, est indispensable — sans lui la zone redevient un simple pari.

**Le décor n'est jamais obligatoire** : les quatre jeux qui peuvent s'en servir se rabattent sur la zone elle-même. Le plus simple est de nommer l'objet comme le jeu et de le poser à côté de la zone.

Pour tester le Train sans attendre une heure : `Config.TRAIN_INTERVAL` à `120` et `Config.TRAIN_WARNING` à `30` (**phase 10**).

---

## Phase 9 — Les cadeaux

**Rien à poser.** L'échelle, l'icône et la fenêtre sont entièrement dans le code.

- [ ] Atteindre 10 min fait apparaître l'icône « CADEAU À RÉCLAMER »
- [ ] La fenêtre montre toute l'échelle : pris / mûr / à atteindre
- [ ] Se reconnecter ne permet pas de réclamer deux fois
- [ ] Redescendre sous le seuil ne rend pas le cadeau réclamable *(il se lit sur le plus haut temps jamais tenu)*
- [ ] Réclamer la Frénésie de 12 h sans posséder le power-up **ne consomme pas** le cadeau

Les seuils montent jusqu'à 50 jours : pour voir les cadeaux hauts, baisse-les temporairement dans `src/shared/Rewards.luau` (**phase 10**).

---

## Phase 10 — Avant de publier

**À vérifier une par une.** Chacune de ces valeurs a pu être baissée pour tester, et publier avec l'une d'elles fausse le jeu — ou efface la progression des joueurs.

| Fichier | Réglage | Valeur à remettre |
|---|---|---|
| `Config.luau:5` | `DATASTORE_NAME` | `"TimeOutPlayerData_v1"` |
| `Config.luau:133` | `AUTOCLICK_FUEL_BASE` | `2 * 3600` |
| `Config.luau:134` | `AUTOCLICK_FUEL_STEP` | `4 * 3600` |
| `Config.luau:161` | `AUTOCLICK_LOW_FUEL` | `60` |
| `Config.luau:310` | `TRAIN_INTERVAL` | `3600` |
| `Config.luau:311` | `TRAIN_WARNING` | `300` |
| `PowerUps.luau` | les `costShare` | valeurs d'origine |
| `Rewards.luau` | les seuils `at` | valeurs d'origine |

- [ ] Les huit lignes ci-dessus sont revenues à leur valeur d'origine
- [ ] `DATASTORE_NAME` en particulier — **le publier avec un suffixe `_test` efface la progression de tous les joueurs**
- [ ] Les trois identifiants de produit sont renseignés (auto-cliqueur + deux packs)
- [ ] `selene src` ne signale aucune erreur
- [ ] Importer `localization/TimeOut.csv` : *Creator Dashboard → Localization → Table Management → Import* — **233 clés, 11 langues**

> L'import du CSV n'est pas bloquant pour tester : le jeu lit `Translations.luau` directement. Il ne sert qu'au portail de traduction de Roblox.

---

## En cas de doute

| Symptôme | Cause la plus probable |
|---|---|
| Une zone ne réagit à rien | Tag mal orthographié — un tag inconnu est ignoré **sans erreur** |
| Un attribut semble ignoré | Mauvais **type** : `TargetTier` créé en `string` au lieu de `number` |
| Le panneau est du mauvais côté | SurfaceGui absente, ou `Face` mal réglée |
| Le guichet à packs ne s'ouvre pas | `PACK_PRODUCTS` encore à `0` |
| Studio ne se connecte pas | `rojo serve` arrêté, ou plugin d'une autre version que le CLI |

La console (*View → Output*) se plaint explicitement : `TimeOut: barriere sans attribut TargetTier valide`, `zone de power-up sans attribut PowerUp valide`.
