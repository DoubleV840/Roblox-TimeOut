-- L'ouverture d'un pack : trois cartes face cachee, un retournement decale, un
-- halo a la couleur de la rarete, et le hall qui s'assombrit autour.
--
-- C'EST L'ECRAN QUE LES JOUEURS METTRONT DANS LEURS VIDEOS. Il merite donc plus
-- de soin que n'importe quelle autre fenetre du jeu, et c'est la seule raison
-- pour laquelle ce module est plus long que ce que sa fonction laisse croire :
-- il n'y a que trois boutons a l'arrivee.
--
-- Trois choses portent la ceremonie :
--   * le VOILE, qui coupe le hall et met les cartes seules a l'ecran ;
--   * le RETOURNEMENT DECALE -- les cartes se revelent une par une, avec un
--     temps d'arret entre chaque. Trois revelations simultanees, c'est une
--     liste ; trois revelations decalees, c'est une ouverture ;
--   * l'AGITATION, qui suit la rarete. Une carte Legendaire ne se contente pas
--     d'etre ecrite en dore, elle ne tient pas en place.
--
-- Le joueur ne peut cliquer qu'apres le dernier retournement : laisser choisir
-- pendant l'animation reviendrait a la rendre facultative, et personne ne la
-- verrait deux fois.
--
-- Tout est construit ICI, cote client : le serveur n'envoie que trois
-- identifiants de carte, la rarete du pack et le palier de tirage. Le texte, les
-- chiffres et la mise en forme sortent de Cards.luau, que le client a deja --
-- donc dans la langue du joueur, sans un octet de texte sur le reseau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Cards = require(ReplicatedStorage.Shared.Cards)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Popup = require(script.Parent.Popup)

local Packs = {}

local CARD_WIDTH = 190
local CARD_HEIGHT = 280
local CARD_GAP = 18

local WINDOW_SIZE = UDim2.new(0, CARD_WIDTH * 3 + CARD_GAP * 2 + 40, 0, CARD_HEIGHT + 130)

local FLIP_DELAY = 0.45 -- temps d'arret entre deux retournements
local FLIP_TIME = 0.28

local BACK_COLOR = Color3.fromRGB(26, 24, 34)
local FACE_COLOR = Color3.fromRGB(16, 16, 20)

-- L'agitation du texte d'une carte suit sa rarete. Une Commune reste sage, une
-- Legendaire ne tient pas en place -- on doit pouvoir dire ce qu'on a tire sans
-- lire le mot.
local RARITY_FX = {
	[Tiers.RARITY_COMMON] = 0.1,
	[Tiers.RARITY_RARE] = 0.4,
	[Tiers.RARITY_EPIC] = 0.7,
	[Tiers.RARITY_LEGENDARY] = 1,
}

local state = { count = 0, rarity = nil, tier = nil, cards = nil }

local veil = nil
local window = nil
local title = nil
local hint = nil
local badge = nil
local badgeLabel = nil
local badgePulse = nil
local badgeShown = false

local slots = {}
local revealing = false

-- Numero d'ouverture. Refermer puis rouvrir aussitot laisserait sinon le fil de
-- retournement de la PREMIERE ouverture retourner les cartes de la seconde, qui
-- viennent d'etre remises face cachee -- et le joueur verrait sa ceremonie se
-- jouer a l'envers.
local generation = 0

--------------------------------------------------------------------------------
-- L'icone qui attend
--------------------------------------------------------------------------------

