--!strict
-- AudioController.luau
-- Controller Client yang mengelola efek suara lokal (Jumpscare, efek UI, dan atmosfer horor).

local SoundService = game:GetService("SoundService")

local AudioController = {}

function AudioController.Init()
	-- Siap diperluas untuk ambient sound malam hari atau efek audio tambahan
end

function AudioController.PlayJumpscareSound(durationSec: number)
	local snd = Instance.new("Sound")
	snd.Name = "JumpscareSound"
	snd.SoundId = "rbxassetid://9114221580"
	snd.Volume = 1.0
	snd.PlaybackSpeed = 0.65
	snd.Parent = SoundService
	snd:Play()

	task.delay(durationSec, function()
		if snd and snd.Parent then
			snd:Destroy()
		end
	end)
end

return AudioController
