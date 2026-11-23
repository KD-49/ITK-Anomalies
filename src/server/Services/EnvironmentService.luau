--!strict
-- EnvironmentService.luau
-- Service Server yang mengatur seluruh objek 3D lingkungan Pos Satpam & Kampus ITK di Workspace:
-- 1. Pembersihan script bawaan Free Model (Runtime / InputOverlay)
-- 2. Animasi 2 daun pintu Gerbang Utama ITK + Panah & Beam Tutorial
-- 3. Gardu Listrik (Workspace.Furnitur.Transformator), Highlight saat mati lampu, dan lampu Pos Satpam
-- 4. Model 3D Laptop Meja Depan, Node Kamera 3D CCTV, dan ProximityPrompt interaksi

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapWaypoints = require(Shared:WaitForChild("Constants"):WaitForChild("MapWaypoints"))

local EnvironmentService = {}

type GatePartData = {
	part: BasePart,
	origCf: CFrame,
	origTransparency: number,
	origCanCollide: boolean,
	role: "LockOrChain" | "RightLeaf" | "LeftLeaf" | "StaticPost",
}

export type EnvironmentCallbacks = {
	onOpenGateStartShift: (player: Player) -> (),
	onInteractLoket: (player: Player) -> (),
	onInteractLaptopData: (player: Player) -> (),
	onInteractPcCctv: (player: Player) -> (),
	onInteractPowerPanel: (player: Player) -> (),
}

local gateParts: { GatePartData } = {}
local gateIsOpen = false
local gateAnimConn: RBXScriptConnection? = nil

local gatePromptNode: Part? = nil
local gatePrompt: ProximityPrompt? = nil
local gateArrowBillboard: BillboardGui? = nil
local tutorialBeamFolder: Folder? = nil
local posLights: { Light } = {}
local blackoutActive = false
local powerIndicatorLight: PointLight? = nil
local powerIndicatorPart: Part? = nil
local powerHighlight: Highlight? = nil
local loketPrompt: ProximityPrompt? = nil
local visitorPrompt: ProximityPrompt? = nil

local function cleanFreeModelScripts()
	-- Matikan sistem injeksi InputOverlay dari free model (seperti di dalam Coffee Machine & ProximityPromptService)
	Workspace:SetAttribute("runtime-object-defaults", true)
	ProximityPromptService.Enabled = true
	for _, child in ipairs(ProximityPromptService:GetChildren()) do
		child:Destroy()
	end
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == "Runtime" or obj.Name == "RuntimeInput" then
			obj:Destroy()
		elseif obj:IsA("Script") and obj.Name == "Script" and obj.Parent and obj.Parent.Parent and obj.Parent.Parent.Name == "Camera" then
			obj:Destroy()
		end
	end
end

local function ensurePlayerCanMove(character: Model)
	task.defer(function()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
			end
		end
		local hum = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum then
			hum.WalkSpeed = 16
			hum.JumpPower = 50
			hum.PlatformStand = false
			hum.Sit = false
		end
	end)
end