-- Meme mecanique que le jeton d'auto-cliqueur (lot 4) : une recompense qui
-- attend dans la sauvegarde, une icone qui pulse, une fenetre qu'on peut
-- refermer sans rien perdre. Elle avait ete construite la-bas pour deux cartes ;
-- elle se remplit ici avec les siennes.
local function buildBadge(screenGui)
	badge = Instance.new("TextButton")
	badge.Name = "PackBadge"
	badge.Position = UDim2.new(0, 16, 0, 144)
	badge.Size = UDim2.new(0, 220, 0, 42)
	badge.BackgroundColor3 = Color3.fromRGB(24, 18, 30)
	badge.AutoButtonColor = false
	badge.Text = ""
	badge.Visible = false
	badge.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Parent = badge

	badgeLabel = Instance.new("TextLabel")
	badgeLabel.Size = UDim2.new(1, -16, 1, -10)
	badgeLabel.Position = UDim2.new(0, 8, 0, 5)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.FontFace = Fonts.Main
	badgeLabel.TextScaled = true
	badgeLabel.Text = ""
	badgeLabel.Parent = badge

	badgePulse = TweenService:Create(
		stroke,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.75 }
	)

	badge.MouseButton1Click:Connect(function()
		Packs.Open()
	end)

	Popup.BindButtonSounds(badge)

	return stroke
end

local badgeStroke = nil

local function setBadgeVisible(visible)
	if visible == badgeShown then
		return
	end

	badgeShown = visible
	badge.Visible = visible

	if visible then
		badgePulse:Play()
	else
		badgePulse:Cancel()
	end
end

--------------------------------------------------------------------------------
-- Les trois cartes
--------------------------------------------------------------------------------

local function buildSlot(parent, index)
	local card = Instance.new("TextButton")
	card.Name = "Card" .. index
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, (index - 2) * (CARD_WIDTH + CARD_GAP), 0, 56)
	card.Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT)
	card.BackgroundColor3 = BACK_COLOR
	card.AutoButtonColor = false
	card.Text = ""
	card.ZIndex = 22
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = card

	-- Le dos de la carte : le symbole du Terminal, seul, sur fond sombre. Il
	-- disparait au retournement.
	local back = Instance.new("TextLabel")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundTransparency = 1
	back.FontFace = Fonts.Symbol
	back.TextScaled = true
	back.Text = "\u{25C8}"
	back.TextColor3 = Color3.fromRGB(90, 80, 110)
	back.ZIndex = 24
	back.Parent = card

	local backPadding = Instance.new("UIPadding")
	backPadding.PaddingTop = UDim.new(0.3, 0)
	backPadding.PaddingBottom = UDim.new(0.3, 0)
	backPadding.PaddingLeft = UDim.new(0.3, 0)
	backPadding.PaddingRight = UDim.new(0.3, 0)
	backPadding.Parent = back

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 1
	face.Visible = false
	face.ZIndex = 23
	face.Parent = card

	local family = Instance.new("TextLabel")
	family.Size = UDim2.new(1, -16, 0, 22)
	family.Position = UDim2.new(0, 8, 0, 10)
	family.BackgroundTransparency = 1
	family.FontFace = Fonts.Main
	family.TextScaled = true
	family.ZIndex = 24
	family.Parent = face

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -16, 0, 52)
	name.Position = UDim2.new(0, 8, 0, 38)
	name.BackgroundTransparency = 1
	name.FontFace = Fonts.Main
	name.TextScaled = true
	name.ZIndex = 24
	name.Parent = face

	local info = Instance.new("TextLabel")
	info.Size = UDim2.new(1, -20, 1, -132)
	info.Position = UDim2.new(0, 10, 0, 96)
	info.BackgroundTransparency = 1
	info.TextColor3 = Color3.fromRGB(225, 228, 235)
	info.FontFace = Fonts.Main
	info.TextScaled = true
	info.TextWrapped = true
	info.ZIndex = 24
	info.Parent = face

	local rarity = Instance.new("TextLabel")
	rarity.AnchorPoint = Vector2.new(0.5, 1)
	rarity.Size = UDim2.new(1, -16, 0, 24)
	rarity.Position = UDim2.new(0.5, 0, 1, -8)
	rarity.BackgroundTransparency = 1
	rarity.FontFace = Fonts.Main
	rarity.TextScaled = true
	rarity.ZIndex = 24
	rarity.Parent = face

	-- Le halo de rarete : un contour qui respire, allume seulement une fois la
	-- carte retournee. Sur une carte face cachee, il vendrait la meche.
	local halo = TweenService:Create(
		stroke,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.65 }
	)

	Popup.BindButtonSounds(card)

	local slot = {
		button = card,
		stroke = stroke,
		back = back,
		face = face,
		family = family,
		name = name,
		info = info,
		rarity = rarity,
		halo = halo,
		revealed = false,
	}

	card.MouseEnter:Connect(function()
		if slot.revealed and not revealing then
			TweenService:Create(card, TweenInfo.new(0.15), {
				Size = UDim2.new(0, CARD_WIDTH + 10, 0, CARD_HEIGHT + 14),
			}):Play()
		end
	end)

	card.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.15), {
			Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT),
		}):Play()
	end)

	card.MouseButton1Click:Connect(function()
		-- Choisir pendant l'animation reviendrait a la rendre facultative --
		-- et personne ne la verrait deux fois.
		if revealing or not slot.revealed then
			return
		end

		Remotes.PackChoose:FireServer(index)
		Sounds.Play("pack_choose")
		Packs.Close()
	end)

	return slot
