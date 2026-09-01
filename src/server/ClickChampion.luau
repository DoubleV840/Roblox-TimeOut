-- Panneau du "maitre du clic" : au-dessus de chaque objet tague Config.CLICKER_TAG,
-- le nom du joueur qui produit le plus de temps par seconde, en gros et en couleur.
--
-- Le debit compte les DEUX sources ensemble :
--   - le clic a la main, mesure sur une fenetre glissante de quelques secondes
--     (CLICKER_REWARD * ClickPower par clic) ;
--   - l'auto-cliqueur, dont le debit est deja une valeur par seconde.
--
-- Le panneau est une vraie Part (et non un BillboardGui) parce qu'il doit tourner
-- avec le cookie : un BillboardGui fait toujours face a la camera et ne tournerait
-- jamais. Elle porte le tag Config.SPIN_TAG, que le client fait tourner avec le
-- meme angle que le cookie -- donc exactement en phase. Texte des deux cotes, pour
-- rester lisible pendant tout le tour.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PlayerData = require(script.Parent.PlayerData)
local AutoClicker = require(script.Parent.AutoClicker)

local ClickChampion = {}

local COLOR_CALM = Color3.fromRGB(255, 221, 0) -- or : petit debit
local COLOR_HOT = Color3.fromRGB(255, 90, 200) -- magenta : gros debit
local COLOR_IDLE = Color3.fromRGB(150, 150, 155)

-- Au-dela de ce debit, le nom est au maximum de couleur et d'agitation. Ce n'est
-- qu'un seuil d'affichage : rien n'empeche d'aller plus haut.
local HEAT_SATURATION_RATE = 20

-- clickLog[player] = { { at = os.clock(), amount = secondes }, ... }
-- On ne garde que la fenetre courante, donc la table reste minuscule.
local clickLog = {}

local signs = {}

--------------------------------------------------------------------------------
-- Mesure du debit
--------------------------------------------------------------------------------

-- Appele par TimeCookie a chaque clic a la main.
function ClickChampion.NoteClick(player, amount)
	local log = clickLog[player]
	if not log then
		log = {}
		clickLog[player] = log
	end

	table.insert(log, { at = os.clock(), amount = amount })
end

local function manualRate(player)
	local log = clickLog[player]
	if not log then
		return 0
	end

	local cutoff = os.clock() - Config.CHAMPION_CLICK_WINDOW
	local total = 0
	local kept = {}

	for _, click in log do
		if click.at >= cutoff then
			total += click.amount
			table.insert(kept, click)
		end
	end

	clickLog[player] = kept

	return total / Config.CHAMPION_CLICK_WINDOW
end

-- Secondes gagnees par seconde, clics a la main et auto-cliqueur confondus.
local function totalRate(player)
	local data = PlayerData.Get(player)
	if not data then
		return 0
	end

	-- Un auto-cliqueur a sec ne compte pas : le panneau annonce ce qui rentre
	-- vraiment, pas ce que le joueur a paye.
	if (data.AutoClickFuel or 0) <= 0 then
		return manualRate(player)
	end

	return manualRate(player) + AutoClicker.Rate(data)
end

local function findChampion()
	local best, bestRate = nil, 0

	for _, player in Players:GetPlayers() do
		local rate = totalRate(player)
		if rate > bestRate then
			best, bestRate = player, rate
		end
	end

	return best, bestRate
end

--------------------------------------------------------------------------------
-- Panneau
--------------------------------------------------------------------------------

local function createFace(part, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.PixelsPerStud = 60
	gui.Parent = part

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.29, 0)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.Parent = gui

	-- Panneau partage par tous les joueurs : le serveur pose la cle, chaque client
	-- l'ecrit dans sa langue (voir Locale).
	Locale.Mark(title, "cookie_champion_title")
	TextFx.Mark(title, 0.3, Color3.fromRGB(235, 235, 235))

	-- Le nom d'un joueur ne se traduit pas : ce label garde son texte brut, et
	-- c'est un label distinct qui porte le message "personne pour l'instant".
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.45, 0)
	name.Position = UDim2.new(0, 0, 0.29, 0)
	name.BackgroundTransparency = 1
	name.FontFace = Fonts.Main
	name.TextScaled = true
	name.Text = ""
	name.Visible = false
	name.Parent = gui

	local rate = Instance.new("TextLabel")
	rate.Size = UDim2.new(1, 0, 0.24, 0)
	rate.Position = UDim2.new(0, 0, 0.75, 0)
	rate.BackgroundTransparency = 1
	rate.FontFace = Fonts.Main
	rate.TextScaled = true
	rate.Text = ""
	rate.Visible = false
	rate.Parent = gui

	local none = Instance.new("TextLabel")
	none.Size = UDim2.new(1, 0, 0.58, 0)
	none.Position = UDim2.new(0, 0, 0.32, 0)
	none.BackgroundTransparency = 1
	none.FontFace = Fonts.Main
	none.TextScaled = true
	none.Parent = gui

	Locale.Mark(none, "cookie_champion_none")
	TextFx.Mark(none, 0, COLOR_IDLE)

	return { name = name, rate = rate, none = none }
