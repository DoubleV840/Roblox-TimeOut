local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Colors = require(ReplicatedStorage.Shared.Colors)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local PlayerData = require(script.Parent.PlayerData)
local Leaderstats = require(script.Parent.Leaderstats)
local Leaderboard = require(script.Parent.Leaderboard)
local TimeBalance = require(script.Parent.TimeBalance)
local MiniGames = require(script.Parent.MiniGames)
local Boons = require(script.Parent.Boons)

local TimeService = {}

-- lifeStart[player] = moment (os.clock) ou la vie en cours a commence,
-- sert a calculer combien de temps reel le joueur a survecu pour le record.
local lifeStart = {}

-- waitingForRestart[player] = true quand le joueur est a 0 et attend de cliquer
-- sur "Recommencer" dans l'ecran de mort (son temps ne bouge plus pendant ce temps).
local waitingForRestart = {}

-- inBetGrace[player] = true quand le joueur est tombe a 0 mais qu'un pari en cours
-- le maintient en vie : on attend le tirage avant de le declarer mort.
local inBetGrace = {}

local function onPlayerAdded(player)
	local data = PlayerData.Load(player)
	lifeStart[player] = os.clock()
	Leaderstats.Setup(player)
	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	Remotes.ClickPowerUpdated:FireClient(player, data.ClickPower, data.ClickBase)
end

local function onPlayerRemoving(player)
	local data = PlayerData.Get(player)
	if data then
		TimeBalance.Submit(player, data.TimeLeft, data.Tier)
	end

	PlayerData.Release(player)
	Leaderstats.Remove(player)
	lifeStart[player] = nil
	waitingForRestart[player] = nil
	inBetGrace[player] = nil
end

-- Credite du temps venu d'ailleurs que la boucle de jeu (aujourd'hui : un achat
-- Robux). Renvoie true si le temps a bien ete pose sur le compte du joueur.
--
-- Cas particulier : le joueur peut etre a 0, devant l'ecran de mort. Le temps
-- achete doit alors le remettre en jeu directement -- lui demander de cliquer
-- "Recommencer" repartirait au temps de base et effacerait ce qu'il vient de payer.
-- Vrai quand le joueur est a 0 et attend de cliquer "Recommencer" : les sources
-- de temps passives (auto-cliqueurs) doivent se taire tant qu'il est mort.
function TimeService.IsWaitingForRestart(player)
	return waitingForRestart[player] == true
end

function TimeService.GrantTime(player, seconds)
	local data = PlayerData.Get(player)
	if not data or seconds <= 0 then
		return false
	end

	local wasDead = waitingForRestart[player] or false

	data.TimeLeft += seconds

	if wasDead then
		waitingForRestart[player] = nil
		inBetGrace[player] = nil
		lifeStart[player] = os.clock()
		Remotes.Revived:FireClient(player)
		player:LoadCharacter()
	end

	PlayerData.NoteTime(data)
	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	Leaderstats.Refresh(player)
	TimeBalance.Submit(player, data.TimeLeft, data.Tier)

	return true
end

--------------------------------------------------------------------------------
-- Second souffle
--------------------------------------------------------------------------------

-- La carte Epique "Second souffle" (lot 3) : la prochaine mort ne renvoie pas au
-- Quai et rend une part du prix d'entree du palier.
--
-- Elle ne fait pas que rendre du temps -- elle empeche la mort d'avoir lieu. Le
-- joueur n'est jamais declare mort, donc il ne reapparait pas en bas et son
-- personnage ne bouge pas : c'est exactement ce que la carte promet, et c'est
-- pour ca qu'elle est traitee ici plutot que dans l'ecran de mort.
--
-- Le plancher a Config.BASE_TIME est delibere : au palier 2, la moitie du prix
-- d'entree vaut 2 min 30, soit MOINS qu'un redemarrage normal. Une carte Epique
-- qui laisse le joueur plus pauvre que la mort ordinaire serait un piege.
local SECOND_WIND_SHARE = 0.5

