--!strict
-- ShiftService.luau
-- Service Server utama yang mengoordinasikan siklus hidup shift (Shift Lifecycle):
-- 1. Mengatur fase shift: WaitingForGate -> Active -> Result / GameOver.
-- 2. Menghitung jam kerja malam (22:00 - 06:00), akurasi, peringkat (S/A/B/C/D), dan gaji coins.
-- 3. Mengelola RemoteEvents di ReplicatedStorage.Remotes dan memvalidasi seluruh aksi Client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RemoteNames = require(Shared:WaitForChild("Constants"):WaitForChild("RemoteNames"))

local AnomalyService = require(script.Parent:WaitForChild("AnomalyService"))
local EnvironmentService = require(script.Parent:WaitForChild("EnvironmentService"))
local InvestigationService = require(script.Parent:WaitForChild("InvestigationService"))
local SanityService = require(script.Parent:WaitForChild("SanityService"))
local VisitorService = require(script.Parent:WaitForChild("VisitorService"))

local ShiftService = {}

local stateSyncEvent: RemoteEvent = nil :: any
local openPanelEvent: RemoteEvent = nil :: any
local jumpscareEvent: RemoteEvent = nil :: any
local actionEvent: RemoteEvent = nil :: any

local shiftNumber = 1
local phase: "WaitingForGate" | "Active" | "Result" | "GameOver" = "WaitingForGate"
local isTransitioning = false

local stats = {
	totalVisitors = GameConfig.SHIFT.VISITORS_PER_SHIFT,
	totalAnomaliesInShift = 0,
	processed = 0,
	correct = 0,
	normalAccepted = 0,
	anomalyRejected = 0,
	anomalyPassed = 0,
	normalRejected = 0,
}

local shiftReport: any = nil
local gameOverData: any = nil

local function getClockString(): string
	local progress = math.clamp(stats.processed / math.max(1, stats.totalVisitors), 0, 1)
	local totalHours = 8 * progress
	local hour = (GameConfig.SHIFT.START_HOUR + math.floor(totalHours)) % 24
	local min = math.floor((totalHours % 1) * 60)
	return string.format("%02d:%02d", hour, min)
end

function ShiftService.BroadcastState()
	local payload = {
		phase = phase,
		shiftNumber = shiftNumber,
		clockText = getClockString(),
		visitorIndex = VisitorService.GetCurrentVisitorIndex(),
		totalVisitors = stats.totalVisitors,
		currentVisitor = VisitorService.GetClientVisitorData(),
		shiftReport = shiftReport,
		gameOverData = gameOverData,
		sanity = SanityService.GetSanity(),
		isBlackout = AnomalyService.IsBlackout(),
		investigation = InvestigationService.GetProgressSummary(),
	}

	stateSyncEvent:FireAllClients(payload)
end

local function triggerSanityDepletedGameOver()
	if phase == "GameOver" then
		return
	end
	phase = "GameOver"
	isTransitioning = false
	gameOverData = {
		shiftNumber = shiftNumber,
		killerName = "Kegelapan & Halusinasi",
		anomalyType = "Sanity Depleted",
		explanation = "Kondisi mental pemain runtuh karena terlalu lama berada dalam kegelapan pos satpam.",
	}
	jumpscareEvent:FireAllClients(gameOverData)
	ShiftService.BroadcastState()
end

local function finishShiftAndCalculateReport()
	phase = "Result"
	AnomalyService.ResetForShift()
	EnvironmentService.SetGateOpen(false)

	local accuracy = math.floor((stats.correct / math.max(1, stats.totalVisitors)) * 100 + 0.5)
	local rank = GameConfig.CalculateRank(accuracy, stats.anomalyPassed)
	local salary = math.max(
		GameConfig.SCORING.MIN_SALARY,
		GameConfig.SCORING.BASE_SALARY
			+ (stats.correct * GameConfig.SCORING.CORRECT_DECISION)
			+ (stats.anomalyPassed * GameConfig.SCORING.ANOMALY_PASSED)
			+ (stats.normalRejected * GameConfig.SCORING.NORMAL_REJECTED)
	)

	shiftReport = {
		shiftNumber = shiftNumber,
		totalVisitors = stats.totalVisitors,
		totalAnomaliesInShift = stats.totalAnomaliesInShift,
		correct = stats.correct,
		normalAccepted = stats.normalAccepted,
		anomalyRejected = stats.anomalyRejected,
		anomalyPassed = stats.anomalyPassed,
		normalRejected = stats.normalRejected,
		accuracy = accuracy,
		rank = rank,
		salary = salary,
	}
	ShiftService.BroadcastState()
