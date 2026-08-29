local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Colors = require(ReplicatedStorage.Shared.Colors)
local PlayerData = require(script.Parent.PlayerData)
local Leaderstats = require(script.Parent.Leaderstats)
local Leaderboard = require(script.Parent.Leaderboard)
local TimeBalance = require(script.Parent.TimeBalance)
local BettingGame = require(script.Parent.BettingGame)

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
	Remotes.ClickPowerUpdated:FireClient(player, data.ClickPower)
end

local function onPlayerRemoving(player)
	local data = PlayerData.Get(player)
	if data then
		TimeBalance.Submit(player, data.TimeLeft)
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
	TimeBalance.Submit(player, data.TimeLeft)

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
						data.TimeLeft -= elapsed

						if data.TimeLeft <= 0 then
							data.TimeLeft = 0

							-- Un pari engage sursoit a la mort : le joueur reste a 0
							-- jusqu'au tirage, qui peut encore le renflouer.
							if BettingGame.HasPendingBet(player) then
								if not inBetGrace[player] then
									inBetGrace[player] = true
									Remotes.Notify:FireClient(player, "notify_bet_grace", nil, Colors.INFO)
								end

								Remotes.TimeUpdated:FireClient(player, 0)
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
					TimeBalance.Submit(player, data.TimeLeft)
				end
			end
		end
	end)
end

return TimeService
