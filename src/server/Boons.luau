-- Les effets a DUREE de vie : pluie d'orbes, pieds legers, pacte du Terminus,
-- frenesie. Un seul registre pour les quatre, parce qu'ils posent tous la meme
-- question a quatre endroits differents du jeu -- "est-ce que c'est encore actif
-- pour ce joueur ?" -- et qu'ecrire quatre fois la reponse est le meilleur moyen
-- d'en oublier une a l'expiration.
--
-- POURQUOI RIEN N'EST SAUVEGARDE. Ces effets se comptent en minutes ; les porter
-- d'une session a l'autre demanderait de dater chacun en temps absolu, de gerer
-- l'horloge qui recule, et de decider ce que devient un pacte de 10 minutes chez
-- un joueur parti trois jours. Pour un gain nul : un effet de 15 minutes n'a
-- aucune raison de survivre a une deconnexion. Ils vivent donc en memoire, et
-- meurent avec la session.
--
-- Le module ne connait AUCUN des effets qu'il porte : il ne fait que dater des
-- noms. C'est TimeOrb qui sait ce que vaut une pluie d'orbes, TimeService ce que
-- fait un pacte -- chacun demande ici s'il doit l'appliquer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Boons = {}

-- active[player][name] = instant (os.clock) ou l'effet s'arrete.
local active = {}

-- Ce que le HUD du client affiche. On ne le previent qu'aux CHANGEMENTS (un
-- effet qui commence, un qui finit), pas a chaque tour de boucle : le compte a
-- rebours descend chez lui, image par image, comme celui du carburant.
local function publish(player)
	local list = {}
	local now = os.clock()

	for name, expiresAt in active[player] or {} do
		if expiresAt > now then
			table.insert(list, { name = name, seconds = expiresAt - now })
		end
	end

	Remotes.BoonUpdated:FireClient(player, list)
end

-- Un effet redonne alors qu'il court encore PROLONGE, il ne se cumule pas : deux
-- pluies d'orbes coup sur coup donnent 120 s de pluie, pas une pluie x6. Les
-- effets de ce jeu sont des fenetres de temps, jamais des empilements.
function Boons.Grant(player, name, seconds)
	local list = active[player]
	if not list then
		list = {}
		active[player] = list
	end

	local now = os.clock()
	local from = math.max(now, list[name] or 0)

	list[name] = from + seconds
	publish(player)

	return list[name] - now
end

function Boons.Active(player, name)
	local list = active[player]
	if not list then
		return false
	end

	local expiresAt = list[name]
	if not expiresAt then
		return false
	end

	if expiresAt <= os.clock() then
		list[name] = nil
		return false
	end

	return true
end

-- Ce qu'il reste, en secondes -- 0 si l'effet n'est pas actif. Sert aux fenetres
-- qui montrent un compte a rebours (la frenesie) plutot qu'un simple oui/non.
function Boons.Remaining(player, name)
	if not Boons.Active(player, name) then
		return 0
	end

	return active[player][name] - os.clock()
end

function Boons.Clear(player, name)
	local list = active[player]
	if list and list[name] then
		list[name] = nil
		publish(player)
	end
end

--------------------------------------------------------------------------------
-- Pieds legers
--------------------------------------------------------------------------------
-- Le seul effet qui touche au personnage plutot qu'a un calcul : il faut donc le
-- poser sur le Humanoid, et le reposer a chaque reapparition tant qu'il court.

local function applySpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if Boons.Active(player, Config.BOON_LIGHT_FEET) then
		humanoid.WalkSpeed = Config.WALK_SPEED * Config.BOON_LIGHT_FEET_SPEED
	else
		humanoid.WalkSpeed = Config.WALK_SPEED
	end
end

Boons.ApplySpeed = applySpeed

function Boons.Start()
	local function watch(player)
		player.CharacterAdded:Connect(function()
			-- Le Humanoid arrive avec le personnage, mais Roblox ecrit sa
			-- WalkSpeed par defaut juste apres : on laisse passer une image.
			task.defer(applySpeed, player)
		end)
	end

	Players.PlayerAdded:Connect(watch)

	for _, player in Players:GetPlayers() do
		watch(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
	end)

	-- Un seul balayage pour tout le monde : il ne sert qu'a PREVENIR le client
	-- qu'un effet vient de finir (et a rendre sa vitesse au joueur). Les effets,
	-- eux, expirent tout seuls -- Boons.Active compare les dates, il n'a besoin
	-- de personne pour se mettre a jour.
	task.spawn(function()
		while true do
			task.wait(1)

			local now = os.clock()

			for player, list in active do
				local expired = false

				for name, expiresAt in list do
					if expiresAt <= now then
						list[name] = nil
						expired = true

						if name == Config.BOON_LIGHT_FEET then
							applySpeed(player)
						end
					end
				end

				if expired and player.Parent then
					publish(player)
				end
			end
		end
	end)
end

return Boons