end

local function createSign(cookie)
	local part = Instance.new("Part")
	part.Name = "ClickChampionSign"
	part.Size = Vector3.new(19, 7.5, 0.2)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1 -- seul le texte se voit, pas la plaque
	part.CastShadow = false

	-- Le CFrame est pose AVANT le parent : le client le lit tel quel a la
	-- replication, et Spin s'en sert comme base de rotation.
	part.CFrame = cookie.CFrame * CFrame.new(0, cookie.Size.Y / 2 + 5.5, 0)
	part.Parent = cookie

	local faces = {
		createFace(part, Enum.NormalId.Front),
		createFace(part, Enum.NormalId.Back),
	}

	-- Le client fait tourner cette Part avec le meme angle que le cookie.
	CollectionService:AddTag(part, Config.SPIN_TAG)

	return { part = part, faces = faces }
end

local function fillSign(sign, championName, rate)
	local heat = math.clamp(rate / HEAT_SATURATION_RATE, 0, 1)
	local color = COLOR_CALM:Lerp(COLOR_HOT, heat)

	for _, face in sign.faces do
		face.none.Visible = championName == nil
		face.name.Visible = championName ~= nil
		face.rate.Visible = championName ~= nil

		if championName then
			face.name.Text = championName
			TextFx.Mark(face.name, 0.35 + heat * 0.65, color)

			-- Le debit est un nombre, pas une duree : une decimale suffit et evite
			-- un "3.3333333333" a l'ecran.
			Locale.Mark(face.rate, "cookie_champion_rate", { rate = string.format("%.1f", rate) })
			TextFx.Mark(face.rate, heat * 0.5, color)
		end
	end
end

local function setupCookie(cookie)
	if not cookie:IsA("BasePart") or signs[cookie] then
		return
	end

	local sign = createSign(cookie)
	signs[cookie] = sign
	fillSign(sign, nil, 0)
end

function ClickChampion.Start()
	for _, cookie in CollectionService:GetTagged(Config.CLICKER_TAG) do
		setupCookie(cookie)
	end

	CollectionService:GetInstanceAddedSignal(Config.CLICKER_TAG):Connect(setupCookie)

	CollectionService:GetInstanceRemovedSignal(Config.CLICKER_TAG):Connect(function(cookie)
		local sign = signs[cookie]
		if sign then
			sign.part:Destroy()
			signs[cookie] = nil
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		clickLog[player] = nil
	end)

	task.spawn(function()
		-- Le nom affiche au tour precedent : la fanfare ne sonne qu'au changement
		-- de titulaire, pas a chaque rafraichissement du panneau.
		local lastChampionName = nil

		while true do
			task.wait(Config.CHAMPION_REFRESH_INTERVAL)

			local champion, rate = findChampion()
			local championName = champion and champion.Name or nil
			local changed = championName ~= nil and championName ~= lastChampionName

			-- On ne retient QUE les titulaires reels, jamais le "personne" qui suit
			-- une accalmie : sinon huit secondes sans cliquer effacent le titre, et
			-- le clic suivant sonne la fanfare pour un joueur qui n'a jamais perdu
			-- sa place -- soit un bip metallique a chaque reprise de clic.
			if championName then
				lastChampionName = championName
			end

			for cookie, sign in signs do
				if cookie.Parent then
					fillSign(sign, championName, rate)

					if changed then
						Sounds.PlayAt("champion_change", cookie)
					end
				else
					signs[cookie] = nil
				end
			end
		end
	end)
end

return ClickChampion