end

local function spawnNextVisitorInShift()
	if phase ~= "Active" or VisitorService.GetCurrentVisitor() ~= nil or isTransitioning then
		return
	end

	if not VisitorService.HasRemainingVisitors() then
		finishShiftAndCalculateReport()
		return
	end

	VisitorService.SpawnNextVisitor(
		function(player: Player)
			openPanelEvent:FireClient(player, RemoteNames.PANELS.LOKET)
		end,
		function()
			ShiftService.BroadcastState()
		end
	)

	ShiftService.BroadcastState()
end

function ShiftService.StartShift(targetShift: number)
	local isNewGame = (targetShift == 1 and shiftNumber == 1 and stats.processed == 0)

	shiftNumber = targetShift
	phase = "WaitingForGate"
	isTransitioning = false
	shiftReport = nil
	gameOverData = nil

	SanityService.ResetForShift(isNewGame)
	AnomalyService.ResetForShift()
	InvestigationService.ResetForShift()

	EnvironmentService.SetGateOpen(false)
	EnvironmentService.SetGateTutorialActive(true)

	local totalCount, anomalyCount = VisitorService.PrepareShiftVisitors(GameConfig.SHIFT.VISITORS_PER_SHIFT)

	stats = {
		totalVisitors = totalCount,
		totalAnomaliesInShift = anomalyCount,
		processed = 0,
		correct = 0,
		normalAccepted = 0,
		anomalyRejected = 0,
		anomalyPassed = 0,
		normalRejected = 0,
	}

	ShiftService.BroadcastState()
end

local function handleGateOpenedByPlayer()
	if phase ~= "WaitingForGate" then
		return
	end

	phase = "Active"
	EnvironmentService.SetGateTutorialActive(false)
	EnvironmentService.SetGateOpen(true)
	ShiftService.BroadcastState()

	task.delay(2.0, function()
		spawnNextVisitorInShift()
	end)
end

local function handleDecision(_player: Player, accept: boolean)
	local currentVis = VisitorService.GetCurrentVisitor()
	-- Validasi server: keputusan hanya sah jika pengunjung sudah tiba di loket
	if phase ~= "Active" or not currentVis or not currentVis.arrivedAtLoket or isTransitioning then
		return
	end

	isTransitioning = true
	local activeVis = VisitorService.TakeCurrentVisitorForDecision()
	if not activeVis then
		isTransitioning = false
		return
	end

	local prof = activeVis.profile
	stats.processed += 1
	SanityService.ApplyDecisionCost()

	if AnomalyService.ShouldTriggerBlackout(stats.processed) then
		task.delay(1.0, function()
			AnomalyService.TriggerBlackout(
				function()
					return phase == "Active"
				end,
				function()
					ShiftService.BroadcastState()
				end,
				triggerSanityDepletedGameOver
			)
		end)
	end

	openPanelEvent:FireAllClients(RemoteNames.PANELS.CLOSE_LOKET)
	ShiftService.BroadcastState()

	if accept then
		if not prof.isAnomaly then
			stats.correct += 1
			stats.normalAccepted += 1
		else
			stats.anomalyPassed += 1

			local isLethal = AnomalyService.HandleAcceptedAnomaly(
				prof,
				activeVis.model,
				shiftNumber,
				function(killPayload: any)
					phase = "GameOver"
					isTransitioning = false
					gameOverData = killPayload
					jumpscareEvent:FireAllClients(gameOverData)
					ShiftService.BroadcastState()
				end
			)
			if isLethal then
				return
			end
		end
	else
		if prof.isAnomaly then
			stats.correct += 1
			stats.anomalyRejected += 1
		else
			stats.normalRejected += 1
		end
	end

	VisitorService.DismissVisitor(activeVis.model, accept, function()
		if phase ~= "Active" then
			isTransitioning = false
			return
		end
		task.delay(GameConfig.SHIFT.NEXT_VISITOR_DELAY, function()
			isTransitioning = false
			spawnNextVisitorInShift()
		end)
	end)