end

--------------------------------------------------------------------------------
-- Le retournement
--------------------------------------------------------------------------------

-- Une carte qui pivote : Roblox ne sait pas retourner un Frame en 3D, donc on
-- ecrase sa largeur jusqu'a zero, on echange le dos pour la face, et on la
-- redeploie. A cette vitesse, l'oeil lit un retournement.
local function reveal(slot, card, tier)
	local button = slot.button

	TweenService:Create(button, TweenInfo.new(FLIP_TIME / 2, Enum.EasingStyle.Quad), {
		Size = UDim2.new(0, 0, 0, CARD_HEIGHT),
	}):Play()

	task.wait(FLIP_TIME / 2)

	local color = Cards.RARITY_COLOR[card.rarity]

	slot.back.Visible = false
	slot.face.Visible = true
	button.BackgroundColor3 = FACE_COLOR
	slot.stroke.Color = color

	slot.family.Text = Locale.Text("card_family_" .. card.family)
	slot.family.TextColor3 = Cards.FAMILY_COLOR[card.family]

	slot.name.Text = Locale.Text("card_" .. card.id .. "_name")
	slot.info.Text = Locale.Text("card_" .. card.id .. "_info", Cards.Params(card, tier))
	slot.rarity.Text = Locale.Text("rarity_" .. card.rarity)

	local fx = RARITY_FX[card.rarity] or 0.2
	TextFx.Mark(slot.name, fx, color)
	TextFx.Mark(slot.rarity, fx * 0.7, color)

	TweenService:Create(button, TweenInfo.new(FLIP_TIME / 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT),
	}):Play()

	slot.revealed = true
	slot.halo:Play()

	-- La note monte avec la rarete : on entend ce qu'on a tire avant de l'avoir
	-- lu, et c'est ce qui fait sursauter sur une Legendaire.
	Sounds.Play("pack_flip", { pitch = 0.9 + (Cards.RARITY_ORDER[card.rarity] or 1) * 0.16 })
end

local function resetSlots()
	revealing = false

	for _, slot in slots do
		slot.revealed = false
		slot.halo:Cancel()
		slot.stroke.Transparency = 0.3
		slot.back.Visible = true
		slot.face.Visible = false
		slot.button.BackgroundColor3 = BACK_COLOR
		slot.button.Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT)
		slot.stroke.Color = Color3.fromRGB(90, 80, 110)
	end
end

--------------------------------------------------------------------------------

