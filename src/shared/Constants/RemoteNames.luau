--!strict
-- RemoteNames.luau
-- Daftar konstanta nama RemoteEvent, aksi Client-ke-Server, dan nama panel UI.
-- Mencegah kesalahan ketik (typo) pada komunikasi Server-Client.

local RemoteNames = {
	FOLDER_NAME = "Remotes",

	EVENTS = {
		STATE_SYNC = "StateSync", -- Server -> Client: Sinkronisasi state sesi permainan
		OPEN_PANEL = "OpenPanel", -- Server -> Client: Membuka/menutup panel interaksi
		JUMPSCARE = "Jumpscare", -- Server -> Client: Memicu efek jumpscare & layar Game Over
		CLIENT_ACTION = "ClientAction", -- Client -> Server: Mengirim aksi pemain untuk divalidasi server
	},

	ACTIONS = {
		REQUEST_CARD = "RequestCard",
		DECISION = "Decision",
		NEXT_SHIFT = "NextShift",
		RETRY_SHIFT = "RetryShift",
		POWER_REPAIRED = "PowerRepaired",
		COLLECT_EVIDENCE = "CollectEvidence",
	},

	PANELS = {
		LOKET = "Loket",
		CLOSE_LOKET = "CloseLoket",
		LAPTOP_DATA = "LaptopData",
		PC_CCTV = "PcCctv",
		WIRING_MINIGAME = "WiringMiniGame",
	},
}

return RemoteNames
