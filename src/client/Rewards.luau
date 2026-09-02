-- Les cadeaux de survie, cote joueur : l'icone qui pulse, et la fenetre ou on
-- les reclame.
--
-- A RECLAMER, PAS A RECEVOIR. C'est toute la raison d'etre de ce module. Le
-- serveur pourrait crediter les seuils tout seul, et ca marcherait -- mais un
-- cadeau encaisse sans qu'on le remarque n'a rien recompense du tout. Il faut
-- que le joueur voie l'icone, clique, et regarde ce qu'il a gagne.
--
-- La fenetre montre TOUTE l'echelle, pas seulement ce qui est mur : les seuils
-- deja pris, ceux qui attendent, et ceux qu'il reste a atteindre. C'est ce qui
-- transforme une liste de recompenses en objectif -- un joueur qui voit "3 j :
-- pack Rare" sait pourquoi il tient encore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local RewardList = require(ReplicatedStorage.Shared.Rewards)
local Popup = require(script.Parent.Popup)

local Rewards = {}

local ROW_HEIGHT = 40
local ROW_GAP = 5
local WINDOW_WIDTH = 360
local WINDOW_SIZE = UDim2.new(
	0,
	WINDOW_WIDTH,
	0,
	58 + #RewardList.List * (ROW_HEIGHT + ROW_GAP) + 52
)

local READY_COLOR = Color3.fromRGB(120, 220, 140)
local DONE_COLOR = Color3.fromRGB(110, 115, 125)
local LOCKED_COLOR = Color3.fromRGB(190, 195, 205)

local state = { ready = {}, maxTime = 0, nextAt = nil, nextIndex = nil }

local badge = nil
local badgeLabel = nil
local badgeStroke = nil
local badgePulse = nil
local badgeShown = false

local window = nil
local rows = {}

--------------------------------------------------------------------------------
-- Ce que dit une ligne
--------------------------------------------------------------------------------

-- Le libelle d'un cadeau se reconstruit ICI, depuis src/shared/Rewards.luau : le
-- serveur n'envoie que des indices, jamais du texte. C'est ce qui permet d'ecrire
-- l'echelle dans la langue du joueur sans un octet de plus sur le reseau.
local function describe(reward)
	if reward.kind == RewardList.KIND_TIME then
		return Locale.Text("reward_time", { amount = reward.amount })
	elseif reward.kind == RewardList.KIND_FUEL then
		return Locale.Text("reward_fuel")
	elseif reward.kind == RewardList.KIND_BOOST then
		return Locale.Text("reward_boost", { count = reward.amount })
	elseif reward.kind == RewardList.KIND_FRENZY then
		return Locale.Text("reward_frenzy")
	elseif reward.kind == RewardList.KIND_PACK then
		local text = Locale.Text("reward_pack", { rarity = Locale.Text("rarity_" .. reward.rarity) })

		-- Le dernier cadeau de l'echelle paie double : un pack Legendaire ET la
		-- couronne. Il tombe a 50 jours, soit l'ordre de grandeur du cumul a
		-- payer pour atteindre le Terminus -- c'est voulu.
		if reward.crown then
			text ..= " + " .. Locale.Text("reward_crown")
		end

		return text
	end

	return ""
end

--------------------------------------------------------------------------------
-- L'icone qui attend
--------------------------------------------------------------------------------

local function buildBadge(screenGui)
	badge = Instance.new("TextButton")
	badge.Name = "RewardBadge"
	badge.Position = UDim2.new(0, 16, 0, 192)
	badge.Size = UDim2.new(0, 220, 0, 42)
	badge.BackgroundColor3 = Color3.fromRGB(18, 26, 20)
	badge.AutoButtonColor = false
	badge.Text = ""
	badge.Visible = false
	badge.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badge

	badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = READY_COLOR
	badgeStroke.Thickness = 2
	badgeStroke.Transparency = 0.15
	badgeStroke.Parent = badge

	badgeLabel = Instance.new("TextLabel")
	badgeLabel.Size = UDim2.new(1, -16, 1, -10)
	badgeLabel.Position = UDim2.new(0, 8, 0, 5)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.TextColor3 = READY_COLOR
	badgeLabel.FontFace = Fonts.Main
	badgeLabel.TextScaled = true
	badgeLabel.Text = ""
	badgeLabel.Parent = badge

	badgePulse = TweenService:Create(
		badgeStroke,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.75 }
	)

	Popup.BindButtonSounds(badge)
	badge.MouseButton1Click:Connect(function()
		Rewards.Toggle()
	end)
end

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
-- La fenetre
--------------------------------------------------------------------------------