-- Menghubungkan script interaksi ke aset Gardu Listrik / Transformator di dalam Folder Furnitur
local function ensurePowerPanel(onRepairInteract: (Player) -> ()): ProximityPrompt
	local oldCustom = Workspace:FindFirstChild("GarduListrik", true)
	if oldCustom and oldCustom:IsA("Model") and oldCustom.Parent and oldCustom.Parent.Name == "Barang Interaktif" then
		oldCustom:Destroy()
	end

	-- Cari aset gardu listrik asli di Workspace.Furnitur (pilih Transformator di darat yang memiliki PowerBox)
	local targetModel: Instance? = nil
	local attachPart: BasePart? = nil

	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("Model") and (desc.Name == "Transformator" or desc.Name == "Gardu" or desc.Name == "GarduListrik") then
			local powerBox = desc:FindFirstChild("PowerBox", true)
			if powerBox then
				targetModel = desc
				attachPart = powerBox:FindFirstChild("Doorpart1", true) :: BasePart?
					or powerBox:FindFirstChildWhichIsA("BasePart", true)
				break
			end
			local anyPart = desc:FindFirstChildWhichIsA("BasePart", true)
			if anyPart and anyPart.Position.Y < 90 and not targetModel then
				targetModel = desc
				attachPart = anyPart
			end
		end
	end

	if targetModel and not attachPart then
		if targetModel:IsA("BasePart") then
			attachPart = targetModel
		elseif targetModel:IsA("Model") then
			attachPart = targetModel.PrimaryPart or targetModel:FindFirstChildWhichIsA("BasePart", true)
		end
	end

	-- Fallback jika aset Transformator belum ada di Workspace
	if not attachPart then
		local folder = Workspace:FindFirstChild("Furnitur")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Furnitur"
			folder.Parent = Workspace
		end

		local panelModel = Instance.new("Model")
		panelModel.Name = "Transformator"

		local panelBox = Instance.new("Part")
		panelBox.Name = "TransformatorBase"
		panelBox.Size = Vector3.new(2.5, 3.5, 2.0)
		panelBox.CFrame = CFrame.new(MapWaypoints.FALLBACK_TRAFO_POS)
		panelBox.Color = Color3.fromRGB(60, 65, 72)
		panelBox.Material = Enum.Material.Metal
		panelBox.Anchored = true
		panelBox.CanCollide = true
		panelBox.Parent = panelModel

		panelModel.PrimaryPart = panelBox
		panelModel.Parent = folder
		targetModel = panelModel
		attachPart = panelBox
	end

	for _, child in ipairs(attachPart:GetChildren()) do
		if child.Name == "PowerPrompt" or child.Name == "GarduStatusLight" or child.Name == "GarduIndicatorPart" then
			child:Destroy()
		end
	end

	local indPart = Instance.new("Part")
	indPart.Name = "GarduIndicatorPart"
	indPart.Size = Vector3.new(0.35, 0.35, 0.35)
	indPart.Position = attachPart.Position + Vector3.new(0, 1.2, 0)
	indPart.Color = Color3.fromRGB(60, 220, 80)
	indPart.Material = Enum.Material.Neon
	indPart.Anchored = true
	indPart.CanCollide = false
	indPart.Parent = attachPart
	powerIndicatorPart = indPart

	local light = Instance.new("PointLight")
	light.Name = "GarduStatusLight"
	light.Color = Color3.fromRGB(60, 220, 80)
	light.Brightness = 1.5
	light.Range = 10
	light.Parent = indPart
	powerIndicatorLight = light

	-- Highlight visual gardu listrik agar mudah ditemukan saat gelap gulita
	local oldHl = (targetModel :: Instance):FindFirstChild("GarduHighlight")
	if oldHl then
		oldHl:Destroy()
	end

	local hl = Instance.new("Highlight")
	hl.Name = "GarduHighlight"
	hl.FillColor = Color3.fromRGB(255, 195, 40)
	hl.OutlineColor = Color3.fromRGB(255, 240, 100)
	hl.FillTransparency = 0.45
	hl.OutlineTransparency = 0
	hl.Enabled = false
	hl.Adornee = targetModel
	hl.Parent = targetModel
	powerHighlight = hl

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PowerPrompt"
	prompt.ObjectText = "Gardu Listrik"
	prompt.ActionText = "Perbaiki Panel Kabel"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = indPart

	prompt.Triggered:Connect(onRepairInteract)
	return prompt
end

