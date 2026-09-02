-- Les mini-jeux, cote joueur. Quatre choses, communes aux huit jeux :
--
--   1. LA FENETRE de confirmation -- ce que coute la partie, ou le cadenas qui
--      dit ce qu'il faut atteindre. La Roue y ajoute son choix de secteur.
--   2. LE CADENAS pose au-dessus d'une zone encore fermee. Il est propre a
--      chaque joueur, alors que le panneau de la zone est partage : c'est donc
--      le client qui le dessine.
--   3. LE HUD des parties en cours, en haut a droite. Une fois sa mise partie,
--      le joueur repart farmer ailleurs et le panneau de la zone ne lui dit plus
--      rien : ce bandeau-la le suit partout et fait descendre le decompte.
--   4. LA SCENE -- le bandeau du milieu pendant la phase active, et la capture
--      des clics pour les deux jeux qui en demandent (duel, braquage).
--
-- C'EST LE PENDANT CLIENT DE L'ETAPE 24. Le pari d'origine dessinait tout ca
-- dans init.client ; en le sortant ici, les sept autres jeux l'ont eu sans
-- ecrire une ligne d'interface. C'est exactement ce que le lot demandait.
--
-- Le serveur n'envoie jamais de phrase toute faite : il pose une cle et ses
-- parametres, et le texte s'ecrit ici, dans la langue du joueur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local MiniGameList = require(ReplicatedStorage.Shared.MiniGameList)
local Popup = require(script.Parent.Popup)

local MiniGames = {}

local LOCKED_COLOR = Color3.fromRGB(200, 200, 210)

--------------------------------------------------------------------------------
-- 1. La fenetre de confirmation
--------------------------------------------------------------------------------

local PROMPT_BASE = UDim2.new(0, 320, 0, 184)
local PROMPT_SECTORS = UDim2.new(0, 320, 0, 260) -- la roue ajoute sa grille

local promptFrame = nil
local promptTitle = nil
local promptAmount = nil
local promptAccept = nil
local promptDecline = nil
local sectorGrid = nil
local sectorButtons = {}

local currentZone = nil
local currentLocked = false
local currentSectors = false
local chosenSector = 1

local function setSector(index)
	chosenSector = index

	for number, button in sectorButtons do
		local picked = number == index
		button.BackgroundColor3 = picked and Color3.fromRGB(70, 130, 180) or Color3.fromRGB(40, 42, 50)
		button.TextColor3 = picked and Color3.new(1, 1, 1) or Color3.fromRGB(190, 195, 205)
	end
end

