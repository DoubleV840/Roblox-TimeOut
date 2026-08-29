-- Police unique du jeu. Tout le texte de l'interface passe par ici :
-- pour changer la typo de tout le jeu, il n'y a que ce fichier a modifier.
--
-- Roblox ne sait PAS charger une police depuis Google Fonts (pas d'URL, pas de .ttf
-- uploade pour un jeu publie). Deux sources possibles seulement :
--   1. les polices integrees (Enum.Font)
--   2. un asset de police installe depuis le Creator Store (create.roblox.com/store/fonts)
--
-- "Honk" n'existe pas dans les polices integrees. Si tu le trouves sur le Creator
-- Store (bouton Install, puis copie l'ID de l'asset), colle son ID ci-dessous et
-- tout le jeu basculera dessus sans autre changement.

local Fonts = {}

local HONK_ASSET_ID = nil -- ex: "rbxassetid://1234567890"

-- Repli tant qu'on n'a pas Honk : la police integree la plus proche de son esprit
-- (grasse, ronde, cartoon).
local FALLBACK = Enum.Font.LuckiestGuy

Fonts.Main = if HONK_ASSET_ID then Font.new(HONK_ASSET_ID) else Font.fromEnum(FALLBACK)

-- Exception assumee : les logos de rang sont des glyphes geometriques (○ △ ◆ ★...)
-- que les polices decoratives ne contiennent pas -- elles les afficheraient vides.
-- Ce n'est pas du texte, c'est une icone, donc elle garde une police qui les possede.
Fonts.Symbol = Font.fromEnum(Enum.Font.GothamBold)

return Fonts