-- Membuat model Laptop 3D di meja depan jika belum ada model Laptop di Workspace
local function ensureFrontDeskLaptop(): BasePart
	local existingLaptop = Workspace:FindFirstChild("Laptop", true)
	if existingLaptop then
		if existingLaptop:IsA("BasePart") then
			return existingLaptop
		elseif existingLaptop:IsA("Model") then
			local part = existingLaptop.PrimaryPart or existingLaptop:FindFirstChildWhichIsA("BasePart", true)
			if part then
				return part
			end
		end
	end

	local laptopModel = Instance.new("Model")
	laptopModel.Name = "Laptop"

	local base = Instance.new("Part")
	base.Name = "LaptopBase"
	base.Size = Vector3.new(1.8, 0.1, 1.3)
	base.CFrame = CFrame.new(MapWaypoints.FALLBACK_LAPTOP_POS)
	base.Color = Color3.fromRGB(40, 44, 52)
	base.Material = Enum.Material.SmoothPlastic
	base.Anchored = true
	base.CanCollide = false
	base.Parent = laptopModel

	local screen = Instance.new("Part")
	screen.Name = "LaptopScreen"
	screen.Size = Vector3.new(1.8, 1.15, 0.08)
	screen.CFrame = CFrame.new(-115.2, 71.65, -8.5) * CFrame.Angles(math.rad(-15), 0, 0)
	screen.Color = Color3.fromRGB(30, 34, 40)
	screen.Material = Enum.Material.SmoothPlastic
	screen.Anchored = true
	screen.CanCollide = false
	screen.Parent = laptopModel

	local display = Instance.new("Part")
	display.Name = "DisplayGlow"
	display.Size = Vector3.new(1.65, 1.0, 0.02)
	display.CFrame = screen.CFrame * CFrame.new(0, 0, -0.04)
	display.Color = Color3.fromRGB(65, 135, 195)
	display.Material = Enum.Material.Neon
	display.Anchored = true
	display.CanCollide = false
	display.Parent = laptopModel

	laptopModel.PrimaryPart = base
	laptopModel.Parent = Workspace
	return base
end

local function createPromptNode(
	name: string,
	position: Vector3,
	objectText: string,
	actionText: string,
	holdDuration: number,
	callback: (Player) -> ()
): (Part, ProximityPrompt)
	local folder = Workspace:FindFirstChild("InteractionPrompts") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "InteractionPrompts"
		folder.Parent = Workspace
	end

	local existing = folder:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end

	local node = Instance.new("Part")
	node.Name = name
	node.Size = Vector3.new(1, 1, 1)
	node.Position = position
	node.Anchored = true
	node.CanCollide = false
	node.CanQuery = false
	node.CanTouch = false
	node.Transparency = 1
	node.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = holdDuration
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = node

	prompt.Triggered:Connect(callback)
	return node, prompt
end

local function attachTutorialBeamToCharacter(character: Model)
	if not tutorialBeamFolder or not gatePromptNode or not gatePrompt or not gatePrompt.Enabled then
		return
	end
	local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not hrp then
		return
	end

	local oldAtt = hrp:FindFirstChild("GateTutorialAtt0")
	if oldAtt then
		oldAtt:Destroy()
	end

	local att0 = Instance.new("Attachment")
	att0.Name = "GateTutorialAtt0"
	att0.Parent = hrp

	local att1 = gatePromptNode:FindFirstChild("GateTutorialAtt1") :: Attachment?
	if not att1 then
		att1 = Instance.new("Attachment")
		att1.Name = "GateTutorialAtt1"
		att1.Parent = gatePromptNode
	end

	local beam = Instance.new("Beam")
	beam.Name = "GateTutorialBeam"
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 215, 60))
	beam.Width0 = 0.65
	beam.Width1 = 0.65
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Transparency = NumberSequence.new(0.15)
	beam.Parent = tutorialBeamFolder
end

