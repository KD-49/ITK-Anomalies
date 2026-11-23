--!strict
-- InteractionController.luau
-- Controller Client yang menangani input pemain (Keyboard Shortcut seperti Escape, Panah Kiri/Kanan CCTV)
-- serta menjembatani pengiriman aksi Client ke Server melalui RemoteEvent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("Constants"):WaitForChild("RemoteNames"))

local CameraController = require(script.Parent:WaitForChild("CameraController"))
local UIController = require(script.Parent:WaitForChild("UIController"))

local InteractionController = {}

local actionEvent: RemoteEvent? = nil

function InteractionController.SendActionToServer(actionType: string, payload: any)
	if actionEvent then
		actionEvent:FireServer(actionType, payload)
	end
end

function InteractionController.Init(remotesFolder: Folder)
	local stateSyncEvent = remotesFolder:WaitForChild(RemoteNames.EVENTS.STATE_SYNC) :: RemoteEvent
	local openPanelEvent = remotesFolder:WaitForChild(RemoteNames.EVENTS.OPEN_PANEL) :: RemoteEvent
	local jumpscareEvent = remotesFolder:WaitForChild(RemoteNames.EVENTS.JUMPSCARE) :: RemoteEvent
	actionEvent = remotesFolder:WaitForChild(RemoteNames.EVENTS.CLIENT_ACTION) :: RemoteEvent

	UIController.Init(function(actionType: string, payload: any)
		InteractionController.SendActionToServer(actionType, payload)
	end)

	stateSyncEvent.OnClientEvent:Connect(function(newState: any)
		UIController.OnStateSync(newState)
	end)

	openPanelEvent.OnClientEvent:Connect(function(panelName: string)
		UIController.OpenPanel(panelName)
	end)

	jumpscareEvent.OnClientEvent:Connect(function(data: any)
		UIController.TriggerJumpscare(data)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			UIController.CloseAllPanels()
		elseif CameraController.IsCctvOpen() and input.KeyCode == Enum.KeyCode.Left then
			CameraController.StepCctv(-1)
			UIController.Refresh()
		elseif CameraController.IsCctvOpen() and input.KeyCode == Enum.KeyCode.Right then
			CameraController.StepCctv(1)
			UIController.Refresh()
		end
	end)
end

return InteractionController
