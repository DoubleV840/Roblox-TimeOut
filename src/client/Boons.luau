-- Les effets a duree de vie, cote joueur : le bandeau qui les liste, et le seul
-- d'entre eux qui demande vraiment quelque chose au client.
--
-- POURQUOI UN BANDEAU. Un effet de quinze minutes qui ne s'affiche nulle part
-- est un effet que le joueur ne sait pas qu'il a. La "Pluie d'orbes" se voit
-- (les orbes reviennent aussitot), le "Pacte" se voit (le chrono degringole) --
-- mais les "Pieds legers" ne se remarquent qu'en courant, et un joueur qui ne
-- sait pas qu'il a quinze minutes de bonus ne s'en sert pas.
--
-- Le compte a rebours descend ICI, image par image, comme le chrono et la jauge
-- de carburant : le serveur ne parle qu'aux changements.
--
-- LA PORTEE DE CLIC, cas particulier. La carte "Pieds legers" double la portee
-- du cookie, et c'est la SEULE chose de tout le jeu qui ne peut pas se decider
-- cote serveur : un ClickDetector est partage par tous les joueurs, et sa
-- MaxActivationDistance ne peut pas valoir 16 pour l'un et 32 pour son voisin.
-- Mais c'est le CLIENT qui decide s'il est assez pres pour cliquer, et une
-- propriete changee chez lui ne remonte jamais au serveur : la doubler
-- localement donne exactement l'effet voulu, et seulement a lui.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local TextFx = require(ReplicatedStorage.Shared.TextFx)
local Locale = require(ReplicatedStorage.Shared.Locale)

local Boons = {}

local ROW_HEIGHT = 24
local ROW_GAP = 4
local WIDTH = 220

-- Une couleur par effet : on les distingue du coin de l'oeil, sans lire.
local COLORS = {
	[Config.BOON_ORB_RAIN] = Color3.fromRGB(120, 220, 255),
	[Config.BOON_LIGHT_FEET] = Color3.fromRGB(150, 230, 150),
	[Config.BOON_PACT] = Color3.fromRGB(255, 90, 70),
	[Config.BOON_FRENZY] = Color3.fromRGB(255, 150, 60),
}

local frame = nil
local rows = {}

-- [nom de l'effet] = instant (os.clock) de fin.
local active = {}

--------------------------------------------------------------------------------
-- La portee du cookie
--------------------------------------------------------------------------------

local function applyReach()
	local factor = active[Config.BOON_LIGHT_FEET] and Config.BOON_LIGHT_FEET_REACH or 1

	for _, part in CollectionService:GetTagged(Config.CLICKER_TAG) do
		local detector = part:FindFirstChildOfClass("ClickDetector")
		if detector then
			detector.MaxActivationDistance = Config.CLICKER_MAX_DISTANCE * factor
		end
	end
end

--------------------------------------------------------------------------------
-- Le bandeau
--------------------------------------------------------------------------------

local function newRow(index)
	local label = Instance.new("TextLabel")
	label.Name = "Boon" .. index
	label.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	label.Position = UDim2.new(0, 0, 0, (index - 1) * (ROW_HEIGHT + ROW_GAP))
	label.BackgroundTransparency = 1
	label.FontFace = Fonts.Main
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = frame

	return label
end

local function render()
	-- Trie par nom : sans ca, deux effets simultanes s'echangeraient de ligne a
	-- chaque image, et le bandeau clignoterait.
	local names = {}
	for name in active do
		table.insert(names, name)
	end
	table.sort(names)

	local now = os.clock()

	for index, name in names do
		local row = rows[index] or newRow(index)
		rows[index] = row

		local remaining = math.max(0, active[name] - now)

		row.Visible = true
		row.Text = Locale.Text("boon_" .. name, { seconds = math.ceil(remaining) })
		TextFx.Mark(row, remaining < 15 and 0.8 or 0.25, COLORS[name] or Color3.new(1, 1, 1))
	end

	for index = #names + 1, #rows do
		rows[index].Visible = false
	end

	frame.Size = UDim2.new(0, WIDTH, 0, math.max(1, #names) * (ROW_HEIGHT + ROW_GAP))
	frame.Visible = #names > 0
end

--------------------------------------------------------------------------------

function Boons.Start(screenGui)
	frame = Instance.new("Frame")
	frame.Name = "BoonHud"
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 16, 1, -110)
	frame.Size = UDim2.new(0, WIDTH, 0, ROW_HEIGHT)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = screenGui

	Remotes.BoonUpdated.OnClientEvent:Connect(function(list)
		local now = os.clock()

		-- Le serveur envoie l'etat COMPLET a chaque changement : on repart de sa
		-- liste plutot que de tenir un journal des debuts et des fins, qu'une
		-- seule perte de message suffirait a desynchroniser.
		table.clear(active)

		for _, boon in list do
			active[boon.name] = now + boon.seconds
		end

		applyReach()
		render()
	end)

	-- Le cookie peut arriver apres l'effet (chargement progressif de la map) :
	-- on repose la portee sur chaque nouveau cookie tague.
	CollectionService:GetInstanceAddedSignal(Config.CLICKER_TAG):Connect(function()
		task.defer(applyReach)
	end)

	-- Le compte a rebours descend ici. C'est aussi lui qui retire une ligne quand
	-- l'effet expire : le serveur le dira aussi, mais une seconde plus tard, et
	-- un compteur qui s'attarde a zero se remarque.
	task.spawn(function()
		while true do
			task.wait(0.25)

			if next(active) then
				local now = os.clock()
				local expired = false

				for name, endsAt in active do
					if endsAt <= now then
						active[name] = nil
						expired = true
					end
				end

				if expired then
					applyReach()
				end

				render()
			end
		end
	end)
end

return Boons
