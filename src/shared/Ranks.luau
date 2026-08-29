-- Rangs bases sur le temps que le joueur possede.
-- Chaque rang a un logo (glyphe geometrique) affiche dans un badge rond colore,
-- utilise a la fois dans le HUD du joueur et sur le panneau de classement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fonts = require(ReplicatedStorage.Shared.Fonts)

local Ranks = {}

-- "key" est la cle de traduction du nom (voir Translations.luau).
Ranks.List = {
	{ key = "rank_ephemeral", minTime = 0, symbol = "\u{25CB}", color = Color3.fromRGB(165, 165, 172) },
	{ key = "rank_survivor", minTime = 300, symbol = "\u{25B3}", color = Color3.fromRGB(235, 235, 235) },
	{ key = "rank_runner", minTime = 1200, symbol = "\u{25B2}", color = Color3.fromRGB(90, 220, 120) },
	{ key = "rank_watchmaker", minTime = 3600, symbol = "\u{25C7}", color = Color3.fromRGB(80, 205, 235) },
	{ key = "rank_chronomancer", minTime = 14400, symbol = "\u{25C6}", color = Color3.fromRGB(95, 145, 255) },
	{ key = "rank_guardian", minTime = 43200, symbol = "\u{25C8}", color = Color3.fromRGB(175, 110, 255) },
	{ key = "rank_master", minTime = 86400, symbol = "\u{2606}", color = Color3.fromRGB(255, 175, 55) },
	{ key = "rank_lord", minTime = 604800, symbol = "\u{2605}", color = Color3.fromRGB(255, 225, 90) },
}

for index, rank in Ranks.List do
	rank.index = index
end

function Ranks.For(seconds)
	local time = math.max(0, seconds or 0)
	local current = Ranks.List[1]

	for _, rank in Ranks.List do
		if time < rank.minTime then
			break
		end
		current = rank
	end

	return current
end

function Ranks.Next(seconds)
	return Ranks.List[Ranks.For(seconds).index + 1]
end

function Ranks.ApplyBadge(badge, rank)
	badge:FindFirstChildOfClass("UIStroke").Color = rank.color

	local symbol = badge.Symbol
	symbol.Text = rank.symbol
	symbol.TextColor3 = rank.color
end

-- La taille du badge est laissee a l'appelant ; il reste carre grace au ratio.
function Ranks.NewBadge(rank)
	local badge = Instance.new("Frame")
	badge.Name = "RankBadge"
	badge.BackgroundColor3 = Color3.new(0, 0, 0)
	badge.BackgroundTransparency = 0.3
	badge.BorderSizePixel = 0

	-- DominantAxis = Height : les appelants ne fixent QUE la hauteur du badge
	-- (largeur 0) et laissent la contrainte en deduire la largeur. Avec le defaut
	-- (Width), une largeur 0 imposait une hauteur 0 -- badge invisible.
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = badge

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = badge

	local symbol = Instance.new("TextLabel")
	symbol.Name = "Symbol"
	symbol.Size = UDim2.fromScale(1, 1)
	symbol.BackgroundTransparency = 1
	symbol.FontFace = Fonts.Symbol
	symbol.TextScaled = true
	symbol.Text = ""
	symbol.Parent = badge

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.2, 0)
	padding.PaddingBottom = UDim.new(0.2, 0)
	padding.PaddingLeft = UDim.new(0.2, 0)
	padding.PaddingRight = UDim.new(0.2, 0)
	padding.Parent = symbol

	Ranks.ApplyBadge(badge, rank or Ranks.List[1])

	return badge
end

return Ranks
