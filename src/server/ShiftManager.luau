--!strict
-- ShiftManager.luau
-- Mengatur alur shift:
-- 1. Pemain wajib membuka gerbang terlebih dahulu (Tahan E) baru pengunjung mulai datang satu per satu.
-- 2. Tidak ada notifikasi yang membocorkan apakah pengunjung tadi anomali atau bukan saat keputusan diambil.
-- 3. Jika anomali lolos: memicu kejadian aneh (lampu berkedip) atau menyerang pemain dengan Jumpscare & langsung mati di tempat.
-- 4. Jumlah anomali baru diketahui di laporan akhir shift (atau saat mati diserang anomali).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local VisitorGenerator = require(Shared:WaitForChild("VisitorGenerator"))
local MapBinder = require(script.Parent:WaitForChild("MapBinder"))

local ShiftManager = {}

local stateSyncEvent: RemoteEvent = nil :: any
local openPanelEvent: RemoteEvent = nil :: any
local jumpscareEvent: RemoteEvent = nil :: any
local actionEvent: RemoteEvent = nil :: any

type CurrentVisitorState = {
	profile: VisitorGenerator.VisitorProfile,
	model: Model?,
	arrivedAtLoket: boolean,
	cardRequested: boolean,
}

local shiftNumber = 1
local phase: "WaitingForGate" | "Active" | "Result" | "GameOver" = "WaitingForGate"
local visitorList: { VisitorGenerator.VisitorProfile } = {}
local currentVisitorIndex = 0
local currentVisitor: CurrentVisitorState? = nil
local isTransitioning = false