-- Membaca arah hadap asli dari 4 model Camera 3D di Workspace supaya CCTV tidak terhalang
local function setupCctvCameraNodes()
	local cctvFolder = ReplicatedStorage:FindFirstChild("CCTVNodes")
	if cctvFolder then
		cctvFolder:Destroy()
	end
	cctvFolder = Instance.new("Folder")
	cctvFolder.Name = "CCTVNodes"
	cctvFolder.Parent = ReplicatedStorage

	local computedCFrames: { [number]: CFrame } = {
		[1] = MapWaypoints.DEFAULT_CCTV_CFRAMES[1],
		[2] = MapWaypoints.DEFAULT_CCTV_CFRAMES[2],
		[3] = MapWaypoints.DEFAULT_CCTV_CFRAMES[3],
		[4] = MapWaypoints.DEFAULT_CCTV_CFRAMES[4],
	}

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name == "Camera" then
			local unionPart = obj:FindFirstChild("Union", true) :: BasePart?
			local lensModel = obj:FindFirstChild("Model")
			if unionPart and lensModel then
				local bodyPos = unionPart.Position
				local lensPos: Vector3? = nil
				local maxDist = -1

				for _, sub in ipairs(lensModel:GetDescendants()) do
					if sub:IsA("BasePart") then
						local d = (sub.Position - bodyPos).Magnitude
						if d > maxDist then
							maxDist = d
							lensPos = sub.Position
						end
					end
				end

				if lensPos and maxDist > 0.05 then
					local forwardDir = (lensPos - bodyPos).Unit
					local eyePos = lensPos + forwardDir * 1.5
					local camCf = CFrame.lookAt(eyePos, eyePos + forwardDir * 40)

					if bodyPos.X > -100 then
						computedCFrames[1] = camCf
					elseif bodyPos.Z > -20 then
						computedCFrames[2] = camCf
					elseif bodyPos.Z > -36 then
						computedCFrames[3] = camCf
					else
						computedCFrames[4] = camCf
					end
				end
			end
		end
	end

	for id = 1, 4 do
		local cfVal = Instance.new("CFrameValue")
		cfVal.Name = "Camera_" .. tostring(id)
		cfVal.Value = computedCFrames[id]
		cfVal.Parent = cctvFolder
	end
end

function EnvironmentService.SetBlackout(active: boolean)
	blackoutActive = active
	for _, l in ipairs(posLights) do
		if l and l.Parent then
			l.Enabled = not active
		end
	end

	local prompt = if powerIndicatorPart then powerIndicatorPart:FindFirstChildWhichIsA("ProximityPrompt", true) else nil
	if prompt then
		prompt.Enabled = active
	end

	if powerHighlight then
		powerHighlight.Enabled = active
	end

	if powerIndicatorLight and powerIndicatorPart then
		if active then
			powerIndicatorLight.Color = Color3.fromRGB(255, 45, 45)
			powerIndicatorLight.Brightness = 4.0
			powerIndicatorLight.Range = 22
			powerIndicatorPart.Color = Color3.fromRGB(255, 45, 45)
		else
			powerIndicatorLight.Color = Color3.fromRGB(60, 220, 80)
			powerIndicatorLight.Brightness = 1.5
			powerIndicatorLight.Range = 10
			powerIndicatorPart.Color = Color3.fromRGB(60, 220, 80)
		end
	end
end

function EnvironmentService.IsBlackout(): boolean
	return blackoutActive
end

function EnvironmentService.SetLoketPromptActive(active: boolean)
	if loketPrompt then
		loketPrompt.Enabled = active
	end
	if visitorPrompt then
		visitorPrompt.Enabled = active
	end
end

function EnvironmentService.RegisterVisitorPrompt(prompt: ProximityPrompt?)
	visitorPrompt = prompt
end

function EnvironmentService.GetTutorialBeamFolder(): Folder?
	return tutorialBeamFolder
end

function EnvironmentService.SetGateTutorialActive(active: boolean)
	if gatePrompt then
		gatePrompt.Enabled = active
	end
	if gateArrowBillboard then
		gateArrowBillboard.Enabled = active
	end
	if tutorialBeamFolder then
		tutorialBeamFolder:ClearAllChildren()
	end

	if active then
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				attachTutorialBeamToCharacter(player.Character)
			end
		end
	end
end