local function buildSectorGrid(parent)
	sectorGrid = Instance.new("Frame")
	sectorGrid.Name = "Sectors"
	sectorGrid.Size = UDim2.new(1, -24, 0, 62)
	sectorGrid.Position = UDim2.new(0, 12, 0, 108)
	sectorGrid.BackgroundTransparency = 1
	sectorGrid.Visible = false
	sectorGrid.Parent = parent

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 44, 0, 28)
	layout.CellPadding = UDim2.new(0, 6, 0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = sectorGrid

	-- Six secteurs : c'est Roue.SECTORS cote serveur. Le nombre est fige des deux
	-- cotes -- une roue dont le nombre de cases changerait n'aurait plus de cote
	-- lisible pour le joueur.
	for number = 1, 6 do
		local button = Instance.new("TextButton")
		button.Name = "Sector" .. number
		button.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
		button.AutoButtonColor = false
		button.FontFace = Fonts.Main
		button.TextScaled = true
		button.Text = tostring(number)
		button.LayoutOrder = number
		button.Parent = sectorGrid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = button

		Popup.BindButtonSounds(button)
		button.MouseButton1Click:Connect(function()
			setSector(number)
		end)

		sectorButtons[number] = button
	end
end

local function hidePrompt()
	currentZone = nil
	currentLocked = false
	currentSectors = false

	if promptFrame then
		Popup.Out(promptFrame)
	end
end

local function buildPrompt(screenGui)
	promptFrame = Instance.new("Frame")
	promptFrame.Name = "MiniGamePrompt"
	promptFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	promptFrame.Position = UDim2.fromScale(0.5, 0.5)
	promptFrame.Size = PROMPT_BASE
	promptFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	promptFrame.BackgroundTransparency = 0.1
	promptFrame.Visible = false
	promptFrame.Parent = screenGui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.Parent = promptFrame

	promptTitle = Instance.new("TextLabel")
	promptTitle.Size = UDim2.new(1, 0, 0, 40)
	promptTitle.BackgroundTransparency = 1
	promptTitle.FontFace = Fonts.Main
	promptTitle.TextScaled = true
	promptTitle.Parent = promptFrame

	promptAmount = Instance.new("TextLabel")
	promptAmount.Size = UDim2.new(1, -20, 0, 54)
	promptAmount.Position = UDim2.new(0, 10, 0, 44)
	promptAmount.BackgroundTransparency = 1
	promptAmount.FontFace = Fonts.Main
	promptAmount.TextScaled = true
	promptAmount.TextWrapped = true
	promptAmount.Parent = promptFrame

	buildSectorGrid(promptFrame)

	promptAccept = Instance.new("TextButton")
	promptAccept.Size = UDim2.new(0.45, 0, 0, 40)
	promptAccept.Position = UDim2.new(0.025, 0, 1, -50)
	promptAccept.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
	promptAccept.TextColor3 = Color3.new(1, 1, 1)
	promptAccept.FontFace = Fonts.Main
	promptAccept.TextScaled = true
	promptAccept.Text = Locale.Text("bet_accept")
	promptAccept.Parent = promptFrame

	promptDecline = Instance.new("TextButton")
	promptDecline.Size = UDim2.new(0.45, 0, 0, 40)
	promptDecline.Position = UDim2.new(0.525, 0, 1, -50)
	promptDecline.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	promptDecline.TextColor3 = Color3.new(1, 1, 1)
	promptDecline.FontFace = Fonts.Main
	promptDecline.TextScaled = true
	promptDecline.Text = Locale.Text("bet_decline")
	promptDecline.Parent = promptFrame

	Popup.BindButtonSounds(promptAccept)
	Popup.BindButtonSounds(promptDecline)

	promptAccept.MouseButton1Click:Connect(function()
		if currentZone and not currentLocked then
			-- Le secteur n'accompagne que la roue ; ailleurs le serveur l'ignore.
			Remotes.MiniGameAccept:FireServer(currentZone, currentSectors and chosenSector or nil)
		end

		hidePrompt()
	end)

	promptDecline.MouseButton1Click:Connect(hidePrompt)
end

-- La meme fenetre sert a tous les etats de la zone : ouverte (on mise),
-- verrouillee (on lit ce qu'il faut), gratuite (le train), pleine (le duel).
-- Un seul bouton quand il n'y a rien a valider.
local function showPrompt(zone, prompt)
	local game = MiniGameList.Get(prompt.game) or MiniGameList.DEFAULT

	currentZone = zone
	currentLocked = prompt.lockedTier ~= nil or prompt.lockedAt ~= nil or not prompt.open
	currentSectors = prompt.sectors == true and not currentLocked

	if prompt.lockedTier then
		promptTitle.Text = Locale.Text("bet_locked_title")
		TextFx.Mark(promptTitle, 0.2, LOCKED_COLOR)
		promptAmount.Text = Locale.Text("minigame_locked_tier", {
			name = Locale.Text("minigame_" .. game.key .. "_name"),
			tier = prompt.lockedTier,
		})
		promptAmount.TextColor3 = LOCKED_COLOR
	elseif prompt.lockedAt then
		-- Le verrou du pari d'origine : avoir POSSEDE ce temps au moins une fois.
		-- Il ne s'applique qu'aux zones qui le portent, et survit tel quel.
		promptTitle.Text = Locale.Text("bet_locked_title")
		TextFx.Mark(promptTitle, 0.2, LOCKED_COLOR)
		promptAmount.Text = Locale.Text("bet_locked_info", { amount = prompt.lockedAt })
		promptAmount.TextColor3 = LOCKED_COLOR
	elseif not prompt.open then
		promptTitle.Text = Locale.Text("minigame_" .. game.key .. "_name")
		TextFx.Mark(promptTitle, 0.3, game.color)
		promptAmount.Text = Locale.Text("minigame_busy")
		promptAmount.TextColor3 = LOCKED_COLOR
	else
		promptTitle.Text = Locale.Text("minigame_" .. game.key .. "_name")
		TextFx.Mark(promptTitle, 0.6, game.color)
		promptAmount.TextColor3 = Color3.fromRGB(255, 221, 0)

		if prompt.free then
			promptAmount.Text = Locale.Text("minigame_train_info", { amount = prompt.pot or 0 })
		elseif (prompt.stakes or 0) > 0 then
			-- Un jeton offert (carte "Poignee de jetons") paie la mise : le
			-- joueur doit le savoir AVANT de valider, sinon il croit depenser.
			promptAmount.Text = Locale.Text("minigame_stake_free", {
				amount = prompt.amount,
				count = prompt.stakes,
			})
		else
			promptAmount.Text = Locale.Text("bet_amount", { amount = prompt.amount })
		end
	end

	sectorGrid.Visible = currentSectors
	if currentSectors then
		setSector(chosenSector)
	end

	promptAccept.Visible = not currentLocked

	if currentLocked then
		promptDecline.Size = UDim2.new(0.95, 0, 0, 40)
		promptDecline.Position = UDim2.new(0.025, 0, 1, -50)
		promptDecline.Text = Locale.Text("shop_close")
	else
		promptDecline.Size = UDim2.new(0.45, 0, 0, 40)
		promptDecline.Position = UDim2.new(0.525, 0, 1, -50)
		promptDecline.Text = Locale.Text("bet_decline")
	end

	local size = currentSectors and PROMPT_SECTORS or PROMPT_BASE
	promptFrame.Size = size
	Popup.In(promptFrame, size)

	if currentLocked then
		-- Une zone fermee se signale a l'oreille : le "pop" de la fenetre est le
		-- meme pour tout le monde, le refus qui le suit ne trompe pas.
		Sounds.Play("ui_denied")
	end
end

--------------------------------------------------------------------------------
-- 2. Le cadenas des zones fermees
--------------------------------------------------------------------------------

local lockSigns = {}

local function setLock(zone, locked, gameKey)
	local sign = lockSigns[zone]

	if not locked then
		if sign then
			sign.billboard:Destroy()
			lockSigns[zone] = nil
		end
		return
	end

	if not sign then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "MyMiniGameLock"
		billboard.Size = UDim2.new(8, 0, 3, 0) -- en studs : taille fixe dans le monde
		billboard.StudsOffset = Vector3.new(0, 7.6, 0) -- au-dessus du panneau de la zone
		billboard.AlwaysOnTop = true
		billboard.Parent = zone

		-- Le cadenas est un emoji : aucune police du jeu ne le contient, c'est le
		-- repli systeme de Roblox qui le dessine. Le texte en dessous porte le
		-- sens a lui seul, pour que rien ne soit perdu si le glyphe manque.
		local glyph = Instance.new("TextLabel")
		glyph.Size = UDim2.new(1, 0, 0.55, 0)
		glyph.BackgroundTransparency = 1
		glyph.FontFace = Fonts.Symbol
		glyph.TextScaled = true
		glyph.Text = "\u{1F512}"
		glyph.TextColor3 = LOCKED_COLOR
		glyph.Parent = billboard

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0.45, 0)
		label.Position = UDim2.new(0, 0, 0.55, 0)
		label.BackgroundTransparency = 1
		label.FontFace = Fonts.Main
		label.TextScaled = true
		label.Parent = billboard

		TextFx.Mark(label, 0.25, LOCKED_COLOR)

		sign = { billboard = billboard, label = label }
		lockSigns[zone] = sign
	end

	if locked.tier then
		sign.label.Text = Locale.Text("minigame_lock_tier", { tier = locked.tier })
	else
		sign.label.Text = Locale.Text("bet_locked_sign", { amount = locked.amount })
	end
end

--------------------------------------------------------------------------------
-- 3. Le HUD des parties en cours
--------------------------------------------------------------------------------

local HUD_WIDTH = 250
local HUD_TITLE_HEIGHT = 26
local HUD_ROW_HEIGHT = 46
local HUD_ROW_GAP = 6
local HUD_TIMER_WIDTH = 74

local HUD_CALM = Color3.fromRGB(120, 220, 140) -- il reste le temps de miser
local HUD_URGENT = Color3.fromRGB(255, 90, 70) -- resultat imminent
local HUD_MINE = Color3.fromRGB(255, 200, 60) -- ma mise est engagee dedans
local HUD_OTHER = Color3.fromRGB(150, 160, 175) -- partie ouverte, sans moi

local hud = nil
local hudList = nil
local hudRows = {}

local function buildHud(screenGui)
	hud = Instance.new("Frame")
	hud.Name = "MiniGameHud"
	hud.AnchorPoint = Vector2.new(1, 0)
	hud.Position = UDim2.new(1, -16, 0, 96)
	hud.Size = UDim2.new(0, HUD_WIDTH, 0, HUD_TITLE_HEIGHT)
	hud.BackgroundTransparency = 1
	hud.Visible = false
	hud.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, HUD_TITLE_HEIGHT)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Right
	title.Text = Locale.Text("minigame_hud_title")
	title.Parent = hud

	TextFx.Mark(title, 0.35, Color3.fromRGB(255, 150, 60))

	hudList = Instance.new("Frame")
	hudList.Position = UDim2.new(0, 0, 0, HUD_TITLE_HEIGHT + HUD_ROW_GAP)
	hudList.Size = UDim2.new(1, 0, 1, -(HUD_TITLE_HEIGHT + HUD_ROW_GAP))
	hudList.BackgroundTransparency = 1
	hudList.Parent = hud

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, HUD_ROW_GAP)
	layout.Parent = hudList
