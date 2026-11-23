--!strict
-- UIController.luau
-- Controller Client yang mengelola seluruh tampilan antarmuka (UI & HUD):
-- 1. HUD Status Shift & Jam Kerja (Kanan Atas) + Sanity Bar (Kiri Bawah) + Banner Peringatan Mati Listrik
-- 2. Dialog Pemeriksaan Pengunjung di Loket & Popup Kartu Identitas (KTM / ID Staf)
-- 3. Layar Laptop Data Kampus (4 Tab Referensi) & Navigasi Kamera CCTV + Layar No Signal saat Blackout
-- 4. Mini-Game Sambung Kabel Gardu Listrik (4 Warna: Merah, Biru, Kuning, Hijau)
-- 5. Layar Jumpscare, Game Over, dan Laporan Akhir Shift

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CampusDatabase = require(Shared:WaitForChild("Config"):WaitForChild("CampusDatabase"))
local RemoteNames = require(Shared:WaitForChild("Constants"):WaitForChild("RemoteNames"))

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))

local UIController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local sendAction: ((actionType: string, payload: any) -> ())? = nil
local latestState: any = nil

local loketOpen = false
local cardOpen = false
local laptopOpen = false
local activeComputerTab = 1

local currentSatpamLine = ""
local currentVisitorLine = ""

local screenGui: ScreenGui = nil :: any
local hudStatusLabel: TextLabel = nil :: any

local loketFrame: Frame = nil :: any
local npcNameLabel: TextLabel = nil :: any
local satpamQuestionLabel: TextLabel = nil :: any
local npcSpeechLabel: TextLabel = nil :: any

local cardFrame: Frame = nil :: any
local cardHeaderLabel: TextLabel = nil :: any
local cardBodyLabel: TextLabel = nil :: any

local cctvBlackoutScreen: Frame = nil :: any
local cctvBlackoutText: TextLabel = nil :: any

local sanityBarFill: Frame = nil :: any
local sanityLabel: TextLabel = nil :: any
local blackoutBanner: Frame = nil :: any

local wiringFrame: Frame = nil :: any
local wiringFeedbackLabel: TextLabel = nil :: any
local wiringConnectedCount = 0
local selectedLeftWire: TextButton? = nil
local activeWireConnections: { [string]: boolean } = {}
local wireColors = {
	{ name = "Merah", color = Color3.fromRGB(235, 65, 65) },
	{ name = "Biru", color = Color3.fromRGB(55, 125, 235) },
	{ name = "Kuning", color = Color3.fromRGB(240, 205, 50) },
	{ name = "Hijau", color = Color3.fromRGB(50, 205, 90) },
}

local laptopFrame: Frame = nil :: any
local laptopScroll: ScrollingFrame = nil :: any
local tabButtons: { TextButton } = {}

local cctvBar: Frame = nil :: any
local cctvTitleLabel: TextLabel = nil :: any

local jumpscareOverlay: Frame = nil :: any
local gameOverFrame: Frame = nil :: any
local gameOverBodyLabel: TextLabel = nil :: any

local resultFrame: Frame = nil :: any
local resultBodyLabel: TextLabel = nil :: any

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function addStroke(parent: Instance, color: Color3)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 1
	s.Parent = parent
end