local function buildWindow(screenGui)
	-- Le voile assombrit le hall : sans lui, les cartes se lisent par-dessus le
	-- decor et l'ouverture n'est qu'une popup de plus.
	veil = Instance.new("Frame")
	veil.Name = "PackVeil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.Visible = false
	veil.ZIndex = 18
	veil.Parent = screenGui

	window = Instance.new("Frame")
	window.Name = "PackWindow"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = WINDOW_SIZE
	window.BackgroundColor3 = Color3.fromRGB(14, 13, 18)
	window.BackgroundTransparency = 0.08
	window.Visible = false
	window.ZIndex = 20
	window.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = window

	title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.ZIndex = 21
	title.Parent = window

	for index = 1, 3 do
		slots[index] = buildSlot(window, index)
	end

	hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Size = UDim2.new(1, -40, 0, 34)
	hint.Position = UDim2.new(0.5, 0, 1, -14)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.fromRGB(200, 205, 215)
	hint.FontFace = Fonts.Main
	hint.TextScaled = true
	hint.ZIndex = 21
	hint.Parent = window
end

--------------------------------------------------------------------------------

local function refreshBadge()
	if state.count > 0 then
		badgeLabel.Text = Locale.Text("hud_pack_waiting", { count = state.count })

		local color = state.rarity and Cards.RARITY_COLOR[state.rarity] or Color3.fromRGB(190, 110, 255)
		badgeLabel.TextColor3 = color
		badgeStroke.Color = color
	end

	setBadgeVisible(state.count > 0)
end

function Packs.Open()
	if state.count <= 0 or not state.cards or window.Visible then
		return
	end

	local rarity = state.rarity or Tiers.RARITY_COMMON
	local tier = state.tier or Tiers.FIRST

	resetSlots()

	title.Text = Locale.Text("pack_title", { rarity = Locale.Text("rarity_" .. rarity) })
	TextFx.Mark(title, RARITY_FX[rarity] or 0.3, Cards.RARITY_COLOR[rarity])
	hint.Text = Locale.Text("pack_hint")

	veil.Visible = true
	TweenService:Create(veil, TweenInfo.new(0.35), { BackgroundTransparency = 0.35 }):Play()

	Popup.In(window, WINDOW_SIZE)

	-- Le retournement decale, dans un fil a part : la fenetre est deja ouverte
	-- et reactive, seules les cartes attendent leur tour.
	revealing = true

	generation += 1
	local mine = generation

	task.spawn(function()
		for index, id in state.cards do
			local card = Cards.Get(id)
			local slot = slots[index]

			if card and slot then
				task.wait(FLIP_DELAY)

				-- Le joueur a pu refermer, ou rouvrir sur un autre pack, entre
				-- deux retournements : on s'arrete plutot que de retourner des
				-- cartes dans le vide ou celles de quelqu'un d'autre.
				if generation ~= mine or not window.Visible then
					return
				end

				reveal(slot, card, tier)
			end
		end

		if generation == mine then
			revealing = false
		end
	end)
end

function Packs.Close()
	if not window or not window.Visible then
		return
	end

	revealing = false
	generation += 1
	Popup.Out(window)

	TweenService:Create(veil, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	task.delay(0.25, function()
		if not window.Visible then
			veil.Visible = false
		end
	end)
end

-- Appele a chaque fois que le serveur annonce l'etat des packs. "gained" est vrai
-- quand un pack vient d'arriver : la fenetre s'ouvre alors toute seule, parce que
-- le joueur vient soit de monter d'un etage, soit de payer.
function Packs.SetState(next_)
	local gained = (next_.count or 0) > state.count

	state = next_

	refreshBadge()

	if state.count <= 0 then
		Packs.Close()
	elseif gained then
		Packs.Open()
	end
end

function Packs.Start(screenGui)
	badgeStroke = buildBadge(screenGui)
	buildWindow(screenGui)
	refreshBadge()

	Remotes.PackUpdated.OnClientEvent:Connect(Packs.SetState)

	-- L'etat est RECLAME, pas attendu : le serveur ne peut pas le pousser a
	-- l'arrivee du joueur, ses Remotes ne sont pas encore branches de ce cote.
	Remotes.PackUpdated:FireServer()
end

return Packs
