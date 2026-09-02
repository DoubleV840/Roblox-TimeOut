# TimeOut

Projet Roblox géré par [Rojo](https://github.com/rojo-rbx/rojo) 7.7.0.

- `plan2.md` — ce que le jeu doit faire (game design)
- `studio.md` — ce qu'il faut poser à la main dans Roblox Studio
- `SUIVI.md` — l'ordre dans lequel avancer, étape par étape

## Mise en route

Les outils sont épinglés dans `aftman.toml` ; [Aftman](https://github.com/LPGhatguy/aftman) les installe aux bonnes versions :

```bash
aftman install
```

| Outil | Version | Rôle |
|---|---|---|
| `rojo` | 7.7.0 | sync du code vers Studio |
| `stylua` | 2.5.2 | formatage Luau |
| `selene` | 0.31.0 | linter Luau |

Après une mise à jour de Rojo, réinstaller le plugin Studio pour qu'il ait la même version que le CLI :

```bash
rojo plugin install
```

## Travailler

```bash
rojo serve
```

Puis, dans Studio, onglet *Rojo* → **Connect**.

Pour produire une place complète sans passer par la sync :

```bash
rojo build -o TimeOut.rbxlx
```

## Vérifications

```bash
selene src            # linter
stylua --check src    # formatage, sans rien modifier
stylua src            # applique le formatage
```

Le sourcemap utilisé par l'extension `luau-lsp` est généré automatiquement par VS Code (voir `.vscode/settings.json`) ; il n'est pas versionné.