local function makeButton(parent: Instance, text: string, pos: UDim2, size: UDim2, bgColor: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.Position = pos
	btn.Size = size
	btn.BackgroundColor3 = bgColor
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(240, 240, 240)
	btn.Font = Enum.Font.SourceSansSemibold
	btn.TextSize = 15
	btn.AutoButtonColor = true
	btn.Parent = parent
	addCorner(btn, 4)
	return btn
end

local function refreshLaptopContent()
	if not laptopFrame or not laptopFrame.Visible then
		return
	end

	for i, btn in ipairs(tabButtons) do
		btn.BackgroundColor3 = if i == activeComputerTab then Color3.fromRGB(55, 85, 120) else Color3.fromRGB(35, 40, 48)
	end

	for _, child in ipairs(laptopScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local lines: { { title: string, sub: string } } = {}
	if activeComputerTab == 1 then
		for _, r in ipairs(CampusDatabase.PenghuniAsrama) do
			table.insert(lines, {
				title = r.nama .. "  |  NIM: " .. r.nim .. "  (" .. r.prodi .. ")",
				sub = "Kamar: " .. r.kamar .. "  |  Keterangan: " .. r.keterangan,
			})
		end
	elseif activeComputerTab == 2 then
		for _, r in ipairs(CampusDatabase.PeminjamanRuangan) do
			table.insert(lines, {
				title = r.peminjam .. "  |  NIM: " .. r.nim .. "  (" .. r.prodi .. ")",
				sub = "Ruang: " .. r.ruang .. "  |  Jam: " .. r.jam,
			})
		end
	elseif activeComputerTab == 3 then
		for _, r in ipairs(CampusDatabase.JadwalKegiatan) do
			table.insert(lines, {
				title = r.organisasi .. "  —  PJ: " .. r.penanggungJawab .. " (NIM: " .. r.nim .. ")",
				sub = "Ruang: " .. r.ruang .. "  |  Jam: " .. r.jam .. "  |  " .. r.kegiatan,
			})
		end
	else
		for _, r in ipairs(CampusDatabase.DosenDanStaf) do
			table.insert(lines, {
				title = r.nama .. "  |  ID: " .. r.idStaf .. "  (" .. r.unit .. ")",
				sub = "Lokasi: " .. r.ruang .. "  |  Jadwal: " .. r.jadwal,
			})
		end
	end

	for idx, item in ipairs(lines) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 52)
		row.Position = UDim2.new(0, 0, 0, (idx - 1) * 58)
		row.BackgroundColor3 = Color3.fromRGB(28, 32, 38)
		row.BorderSizePixel = 0
		row.Parent = laptopScroll
		addCorner(row, 4)

		local t = Instance.new("TextLabel")
		t.Position = UDim2.new(0, 10, 0, 4)
		t.Size = UDim2.new(1, -20, 0, 20)
		t.BackgroundTransparency = 1
		t.Text = item.title
		t.TextColor3 = Color3.fromRGB(235, 240, 245)
		t.Font = Enum.Font.SourceSansBold
		t.TextSize = 15
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Parent = row

		local s = Instance.new("TextLabel")
		s.Position = UDim2.new(0, 10, 0, 26)
		s.Size = UDim2.new(1, -20, 0, 20)
		s.BackgroundTransparency = 1
		s.Text = item.sub
		s.TextColor3 = Color3.fromRGB(180, 190, 205)
		s.Font = Enum.Font.SourceSans
		s.TextSize = 14
		s.TextXAlignment = Enum.TextXAlignment.Left
		s.Parent = row
	end

	laptopScroll.CanvasSize = UDim2.new(0, 0, 0, #lines * 58)
end

function UIController.Refresh()
	if not latestState then
		return
	end

	if latestState.phase == "WaitingForGate" then
		hudStatusLabel.Text = string.format("Shift %d   |   Tugas: Buka Gerbang [Tahan E]", latestState.shiftNumber or 1)
	else
		hudStatusLabel.Text = string.format(
			"Shift %d   |   %s   |   Pengunjung: %d/%d",
			latestState.shiftNumber or 1,
			latestState.clockText or "22:00",
			latestState.visitorIndex or 0,
			latestState.totalVisitors or 5
		)
	end

	local curVis = latestState.currentVisitor
	local canOpenLoket = (curVis ~= nil and curVis.arrivedAtLoket == true)
	if not curVis or not curVis.arrivedAtLoket then
		loketOpen = false
		cardOpen = false
	end

	local cctvOpen = CameraController.IsCctvOpen()
	loketFrame.Visible = loketOpen and canOpenLoket and (not cctvOpen)
	cardFrame.Visible = cardOpen and canOpenLoket and (not cctvOpen)
	laptopFrame.Visible = laptopOpen and (not cctvOpen)
	cctvBar.Visible = cctvOpen

	local sanity = latestState.sanity or 100
	if sanityBarFill and sanityLabel then
		local alpha = math.clamp(sanity / 100, 0, 1)
		sanityBarFill.Size = UDim2.new(alpha, 0, 1, 0)
		sanityBarFill.BackgroundColor3 = if sanity <= 30
			then Color3.fromRGB(235, 55, 55)
			elseif sanity <= 60 then Color3.fromRGB(235, 175, 45)
			else Color3.fromRGB(60, 195, 105)
		sanityLabel.Text = string.format("🧠 Sanity: %d%%", math.floor(sanity))
		sanityLabel.TextColor3 = if sanity <= 30 then Color3.fromRGB(255, 110, 110) else Color3.fromRGB(235, 240, 245)
	end

	local isBlackoutNow = (latestState.isBlackout == true)
	if blackoutBanner then
		blackoutBanner.Visible = isBlackoutNow
	end

	if cctvBlackoutScreen then
		cctvBlackoutScreen.Visible = cctvOpen and isBlackoutNow
	end

	if cctvOpen then
		cctvTitleLabel.Text = CameraController.GetCurrentCctvName()
	end

	if curVis and curVis.profile then
		local p = curVis.profile
		npcNameLabel.Text = p.displayName .. "  (" .. p.visitorType .. ")"

		if currentVisitorLine == "" then
			currentSatpamLine = ""
			currentVisitorLine = p.greeting
		end

		if currentSatpamLine ~= "" then
			satpamQuestionLabel.Visible = true
			satpamQuestionLabel.Text = 'Satpam: "' .. currentSatpamLine .. '"'
			npcSpeechLabel.Position = UDim2.new(0, 14, 0, 56)
			npcSpeechLabel.Size = UDim2.new(1, -28, 0, 38)
		else
			satpamQuestionLabel.Visible = false
			npcSpeechLabel.Position = UDim2.new(0, 14, 0, 36)
			npcSpeechLabel.Size = UDim2.new(1, -28, 0, 54)
		end

		npcSpeechLabel.Text = p.displayName .. ': "' .. currentVisitorLine .. '"'

		local c = p.card
		cardHeaderLabel.Text = c.institusi .. "\n" .. c.cardType
		cardBodyLabel.Text = string.format(
			"Nama          : %s\n%s           : %s\nProdi / Unit  : %s\nKeterangan    : %s\nMasa Berlaku  : %s",
			c.nama,
			c.labelNomorId,
			c.nomorId,
			c.prodiAtauUnit,
			c.angkatanAtauRuang,
			c.masaBerlaku
		)
	end

	refreshLaptopContent()

	local showResult = (latestState.phase == "Result" and latestState.shiftReport ~= nil)
	resultFrame.Visible = showResult
	if showResult then
		local r = latestState.shiftReport
		resultBodyLabel.Text = string.format(
			"Laporan Selesai Shift %d\n\n"
				.. "Total Pengunjung Datang  : %d\n"
				.. "Jumlah Anomali di Shift  : %d\n"
				.. "----------------------------------\n"
				.. "Pengunjung Normal Masuk  : %d\n"
				.. "Anomali Berhasil Ditolak : %d\n"
				.. "Anomali Lolos Masuk      : %d\n"
				.. "Normal Salah Ditolak     : %d\n"
				.. "----------------------------------\n"
				.. "Akurasi Pemeriksaan      : %d%%\n"
				.. "Peringkat Shift          : %s\n"
				.. "Gaji Diterima            : %d Coins",
			r.shiftNumber,
			r.totalVisitors,
			r.totalAnomaliesInShift or 0,
			r.normalAccepted,
			r.anomalyRejected,
			r.anomalyPassed,
			r.normalRejected,
			r.accuracy,
			r.rank,
			r.salary
		)
	end

	local showGameOver = (latestState.phase == "GameOver" and latestState.gameOverData ~= nil)
	if not showGameOver then
		gameOverFrame.Visible = false
	end
end

function UIController.CloseAllPanels()
	CameraController.StopCctv()
	loketOpen = false
	cardOpen = false
	laptopOpen = false
	if wiringFrame then
		wiringFrame.Visible = false
	end
	UIController.Refresh()
end

function UIController.TriggerJumpscare(data: any)
	UIController.CloseAllPanels()
	AudioController.PlayJumpscareSound(1.2)

	jumpscareOverlay.Visible = true
	local cam = Workspace.CurrentCamera
	local origCf = if cam then cam.CFrame else CFrame.new()

	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < 1.1 do
			jumpscareOverlay.BackgroundColor3 = if math.random() < 0.5
				then Color3.fromRGB(160, 15, 15)
				else Color3.fromRGB(10, 10, 12)
			CameraController.ApplyRandomShakeOffset(origCf)
			task.wait(0.04)
		end

		jumpscareOverlay.Visible = false

		if data then
			gameOverBodyLabel.Text = string.format(
				"Kamu tewas diserang oleh %s (%s) yang berhasil masuk melewati gerbang!\n\n"
					.. "Catatan Bukti:\n%s",
				tostring(data.killerName or "Anomali"),
				tostring(data.anomalyType or "Anomali"),
				tostring(data.explanation or "")
			)
		end
		gameOverFrame.Visible = true
	end)
end

function UIController.OpenPanel(panelName: string)
	if panelName == RemoteNames.PANELS.LOKET then
		if latestState and latestState.currentVisitor and latestState.currentVisitor.arrivedAtLoket then
			CameraController.StopCctv()
			loketOpen = true
			laptopOpen = false
			UIController.Refresh()
		end
	elseif panelName == RemoteNames.PANELS.CLOSE_LOKET then
		loketOpen = false
		cardOpen = false
		UIController.Refresh()
	elseif panelName == RemoteNames.PANELS.LAPTOP_DATA then
		if latestState and latestState.isBlackout then
			return
		end
		CameraController.StopCctv()
		laptopOpen = true
		loketOpen = false
		cardOpen = false
		UIController.Refresh()
	elseif panelName == RemoteNames.PANELS.PC_CCTV then
		loketOpen = false
		cardOpen = false
		laptopOpen = false
		CameraController.StartCctv(CameraController.GetCurrentCctvIndex())
		UIController.Refresh()
	elseif panelName == RemoteNames.PANELS.WIRING_MINIGAME then
		CameraController.StopCctv()
		loketOpen = false
		cardOpen = false
		laptopOpen = false
		if wiringFrame then
			wiringFrame.Visible = true
		end
	end
end

function UIController.OnStateSync(newState: any)
	local oldUid = latestState and latestState.currentVisitor and latestState.currentVisitor.profile and latestState.currentVisitor.profile.uid
	local newUid = newState and newState.currentVisitor and newState.currentVisitor.profile and newState.currentVisitor.profile.uid
	if oldUid ~= newUid then
		currentSatpamLine = ""
		currentVisitorLine = ""
		cardOpen = false
	end

	latestState = newState
	UIController.Refresh()
end

function UIController.Init(onAction: (actionType: string, payload: any) -> ())
	sendAction = onAction

	for _, name in ipairs({ "ITKAnomaliesGui", "ITKAnomaliesHUD", "InputOverlay", "RuntimeInput" }) do
		local old = playerGui:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ITKAnomaliesGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- 1. Indikator status di kanan atas
	local topRightBox = Instance.new("Frame")
	topRightBox.Position = UDim2.new(1, -320, 0, 12)
	topRightBox.Size = UDim2.new(0, 308, 0, 32)
	topRightBox.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
	topRightBox.BackgroundTransparency = 0.2
	topRightBox.BorderSizePixel = 0
	topRightBox.Parent = screenGui
	addCorner(topRightBox, 5)
	addStroke(topRightBox, Color3.fromRGB(65, 75, 90))

	hudStatusLabel = Instance.new("TextLabel")
	hudStatusLabel.Size = UDim2.new(1, -16, 1, 0)
	hudStatusLabel.Position = UDim2.new(0, 8, 0, 0)
	hudStatusLabel.BackgroundTransparency = 1
	hudStatusLabel.Text = "Shift 1   |   Tugas: Buka Gerbang [Tahan E]"
	hudStatusLabel.TextColor3 = Color3.fromRGB(230, 235, 240)
	hudStatusLabel.Font = Enum.Font.SourceSansSemibold
	hudStatusLabel.TextSize = 15
	hudStatusLabel.Parent = topRightBox

	-- 1B. Sanity Bar (Kiri Bawah sesuai GDD Bab 8.3)
	local sanityBox = Instance.new("Frame")
	sanityBox.Position = UDim2.new(0, 16, 1, -48)
	sanityBox.Size = UDim2.new(0, 200, 0, 30)
	sanityBox.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
	sanityBox.BackgroundTransparency = 0.2
	sanityBox.BorderSizePixel = 0
	sanityBox.Parent = screenGui
	addCorner(sanityBox, 5)
	addStroke(sanityBox, Color3.fromRGB(65, 75, 90))

	local sanityBg = Instance.new("Frame")
	sanityBg.Position = UDim2.new(0, 8, 0, 6)
	sanityBg.Size = UDim2.new(1, -16, 0, 18)
	sanityBg.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
	sanityBg.BorderSizePixel = 0
	sanityBg.Parent = sanityBox
	addCorner(sanityBg, 3)

	sanityBarFill = Instance.new("Frame")
	sanityBarFill.Size = UDim2.new(1, 0, 1, 0)
	sanityBarFill.BackgroundColor3 = Color3.fromRGB(60, 195, 105)
	sanityBarFill.BorderSizePixel = 0
	sanityBarFill.Parent = sanityBg
	addCorner(sanityBarFill, 3)

	sanityLabel = Instance.new("TextLabel")
	sanityLabel.Size = UDim2.new(1, 0, 1, 0)
	sanityLabel.BackgroundTransparency = 1
	sanityLabel.Text = "🧠 Sanity: 100%"
	sanityLabel.TextColor3 = Color3.fromRGB(240, 245, 250)
	sanityLabel.Font = Enum.Font.SourceSansBold
	sanityLabel.TextSize = 13
	sanityLabel.Parent = sanityBg

	-- 1C. Banner Peringatan Mati Listrik
	blackoutBanner = Instance.new("Frame")
	blackoutBanner.Position = UDim2.new(0.5, -210, 0, 52)
	blackoutBanner.Size = UDim2.new(0, 420, 0, 34)
	blackoutBanner.BackgroundColor3 = Color3.fromRGB(175, 35, 35)
	blackoutBanner.BorderSizePixel = 0
	blackoutBanner.Visible = false
	blackoutBanner.Parent = screenGui
	addCorner(blackoutBanner, 4)
	addStroke(blackoutBanner, Color3.fromRGB(245, 180, 180))

	local blackoutText = Instance.new("TextLabel")
	blackoutText.Size = UDim2.new(1, 0, 1, 0)
	blackoutText.BackgroundTransparency = 1
	blackoutText.Text = "⚡ LISTRIK POS PADAM! Ikuti Highlight Kuning menuju Gardu Listrik!"
	blackoutText.TextColor3 = Color3.fromRGB(255, 255, 255)
	blackoutText.Font = Enum.Font.SourceSansBold
	blackoutText.TextSize = 14
	blackoutText.Parent = blackoutBanner

	-- 2. Kotak Dialog Loket
	loketFrame = Instance.new("Frame")
	loketFrame.Position = UDim2.new(0.5, -270, 1, -180)
	loketFrame.Size = UDim2.new(0, 540, 0, 165)
	loketFrame.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
	loketFrame.BackgroundTransparency = 0.06
	loketFrame.BorderSizePixel = 0
	loketFrame.Visible = false
	loketFrame.Parent = screenGui
	addCorner(loketFrame, 6)
	addStroke(loketFrame, Color3.fromRGB(70, 80, 95))

	npcNameLabel = Instance.new("TextLabel")
	npcNameLabel.Position = UDim2.new(0, 14, 0, 8)
	npcNameLabel.Size = UDim2.new(1, -90, 0, 22)
	npcNameLabel.BackgroundTransparency = 1
	npcNameLabel.Text = "Pengunjung"
	npcNameLabel.TextColor3 = Color3.fromRGB(240, 245, 250)
	npcNameLabel.Font = Enum.Font.SourceSansBold
	npcNameLabel.TextSize = 17
	npcNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	npcNameLabel.Parent = loketFrame

	local closeLoketBtn = makeButton(loketFrame, "Tutup", UDim2.new(1, -68, 0, 7), UDim2.new(0, 56, 0, 24), Color3.fromRGB(50, 55, 65))
	closeLoketBtn.MouseButton1Click:Connect(function()
		loketOpen = false
		cardOpen = false
		UIController.Refresh()
	end)

	satpamQuestionLabel = Instance.new("TextLabel")
	satpamQuestionLabel.Position = UDim2.new(0, 14, 0, 32)
	satpamQuestionLabel.Size = UDim2.new(1, -28, 0, 20)
	satpamQuestionLabel.BackgroundTransparency = 1
	satpamQuestionLabel.Text = ""
	satpamQuestionLabel.TextColor3 = Color3.fromRGB(150, 195, 240)
	satpamQuestionLabel.Font = Enum.Font.SourceSansItalic
	satpamQuestionLabel.TextSize = 15
	satpamQuestionLabel.TextWrapped = true
	satpamQuestionLabel.TextXAlignment = Enum.TextXAlignment.Left
	satpamQuestionLabel.Visible = false
	satpamQuestionLabel.Parent = loketFrame

	npcSpeechLabel = Instance.new("TextLabel")
	npcSpeechLabel.Position = UDim2.new(0, 14, 0, 54)
	npcSpeechLabel.Size = UDim2.new(1, -28, 0, 40)
	npcSpeechLabel.BackgroundTransparency = 1
	npcSpeechLabel.Text = ""
	npcSpeechLabel.TextColor3 = Color3.fromRGB(225, 232, 240)
	npcSpeechLabel.Font = Enum.Font.SourceSans
	npcSpeechLabel.TextSize = 16
	npcSpeechLabel.TextWrapped = true
	npcSpeechLabel.TextXAlignment = Enum.TextXAlignment.Left
	npcSpeechLabel.Parent = loketFrame

	local askCardBtn = makeButton(loketFrame, "1. Minta Kartu", UDim2.new(0, 14, 0, 102), UDim2.new(0, 114, 0, 30), Color3.fromRGB(42, 65, 95))
	askCardBtn.MouseButton1Click:Connect(function()
		if latestState and latestState.currentVisitor then
			local p = latestState.currentVisitor.profile
			currentSatpamLine = p.cardQuestion
			currentVisitorLine = p.cardResponse
			cardOpen = true
			if sendAction then
				sendAction(RemoteNames.ACTIONS.REQUEST_CARD, {})
			end
			UIController.Refresh()
		end
	end)

	local askReasonBtn = makeButton(loketFrame, "2. Tanya Tujuan", UDim2.new(0, 134, 0, 102), UDim2.new(0, 114, 0, 30), Color3.fromRGB(42, 65, 95))
	askReasonBtn.MouseButton1Click:Connect(function()
		if latestState and latestState.currentVisitor then
			local p = latestState.currentVisitor.profile
			currentSatpamLine = p.reasonQuestion
			currentVisitorLine = p.reasonResponse
			UIController.Refresh()
		end
	end)

	local askQuirkBtn = makeButton(loketFrame, "3. Tanya Gelagat", UDim2.new(0, 254, 0, 102), UDim2.new(0, 114, 0, 30), Color3.fromRGB(42, 65, 95))
	askQuirkBtn.MouseButton1Click:Connect(function()
		if latestState and latestState.currentVisitor then
			local p = latestState.currentVisitor.profile
			currentSatpamLine = p.quirkQuestion
			currentVisitorLine = p.quirkResponse
			UIController.Refresh()
		end
	end)

	local acceptBtn = makeButton(loketFrame, "Terima", UDim2.new(0, 380, 0, 102), UDim2.new(0, 70, 0, 50), Color3.fromRGB(40, 115, 65))
	acceptBtn.MouseButton1Click:Connect(function()
		if sendAction then
			sendAction(RemoteNames.ACTIONS.DECISION, { accept = true })
		end
	end)

	local rejectBtn = makeButton(loketFrame, "Tolak", UDim2.new(0, 456, 0, 102), UDim2.new(0, 70, 0, 50), Color3.fromRGB(135, 45, 45))
	rejectBtn.MouseButton1Click:Connect(function()
		if sendAction then
			sendAction(RemoteNames.ACTIONS.DECISION, { accept = false })
		end
	end)

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Position = UDim2.new(0, 14, 0, 136)
	hintLabel.Size = UDim2.new(0, 355, 0, 20)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "Cocokkan data kartu dengan Laptop di meja depan Pos Satpam."
	hintLabel.TextColor3 = Color3.fromRGB(145, 155, 170)
	hintLabel.Font = Enum.Font.SourceSans
	hintLabel.TextSize = 14
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = loketFrame

	-- 3. Kartu Identitas Popup
	cardFrame = Instance.new("Frame")
	cardFrame.Position = UDim2.new(0, 24, 0.5, -110)
	cardFrame.Size = UDim2.new(0, 340, 0, 210)
	cardFrame.BackgroundColor3 = Color3.fromRGB(235, 238, 242)
	cardFrame.BorderSizePixel = 0
	cardFrame.Visible = false
	cardFrame.Parent = screenGui
	addCorner(cardFrame, 6)
	addStroke(cardFrame, Color3.fromRGB(60, 80, 110))

	local cardTop = Instance.new("Frame")
	cardTop.Size = UDim2.new(1, 0, 0, 44)
	cardTop.BackgroundColor3 = Color3.fromRGB(28, 52, 88)
	cardTop.BorderSizePixel = 0
	cardTop.Parent = cardFrame
	addCorner(cardTop, 6)

	cardHeaderLabel = Instance.new("TextLabel")
	cardHeaderLabel.Position = UDim2.new(0, 12, 0, 4)
	cardHeaderLabel.Size = UDim2.new(1, -70, 1, -8)
	cardHeaderLabel.BackgroundTransparency = 1
	cardHeaderLabel.Text = "INSTITUT TEKNOLOGI KALIMANTAN\nKTM"
	cardHeaderLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
	cardHeaderLabel.Font = Enum.Font.SourceSansBold
	cardHeaderLabel.TextSize = 14
	cardHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
	cardHeaderLabel.Parent = cardTop

	local closeCardBtn = makeButton(cardTop, "X", UDim2.new(1, -34, 0, 8), UDim2.new(0, 26, 0, 26), Color3.fromRGB(120, 45, 45))
	closeCardBtn.MouseButton1Click:Connect(function()
		cardOpen = false
		UIController.Refresh()
	end)

	cardBodyLabel = Instance.new("TextLabel")
	cardBodyLabel.Position = UDim2.new(0, 14, 0, 54)
	cardBodyLabel.Size = UDim2.new(1, -28, 1, -64)
	cardBodyLabel.BackgroundTransparency = 1
	cardBodyLabel.Text = ""
	cardBodyLabel.TextColor3 = Color3.fromRGB(25, 30, 38)
	cardBodyLabel.Font = Enum.Font.RobotoMono
	cardBodyLabel.TextSize = 13
	cardBodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	cardBodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	cardBodyLabel.Parent = cardFrame

	-- 4. Layar Laptop Data Kampus
	laptopFrame = Instance.new("Frame")
	laptopFrame.Position = UDim2.new(0.5, -270, 0.5, -170)
	laptopFrame.Size = UDim2.new(0, 540, 0, 340)
	laptopFrame.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
	laptopFrame.BorderSizePixel = 0
	laptopFrame.Visible = false
	laptopFrame.Parent = screenGui
	addCorner(laptopFrame, 6)
	addStroke(laptopFrame, Color3.fromRGB(75, 90, 110))

	local compTitle = Instance.new("TextLabel")
	compTitle.Position = UDim2.new(0, 14, 0, 10)
	compTitle.Size = UDim2.new(1, -90, 0, 24)
	compTitle.BackgroundTransparency = 1
	compTitle.Text = "Laptop Data Kampus ITK"
	compTitle.TextColor3 = Color3.fromRGB(235, 240, 245)
	compTitle.Font = Enum.Font.SourceSansBold
	compTitle.TextSize = 18
	compTitle.TextXAlignment = Enum.TextXAlignment.Left
	compTitle.Parent = laptopFrame

	local closeCompBtn = makeButton(laptopFrame, "Tutup", UDim2.new(1, -72, 0, 10), UDim2.new(0, 58, 0, 26), Color3.fromRGB(55, 60, 70))
	closeCompBtn.MouseButton1Click:Connect(function()
		laptopOpen = false
		UIController.Refresh()
	end)

	local tabLabels = { "Penghuni Asrama", "Peminjaman Ruang", "Kegiatan Malam", "Dosen & Staf" }
	for i, lbl in ipairs(tabLabels) do
		local b = makeButton(
			laptopFrame,
			lbl,
			UDim2.new(0, 14 + (i - 1) * 128, 0, 44),
			UDim2.new(0, 122, 0, 28),
			Color3.fromRGB(35, 40, 48)
		)
		b.TextSize = 14
		b.MouseButton1Click:Connect(function()
			activeComputerTab = i
			refreshLaptopContent()
		end)
		table.insert(tabButtons, b)
	end

	laptopScroll = Instance.new("ScrollingFrame")
	laptopScroll.Position = UDim2.new(0, 14, 0, 82)
	laptopScroll.Size = UDim2.new(1, -28, 1, -94)
	laptopScroll.BackgroundTransparency = 1
	laptopScroll.BorderSizePixel = 0
	laptopScroll.ScrollBarThickness = 5
	laptopScroll.Parent = laptopFrame

	-- 5. Navigasi CCTV
	cctvBar = Instance.new("Frame")
	cctvBar.Position = UDim2.new(0.5, -230, 1, -75)
	cctvBar.Size = UDim2.new(0, 460, 0, 54)
	cctvBar.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
	cctvBar.BackgroundTransparency = 0.1
	cctvBar.BorderSizePixel = 0
	cctvBar.Visible = false
	cctvBar.Parent = screenGui
	addCorner(cctvBar, 6)
	addStroke(cctvBar, Color3.fromRGB(70, 85, 105))

	cctvTitleLabel = Instance.new("TextLabel")
	cctvTitleLabel.Position = UDim2.new(0, 110, 0, 4)
	cctvTitleLabel.Size = UDim2.new(1, -220, 0, 20)
	cctvTitleLabel.BackgroundTransparency = 1
	cctvTitleLabel.Text = "CCTV 1 — Gerbang Utama"
	cctvTitleLabel.TextColor3 = Color3.fromRGB(235, 240, 245)
	cctvTitleLabel.Font = Enum.Font.SourceSansBold
	cctvTitleLabel.TextSize = 15
	cctvTitleLabel.Parent = cctvBar

	cctvBlackoutScreen = Instance.new("Frame")
	cctvBlackoutScreen.Size = UDim2.new(1, 0, 1, 0)
	cctvBlackoutScreen.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	cctvBlackoutScreen.BorderSizePixel = 0
	cctvBlackoutScreen.Visible = false
	cctvBlackoutScreen.ZIndex = 2
	cctvBlackoutScreen.Parent = screenGui

	cctvBlackoutText = Instance.new("TextLabel")
	cctvBlackoutText.Size = UDim2.new(1, 0, 1, 0)
	cctvBlackoutText.BackgroundTransparency = 1
	cctvBlackoutText.Text = "⚠️ SINYAL CCTV TERPUTUS (NO SIGNAL)\n\nSumber daya listrik pos satpam mati!\nIkuti Highlight Kuning ke Gardu Listrik untuk memperbaiki kabel."
	cctvBlackoutText.TextColor3 = Color3.fromRGB(240, 70, 70)
	cctvBlackoutText.Font = Enum.Font.RobotoMono
	cctvBlackoutText.TextSize = 20
	cctvBlackoutText.ZIndex = 3
	cctvBlackoutText.Parent = cctvBlackoutScreen

	local prevCctvBtn = makeButton(cctvBar, "< Kamera", UDim2.new(0, 10, 0, 12), UDim2.new(0, 90, 0, 30), Color3.fromRGB(40, 50, 65))
	prevCctvBtn.MouseButton1Click:Connect(function()
		CameraController.StepCctv(-1)
		UIController.Refresh()
	end)

	local nextCctvBtn = makeButton(cctvBar, "Kamera >", UDim2.new(1, -195, 0, 12), UDim2.new(0, 90, 0, 30), Color3.fromRGB(40, 50, 65))
	nextCctvBtn.MouseButton1Click:Connect(function()
		CameraController.StepCctv(1)
		UIController.Refresh()
	end)

	local closeCctvBtn = makeButton(cctvBar, "Tutup", UDim2.new(1, -95, 0, 12), UDim2.new(0, 85, 0, 30), Color3.fromRGB(130, 45, 45))
	closeCctvBtn.MouseButton1Click:Connect(function()
		CameraController.StopCctv()
		UIController.Refresh()
	end)

	-- 6B. Panel Mini-Game Sambung Kabel Gardu Listrik
	wiringFrame = Instance.new("Frame")
	wiringFrame.Position = UDim2.new(0.5, -240, 0.5, -160)
	wiringFrame.Size = UDim2.new(0, 480, 0, 320)
	wiringFrame.BackgroundColor3 = Color3.fromRGB(30, 34, 40)
	wiringFrame.BorderSizePixel = 0
	wiringFrame.Visible = false
	wiringFrame.Parent = screenGui
	addCorner(wiringFrame, 8)
	addStroke(wiringFrame, Color3.fromRGB(85, 100, 120))

	local wiringTitle = Instance.new("TextLabel")
	wiringTitle.Position = UDim2.new(0, 16, 0, 12)
	wiringTitle.Size = UDim2.new(1, -90, 0, 24)
	wiringTitle.BackgroundTransparency = 1
	wiringTitle.Text = "Panel Gardu Listrik: Sambungkan Kabel Sesuai Warna"
	wiringTitle.TextColor3 = Color3.fromRGB(240, 245, 250)
	wiringTitle.Font = Enum.Font.SourceSansBold
	wiringTitle.TextSize = 16
	wiringTitle.TextXAlignment = Enum.TextXAlignment.Left
	wiringTitle.Parent = wiringFrame

	local closeWiringBtn = makeButton(wiringFrame, "Tutup", UDim2.new(1, -70, 0, 10), UDim2.new(0, 56, 0, 24), Color3.fromRGB(55, 60, 70))
	closeWiringBtn.MouseButton1Click:Connect(function()
		wiringFrame.Visible = false
	end)

	wiringFeedbackLabel = Instance.new("TextLabel")
	wiringFeedbackLabel.Position = UDim2.new(0, 16, 0, 42)
	wiringFeedbackLabel.Size = UDim2.new(1, -32, 0, 20)
	wiringFeedbackLabel.BackgroundTransparency = 1
	wiringFeedbackLabel.Text = "Klik soket di sebelah kiri, lalu klik soket dengan warna yang sama di kanan."
	wiringFeedbackLabel.TextColor3 = Color3.fromRGB(180, 190, 205)
	wiringFeedbackLabel.Font = Enum.Font.SourceSans
	wiringFeedbackLabel.TextSize = 14
	wiringFeedbackLabel.TextXAlignment = Enum.TextXAlignment.Left
	wiringFeedbackLabel.Parent = wiringFrame

	local rightOrder = { 3, 1, 4, 2 }
	local leftButtons: { [number]: TextButton } = {}
	local rightButtons: { [number]: TextButton } = {}

	local function resetWiringBoard()
		wiringConnectedCount = 0
		selectedLeftWire = nil
		activeWireConnections = {}
		wiringFeedbackLabel.Text = "Klik soket di sebelah kiri, lalu klik soket dengan warna yang sama di kanan."
		wiringFeedbackLabel.TextColor3 = Color3.fromRGB(180, 190, 205)
		for _, b in pairs(leftButtons) do
			b.Text = b:GetAttribute("OrigText") or ""
		end
		for _, b in pairs(rightButtons) do
			b.Text = b:GetAttribute("OrigText") or ""
		end
	end

	for i, w in ipairs(wireColors) do
		local lBtn = makeButton(wiringFrame, "● " .. w.name, UDim2.new(0, 24, 0, 80 + (i - 1) * 52), UDim2.new(0, 130, 0, 38), w.color)
		lBtn:SetAttribute("ColorName", w.name)
		lBtn:SetAttribute("OrigText", "● " .. w.name)
		lBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		leftButtons[i] = lBtn

		lBtn.MouseButton1Click:Connect(function()
			if activeWireConnections[w.name] then
				return
			end
			selectedLeftWire = lBtn
			wiringFeedbackLabel.Text = "Kabel [" .. w.name .. "] dipilih. Sekarang klik ujung kabel [" .. w.name .. "] di kanan!"
			wiringFeedbackLabel.TextColor3 = Color3.fromRGB(245, 220, 65)
		end)
	end

	for slotIdx, colorIdx in ipairs(rightOrder) do
		local rw = wireColors[colorIdx]
		local rBtn = makeButton(wiringFrame, rw.name .. " ●", UDim2.new(1, -154, 0, 80 + (slotIdx - 1) * 52), UDim2.new(0, 130, 0, 38), rw.color)
		rBtn:SetAttribute("ColorName", rw.name)
		rBtn:SetAttribute("OrigText", rw.name .. " ●")
		rBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		rightButtons[slotIdx] = rBtn

		rBtn.MouseButton1Click:Connect(function()
			if not selectedLeftWire then
				wiringFeedbackLabel.Text = "Pilih kabel di sebelah kiri terlebih dahulu!"
				wiringFeedbackLabel.TextColor3 = Color3.fromRGB(245, 120, 120)
				return
			end

			local leftColor = selectedLeftWire:GetAttribute("ColorName")
			local rightColor = rBtn:GetAttribute("ColorName")

			if leftColor == rightColor then
				activeWireConnections[leftColor] = true
				selectedLeftWire.Text = "✓ Tersambung"
				rBtn.Text = "Tersambung ✓"
				wiringConnectedCount += 1
				selectedLeftWire = nil

				wiringFeedbackLabel.Text = string.format("Kabel %s tersambung! (%d/4)", tostring(leftColor), wiringConnectedCount)
				wiringFeedbackLabel.TextColor3 = Color3.fromRGB(80, 240, 120)

				if wiringConnectedCount >= 4 then
					wiringFeedbackLabel.Text = "Semua kabel tersambung! Listrik berhasil dipulihkan!"
					wiringFeedbackLabel.TextColor3 = Color3.fromRGB(80, 240, 120)
					task.delay(0.8, function()
						wiringFrame.Visible = false
						resetWiringBoard()
						if sendAction then
							sendAction(RemoteNames.ACTIONS.POWER_REPAIRED, {})
						end
					end)
				end
			else
				wiringFeedbackLabel.Text = "Salah sambung! Warna kabel tidak cocok!"
				wiringFeedbackLabel.TextColor3 = Color3.fromRGB(245, 80, 80)
			end
		end)
	end

	-- 6. Jumpscare Overlay & Game Over
	jumpscareOverlay = Instance.new("Frame")
	jumpscareOverlay.Size = UDim2.new(1, 0, 1, 0)
	jumpscareOverlay.BackgroundColor3 = Color3.fromRGB(150, 15, 15)
	jumpscareOverlay.BorderSizePixel = 0
	jumpscareOverlay.Visible = false
	jumpscareOverlay.Parent = screenGui

	local jsLabel = Instance.new("TextLabel")
	jsLabel.Size = UDim2.new(1, 0, 1, 0)
	jsLabel.BackgroundTransparency = 1
	jsLabel.Text = "ANOMALI MENYERANG!"
	jsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	jsLabel.Font = Enum.Font.SourceSansBold
	jsLabel.TextSize = 48
	jsLabel.Parent = jumpscareOverlay

	gameOverFrame = Instance.new("Frame")
	gameOverFrame.Position = UDim2.new(0.5, -210, 0.5, -130)
	gameOverFrame.Size = UDim2.new(0, 420, 0, 260)
	gameOverFrame.BackgroundColor3 = Color3.fromRGB(24, 18, 20)
	gameOverFrame.BorderSizePixel = 0
	gameOverFrame.Visible = false
	gameOverFrame.Parent = screenGui
	addCorner(gameOverFrame, 6)
	addStroke(gameOverFrame, Color3.fromRGB(165, 50, 50))

	local goTitle = Instance.new("TextLabel")
	goTitle.Position = UDim2.new(0, 20, 0, 14)
	goTitle.Size = UDim2.new(1, -40, 0, 28)
	goTitle.BackgroundTransparency = 1
	goTitle.Text = "GAME OVER — DISERANG ANOMALI"
	goTitle.TextColor3 = Color3.fromRGB(235, 80, 80)
	goTitle.Font = Enum.Font.SourceSansBold
	goTitle.TextSize = 20
	goTitle.TextXAlignment = Enum.TextXAlignment.Left
	goTitle.Parent = gameOverFrame

	gameOverBodyLabel = Instance.new("TextLabel")
	gameOverBodyLabel.Position = UDim2.new(0, 20, 0, 50)
	gameOverBodyLabel.Size = UDim2.new(1, -40, 1, -110)
	gameOverBodyLabel.BackgroundTransparency = 1
	gameOverBodyLabel.Text = ""
	gameOverBodyLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
	gameOverBodyLabel.Font = Enum.Font.SourceSans
	gameOverBodyLabel.TextSize = 16
	gameOverBodyLabel.TextWrapped = true
	gameOverBodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	gameOverBodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	gameOverBodyLabel.Parent = gameOverFrame

	local retryBtn = makeButton(gameOverFrame, "Ulangi Shift Ini", UDim2.new(0.5, -90, 1, -48), UDim2.new(0, 180, 0, 34), Color3.fromRGB(135, 45, 45))
	retryBtn.MouseButton1Click:Connect(function()
		gameOverFrame.Visible = false
		if sendAction then
			sendAction(RemoteNames.ACTIONS.RETRY_SHIFT, {})
		end
	end)

	-- 7. Ringkasan Selesai Shift
	resultFrame = Instance.new("Frame")
	resultFrame.Position = UDim2.new(0.5, -200, 0.5, -165)
	resultFrame.Size = UDim2.new(0, 400, 0, 330)
	resultFrame.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
	resultFrame.BorderSizePixel = 0
	resultFrame.Visible = false
	resultFrame.Parent = screenGui
	addCorner(resultFrame, 6)
	addStroke(resultFrame, Color3.fromRGB(80, 95, 115))

	resultBodyLabel = Instance.new("TextLabel")
	resultBodyLabel.Position = UDim2.new(0, 20, 0, 18)
	resultBodyLabel.Size = UDim2.new(1, -40, 1, -76)
	resultBodyLabel.BackgroundTransparency = 1
	resultBodyLabel.Text = ""
	resultBodyLabel.TextColor3 = Color3.fromRGB(235, 240, 245)
	resultBodyLabel.Font = Enum.Font.RobotoMono
	resultBodyLabel.TextSize = 14
	resultBodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	resultBodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	resultBodyLabel.Parent = resultFrame

	local nextBtn = makeButton(resultFrame, "Lanjut Shift Berikutnya", UDim2.new(0.5, -100, 1, -46), UDim2.new(0, 200, 0, 34), Color3.fromRGB(45, 110, 70))
	nextBtn.MouseButton1Click:Connect(function()
		if sendAction then
			sendAction(RemoteNames.ACTIONS.NEXT_SHIFT, {})
		end
	end)
end

return UIController
