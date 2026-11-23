--!strict
-- MapBinder.luau
-- Mengatur objek 3D di Workspace:
-- 1. Gerbang Utama ITK (Tahan E di awal untuk membuka gerbang + Tanda Panah Tutorial)
-- 2. Laptop di meja depan untuk Data Kampus
-- 3. PC di meja belakang untuk melihat CCTV
-- 4. Pergerakan NPC pengunjung satu per satu dengan kecepatan jalan normal

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MapBinder = {}

-- Jalur jalan raya utama berada di Z = 16.5 (bebas dari tanaman/cone/pot di dekat dinding pos Z = -2)
local WAYPOINTS = {
	GATE_PROMPT_POS = Vector3.new(-45.25, 71.2, 16.5),
	SPAWN_OUTSIDE_GATE = Vector3.new(-33.0, 72.0, 16.5),
	ROAD_TURN_POINT = Vector3.new(-111.9, 72.0, 16.5),
	LOKET_STAND = Vector3.new(-111.9, 71.0, -4.5),
	LOKET_LOOK_AT = Vector3.new(-111.9, 71.0, -11.0),
	ACCEPT_CAMPUS_DEST = Vector3.new(-165.0, 72.0, 16.5),
	REJECT_OUTSIDE_DEST = Vector3.new(-30.0, 72.0, 16.5),
}

-- Engsel daun gerbang kiri & kanan supaya gerbang membuka dari tengah
local GATE_CENTER_Z = 16.49
local RIGHT_GATE_HINGE = CFrame.new(-45.25, 72.0, 1.75)
local LEFT_GATE_HINGE = CFrame.new(-45.25, 72.0, 31.23)

type GatePartData = {
	part: BasePart,
	origCf: CFrame,
	origTransparency: number,
	origCanCollide: boolean,
	role: "LockOrChain" | "RightLeaf" | "LeftLeaf" | "StaticPost",
}

local rigTemplate: Model? = nil
local activeNpcFolder: Folder = nil :: any
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
local powerBeam: Beam? = nil
local loketPrompt: ProximityPrompt? = nil
local visitorPrompt: ProximityPrompt? = nil

-- Menghubungkan script interaksi ke aset Gardu Listrik / Transformator di dalam Folder Furnitur
local function ensurePowerPanel(onRepairInteract: (Player) -> ())
	-- Hapus panel buatan lama jika ada
	local oldCustom = Workspace:FindFirstChild("GarduListrik", true)
	if oldCustom and oldCustom:IsA("Model") and oldCustom.Parent and oldCustom.Parent.Name == "Barang Interaktif" then
		oldCustom:Destroy()
	end

	-- Cari aset gardu listrik asli di Workspace.Furnitur (pilih Transformator yang berada di darat / memiliki PowerBox)
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

	-- Fallback jika aset belum diletakkan di Workspace
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
		panelBox.CFrame = CFrame.new(-183.0, 71.5, 42.9)
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

	-- Bersihkan prompt atau indikator lama yang mungkin menempel
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

function MapBinder.SetBlackout(active: boolean)
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

function MapBinder.IsBlackout(): boolean
	return blackoutActive
end

function MapBinder.SetLoketPromptActive(active: boolean)
	if loketPrompt then
		loketPrompt.Enabled = active
	end
	if visitorPrompt then
		visitorPrompt.Enabled = active
	end
end

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
	base.CFrame = CFrame.new(-115.2, 71.1, -9.1)
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

function MapBinder.SetGateTutorialActive(active: boolean)
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
function MapBinder.SetGateOpen(open: boolean)
	if gateIsOpen == open then
		return
	end
	gateIsOpen = open

	if gateAnimConn then
		gateAnimConn:Disconnect()
		gateAnimConn = nil
	end

	-- Sembunyikan/munculkan gembok dan rantai di tengah gerbang
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
		-- Smoothstep easing
		local smoothT = t * t * (3 - 2 * t)
		local alpha = startAlpha + (targetAlpha - startAlpha) * smoothT

		local rightSwing = CFrame.Angles(0, math.rad(-85 * alpha), 0)
		local leftSwing = CFrame.Angles(0, math.rad(85 * alpha), 0)

		for _, item in ipairs(gateParts) do
			if item.part and item.part.Parent then
				if item.role == "RightLeaf" then
					local rel = RIGHT_GATE_HINGE:Inverse() * item.origCf
					item.part.CFrame = RIGHT_GATE_HINGE * rightSwing * rel
				elseif item.role == "LeftLeaf" then
					local rel = LEFT_GATE_HINGE:Inverse() * item.origCf
					item.part.CFrame = LEFT_GATE_HINGE * leftSwing * rel
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
function MapBinder.TriggerWeirdFlicker()
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
					l.Enabled = true
				end
			end
			task.wait(0.18)
		end
	end)