local function buildRow(parent, reward, index)
	local row = Instance.new("TextButton")
	row.Name = "Reward" .. index
	row.Size = UDim2.new(1, -24, 0, ROW_HEIGHT)
	row.Position = UDim2.new(0, 12, 0, 52 + (index - 1) * (ROW_HEIGHT + ROW_GAP))
	row.BackgroundColor3 = Color3.fromRGB(26, 30, 28)
	row.BackgroundTransparency = 0.2
	row.AutoButtonColor = false
	row.Text = ""
	row.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = row

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 0.6
	stroke.Parent = row

	local at = Instance.new("TextLabel")
	at.Size = UDim2.new(0.3, 0, 1, -10)
	at.Position = UDim2.new(0, 10, 0, 5)
	at.BackgroundTransparency = 1
	at.FontFace = Fonts.Main
	at.TextScaled = true
	at.TextXAlignment = Enum.TextXAlignment.Left
	at.Text = Locale.Text("reward_at", { amount = reward.at })
	at.Parent = row

	local gift = Instance.new("TextLabel")
	gift.Size = UDim2.new(0.68, -12, 1, -10)
	gift.Position = UDim2.new(0.32, 0, 0, 5)
	gift.BackgroundTransparency = 1
	gift.FontFace = Fonts.Main
	gift.TextScaled = true
	gift.TextXAlignment = Enum.TextXAlignment.Right
	gift.Text = describe(reward)
	gift.Parent = row

	Popup.BindButtonSounds(row)

	row.MouseButton1Click:Connect(function()
		-- Le serveur revalide de toute facon : ce test-la ne sert qu'a ne pas
		-- envoyer un message pour rien sur une ligne grisee.
		if rows[index] and rows[index].claimable then
			Remotes.RewardClaim:FireServer(index)
			Sounds.Play("reward_claim")
		end
	end)

	return { frame = row, stroke = stroke, at = at, gift = gift, claimable = false }
end

local function buildWindow(screenGui)
	window = Instance.new("Frame")
	window.Name = "RewardWindow"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = WINDOW_SIZE
	window.BackgroundColor3 = Color3.fromRGB(18, 20, 19)
	window.BackgroundTransparency = 0.08
	window.Visible = false
	window.ZIndex = 15
	window.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = window

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 38)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.Text = Locale.Text("reward_title")
	title.Parent = window

	TextFx.Mark(title, 0.55, READY_COLOR)

	for index, reward in RewardList.List do
		rows[index] = buildRow(window, reward, index)
	end

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Size = UDim2.new(1, -24, 0, 34)
	close.Position = UDim2.new(0.5, 0, 1, -10)
	close.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
	close.TextColor3 = Color3.new(1, 1, 1)
	close.FontFace = Fonts.Main
	close.TextScaled = true
	close.Text = Locale.Text("shop_close")
	close.Parent = window

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = close

	Popup.BindButtonSounds(close)
	close.MouseButton1Click:Connect(function()
		Popup.Out(window)
	end)
end

--------------------------------------------------------------------------------

local function refresh()
	local ready = {}
	for _, index in state.ready do
		ready[index] = true
	end

	for index, reward in RewardList.List do
		local row = rows[index]
		if row then
			local reached = state.maxTime >= reward.at

			row.claimable = ready[index] == true

			if row.claimable then
				-- Mur, et pas encore pris : c'est la seule ligne sur laquelle il
				-- y a quelque chose a faire, elle doit se voir comme telle.
				row.frame.BackgroundTransparency = 0.05
				row.stroke.Color = READY_COLOR
				row.stroke.Transparency = 0.1
				row.at.TextColor3 = READY_COLOR
				row.gift.Text = describe(reward) .. "  " .. Locale.Text("reward_claim")
				TextFx.Mark(row.gift, 0.6, READY_COLOR)
			elseif reached then
				-- Deja reclame : garde sa place dans l'echelle, mais s'efface.
				row.frame.BackgroundTransparency = 0.55
				row.stroke.Color = DONE_COLOR
				row.stroke.Transparency = 0.75
				row.at.TextColor3 = DONE_COLOR
				TextFx.Detach(row.gift)
				row.gift.Text = describe(reward)
				row.gift.TextColor3 = DONE_COLOR
			else
				row.frame.BackgroundTransparency = 0.35
				row.stroke.Color = LOCKED_COLOR
				row.stroke.Transparency = 0.7
				row.at.TextColor3 = LOCKED_COLOR
				TextFx.Detach(row.gift)
				row.gift.Text = describe(reward)
				row.gift.TextColor3 = LOCKED_COLOR
			end
		end
	end

	local count = #state.ready

	if count > 0 then
		badgeLabel.Text = Locale.Text("hud_reward_ready", { count = count })
	end

	setBadgeVisible(count > 0)

	-- Une fenetre ouverte alors que le dernier cadeau vient d'etre pris se
	-- referme toute seule : il n'y reste plus rien a faire.
	if count == 0 and window.Visible and not state.nextAt then
		Popup.Out(window)
	end
end

function Rewards.Toggle()
	if window.Visible then
		Popup.Out(window)
		return
	end

	refresh()
	Popup.In(window, WINDOW_SIZE)
end

function Rewards.SetState(next_)
	state = next_
	refresh()
end

function Rewards.Start(screenGui)
	buildBadge(screenGui)
	buildWindow(screenGui)
	refresh()

	Remotes.RewardUpdated.OnClientEvent:Connect(Rewards.SetState)

	-- L'etat est reclame, pas attendu (meme raison que partout ailleurs).
	Remotes.RewardUpdated:FireServer()
end

return Rewards
