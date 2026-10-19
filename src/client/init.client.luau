--!strict
-- init.client.luau
-- Script utama client ITK Anomalies

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UIManager = require(script:WaitForChild("UIManager"))

local cam = Workspace.CurrentCamera
if cam then
	cam.CameraType = Enum.CameraType.Custom
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
if not remotes then
	return
end

local stateSyncEvent = remotes:WaitForChild("StateSync") :: RemoteEvent
local openPanelEvent = remotes:WaitForChild("OpenPanel") :: RemoteEvent
local jumpscareEvent = remotes:WaitForChild("Jumpscare") :: RemoteEvent
local actionEvent = remotes:WaitForChild("ClientAction") :: RemoteEvent

UIManager.Init(function(actionType: string, payload: any)
	actionEvent:FireServer(actionType, payload)
end)

stateSyncEvent.OnClientEvent:Connect(function(newState: any)
	UIManager.OnStateSync(newState)
end)

openPanelEvent.OnClientEvent:Connect(function(panelName: string)
	UIManager.OpenPanel(panelName)
end)

jumpscareEvent.OnClientEvent:Connect(function(data: any)
	UIManager.TriggerJumpscare(data)
end)