-- Membuka gerbang dari tengah (2 daun pintu berputar pada engsel kiri & kanan, gembok & rantai menghilang)
function EnvironmentService.SetGateOpen(open: boolean)
	if gateIsOpen == open then
		return
	end
	gateIsOpen = open

	if gateAnimConn then
		gateAnimConn:Disconnect()
		gateAnimConn = nil
	end

	for _, item in ipairs(gateParts) do
		if item.part and item.part.Parent then
			if item.role == "LockOrChain" then
				item.part.Transparency = if open then 1 else item.origTransparency
				item.part.CanCollide = if open then false else item.origCanCollide
			elseif item.role == "RightLeaf" or item.role == "LeftLeaf" then
				item.part.CanCollide = not open
			end
		end
	end

	local startAlpha = if open then 0 else 1
	local targetAlpha = if open then 1 else 0
	local elapsed = 0
	local duration = 1.25

	gateAnimConn = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local t = math.clamp(elapsed / duration, 0, 1)
		local smoothT = t * t * (3 - 2 * t)
		local alpha = startAlpha + (targetAlpha - startAlpha) * smoothT

		local rightSwing = CFrame.Angles(0, math.rad(-85 * alpha), 0)
		local leftSwing = CFrame.Angles(0, math.rad(85 * alpha), 0)

		for _, item in ipairs(gateParts) do
			if item.part and item.part.Parent then
				if item.role == "RightLeaf" then
					local rel = MapWaypoints.RIGHT_GATE_HINGE:Inverse() * item.origCf
					item.part.CFrame = MapWaypoints.RIGHT_GATE_HINGE * rightSwing * rel
				elseif item.role == "LeftLeaf" then
					local rel = MapWaypoints.LEFT_GATE_HINGE:Inverse() * item.origCf
					item.part.CFrame = MapWaypoints.LEFT_GATE_HINGE * leftSwing * rel
				end
			end
		end

		if t >= 1 and gateAnimConn then
			gateAnimConn:Disconnect()
			gateAnimConn = nil
		end
	end)
end

-- Kejadian aneh (lampu Pos Satpam berkedip-kedip) ketika Anomali Penipu lolos masuk
function EnvironmentService.TriggerWeirdFlicker()
	task.spawn(function()
		for _ = 1, 8 do
			for _, l in ipairs(posLights) do
				if l and l.Parent then
					l.Enabled = false
				end
			end
			task.wait(0.12)
			for _, l in ipairs(posLights) do
				if l and l.Parent then
					l.Enabled = not blackoutActive
				end
			end
			task.wait(0.18)
		end
	end)
end