end

-- Validasi seluruh permintaan dari Client di sisi Server
local function onClientAction(player: Player, actionType: string, payload: any)
	if type(actionType) ~= "string" then
		return
	end
	payload = if type(payload) == "table" then payload else {}

	if actionType == RemoteNames.ACTIONS.REQUEST_CARD then
		if phase == "Active" and VisitorService.MarkCardRequested() then
			ShiftService.BroadcastState()
		end
	elseif actionType == RemoteNames.ACTIONS.DECISION then
		handleDecision(player, payload.accept == true)
	elseif actionType == RemoteNames.ACTIONS.NEXT_SHIFT then
		if phase == "Result" then
			ShiftService.StartShift(shiftNumber + 1)
		end
	elseif actionType == RemoteNames.ACTIONS.RETRY_SHIFT then
		if phase == "GameOver" then
			ShiftService.StartShift(shiftNumber)
		end
	elseif actionType == RemoteNames.ACTIONS.POWER_REPAIRED then
		if phase == "Active" and AnomalyService.IsBlackout() then
			AnomalyService.RestorePower(function()
				ShiftService.BroadcastState()
			end)
		end
	elseif actionType == RemoteNames.ACTIONS.COLLECT_EVIDENCE then
		if phase == "Active" and InvestigationService.CollectEvidence(tostring(payload.evidenceId or "")) then
			ShiftService.BroadcastState()
		end
	end
end

local function setupRemotes()
	local existingFolder = ReplicatedStorage:FindFirstChild(RemoteNames.FOLDER_NAME)
	if existingFolder then
		existingFolder:Destroy()
	end

	local remotes = Instance.new("Folder")
	remotes.Name = RemoteNames.FOLDER_NAME
	remotes.Parent = ReplicatedStorage

	stateSyncEvent = Instance.new("RemoteEvent")
	stateSyncEvent.Name = RemoteNames.EVENTS.STATE_SYNC
	stateSyncEvent.Parent = remotes

	openPanelEvent = Instance.new("RemoteEvent")
	openPanelEvent.Name = RemoteNames.EVENTS.OPEN_PANEL
	openPanelEvent.Parent = remotes

	jumpscareEvent = Instance.new("RemoteEvent")
	jumpscareEvent.Name = RemoteNames.EVENTS.JUMPSCARE
	jumpscareEvent.Parent = remotes

	actionEvent = Instance.new("RemoteEvent")
	actionEvent.Name = RemoteNames.EVENTS.CLIENT_ACTION
	actionEvent.Parent = remotes
end

function ShiftService.Init()
	setupRemotes()
	VisitorService.Init()
	InvestigationService.Init()

	EnvironmentService.Init({
		onOpenGateStartShift = function(_player: Player)
			handleGateOpenedByPlayer()
		end,
		onInteractLoket = function(player: Player)
			local curVis = VisitorService.GetCurrentVisitor()
			if curVis and curVis.arrivedAtLoket then
				openPanelEvent:FireClient(player, RemoteNames.PANELS.LOKET)
			end
		end,
		onInteractLaptopData = function(player: Player)
			openPanelEvent:FireClient(player, RemoteNames.PANELS.LAPTOP_DATA)
		end,
		onInteractPcCctv = function(player: Player)
			openPanelEvent:FireClient(player, RemoteNames.PANELS.PC_CCTV)
		end,
		onInteractPowerPanel = function(player: Player)
			if AnomalyService.IsBlackout() then
				openPanelEvent:FireClient(player, RemoteNames.PANELS.WIRING_MINIGAME)
			end
		end,
	})

	actionEvent.OnServerEvent:Connect(onClientAction)

	Players.PlayerAdded:Connect(function()
		task.delay(1.0, function()
			ShiftService.BroadcastState()
		end)
	end)

	ShiftService.StartShift(1)
end

return ShiftService