local stats = {
	totalVisitors = 5,
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

function ShiftManager.BroadcastState()
	local visitorClientData = nil
	if currentVisitor then
		visitorClientData = {
			profile = VisitorGenerator.SanitizeForClient(currentVisitor.profile),
			arrivedAtLoket = currentVisitor.arrivedAtLoket,
			cardRequested = currentVisitor.cardRequested,
		}
	end

	local payload = {
		phase = phase,
		shiftNumber = shiftNumber,
		clockText = getClockString(),
		visitorIndex = currentVisitorIndex,
		totalVisitors = stats.totalVisitors,
		currentVisitor = visitorClientData,
		shiftReport = shiftReport,
		gameOverData = gameOverData,
	}

	stateSyncEvent:FireAllClients(payload)
end

local function spawnNextVisitor()
	if phase ~= "Active" or currentVisitor ~= nil or isTransitioning then
		return
	end

	if currentVisitorIndex >= #visitorList then
		-- Seluruh pengunjung pada shift ini sudah diproses -> baru tampilkan laporan anomali shift
		phase = "Result"
		MapBinder.SetGateOpen(false)

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
		ShiftManager.BroadcastState()
		return
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

	newState.model = MapBinder.SpawnSingleVisitor(
		profile.displayName,
		profile.visitorType,
		profile.shirtColor,
		function(player: Player)
			if newState.arrivedAtLoket then
				openPanelEvent:FireClient(player, "Loket")
			end
		end,
		function()
			if currentVisitor == newState then
				newState.arrivedAtLoket = true
				ShiftManager.BroadcastState()
			end
		end
	)

	ShiftManager.BroadcastState()
end

function ShiftManager.StartShift(targetShift: number)
	shiftNumber = targetShift
	phase = "WaitingForGate"
	isTransitioning = false
	currentVisitor = nil
	currentVisitorIndex = 0
	shiftReport = nil
	gameOverData = nil

	MapBinder.CleanupAllVisitors()
	MapBinder.SetGateOpen(false)
	MapBinder.SetGateTutorialActive(true)

	visitorList = VisitorGenerator.GenerateShiftList(GameConfig.SHIFT.VISITORS_PER_SHIFT)
	local anomalyCount = 0
	for _, v in ipairs(visitorList) do
		if v.isAnomaly then
			anomalyCount += 1
		end
	end

	stats = {
		totalVisitors = #visitorList,
		totalAnomaliesInShift = anomalyCount,
		processed = 0,
		correct = 0,
		normalAccepted = 0,
		anomalyRejected = 0,
		anomalyPassed = 0,
		normalRejected = 0,
	}

	ShiftManager.BroadcastState()
end

local function handleGateOpenedByPlayer()
	if phase ~= "WaitingForGate" then
		return
	end

	phase = "Active"
	MapBinder.SetGateTutorialActive(false)
	MapBinder.SetGateOpen(true)
	ShiftManager.BroadcastState()

	-- Setelah gerbang dibuka oleh pemain, pengunjung pertama mulai datang
	task.delay(2.0, function()
		spawnNextVisitor()
	end)
end

local function handleDecision(_player: Player, accept: boolean)
	if phase ~= "Active" or not currentVisitor or isTransitioning then
		return
	end

	isTransitioning = true
	local activeVis = currentVisitor
	local prof = activeVis.profile
	currentVisitor = nil

	stats.processed += 1

	-- Tutup panel loket tanpa memberi notifikasi benar/salah di atas layar
	openPanelEvent:FireAllClients("CloseLoket")
	ShiftManager.BroadcastState()

	if accept then
		if not prof.isAnomaly then
			stats.correct += 1
			stats.normalAccepted += 1
		else
			stats.anomalyPassed += 1

			-- Cek konsekuensi jika anomali dibiarkan masuk
			if prof.consequenceIfAccepted == "JumpscareKill" then
				-- Anomali berjalan sebentar lalu langsung menyerang pemain dengan Jumpscare & mati di tempat!
				task.delay(1.8, function()
					if activeVis.model and activeVis.model.Parent then
						activeVis.model:Destroy()
					end
					phase = "GameOver"
					isTransitioning = false
					gameOverData = {
						shiftNumber = shiftNumber,
						killerName = prof.displayName,
						anomalyType = prof.anomalyType or "Anomali",
						explanation = prof.explanation,
					}
					jumpscareEvent:FireAllClients(gameOverData)
					ShiftManager.BroadcastState()
				end)
				return
			elseif prof.consequenceIfAccepted == "WeirdEvent" then
				-- Kejadian aneh: lampu Pos Satpam berkedip-kedip tanpa teks bocoran
				task.delay(2.2, function()
					MapBinder.TriggerWeirdFlicker()
				end)
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

	MapBinder.DismissCurrentVisitor(activeVis.model, accept, function()
		if phase ~= "Active" then
			isTransitioning = false
			return
		end
		task.delay(GameConfig.SHIFT.NEXT_VISITOR_DELAY, function()
			isTransitioning = false
			spawnNextVisitor()
		end)
	end)
end

local function onClientAction(player: Player, actionType: string, payload: any)
	payload = if type(payload) == "table" then payload else {}

	if actionType == "RequestCard" then
		if currentVisitor then
			currentVisitor.cardRequested = true
			ShiftManager.BroadcastState()
		end
	elseif actionType == "Decision" then
		handleDecision(player, payload.accept == true)
	elseif actionType == "NextShift" then
		ShiftManager.StartShift(shiftNumber + 1)
	elseif actionType == "RetryShift" then
		ShiftManager.StartShift(shiftNumber)
	end
end

function ShiftManager.Init()
	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage

	stateSyncEvent = Instance.new("RemoteEvent")
	stateSyncEvent.Name = "StateSync"
	stateSyncEvent.Parent = remotes

	openPanelEvent = Instance.new("RemoteEvent")
	openPanelEvent.Name = "OpenPanel"
	openPanelEvent.Parent = remotes

	jumpscareEvent = Instance.new("RemoteEvent")
	jumpscareEvent.Name = "Jumpscare"
	jumpscareEvent.Parent = remotes

	actionEvent = Instance.new("RemoteEvent")
	actionEvent.Name = "ClientAction"
	actionEvent.Parent = remotes

	MapBinder.Init({
		onOpenGateStartShift = function(_player: Player)
			handleGateOpenedByPlayer()
		end,
		onInteractLoket = function(player: Player)
			if currentVisitor and currentVisitor.arrivedAtLoket then
				openPanelEvent:FireClient(player, "Loket")
			end
		end,
		onInteractLaptopData = function(player: Player)
			openPanelEvent:FireClient(player, "LaptopData")
		end,
		onInteractPcCctv = function(player: Player)
			openPanelEvent:FireClient(player, "PcCctv")
		end,
	})

	actionEvent.OnServerEvent:Connect(onClientAction)

	Players.PlayerAdded:Connect(function()
		task.delay(1.0, function()
			ShiftManager.BroadcastState()
		end)
	end)

	ShiftManager.StartShift(1)
end

return ShiftManager
