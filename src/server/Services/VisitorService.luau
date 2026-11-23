--!strict
-- VisitorService.luau
-- Service Server yang mengelola siklus pengunjung:
-- 1. Pembuatan antrean pengunjung tiap shift
-- 2. Spawning model 3D Avatar R6 manusia lengkap
-- 3. Pergerakan NPC dengan animasi ayunan tangan/kaki R6 dan penghindaran pemain (jalan memutar jika dihalangi)
-- 4. Penyimpanan state pengunjung aktif dan validasi pemeriksaan kartu identitas

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapWaypoints = require(Shared:WaitForChild("Constants"):WaitForChild("MapWaypoints"))
local R6AvatarBuilder = require(Shared:WaitForChild("Utilities"):WaitForChild("R6AvatarBuilder"))
local VisitorGenerator = require(Shared:WaitForChild("Utilities"):WaitForChild("VisitorGenerator"))

local EnvironmentService = require(script.Parent:WaitForChild("EnvironmentService"))

local VisitorService = {}

export type CurrentVisitorState = {
	profile: VisitorGenerator.VisitorProfile,
	model: Model?,
	arrivedAtLoket: boolean,
	cardRequested: boolean,
}

local rigTemplate: Model? = nil
local activeNpcFolder: Folder = nil :: any
local visitorList: { VisitorGenerator.VisitorProfile } = {}
local currentVisitorIndex = 0
local currentVisitor: CurrentVisitorState? = nil
local currentAvoidOffset = Vector2.zero