local function useSecondWind(player, data)
	if not data.SecondWind then
		return false
	end

	data.SecondWind = false
	data.TimeLeft = math.max(Config.BASE_TIME, math.floor(Tiers.Cost(data.Tier) * SECOND_WIND_SHARE))

	PlayerData.NoteTime(data)
	Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
	Remotes.Notify:FireClient(player, "notify_second_wind", { amount = data.TimeLeft }, Colors.WIN)
	PlayerData.Save(player)

	return true
end

function TimeService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	game:BindToClose(function()
		PlayerData.SaveAll()
	end)

	Remotes.RequestRestart.OnServerEvent:Connect(function(player)
		if not waitingForRestart[player] then
			return
		end

		local data = PlayerData.Get(player)
		if not data then
			return
		end

		data.TimeLeft = Config.BASE_TIME
		lifeStart[player] = os.clock()
		waitingForRestart[player] = nil
		inBetGrace[player] = nil

		Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
		Leaderstats.Refresh(player)
		player:LoadCharacter()
	end)

	-- boucle principale : decremente le temps de chaque joueur connecte.
	-- On retire le temps reellement ecoule (task.wait renvoie le delai effectif),
	-- pour que le chrono reste juste a la milliseconde pres.
	task.spawn(function()
		while true do
			local elapsed = task.wait(Config.TICK_RATE)

			for _, player in Players:GetPlayers() do
				if not waitingForRestart[player] then
					local data = PlayerData.Get(player)
					if data then
						-- Le drain vaut 1 s/s a TOUS les paliers : c'est une
						-- decision de fond du plan 2, un drain qui accelererait
						-- punirait le joueur d'avoir progresse. La seule chose
						-- qui le double est le "Pacte du Terminus", une carte
						-- que le joueur a CHOISIE en echange de beaucoup de
						-- temps -- et pour dix minutes seulement.
						local drain = elapsed

						if Boons.Active(player, Config.BOON_PACT) then
							drain *= Config.BOON_PACT_DRAIN
						end

						data.TimeLeft -= drain

						if data.TimeLeft <= 0 then
							data.TimeLeft = 0

							-- Une mise engagee sursoit a la mort : le joueur reste a 0
							-- jusqu'au resultat, qui peut encore le renflouer.
							if MiniGames.HasPendingStake(player) then
								if not inBetGrace[player] then
									inBetGrace[player] = true
									Remotes.Notify:FireClient(player, "notify_bet_grace", nil, Colors.INFO)
								end

								Remotes.TimeUpdated:FireClient(player, 0)
							elseif useSecondWind(player, data) then
								-- Rien d'autre a faire : le joueur n'est pas mort,
								-- il n'a donc ni record a enregistrer ni ecran a
								-- voir. Il continue sa vie la ou il etait.
								inBetGrace[player] = nil
							else
								local survived = os.clock() - lifeStart[player]
								if survived > data.BestSurvival then
									data.BestSurvival = survived
									Leaderboard.SubmitScore(player, data.BestSurvival)
								end

								inBetGrace[player] = nil
								waitingForRestart[player] = true
								Remotes.TimeUpdated:FireClient(player, 0)
								Remotes.PlayerTimedOut:FireClient(player)
							end
						else
							inBetGrace[player] = nil
							PlayerData.NoteTime(data)
							Remotes.TimeUpdated:FireClient(player, data.TimeLeft)
						end

						Leaderstats.Refresh(player)
					end
				end
			end
		end
	end)

	-- sauvegarde automatique periodique (au cas ou le serveur crash)
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			PlayerData.SaveAll()
		end
	end)

	-- synchronise le temps courant de chaque joueur pour le classement
	-- (pour que les joueurs deconnectes restent visibles, en pause)
	task.spawn(function()
		while true do
			task.wait(Config.TIME_BALANCE_SYNC_INTERVAL)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.Get(player)
				if data then
					TimeBalance.Submit(player, data.TimeLeft, data.Tier)
				end
			end
		end
	end)
end

return TimeService
