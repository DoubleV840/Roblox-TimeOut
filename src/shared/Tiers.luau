-- L'echelle des paliers : 8 etages qu'on achete en temps, du Quai crasseux au
-- Terminus. C'est LE tableau d'equilibrage du jeu -- tout le reste (barrieres,
-- HUD, multiplicateurs, packs, verrous de mini-jeu) le lit ici et nulle part
-- ailleurs, pour qu'un test en jeu puisse tout reajuster d'un seul endroit.
--
-- Regles qui gouvernent ce tableau :
--   * "cost" est le prix d'ENTREE du palier, paye une fois et pour toujours. On
--     ne paie jamais le cumul : le joueur monte marche par marche.
--   * "multiplier" ne multiplie QUE les gains actifs -- un clic, une orbe, un
--     gain de mini-jeu. Jamais le chrono (qui descend a 1 s/s partout), jamais
--     l'auto-cliqueur (seule source passive du jeu).
--   * "packRarity" est la rarete du pack offert a l'arrivee dans le palier.
--   * Le symbole et la couleur reprennent les 8 anciens rangs : meme identite
--     visuelle, mais indexee sur le palier atteint et non plus sur le temps
--     possede.

local Tiers = {}

Tiers.RARITY_COMMON = "Common"
Tiers.RARITY_RARE = "Rare"
Tiers.RARITY_EPIC = "Epic"
Tiers.RARITY_LEGENDARY = "Legendary"

-- "key" est la cle de traduction du nom (voir Translations.luau).
Tiers.List = {
	{
		key = "tier_1",
		cost = 0,
		multiplier = 1,
		packRarity = nil,
		symbol = "\u{25CB}",
		color = Color3.fromRGB(165, 165, 172),
	},
	{
		key = "tier_2",
		cost = 5 * 60,
		multiplier = 1.5,
		packRarity = Tiers.RARITY_COMMON,
		symbol = "\u{25B3}",
		color = Color3.fromRGB(235, 235, 235),
	},
	{
		key = "tier_3",
		cost = 20 * 60,
		multiplier = 2,
		packRarity = Tiers.RARITY_COMMON,
		symbol = "\u{25B2}",
		color = Color3.fromRGB(90, 220, 120),
	},
	{
		key = "tier_4",
		cost = 90 * 60,
		multiplier = 3,
		packRarity = Tiers.RARITY_RARE,
		symbol = "\u{25C7}",
		color = Color3.fromRGB(80, 205, 235),
	},
	{
		key = "tier_5",
		cost = 6 * 3600,
		multiplier = 5,
		packRarity = Tiers.RARITY_RARE,
		symbol = "\u{25C6}",
		color = Color3.fromRGB(95, 145, 255),
	},
	{
		key = "tier_6",
		cost = 30 * 3600,
		multiplier = 8,
		packRarity = Tiers.RARITY_EPIC,
		symbol = "\u{25C8}",
		color = Color3.fromRGB(175, 110, 255),
	},
	{
		key = "tier_7",
		cost = 150 * 3600,
		multiplier = 13,
		packRarity = Tiers.RARITY_EPIC,
		symbol = "\u{2606}",
		color = Color3.fromRGB(255, 175, 55),
	},
	{
		key = "tier_8",
		cost = 1000 * 3600,
		multiplier = 21,
		packRarity = Tiers.RARITY_LEGENDARY,
		symbol = "\u{2605}",
		color = Color3.fromRGB(255, 225, 90),
	},
}

for index, tier in Tiers.List do
	tier.index = index
end

Tiers.FIRST = 1
Tiers.LAST = #Tiers.List

-- Tout ce qui vient d'une sauvegarde ou d'un attribut de Part passe par ici : un
-- palier hors bornes (donnees anciennes, attribut mal saisi dans Studio) ne doit
-- jamais faire planter un appelant, juste retomber sur le Quai.
function Tiers.Get(index)
	return Tiers.List[math.clamp(math.floor(tonumber(index) or 1), Tiers.FIRST, Tiers.LAST)]
end

function Tiers.Clamp(index)
	return Tiers.Get(index).index
end

-- Prix d'entree du palier vise. Le Quai est gratuit : personne ne paie pour
-- arriver dans le jeu.
function Tiers.Cost(index)
	return Tiers.Get(index).cost
end

function Tiers.Multiplier(index)
	return Tiers.Get(index).multiplier
end

-- Le palier au-dessus, ou nil au Terminus -- c'est ce nil qui fait taire la
-- barre de progression du HUD une fois l'echelle terminee.
function Tiers.Next(index)
	return Tiers.List[Tiers.Clamp(index) + 1]
end

return Tiers
