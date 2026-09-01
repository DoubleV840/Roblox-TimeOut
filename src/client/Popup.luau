-- Les trois gestes communs a toutes les fenetres du jeu : l'ouverture qui
-- rebondit, la fermeture qui ne sonne que si quelque chose etait ouvert, et le
-- branchement des sons de bouton.
--
-- Extrait de init.client pour que les modules clients (paliers, et la suite du
-- plan 2) ouvrent leurs fenetres exactement comme les popups d'origine, au lieu
-- de reinventer chacun leur animation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Popup = {}

-- Petite animation "pop" (rebond) utilisee a l'ouverture des popups.
function Popup.In(frame, targetSize)
	frame.Size = UDim2.new(
		targetSize.X.Scale * 0.7,
		targetSize.X.Offset * 0.7,
		targetSize.Y.Scale * 0.7,
		targetSize.Y.Offset * 0.7
	)
	frame.Visible = true
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = targetSize,
	}):Play()
	Sounds.Play("ui_popup_open")
end

-- Referme une popup en la faisant sonner -- mais seulement si elle etait
-- ouverte : les fermetures se font aussi en cascade (mort, sortie de zone) sur
-- des popups deja invisibles, et ca ne doit rien declencher.
function Popup.Out(frame)
	if not frame.Visible then
		return
	end

	frame.Visible = false
	Sounds.Play("ui_popup_close")
end

-- Tout bouton du jeu reagit au survol et au clic. Une seule fonction, appelee a
-- la creation : impossible d'oublier un bouton en route.
function Popup.BindButtonSounds(button)
	button.MouseEnter:Connect(function()
		Sounds.Play("ui_hover")
	end)

	button.MouseButton1Down:Connect(function()
		Sounds.Play("ui_click")
	end)
end

return Popup
