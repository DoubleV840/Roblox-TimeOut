-- Auto-cliqueur : source de temps passive, achetee en Robux au guichet "AutoClick"
-- (voir Shop.luau) et persistante (data.AutoClickers = nombre d'achats).
--
-- Il est volontairement INDEPENDANT du clic a la main : ni Config.CLICKER_REWARD
-- ni le Chrono Boost (ClickPower) n'entrent dans son debit. Les deux progressions
-- avancent chacune de leur cote, et ameliorer l'une n'inflate pas l'autre.
--
-- Chaque achat double le debit : niveau 1 -> AUTOCLICK_BASE_RATE, 2 -> x2, 3 -> x4...

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local TimeService = require(script.Parent.TimeService)

local AutoClicker = {}

-- Secondes gagnees par seconde a ce niveau (0 avant le premier achat).
-- Le client s'en sert aussi pour afficher le palier suivant, d'ou le calcul a
-- partir d'un niveau et non des donnees du joueur.
function AutoClicker.RateAt(level)
	if level <= 0 then
		return 0
	end

	return Config.AUTOCLICK_BASE_RATE * Config.AUTOCLICK_GROWTH ^ (level - 1)
end

function AutoClicker.Start()
	-- Joueurs a qui on a deja annonce leur niveau. Le client en a besoin des son
	-- arrivee pour regler le bourdonnement de l'auto-cliqueur (hauteur et volume
	-- suivent le nombre d'achats), sans quoi il resterait muet jusqu'au premier
	-- passage au guichet. L'annonce ne peut pas partir de PlayerAdded : a cet
	-- instant le LocalScript du joueur n'a pas encore branche ses Remotes, et le
	-- message se perdrait. On la fait donc au premier tour de boucle, une
	-- seconde plus tard -- le client est alors debout depuis longtemps.
	local announced = {}

	Players.PlayerRemoving:Connect(function(player)
		announced[player] = nil
	end)

	task.spawn(function()
		while true do
			-- On credite le delai reellement ecoule, comme la boucle principale :
			-- un tick en retard ne doit ni voler ni offrir de temps.
			local elapsed = task.wait(Config.AUTOCLICK_INTERVAL)

			for _, player in Players:GetPlayers() do
				-- Un joueur devant l'ecran de mort ne gagne rien : son temps est
				-- gele jusqu'a ce qu'il relance une partie.
				if not TimeService.IsWaitingForRestart(player) then
					local data = PlayerData.Get(player)
					local rate = data and AutoClicker.RateAt(data.AutoClickers) or 0

					if rate > 0 then
						if not announced[player] then
							announced[player] = true
							Remotes.AutoClickUpdated:FireClient(player, data.AutoClickers)
						end

						data.TimeLeft += rate * elapsed
						PlayerData.NoteTime(data)
						Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
					end
				end
			end
		end
	end)
end

return AutoClicker