end

-- Une ligne = une partie ouverte : le jeu et la mise a gauche, le decompte a
-- droite. Les parties ou le joueur n'a rien mis y figurent aussi, en gris :
-- c'est ce qui donne envie d'y courir avant la fin.
local function newHudRow(index, joined)
	local accent = joined and HUD_MINE or HUD_OTHER

	local frame = Instance.new("Frame")
	frame.Name = "Round" .. index
	frame.Size = UDim2.new(1, 0, 0, HUD_ROW_HEIGHT)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = joined and 0.15 or 0.4
	frame.LayoutOrder = index
	frame.Parent = hudList

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = joined and 2 or 1
	stroke.Transparency = joined and 0.1 or 0.55
	stroke.Parent = frame

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -(HUD_TIMER_WIDTH + 20), 0, 22)
	name.Position = UDim2.new(0, 10, 0, 4)
	name.BackgroundTransparency = 1
	name.TextColor3 = accent
	name.FontFace = Fonts.Main
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = frame

	local players = Instance.new("TextLabel")
	players.Size = UDim2.new(1, -(HUD_TIMER_WIDTH + 20), 0, 16)
	players.Position = UDim2.new(0, 10, 0, 26)
	players.BackgroundTransparency = 1
	players.TextColor3 = Color3.fromRGB(190, 195, 205)
	players.FontFace = Fonts.Main
	players.TextScaled = true
	players.TextXAlignment = Enum.TextXAlignment.Left
	players.Parent = frame

	local timer = Instance.new("TextLabel")
	timer.Size = UDim2.new(0, HUD_TIMER_WIDTH, 1, -12)
	timer.Position = UDim2.new(1, -(HUD_TIMER_WIDTH + 10), 0, 6)
	timer.BackgroundTransparency = 1
	timer.TextColor3 = HUD_CALM
	timer.TextStrokeTransparency = 0.4
	timer.TextStrokeColor3 = Color3.new(0, 0, 0)
	timer.FontFace = Fonts.Main
	timer.TextScaled = true
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.Parent = frame

	return { frame = frame, name = name, players = players, timer = timer }
