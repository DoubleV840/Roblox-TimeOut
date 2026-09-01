-- Le badge rond du palier : un glyphe geometrique dans un cercle colore, affiche
-- a la fois dans le HUD du joueur, sur le panneau de classement et au-dessus des
-- personnages.
--
-- Le module ne connait pas les paliers : il prend un "style" -- n'importe quelle
-- table portant .symbol et .color -- et le dessine. C'est Tiers.luau qui decide
-- quel style va a quel joueur (auparavant c'etait le temps possede qui le
-- decidait, via les rangs ; le badge affiche desormais le palier ATTEINT).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fonts = require(ReplicatedStorage.Shared.Fonts)

local Badge = {}

function Badge.Apply(badge, style)
	badge:FindFirstChildOfClass("UIStroke").Color = style.color

	local symbol = badge.Symbol
	symbol.Text = style.symbol
	symbol.TextColor3 = style.color
end

-- La taille du badge est laissee a l'appelant ; il reste carre grace au ratio.
function Badge.New(style)
	local badge = Instance.new("Frame")
	badge.Name = "TierBadge"
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

	Badge.Apply(badge, style)

	return badge
end

return Badge
