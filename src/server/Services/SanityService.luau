--!strict
-- SanityService.luau
-- Service Server yang mengelola kondisi mental (Sanity 0-100%) pemain:
-- 1. Sanity bersifat persisten antar shift (tidak reset penuh saat lanjut ke shift berikutnya).
-- 2. Sanity berkurang saat mengambil keputusan pemeriksaan atau saat berada dalam kegelapan (blackout).
-- 3. Sanity bertambah saat berhasil memperbaiki Gardu Listrik.
-- 4. Mendeteksi saat Sanity mencapai 0% untuk memicu Game Over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local SanityService = {}

local sanityValue: number = GameConfig.SANITY.INITIAL
local drainThread: thread? = nil

function SanityService.GetSanity(): number
	return sanityValue
end

function SanityService.ResetForShift(isNewGame: boolean)
	SanityService.StopBlackoutDrain()
	-- Sanity dipertahankan antar shift; hanya reset ke 100% di awal game baru atau saat retry setelah mati
	if isNewGame or sanityValue <= 0 then
		sanityValue = GameConfig.SANITY.INITIAL
	end
end

function SanityService.ApplyDecisionCost(): number
	sanityValue = math.clamp(sanityValue - GameConfig.SANITY.DECISION_COST, 0, GameConfig.SANITY.MAX)
	return sanityValue
end

function SanityService.ApplyRepairBonus(): number
	sanityValue = math.clamp(sanityValue + GameConfig.SANITY.REPAIR_BONUS, 0, GameConfig.SANITY.MAX)
	return sanityValue
end

function SanityService.StopBlackoutDrain()
	if drainThread then
		task.cancel(drainThread)
		drainThread = nil
	end
end

function SanityService.StartBlackoutDrain(
	isDrainActiveCallback: () -> boolean,
	onSanityTickCallback: () -> (),
	onSanityDepletedCallback: () -> ()
)
	SanityService.StopBlackoutDrain()

	drainThread = task.spawn(function()
		while isDrainActiveCallback() do
			task.wait(GameConfig.SANITY.BLACKOUT_TICK_INTERVAL)
			if not isDrainActiveCallback() then
				break
			end

			sanityValue = math.clamp(sanityValue - GameConfig.SANITY.BLACKOUT_TICK_COST, 0, GameConfig.SANITY.MAX)
			onSanityTickCallback()

			if sanityValue <= 0 then
				onSanityDepletedCallback()
				break
			end
		end
	end)
end

return SanityService