end

local function setRounds(rounds)
	for _, row in hudRows do
		row.frame:Destroy()
	end

	table.clear(hudRows)

	for index, round in rounds do
		local game = MiniGameList.Get(round.game) or MiniGameList.DEFAULT
		local row = newHudRow(index, round.joined)

		row.name.Text = Locale.Text("minigame_" .. game.key .. "_name")
		row.players.Text = Locale.Text(round.joined and "bet_hud_mine" or "bet_hud_players", {
			count = round.count,
		})
		row.endsAt = round.endsAt
		row.running = round.running

		if round.running then
			-- Une partie deja lancee n'a plus de decompte d'inscription : on
			-- affiche ce qu'elle est, pas un chiffre qui ne descend plus.
			row.timer.Text = Locale.Text("minigame_hud_running")
			row.timer.TextColor3 = HUD_URGENT
		end

		table.insert(hudRows, row)
	end

	hud.Size = UDim2.new(
		0,
		HUD_WIDTH,
		0,
		HUD_TITLE_HEIGHT + HUD_ROW_GAP + #hudRows * (HUD_ROW_HEIGHT + HUD_ROW_GAP)
	)
	hud.Visible = #hudRows > 0
end

--------------------------------------------------------------------------------
-- 4. La scene
--------------------------------------------------------------------------------

local stageFrame = nil
local stageLabel = nil
local stageTimer = nil
local stageHint = nil

local stageZone = nil
local stageEndsAt = nil
local stageClicks = false

-- Les clics du duel et du braquage partent par PAQUETS, dix fois par seconde :
-- un message par clic saturerait le reseau pour un compteur que le serveur sait
-- additionner tout seul.
local pendingClicks = 0

