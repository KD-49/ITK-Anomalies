--!strict
-- GameConfig.luau
-- Konfigurasi utama permainan ITK Anomalies (Shift, Sanity, dan Penilaian/Gaji).
-- Ditempatkan di ReplicatedStorage.Shared.Config agar dapat diakses oleh Server dan Client.

local GameConfig = {}

GameConfig.SHIFT = {
	START_HOUR = 22, -- Shift mulai pukul 22:00 WITA
	END_HOUR = 6, -- Shift berakhir pukul 06:00 WITA
	VISITORS_PER_SHIFT = 5, -- Jumlah pengunjung tiap shift (datang satu per satu)
	NEXT_VISITOR_DELAY = 3.5, -- Jeda detik sebelum pengunjung berikutnya datang
}

GameConfig.SANITY = {
	MAX = 100,
	INITIAL = 100,
	DECISION_COST = 1, -- Pengurangan sanity tiap kali selesai memeriksa pengunjung
	BLACKOUT_TICK_COST = 1, -- Pengurangan sanity tiap 1.5 detik selama mati lampu
	BLACKOUT_TICK_INTERVAL = 1.5, -- Interval detik pengurangan sanity saat blackout
	ANOMALY_PASSED_COST = 15,
	REPAIR_BONUS = 5, -- Pemulihan sanity setelah berhasil menyambung kabel di Gardu Listrik
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
