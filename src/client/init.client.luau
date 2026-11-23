--!strict
-- init.client.luau (Main.client.luau)
-- Entry point utama Client ITK Anomalies.
-- Menginisialisasi seluruh Client Controllers (AudioController, CameraController, UIController, InteractionController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("Constants"):WaitForChild("RemoteNames"))

local Controllers = script:WaitForChild("Controllers")
local AudioController = require(Controllers:WaitForChild("AudioController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))
local InteractionController = require(Controllers:WaitForChild("InteractionController"))

AudioController.Init()
CameraController.Init()

local remotes = ReplicatedStorage:WaitForChild(RemoteNames.FOLDER_NAME, 15) :: Folder?
if remotes then
	InteractionController.Init(remotes)
end