local function buildStage(screenGui)
	stageFrame = Instance.new("Frame")
	stageFrame.Name = "MiniGameStage"
	stageFrame.AnchorPoint = Vector2.new(0.5, 0)
	stageFrame.Position = UDim2.new(0.5, 0, 0, 92)
	stageFrame.Size = UDim2.new(0, 420, 0, 96)
	stageFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	stageFrame.BackgroundTransparency = 0.15
	stageFrame.Visible = false
	stageFrame.ZIndex = 12
	stageFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = stageFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 150, 60)
	stroke.Thickness = 2
	stroke.Transparency = 0.25
	stroke.Parent = stageFrame

	stageLabel = Instance.new("TextLabel")
	stageLabel.Size = UDim2.new(1, -20, 0, 40)
	stageLabel.Position = UDim2.new(0, 10, 0, 6)
	stageLabel.BackgroundTransparency = 1
	stageLabel.FontFace = Fonts.Main
	stageLabel.TextScaled = true
	stageLabel.ZIndex = 13
	stageLabel.Parent = stageFrame

	stageTimer = Instance.new("TextLabel")
	stageTimer.Size = UDim2.new(1, -20, 0, 26)
	stageTimer.Position = UDim2.new(0, 10, 0, 44)
	stageTimer.BackgroundTransparency = 1
	stageTimer.TextColor3 = Color3.fromRGB(255, 221, 0)
	stageTimer.FontFace = Fonts.Main
	stageTimer.TextScaled = true
	stageTimer.Text = ""
	stageTimer.ZIndex = 13
	stageTimer.Parent = stageFrame

	stageHint = Instance.new("TextLabel")
	stageHint.Size = UDim2.new(1, -20, 0, 22)
	stageHint.Position = UDim2.new(0, 10, 0, 70)
	stageHint.BackgroundTransparency = 1
	stageHint.TextColor3 = Color3.fromRGB(190, 195, 205)
	stageHint.FontFace = Fonts.Main
	stageHint.TextScaled = true
	stageHint.Text = ""
	stageHint.ZIndex = 13
	stageHint.Parent = stageFrame
end

local function setStage(zone, info)
	if not info then
		stageZone = nil
		stageEndsAt = nil
		stageClicks = false
		pendingClicks = 0
		stageFrame.Visible = false
		return
	end

	local game = MiniGameList.Get(info.game) or MiniGameList.DEFAULT

	stageZone = zone
	stageEndsAt = info.endsAt
	stageClicks = game.clicks == true

	stageLabel.Text = Locale.Text(info.key, info.params)
	TextFx.Mark(stageLabel, 0.7, game.color)

	stageHint.Text = stageClicks and Locale.Text("minigame_hint_click") or ""
	stageTimer.Text = ""
	stageFrame.Visible = true
end

--------------------------------------------------------------------------------

function MiniGames.Hide()
	hidePrompt()
end

function MiniGames.Start(screenGui)
	buildPrompt(screenGui)
	buildHud(screenGui)
	buildStage(screenGui)

	Remotes.MiniGamePrompt.OnClientEvent:Connect(showPrompt)

	Remotes.MiniGamePromptHide.OnClientEvent:Connect(function(zone)
		if currentZone == zone then
			hidePrompt()
		end
	end)

	Remotes.MiniGameLockUpdated.OnClientEvent:Connect(setLock)
	Remotes.MiniGameRoundsUpdated.OnClientEvent:Connect(setRounds)
	Remotes.MiniGameStage.OnClientEvent:Connect(setStage)

	-- Au demarrage, une partie peut deja tourner : on reclame l'etat courant
	-- plutot que d'attendre le prochain changement.
	Remotes.MiniGameRoundsUpdated:FireServer()

	-- Les clics du duel et du braquage. On capte le clic gauche et le toucher,
	-- mais SEULEMENT pendant une phase active qui en demande : hors partie, ce
	-- gestionnaire ne fait rien du tout.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not stageClicks or not stageZone then
			return
		end

		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pendingClicks += 1
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)

			if pendingClicks > 0 and stageZone then
				Remotes.MiniGameAction:FireServer(stageZone, pendingClicks)
				pendingClicks = 0
			end
		end
	end)

	-- Les decomptes se calculent a partir de l'horloge SERVEUR : aucune derive
	-- possible, et deux joueurs devant la meme zone voient le meme chiffre.
	RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()

		for _, row in hudRows do
			if not row.running then
				local remaining = math.max(0, (row.endsAt or now) - now)
				local urgency = 1 - math.clamp(remaining / Config.BET_JOIN_WINDOW, 0, 1)

				row.timer.Text = Locale.Text("bet_hud_timer", { seconds = string.format("%.1f", remaining) })
				row.timer.TextColor3 = HUD_CALM:Lerp(HUD_URGENT, urgency)
			end
		end

		if stageFrame.Visible and stageEndsAt then
			local remaining = math.max(0, stageEndsAt - now)
			stageTimer.Text = Locale.Text("bet_hud_timer", { seconds = string.format("%.1f", remaining) })
		end
	end)
end

return MiniGames