function EnvironmentService.Init(callbacks: EnvironmentCallbacks)
	cleanFreeModelScripts()
	setupCctvCameraNodes()
	ensurePowerPanel(callbacks.onInteractPowerPanel)

	tutorialBeamFolder = Workspace:FindFirstChild("TutorialBeams") :: Folder
	if not tutorialBeamFolder then
		tutorialBeamFolder = Instance.new("Folder")
		tutorialBeamFolder.Name = "TutorialBeams"
		tutorialBeamFolder.Parent = Workspace
	end

	posLights = {}
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
			if not powerIndicatorLight or obj ~= powerIndicatorLight then
				table.insert(posLights, obj)
			end
		end
	end

	-- Klasifikasikan bagian-bagian fence gate: Gembok/Rantai, Daun Pintu Kanan, Daun Pintu Kiri, dan Tiang Pagar Samping
	gateParts = {}
	local foundGate = Workspace:FindFirstChild("fence gate", true)
	if foundGate and foundGate:IsA("Model") then
		local padlockModel = foundGate:FindFirstChild("Model")
		for _, desc in ipairs(foundGate:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				local z = desc.Position.Z
				local role: "LockOrChain" | "RightLeaf" | "LeftLeaf" | "StaticPost" = "StaticPost"

				if (padlockModel and desc:IsDescendantOf(padlockModel)) or desc.Name == "chain link" then
					role = "LockOrChain"
				elseif z > 1.85 and z < MapWaypoints.GATE_CENTER_Z then
					role = "RightLeaf"
				elseif z >= MapWaypoints.GATE_CENTER_Z and z < 31.15 then
					role = "LeftLeaf"
				else
					role = "StaticPost"
				end

				table.insert(gateParts, {
					part = desc,
					origCf = desc.CFrame,
					origTransparency = desc.Transparency,
					origCanCollide = desc.CanCollide,
					role = role,
				})
			end
		end
	end

	-- 1. Prompt Gerbang Utama (Tahan E selama 1.5 detik untuk membuka gerbang di awal permainan)
	local gNode, gPrompt = createPromptNode(
		"Prompt_Gerbang",
		MapWaypoints.GATE_PROMPT_POS,
		"Gerbang Kampus ITK",
		"Buka Gerbang (Tahan E)",
		1.5,
		function(player: Player)
			callbacks.onOpenGateStartShift(player)
		end
	)
	gatePromptNode = gNode
	gatePrompt = gPrompt

	-- Tanda Panah Penunjuk Tutorial di atas Gerbang
	local arrowGui = Instance.new("BillboardGui")
	arrowGui.Name = "GateTutorialArrow"
	arrowGui.Size = UDim2.new(0, 200, 0, 65)
	arrowGui.StudsOffset = Vector3.new(0, 4.5, 0)
	arrowGui.AlwaysOnTop = true
	arrowGui.MaxDistance = 120
	arrowGui.Parent = gNode

	local arrowText = Instance.new("TextLabel")
	arrowText.Size = UDim2.new(1, 0, 1, 0)
	arrowText.BackgroundTransparency = 1
	arrowText.Text = "BUKA GERBANG DULU\n[Tahan E]\n▼"
	arrowText.TextColor3 = Color3.fromRGB(255, 220, 65)
	arrowText.TextStrokeTransparency = 0.2
	arrowText.Font = Enum.Font.SourceSansBold
	arrowText.TextSize = 20
	arrowText.Parent = arrowGui
	gateArrowBillboard = arrowGui

	-- 2. Prompt Laptop di Meja Depan untuk Data Kampus
	local laptopPart = ensureFrontDeskLaptop()
	createPromptNode(
		"Prompt_LaptopDepan",
		laptopPart.Position + Vector3.new(0, 0.3, 0),
		"Laptop Pos Satpam",
		"Buka Data Kampus",
		0,
		callbacks.onInteractLaptopData
	)

	-- 3. Prompt PC di Ruang Belakang untuk melihat CCTV
	createPromptNode(
		"Prompt_PCBelakang",
		MapWaypoints.PC_BELAKANG_PROMPT_POS,
		"PC Monitor Belakang",
		"Lihat Kamera CCTV",
		0,
		callbacks.onInteractPcCctv
	)

	-- 4. Prompt Meja Loket Depan (Hanya aktif ketika pengunjung telah sampai di depan loket)
	local _loketNode, lPrompt = createPromptNode(
		"Prompt_LoketDepan",
		MapWaypoints.LOKET_PROMPT_POS,
		"Loket Pemeriksaan",
		"Bicara dengan Pengunjung",
		0,
		callbacks.onInteractLoket
	)
	lPrompt.Enabled = false
	loketPrompt = lPrompt

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			ensurePlayerCanMove(char)
			task.delay(0.5, function()
				if gatePrompt and gatePrompt.Enabled then
					attachTutorialBeamToCharacter(char)
				end
			end)
		end)
		if player.Character then
			ensurePlayerCanMove(player.Character)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(char)
			ensurePlayerCanMove(char)
			task.delay(0.5, function()
				if gatePrompt and gatePrompt.Enabled then
					attachTutorialBeamToCharacter(char)
				end
			end)
		end)
		if player.Character then
			ensurePlayerCanMove(player.Character)
			if gatePrompt and gatePrompt.Enabled then
				attachTutorialBeamToCharacter(player.Character)
			end
		end
	end
end

return EnvironmentService
