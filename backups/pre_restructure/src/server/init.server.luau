--!strict
-- init.server.luau
-- Entry point utama Server ITK Anomalies

local ShiftManager = require(script:WaitForChild("ShiftManager"))

print("[ITK Anomalies] Memulai sistem server Pos Satpam Malam ITK...")
ShiftManager.Init()
print("[ITK Anomalies] Sistem server berhasil dijalankan.")
