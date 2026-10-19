--!strict
-- GameConfig.luau
-- Konfigurasi dasar ITK Anomalies (Progress 30% - Fitur Esensial Core Loop)

local GameConfig = {}

GameConfig.SHIFT = {
	START_HOUR = 22, -- 22:00
	END_HOUR = 6, -- 06:00
	VISITORS_PER_SHIFT = 5, -- 5 pengunjung per shift (datang satu per satu)
	NEXT_VISITOR_DELAY = 3.5, -- Jeda detik setelah pengunjung sebelumnya selesai diproses
}

GameConfig.SCORING = {
	BASE_SALARY = 80,
	CORRECT_DECISION = 5,
	ANOMALY_PASSED = -10,
	NORMAL_REJECTED = -4,
	MIN_SALARY = 50,
}

function GameConfig.CalculateRank(accuracyPercent: number, anomaliesPassed: number): string
	if accuracyPercent >= 95 and anomaliesPassed == 0 then
		return "S"
	elseif accuracyPercent >= 85 then
		return "A"
	elseif accuracyPercent >= 70 then
		return "B"
	elseif accuracyPercent >= 50 then
		return "C"
	else
		return "D"
	end
end

return GameConfig