end

-- Membaca arah hadap asli dari 4 model Camera 3D di Workspace supaya CCTV tidak terhalang dan sesuai arah kamera
local function setupCctvCameraNodes()
	local cctvFolder = ReplicatedStorage:FindFirstChild("CCTVNodes")
	if cctvFolder then
		cctvFolder:Destroy()
	end
	cctvFolder = Instance.new("Folder")
	cctvFolder.Name = "CCTVNodes"
	cctvFolder.Parent = ReplicatedStorage

	-- Fallback apabila model Camera tidak ditemukan
	local computedCFrames: { [number]: CFrame } = {
		[1] = CFrame.lookAt(Vector3.new(-87.3, 78.0, -4.8), Vector3.new(-45.2, 70.5, 16.5)),
		[2] = CFrame.lookAt(Vector3.new(-122.8, 78.2, -5.3), Vector3.new(-160.0, 71.0, 7.0)),
		[3] = CFrame.lookAt(Vector3.new(-118.7, 76.8, -33.2), Vector3.new(-100.0, 70.0, -18.0)),
		[4] = CFrame.lookAt(Vector3.new(-119.2, 76.9, -39.3), Vector3.new(-105.0, 68.0, -70.0)),
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
					-- Tempatkan titik kamera 1.5 stud di depan ujung lensa agar tidak terhalang bodi kamera/tembok
					local eyePos = lensPos + forwardDir * 1.5
					local camCf = CFrame.lookAt(eyePos, eyePos + forwardDir * 40)

					-- Urutkan ke slot CCTV 1..4 berdasarkan posisi kamera di Pos Satpam
					if bodyPos.X > -100 then
						computedCFrames[1] = camCf -- CCTV 1: Kamera sudut kanan depan (menghadap Gerbang Utama)
					elseif bodyPos.Z > -20 then
						computedCFrames[2] = camCf -- CCTV 2: Kamera sudut kiri depan (menghadap Jalan Kampus)
					elseif bodyPos.Z > -36 then
						computedCFrames[3] = camCf -- CCTV 3: Kamera dalam ruangan Pos Satpam
					else
						computedCFrames[4] = camCf -- CCTV 4: Kamera belakang pos (menghadap Hutan Belakang)
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

function MapBinder.Init(callbacks: {
	onOpenGateStartShift: (player: Player) -> (),
	onInteractLoket: (player: Player) -> (),
	onInteractLaptopData: (player: Player) -> (),
	onInteractPcCctv: (player: Player) -> (),
	onInteractPowerPanel: (player: Player) -> (),
})
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
			table.insert(posLights, obj)
		end
	end

	-- Cari Rig secara rekursif (di dalam Folder Furnitur atau Workspace)
	local existingRig = Workspace:FindFirstChild("Rig", true)
	if existingRig and existingRig:IsA("Model") then
		rigTemplate = existingRig:Clone()
		rigTemplate.Name = "VisitorRigTemplate"
		rigTemplate.Parent = ServerStorage
		existingRig:Destroy()
	end

	local npcFolder = Workspace:FindFirstChild("ActiveVisitors") :: Folder
	if npcFolder then
		npcFolder:ClearAllChildren()
	else
		npcFolder = Instance.new("Folder")
		npcFolder.Name = "ActiveVisitors"
		npcFolder.Parent = Workspace
	end
	activeNpcFolder = npcFolder

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
				elseif z > 1.85 and z < GATE_CENTER_Z then
					role = "RightLeaf"
				elseif z >= GATE_CENTER_Z and z < 31.15 then
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
		WAYPOINTS.GATE_PROMPT_POS,
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
		Vector3.new(-117.6, 71.0, -33.2),
		"PC Monitor Belakang",
		"Lihat Kamera CCTV",
		0,
		callbacks.onInteractPcCctv
	)

	-- 4. Prompt Meja Loket Depan (Hanya aktif ketika pengunjung telah sampai di depan loket)
	local _loketNode, lPrompt = createPromptNode(
		"Prompt_LoketDepan",
		Vector3.new(-111.9, 71.3, -9.2),
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

-- Mencari tinggi permukaan tanah tepat di bawah titik (x, z) supaya kaki pengunjung menapak pas di jalan
local function getGroundHrpY(npc: Model, x: number, z: number, fallbackY: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excludeList: { Instance } = { npc }
	if tutorialBeamFolder then
		table.insert(excludeList, tutorialBeamFolder)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(excludeList, player.Character)
		end
	end
	params.FilterDescendantsInstances = excludeList
	params.IgnoreWater = true

	-- Mulai raycast dari Y = 73.5 (di bawah atap pos Y = 79.7, di atas jalan Y = 69.0)
	local result = Workspace:Raycast(Vector3.new(x, 73.5, z), Vector3.new(0, -10, 0), params)
	if result and result.Position then
		return result.Position.Y + 3.0
	end
	return fallbackY
end

-- Deteksi apakah pemain menghalangi jalur jalan NPC, lalu hitung pergeseran memutar (lateral offset)
local currentAvoidOffset = Vector2.zero
local function getPlayerAvoidanceOffset(npcPos: Vector3, forwardDir: Vector3): Vector2
	local avoidTarget = Vector2.zero
	local closestDist = 999

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if hrp then
			local diff = hrp.Position - npcPos
			local flatDiff = Vector2.new(diff.X, diff.Z)
			local dist = flatDiff.Magnitude

			if dist < 5.2 and dist < closestDist then
				closestDist = dist
				local flatFwd = Vector2.new(forwardDir.X, forwardDir.Z).Unit
				local dot = flatFwd:Dot(flatDiff)
				-- Jika pemain berada di depan arah jalan NPC (dalam sudut pandang depan)
				if dot > -0.5 then
					local sideCross = flatFwd.X * flatDiff.Y - flatFwd.Y * flatDiff.X
					-- Geser memutar ke kanan atau ke kiri jalur
					local sideSign = if sideCross >= 0 then -1 else 1
					local pushAmount = math.clamp(4.5 - dist * 0.7, 1.8, 3.8)
					local rightVec = Vector2.new(flatFwd.Y, -flatFwd.X)
					avoidTarget = rightVec * (sideSign * pushAmount)
				end
			end
		end
	end

	return avoidTarget
end

-- Generator Model Avatar R6 lengkap (Head + Face, Torso, Arms, Legs, Motor6D, Humanoid)
local function buildFullR6Avatar(shirtColor: Color3): Model
	local npc = Instance.new("Model")
	npc.Name = "VisitorR6"

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.Anchored = true
	hrp.Parent = npc

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = shirtColor
	torso.Material = Enum.Material.SmoothPlastic
	torso.CanCollide = false
	torso.Anchored = false
	torso.Parent = npc

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Color = Color3.fromRGB(245, 205, 175)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Anchored = false
	head.Parent = npc

	local specialMesh = Instance.new("SpecialMesh")
	specialMesh.MeshType = Enum.MeshType.Head
	specialMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	specialMesh.Parent = head

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.Color = shirtColor
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.CanCollide = false
	leftArm.Anchored = false
	leftArm.Parent = npc

	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.Color = shirtColor
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.CanCollide = false
	rightArm.Anchored = false
	rightArm.Parent = npc

	local pantsColor = Color3.fromRGB(35, 40, 52)
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.Color = pantsColor
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.CanCollide = false
	leftLeg.Anchored = false
	leftLeg.Parent = npc

	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.Color = pantsColor
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.CanCollide = false
	rightLeg.Anchored = false
	rightLeg.Parent = npc

	-- Motor6D joints standard R6
	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "RootJoint"
	rootJoint.Part0 = hrp
	rootJoint.Part1 = torso
	rootJoint.C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	rootJoint.C1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	rootJoint.Parent = hrp

	local neck = Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = torso
	neck.Part1 = head
	neck.C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	neck.C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	neck.Parent = torso

	local leftShoulder = Instance.new("Motor6D")
	leftShoulder.Name = "Left Shoulder"
	leftShoulder.Part0 = torso
	leftShoulder.Part1 = leftArm
	leftShoulder.C0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	leftShoulder.C1 = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	leftShoulder.Parent = torso

	local rightShoulder = Instance.new("Motor6D")
	rightShoulder.Name = "Right Shoulder"
	rightShoulder.Part0 = torso
	rightShoulder.Part1 = rightArm
	rightShoulder.C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	rightShoulder.C1 = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	rightShoulder.Parent = torso

	local leftHip = Instance.new("Motor6D")
	leftHip.Name = "Left Hip"
	leftHip.Part0 = torso
	leftHip.Part1 = leftLeg
	leftHip.C0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	leftHip.C1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	leftHip.Parent = torso

	local rightHip = Instance.new("Motor6D")
	rightHip.Name = "Right Hip"
	rightHip.Part0 = torso
	rightHip.Part1 = rightLeg
	rightHip.C0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	rightHip.C1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	rightHip.Parent = torso

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.PlatformStand = true
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.Parent = npc

	npc.PrimaryPart = hrp
	return npc
end

-- Menggerakkan pengunjung menyusuri daftar waypoint dengan arah hadap sesuai jalan + animasi ayunan kaki & tangan R6 + jalan memutar jika dihalangi pemain
local function walkVisitorPath(
	npc: Model,
	waypoints: { Vector3 },
	finalLookAt: Vector3,
	speedStudsPerSec: number,
	onDone: (() -> ())?
)
	if not npc or not npc.Parent or #waypoints < 2 then
		if onDone then
			onDone()
		end
		return
	end

	local rootPart = (npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart) :: BasePart?
	if not rootPart then
		if onDone then
			onDone()
		end
		return
	end

	local torso = npc:FindFirstChild("Torso")
	local rightHip = if torso then torso:FindFirstChild("Right Hip") :: Motor6D? else nil
	local leftHip = if torso then torso:FindFirstChild("Left Hip") :: Motor6D? else nil
	local rightShoulder = if torso then torso:FindFirstChild("Right Shoulder") :: Motor6D? else nil
	local leftShoulder = if torso then torso:FindFirstChild("Left Shoulder") :: Motor6D? else nil

	local origRightHipC0 = if rightHip then rightHip.C0 else CFrame.identity
	local origLeftHipC0 = if leftHip then leftHip.C0 else CFrame.identity
	local origRightShoulderC0 = if rightShoulder then rightShoulder.C0 else CFrame.identity
	local origLeftShoulderC0 = if leftShoulder then leftShoulder.C0 else CFrame.identity

	local function resetLimbs()
		if rightHip then
			rightHip.C0 = origRightHipC0
		end
		if leftHip then
			leftHip.C0 = origLeftHipC0
		end
		if rightShoulder then
			rightShoulder.C0 = origRightShoulderC0
		end
		if leftShoulder then
			leftShoulder.C0 = origLeftShoulderC0
		end
	end

	local segIndex = 1
	local segElapsed = 0
	local totalWalkDist = 0

	local startPos = waypoints[1]
	local nextPos = waypoints[2]
	local flatStart = Vector3.new(startPos.X, 0, startPos.Z)
	local flatNext = Vector3.new(nextPos.X, 0, nextPos.Z)
	local segLength = math.max(0.01, (flatNext - flatStart).Magnitude)
	local segDuration = segLength / math.max(1, speedStudsPerSec)
	local currentLookDir = (flatNext - flatStart).Unit
	currentAvoidOffset = Vector2.zero

	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if not npc or not npc.Parent or not rootPart or not rootPart.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end

		segElapsed += dt
		totalWalkDist += dt * speedStudsPerSec
		local alpha = math.clamp(segElapsed / segDuration, 0, 1)

		local baseInterpX = startPos.X + (nextPos.X - startPos.X) * alpha
		local baseInterpZ = startPos.Z + (nextPos.Z - startPos.Z) * alpha
		local interpFallbackY = startPos.Y + (nextPos.Y - startPos.Y) * alpha

		-- Jika pemain menghalangi di depan, NPC belok memutar secara halus (menghindar ke samping)
		local targetAvoid = getPlayerAvoidanceOffset(Vector3.new(baseInterpX, interpFallbackY, baseInterpZ), currentLookDir)
		currentAvoidOffset = currentAvoidOffset:Lerp(targetAvoid, math.clamp(dt * 6, 0, 1))

		local interpX = baseInterpX + currentAvoidOffset.X
		local interpZ = baseInterpZ + currentAvoidOffset.Y
		local groundY = getGroundHrpY(npc, interpX, interpZ, interpFallbackY)

		local targetDir = (flatNext - flatStart).Unit
		if currentAvoidOffset.Magnitude > 0.3 then
			local detourDir = (Vector2.new(flatNext.X, flatNext.Z) - Vector2.new(interpX, interpZ)).Unit
			targetDir = Vector3.new(detourDir.X, 0, detourDir.Y)
		end
		currentLookDir = currentLookDir:Lerp(targetDir, math.clamp(dt * 8, 0, 1)).Unit

		-- Ayunan kaki & lengan R6 secara natural saat melangkah
		local stridePhase = totalWalkDist * 1.65
		local swingAngle = math.sin(stridePhase) * math.rad(36)
		local verticalBob = math.abs(math.cos(stridePhase)) * 0.08

		if rightHip then
			rightHip.C0 = origRightHipC0 * CFrame.Angles(0, 0, swingAngle)
		end
		if leftHip then
			leftHip.C0 = origLeftHipC0 * CFrame.Angles(0, 0, swingAngle)
		end
		if rightShoulder then
			rightShoulder.C0 = origRightShoulderC0 * CFrame.Angles(0, 0, -swingAngle * 0.75)
		end
		if leftShoulder then
			leftShoulder.C0 = origLeftShoulderC0 * CFrame.Angles(0, 0, -swingAngle * 0.75)
		end

		local posNow = Vector3.new(interpX, groundY + verticalBob, interpZ)
		rootPart.CFrame = CFrame.lookAt(posNow, posNow + currentLookDir)

		if alpha >= 1 then
			segIndex += 1
			if segIndex < #waypoints then
				startPos = waypoints[segIndex]
				nextPos = waypoints[segIndex + 1]
				flatStart = Vector3.new(startPos.X, 0, startPos.Z)
				flatNext = Vector3.new(nextPos.X, 0, nextPos.Z)
				segLength = math.max(0.01, (flatNext - flatStart).Magnitude)
				segDuration = segLength / math.max(1, speedStudsPerSec)
				segElapsed = 0
			else
				if conn then
					conn:Disconnect()
					conn = nil
				end
				resetLimbs()
				local endY = getGroundHrpY(npc, nextPos.X, nextPos.Z, nextPos.Y)
				local finalPos = Vector3.new(nextPos.X, endY, nextPos.Z)
				local finalLook = Vector3.new(finalLookAt.X, endY, finalLookAt.Z)
				rootPart.CFrame = CFrame.lookAt(finalPos, finalLook)
				if onDone then
					onDone()
				end
			end
		end
	end)
end

function MapBinder.SpawnSingleVisitor(
	displayName: string,
	visitorType: string,
	shirtColor: Color3,
	onInteract: (player: Player) -> (),
	onArrivedAtLoket: () -> ()
): Model
	if activeNpcFolder then
		activeNpcFolder:ClearAllChildren()
	end

	local npc: Model
	if rigTemplate then
		npc = rigTemplate:Clone()
	else
		-- Membuat Full Avatar R6 manusia lengkap secara otomatis jika di Workspace belum ada Rig
		npc = buildFullR6Avatar(shirtColor)
	end

	npc.Name = displayName

	local rootPart = (npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")) :: BasePart
	if rootPart then
		npc.PrimaryPart = rootPart
	end

	-- Hanya HumanoidRootPart yang Anchored = true agar Motor6D kaki & tangan bisa berayun saat berjalan
	-- Pastikan CanCollide = false agar pengunjung tidak mendorong pemain ke atas/terbang saat berpapasan
	for _, desc in ipairs(npc:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = (desc == rootPart)
			desc.CanCollide = false
			if desc.Name == "Torso" or desc.Name == "UpperTorso" then
				desc.Color = shirtColor
			elseif desc.Name == "Left Leg" or desc.Name == "Right Leg" then
				desc.Color = Color3.fromRGB(35, 38, 48)
			end
		elseif desc:IsA("BodyColors") then
			desc.TorsoColor3 = shirtColor
			desc.LeftLegColor3 = Color3.fromRGB(35, 38, 48)
			desc.RightLegColor3 = Color3.fromRGB(35, 38, 48)
		elseif desc:IsA("LocalScript") or desc:IsA("Script") then
			desc:Destroy()
		end
	end

	local hum = npc:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = displayName .. " (" .. visitorType .. ")"
		hum.NameDisplayDistance = 35
		hum.HealthDisplayDistance = 0
		hum.PlatformStand = true
	end

	if rootPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = displayName .. " (" .. visitorType .. ")"
		prompt.ActionText = "Periksa Pengunjung"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = rootPart

		visitorPrompt = prompt
		prompt.Triggered:Connect(onInteract)
	end

	local startY = getGroundHrpY(npc, WAYPOINTS.SPAWN_OUTSIDE_GATE.X, WAYPOINTS.SPAWN_OUTSIDE_GATE.Z, WAYPOINTS.SPAWN_OUTSIDE_GATE.Y)
	local startPos = Vector3.new(WAYPOINTS.SPAWN_OUTSIDE_GATE.X, startY, WAYPOINTS.SPAWN_OUTSIDE_GATE.Z)
	if rootPart then
		rootPart.CFrame = CFrame.lookAt(startPos, Vector3.new(WAYPOINTS.ROAD_TURN_POINT.X, startY, WAYPOINTS.ROAD_TURN_POINT.Z))
	end
	npc.Parent = activeNpcFolder

	-- Berjalan dari luar gerbang -> melewati tengah gerbang yang terbuka -> menyusuri jalan utama -> belok ke loket
	local arrivalPath = {
		WAYPOINTS.SPAWN_OUTSIDE_GATE,
		WAYPOINTS.ROAD_TURN_POINT,
		WAYPOINTS.LOKET_STAND,
	}

	walkVisitorPath(npc, arrivalPath, WAYPOINTS.LOKET_LOOK_AT, 7.5, function()
		if rootPart then
			local p = rootPart:FindFirstChildOfClass("ProximityPrompt")
			if p then
				p.Enabled = true
			end
		end
		MapBinder.SetLoketPromptActive(true)
		onArrivedAtLoket()
	end)

	return npc
end

function MapBinder.DismissCurrentVisitor(npc: Model?, accepted: boolean, onFinished: () -> ())
	MapBinder.SetLoketPromptActive(false)
	if not npc or not npc.Parent then
		onFinished()
		return
	end

	for _, desc in ipairs(npc:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			desc:Destroy()
		end
	end

	if accepted then
		-- Kembali ke jalan utama dulu baru belok kanan masuk ke area kampus (tidak menabrak Traffic Cone / Pot tanaman)
		local acceptPath = {
			WAYPOINTS.LOKET_STAND,
			WAYPOINTS.ROAD_TURN_POINT,
			WAYPOINTS.ACCEPT_CAMPUS_DEST,
		}
		walkVisitorPath(npc, acceptPath, WAYPOINTS.ACCEPT_CAMPUS_DEST + Vector3.new(-10, 0, 0), 8.0, function()
			if npc and npc.Parent then
				npc:Destroy()
			end
			onFinished()
		end)
	else
		-- Kembali ke jalan utama dulu baru belok kiri keluar gerbang (tidak menabrak semak tanaman)
		local rejectPath = {
			WAYPOINTS.LOKET_STAND,
			WAYPOINTS.ROAD_TURN_POINT,
			WAYPOINTS.REJECT_OUTSIDE_DEST,
		}
		walkVisitorPath(npc, rejectPath, WAYPOINTS.REJECT_OUTSIDE_DEST + Vector3.new(10, 0, 0), 8.0, function()
			if npc and npc.Parent then
				npc:Destroy()
			end
			onFinished()
		end)
	end
end

function MapBinder.CleanupAllVisitors()
	if activeNpcFolder then
		activeNpcFolder:ClearAllChildren()
	end
end

return MapBinder
