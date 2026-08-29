-- Guichet : entrer dans une Part taguee Config.SHOP_TAG ouvre une popup d'achat en
-- Robux. Le client demande un achat, le serveur declenche le prompt Roblox, et
-- c'est ProcessReceipt qui credite.
--
-- Deux sortes de guichet, choisies par l'attribut Config.SHOP_KIND_ATTRIBUTE sur
-- la Part ("Time" par defaut) :
--   "Time"      -> paquets de secondes (Config.TIME_PRODUCTS)
--   "AutoClick" -> auto-cliqueur (Config.AUTOCLICK_PRODUCT, un seul produit
--                  rachetable a l'infini : chaque achat double le debit)
--
-- Deux regles non negociables pour l'argent reel :
--
-- 1. ProcessReceipt ne doit etre assigne QU'UNE FOIS dans tout le jeu. Un second
--    assignement ecrase le premier et les achats de l'autre systeme se perdent.
--
-- 2. Il ne renvoie PurchaseGranted que si le temps a reellement ete pose sur le
--    compte. Sinon NotProcessedYet : Roblox rappellera plus tard (jusqu'a la
--    prochaine session du joueur s'il le faut) plutot que d'encaisser dans le vide.
--
-- L'anti double-credit repose sur receiptInfo.PurchaseId, unique par achat : le
-- receipt est reserve dans un DataStore avant le credit, puis marque honore apres.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Colors = require(ReplicatedStorage.Shared.Colors)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)
local ZoneAura = require(ReplicatedStorage.Shared.ZoneAura)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local PlayerData = require(script.Parent.PlayerData)
local TimeService = require(script.Parent.TimeService)
local AutoClicker = require(script.Parent.AutoClicker)

local Shop = {}

local purchaseStore = DataStoreService:GetDataStore(Config.PURCHASE_DATASTORE_NAME)

-- Un produit dont le productId vaut 0 n'a pas encore d'equivalent dans le Creator
-- Dashboard : on l'ignore partout plutot que de proposer un achat impossible.
--
-- L'auto-cliqueur est un produit UNIQUE, rachetable a l'infini : chaque achat
-- monte le joueur d'un niveau, donc il n'y a rien a distinguer d'un achat a
-- l'autre -- c'est le PurchaseId qui garantit qu'aucun n'est compte deux fois.
local productsById = {}

for _, product in Config.TIME_PRODUCTS do
	if product.productId ~= 0 then
		productsById[product.productId] = { kind = Config.SHOP_KIND_TIME, seconds = product.seconds }
	end
end

if Config.AUTOCLICK_PRODUCT.productId ~= 0 then
	productsById[Config.AUTOCLICK_PRODUCT.productId] = { kind = Config.SHOP_KIND_AUTOCLICK }
end

-- Filet de securite en memoire : si UpdateAsync a credite puis a echoue en
-- ecrivant, Roblox reessaiera le meme PurchaseId. Sans cette trace on redonnerait
-- le temps une seconde fois dans la meme session.
local grantedThisSession = {}

local zoneStates = {}

--------------------------------------------------------------------------------
-- Encaissement
--------------------------------------------------------------------------------

-- Pose l'achat sur le compte du joueur et le lui annonce. Renvoie false si rien
-- n'a pu etre credite -- l'appelant transforme ca en NotProcessedYet, pour que
-- Roblox reessaie plutot que d'encaisser dans le vide.
local function grant(player, product)
	if product.kind == Config.SHOP_KIND_AUTOCLICK then
		local data = PlayerData.Get(player)
		if not data then
			return false
		end

		-- Un achat = un niveau. Le +1 est sur : la reservation par PurchaseId
		-- garantit qu'un meme receipt ne repasse jamais ici.
		data.AutoClickers += 1

		Remotes.AutoClickUpdated:FireClient(player, data.AutoClickers)
		Remotes.Notify:FireClient(player, "notify_autoclick_granted", {
			level = data.AutoClickers,
			rate = AutoClicker.RateAt(data.AutoClickers),
		}, Colors.WIN)

		return true
	end

	if not TimeService.GrantTime(player, product.seconds) then
		return false
	end

	Remotes.Notify:FireClient(
		player,
		"notify_shop_granted",
		{ amount = product.seconds },
		Colors.WIN
	)

	return true
end

local function processReceipt(receiptInfo)
	local product = productsById[receiptInfo.ProductId]
	if not product then
		-- Produit inconnu de cette version du jeu (paquet retire de Config, ou
		-- serveur pas encore a jour). On ne sait pas quoi crediter : on laisse
		-- Roblox reessayer plus tard plutot que de garder les Robux.
		warn("TimeOut: achat d'un produit inconnu -> " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not PlayerData.Get(player) then
		-- Joueur parti (ou donnees pas encore chargees) : rien a crediter ici.
		-- Roblox rappellera a sa prochaine connexion.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if grantedThisSession[receiptInfo.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = "Receipt_" .. receiptInfo.PurchaseId
	local needsGrant = false

	-- Etape 1 : reserver le receipt. Le transform d'UpdateAsync ne doit PAS yield
	-- (pas de DataStore, pas de LoadCharacter dedans), donc il se contente de lire
	-- et d'ecrire la trace ; le credit vient apres.
	--
	-- La trace passe par deux etats : reservee (granted = false) puis honoree
	-- (granted = true). Si le serveur tombe entre les deux, la reprise voit une
	-- reservation incomplete et credite -- au lieu de considerer a tort que le
	-- joueur a deja recu son temps.
	local reserveOk, reserveErr = pcall(function()
		purchaseStore:UpdateAsync(key, function(existing)
			if existing and existing.granted then
				return existing
			end

			needsGrant = true
			return { granted = false, at = os.time() }
		end)
	end)

	if not reserveOk then
		warn("TimeOut: echec de reservation d'achat pour " .. player.Name .. " -> " .. tostring(reserveErr))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not needsGrant then
		-- Deja honore lors d'une session precedente.
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if not grant(player, product) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	grantedThisSession[receiptInfo.PurchaseId] = true

	-- Sauvegarde immediate : attendre l'autosave exposerait le joueur a perdre du
	-- temps qu'il vient de payer si le serveur tombe entre-temps.
	PlayerData.Save(player)

	-- Etape 2 : marquer le receipt honore. Si cette ecriture echoue, la trace
	-- reste "reservee" et un rappel de Roblox dans une AUTRE session rendrait le
	-- temps une seconde fois. C'est le seul deraillement possible, il est rare et
	-- il penche du cote du joueur -- l'inverse (encaisser sans rien donner) serait
	-- bien pire.
	local markOk, markErr = pcall(function()
		purchaseStore:SetAsync(key, { granted = true, at = os.time() })
	end)

	if not markOk then
		warn("TimeOut: achat credite mais non marque pour " .. player.Name .. " -> " .. tostring(markErr))
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------------------
-- Guichet
--------------------------------------------------------------------------------

local function getKind(zone)
	return zone:GetAttribute(Config.SHOP_KIND_ATTRIBUTE) or Config.SHOP_KIND_TIME
end

-- Un guichet doit se voir de loin, sinon personne n'y va : meme aura neon que les
-- zones de pari, plus un panneau flottant dont le texte ondule (TextFx). Chaque
-- sorte a sa couleur, pour qu'on distingue les deux comptoirs d'un coup d'oeil.
local SIGN_STYLE = {
	[Config.SHOP_KIND_TIME] = {
		color = Color3.fromRGB(90, 210, 255), -- cyan : le guichet a temps
		titleKey = "shop_title",
		subtitleKey = "shop_sign_time",
		hum = "shop_hum_time",
	},
	[Config.SHOP_KIND_AUTOCLICK] = {
		color = Color3.fromRGB(255, 130, 215), -- magenta : les auto-cliqueurs
		titleKey = "shop_auto_title",
		subtitleKey = "shop_sign_auto",
		hum = "shop_hum_auto",
	},
}

local function createSign(zone)
	local style = SIGN_STYLE[getKind(zone)] or SIGN_STYLE[Config.SHOP_KIND_TIME]

	ZoneAura.Create(zone, style.color, 0.85)

	-- Chaque comptoir a son bourdonnement : on distingue les deux guichets a
	-- l'oreille avant meme de lire le panneau.
	Sounds.Loop(style.hum, zone)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShopSign"
	billboard.Size = UDim2.new(17, 0, 6.6, 0) -- en studs : taille fixe dans le monde
	billboard.StudsOffset = Vector3.new(0, 6.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.66, 0)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Main
	title.TextScaled = true
	title.Parent = billboard

	-- Panneau partage par tous les joueurs : le serveur pose la cle, chaque client
	-- l'ecrit dans sa langue (voir Locale).
	Locale.Mark(title, style.titleKey)
	TextFx.Mark(title, 0.85, style.color)

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0.34, 0)
	subtitle.Position = UDim2.new(0, 0, 0.66, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.FontFace = Fonts.Main
	subtitle.TextScaled = true
	subtitle.Parent = billboard

	Locale.Mark(subtitle, style.subtitleKey)
	TextFx.Mark(subtitle, 0.45, Color3.fromRGB(255, 221, 0))
end

-- Le catalogue vit dans Config, que le client a deja : le serveur n'envoie que ce
-- que le client ne peut pas savoir, c'est-a-dire combien d'auto-cliqueurs le
-- joueur possede. Le client en deduit seul le palier a proposer, et le met a jour
-- tout seul sur AutoClickUpdated quand un achat aboutit.
local function sendPrompt(player, zone)
	local kind = getKind(zone)

	if kind ~= Config.SHOP_KIND_AUTOCLICK then
		Remotes.ShopPrompt:FireClient(player, zone, Config.SHOP_KIND_TIME)
		return
	end

	local data = PlayerData.Get(player)
	if not data then
		return
	end

	Remotes.ShopPrompt:FireClient(player, zone, Config.SHOP_KIND_AUTOCLICK, data.AutoClickers)
end

local function setupZone(zone)
	if not zone:IsA("BasePart") or zoneStates[zone] then
		return
	end

	local state = { playersInside = {}, touchCounts = {} }
	zoneStates[zone] = state

	createSign(zone)

	zone.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		state.touchCounts[player] = (state.touchCounts[player] or 0) + 1
		if state.touchCounts[player] == 1 then
			state.playersInside[player] = true
			sendPrompt(player, zone)
		end
	end)

	zone.TouchEnded:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		state.touchCounts[player] = math.max(0, (state.touchCounts[player] or 1) - 1)
		if state.touchCounts[player] == 0 then
			state.playersInside[player] = nil
			Remotes.ShopPromptHide:FireClient(player, zone)
		end
	end)
end

function Shop.Start()
	MarketplaceService.ProcessReceipt = processReceipt

	for _, zone in CollectionService:GetTagged(Config.SHOP_TAG) do
		setupZone(zone)
	end

	CollectionService:GetInstanceAddedSignal(Config.SHOP_TAG):Connect(setupZone)

	-- Le client envoie un productId : on ne fait confiance qu'a ce qui figure
	-- dans Config, sinon n'importe quel produit du site pourrait etre propose.
	Remotes.ShopBuy.OnServerEvent:Connect(function(player, productId)
		if typeof(productId) ~= "number" then
			return
		end

		if not productsById[productId] then
			return
		end

		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)

		if not ok then
			warn("TimeOut: echec d'ouverture du prompt d'achat -> " .. tostring(err))
			Remotes.Notify:FireClient(player, "notify_shop_failed", nil, Colors.LOSE)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, state in zoneStates do
			state.playersInside[player] = nil
			state.touchCounts[player] = nil
		end
	end)
end

return Shop