-- Mencari tinggi permukaan tanah tepat di bawah titik (x, z) supaya kaki pengunjung menapak pas di jalan
local function getGroundHrpY(npc: Model, x: number, z: number, fallbackY: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excludeList: { Instance } = { npc }
	local beamFolder = EnvironmentService.GetTutorialBeamFolder()
	if beamFolder then
		table.insert(excludeList, beamFolder)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(excludeList, player.Character)
		end
	end
	params.FilterDescendantsInstances = excludeList
	params.IgnoreWater = true

	local result = Workspace:Raycast(Vector3.new(x, 73.5, z), Vector3.new(0, -10, 0), params)
	if result and result.Position then
		return result.Position.Y + 3.0
	end
	return fallbackY
end

-- Deteksi apakah pemain menghalangi jalur jalan NPC, lalu hitung pergeseran memutar (lateral offset)
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
				if dot > -0.5 then
					local sideCross = flatFwd.X * flatDiff.Y - flatFwd.Y * flatDiff.X
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

-- Menggerakkan pengunjung menyusuri daftar waypoint + animasi ayunan kaki & tangan R6 + jalan memutar jika dihalangi pemain
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

local function spawnSingleVisitorModel(
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
		npc = R6AvatarBuilder.Build(shirtColor)
	end

	npc.Name = displayName

	local rootPart = (npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")) :: BasePart
	if rootPart then
		npc.PrimaryPart = rootPart
	end

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

		EnvironmentService.RegisterVisitorPrompt(prompt)
		prompt.Triggered:Connect(onInteract)
	end

	local startY = getGroundHrpY(npc, MapWaypoints.SPAWN_OUTSIDE_GATE.X, MapWaypoints.SPAWN_OUTSIDE_GATE.Z, MapWaypoints.SPAWN_OUTSIDE_GATE.Y)
	local startPos = Vector3.new(MapWaypoints.SPAWN_OUTSIDE_GATE.X, startY, MapWaypoints.SPAWN_OUTSIDE_GATE.Z)
	if rootPart then
		rootPart.CFrame = CFrame.lookAt(startPos, Vector3.new(MapWaypoints.ROAD_TURN_POINT.X, startY, MapWaypoints.ROAD_TURN_POINT.Z))
	end
	npc.Parent = activeNpcFolder

	local arrivalPath = {
		MapWaypoints.SPAWN_OUTSIDE_GATE,
		MapWaypoints.ROAD_TURN_POINT,
		MapWaypoints.LOKET_STAND,
	}

	walkVisitorPath(npc, arrivalPath, MapWaypoints.LOKET_LOOK_AT, 7.5, function()
		if rootPart then
			local p = rootPart:FindFirstChildOfClass("ProximityPrompt")
			if p then
				p.Enabled = true
			end
		end
		EnvironmentService.SetLoketPromptActive(true)
		onArrivedAtLoket()
	end)

	return npc
end

function VisitorService.Init()
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
end

function VisitorService.CleanupAllVisitors()
	currentVisitor = nil
	EnvironmentService.SetLoketPromptActive(false)
	if activeNpcFolder then
		activeNpcFolder:ClearAllChildren()
	end
end

function VisitorService.PrepareShiftVisitors(visitorsPerShift: number): (number, number)
	VisitorService.CleanupAllVisitors()
	currentVisitorIndex = 0
	visitorList = VisitorGenerator.GenerateShiftList(visitorsPerShift)

	local anomalyCount = 0
	for _, v in ipairs(visitorList) do
		if v.isAnomaly then
			anomalyCount += 1
		end
	end

	return #visitorList, anomalyCount
end

function VisitorService.GetCurrentVisitor(): CurrentVisitorState?
	return currentVisitor
end

function VisitorService.GetCurrentVisitorIndex(): number
	return currentVisitorIndex
end

function VisitorService.HasRemainingVisitors(): boolean
	return currentVisitorIndex < #visitorList
end

function VisitorService.MarkCardRequested(): boolean
	if currentVisitor and currentVisitor.arrivedAtLoket then
		currentVisitor.cardRequested = true
		return true
	end
	return false
end

function VisitorService.GetClientVisitorData(): any
	if not currentVisitor then
		return nil
	end
	return {
		profile = VisitorGenerator.SanitizeForClient(currentVisitor.profile),
		arrivedAtLoket = currentVisitor.arrivedAtLoket,
		cardRequested = currentVisitor.cardRequested,
	}
end

function VisitorService.SpawnNextVisitor(
	onInteractVisitorLoket: (player: Player) -> (),
	onVisitorArrivedCallback: () -> ()
): CurrentVisitorState?
	if currentVisitor ~= nil or currentVisitorIndex >= #visitorList then
		return nil
	end

	currentVisitorIndex += 1
	local profile = visitorList[currentVisitorIndex]

	local newState: CurrentVisitorState = {
		profile = profile,
		model = nil,
		arrivedAtLoket = false,
		cardRequested = false,
	}
	currentVisitor = newState

	newState.model = spawnSingleVisitorModel(
		profile.displayName,
		profile.visitorType,
		profile.shirtColor,
		function(player: Player)
			if newState.arrivedAtLoket then
				onInteractVisitorLoket(player)
			end
		end,
		function()
			if currentVisitor == newState then
				newState.arrivedAtLoket = true
				onVisitorArrivedCallback()
			end
		end
	)

	return newState
end

function VisitorService.TakeCurrentVisitorForDecision(): CurrentVisitorState?
	local activeVis = currentVisitor
	currentVisitor = nil
	return activeVis
end

function VisitorService.DismissVisitor(npc: Model?, accepted: boolean, onFinished: () -> ())
	EnvironmentService.SetLoketPromptActive(false)
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
		local acceptPath = {
			MapWaypoints.LOKET_STAND,
			MapWaypoints.ROAD_TURN_POINT,
			MapWaypoints.ACCEPT_CAMPUS_DEST,
		}
		walkVisitorPath(npc, acceptPath, MapWaypoints.ACCEPT_CAMPUS_DEST + Vector3.new(-10, 0, 0), 8.0, function()
			if npc and npc.Parent then
				npc:Destroy()
			end
			onFinished()
		end)
	else
		local rejectPath = {
			MapWaypoints.LOKET_STAND,
			MapWaypoints.ROAD_TURN_POINT,
			MapWaypoints.REJECT_OUTSIDE_DEST,
		}
		walkVisitorPath(npc, rejectPath, MapWaypoints.REJECT_OUTSIDE_DEST + Vector3.new(10, 0, 0), 8.0, function()
			if npc and npc.Parent then
				npc:Destroy()
			end
			onFinished()
		end)
	end
end

return VisitorService
