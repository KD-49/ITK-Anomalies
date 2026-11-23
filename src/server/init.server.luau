--!strict
-- init.server.luau (Main.server.luau)
-- Entry point utama Server ITK Anomalies.
-- Menginisialisasi seluruh Server Services secara berurutan melalui ShiftService.

local Services = script:WaitForChild("Services")
local ShiftService = require(Services:WaitForChild("ShiftService"))

print("[ITK Anomalies] Memulai arsitektur Server Services Pos Satpam Malam ITK...")
ShiftService.Init()
print("[ITK Anomalies] Seluruh Server Services berhasil dijalankan.")
