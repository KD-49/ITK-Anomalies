--!strict
-- CameraController.luau
-- Controller Client yang menangani kamera pemain:
-- 1. Mode tampilan Kamera CCTV (CCTV 1 - 4) beserta goyangan (sway) kamera
-- 2. Menyembunyikan bodi model Camera 3D secara lokal agar pandangan CCTV tidak terhalang
-- 3. Efek guncangan kamera (Camera Shake) saat terkena Jumpscare

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraController = {}

local CCTV_NAMES = {
	"CCTV 1 — Gerbang Utama",
	"CCTV 2 — Jalan Masuk Kampus",
	"CCTV 3 — Bagian Dalam Pos",
	"CCTV 4 — Hutan Belakang Pos",
}

local cctvOpen = false
local currentCctvIndex = 1
local cctvConn: RBXScriptConnection? = nil

local function setCctvModelsLocalTransparency(transparency: number)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name == "Camera" then
			for _, part in ipairs(obj:GetDescendants()) do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = transparency
				end
			end
		end
	end
end

function CameraController.Init()
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
end

function CameraController.IsCctvOpen(): boolean
	return cctvOpen
end

function CameraController.GetCurrentCctvIndex(): number
	return currentCctvIndex
end

function CameraController.GetCurrentCctvName(): string
	return CCTV_NAMES[currentCctvIndex] or "CCTV"
end

function CameraController.StopCctv()
	cctvOpen = false
	if cctvConn then
		cctvConn:Disconnect()
		cctvConn = nil
	end
	setCctvModelsLocalTransparency(0)
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
end

function CameraController.StartCctv(index: number)
	currentCctvIndex = ((index - 1) % 4) + 1
	cctvOpen = true
	setCctvModelsLocalTransparency(1)

	if cctvConn then
		cctvConn:Disconnect()
	end

	cctvConn = RunService.RenderStepped:Connect(function()
		if not cctvOpen then
			return
		end
		local cam = Workspace.CurrentCamera
		local cctvFolder = ReplicatedStorage:FindFirstChild("CCTVNodes")
		if cam and cctvFolder then
			local node = cctvFolder:FindFirstChild("Camera_" .. tostring(currentCctvIndex))
			if node and node:IsA("CFrameValue") then
				cam.CameraType = Enum.CameraType.Scriptable
				local sway = math.sin(os.clock() * 0.4) * math.rad(2.5)
				cam.CFrame = node.Value * CFrame.Angles(0, sway, 0)
			end
		end
	end)
end

function CameraController.StepCctv(delta: number)
	CameraController.StartCctv(currentCctvIndex + delta)
end

function CameraController.ApplyRandomShakeOffset(origCf: CFrame)
	local cam = Workspace.CurrentCamera
	if cam then
		local rx = (math.random() - 0.5) * 0.25
		local ry = (math.random() - 0.5) * 0.25
		cam.CFrame = origCf * CFrame.Angles(rx, ry, 0)
	end
end

return CameraController
