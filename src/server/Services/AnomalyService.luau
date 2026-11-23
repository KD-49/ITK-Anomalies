--!strict
-- AnomalyService.luau
-- Service Server yang mengendalikan logika anomali, status mati lampu (Blackout),
-- dan konsekuensi saat pengunjung anomali lolos masuk melewati gerbang kampus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VisitorGenerator = require(Shared:WaitForChild("Utilities"):WaitForChild("VisitorGenerator"))

local EnvironmentService = require(script.Parent:WaitForChild("EnvironmentService"))
local SanityService = require(script.Parent:WaitForChild("SanityService"))

local AnomalyService = {}

local isBlackout = false
local blackoutVisitorTarget = 2

function AnomalyService.IsBlackout(): boolean
	return isBlackout
end

function AnomalyService.ResetForShift()
	isBlackout = false
	blackoutVisitorTarget = math.random(2, 3)
	SanityService.StopBlackoutDrain()
	EnvironmentService.SetBlackout(false)
end

function AnomalyService.ShouldTriggerBlackout(processedVisitorsCount: number): boolean
	return (processedVisitorsCount == blackoutVisitorTarget) and (not isBlackout)
end

function AnomalyService.TriggerBlackout(
	isShiftActiveCallback: () -> boolean,
	onStateChangedCallback: () -> (),
	onSanityDepletedCallback: () -> ()
)
	if isBlackout or not isShiftActiveCallback() then
		return
	end

	isBlackout = true
	EnvironmentService.SetBlackout(true)
	onStateChangedCallback()

	SanityService.StartBlackoutDrain(
		function()
			return isBlackout and isShiftActiveCallback()
		end,
		onStateChangedCallback,
		onSanityDepletedCallback
	)
end

function AnomalyService.RestorePower(onStateChangedCallback: () -> ())
	if not isBlackout then
		return
	end

	isBlackout = false
	SanityService.StopBlackoutDrain()
	EnvironmentService.SetBlackout(false)
	SanityService.ApplyRepairBonus()
	onStateChangedCallback()
end

-- Mengeksekusi konsekuensi ketika pengunjung anomali diizinkan masuk oleh pemain.
-- Mengembalikan true apabila anomali tersebut langsung membunuh pemain (JumpscareKill).
function AnomalyService.HandleAcceptedAnomaly(
	profile: VisitorGenerator.VisitorProfile,
	npcModel: Model?,
	shiftNumber: number,
	onLethalJumpscareCallback: (gameOverPayload: any) -> ()
): boolean
	if not profile.isAnomaly then
		return false
	end

	if profile.consequenceIfAccepted == "JumpscareKill" then
		task.delay(1.8, function()
			if npcModel and npcModel.Parent then
				npcModel:Destroy()
			end
			local gameOverPayload = {
				shiftNumber = shiftNumber,
				killerName = profile.displayName,
				anomalyType = profile.anomalyType or "Anomali",
				explanation = profile.explanation,
			}
			onLethalJumpscareCallback(gameOverPayload)
		end)
		return true
	elseif profile.consequenceIfAccepted == "WeirdEvent" then
		-- Kejadian aneh: lampu Pos Satpam berkedip-kedip tanpa membocorkan notifikasi teks
		task.delay(2.2, function()
			EnvironmentService.TriggerWeirdFlicker()
		end)
		return false
	end

	return false
end

return AnomalyService
