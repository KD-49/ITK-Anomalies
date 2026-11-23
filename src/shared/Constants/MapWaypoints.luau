--!strict
-- MapWaypoints.luau
-- Menyimpan koordinat 3D penting di Workspace (Gerbang, Jalur Jalan NPC, Loket, PC, dan CCTV).

local MapWaypoints = {
	-- Jalur jalan raya utama berada di Z = 16.5 (bebas dari tanaman/cone/pot di dekat dinding pos Z = -2)
	GATE_PROMPT_POS = Vector3.new(-45.25, 71.2, 16.5),
	SPAWN_OUTSIDE_GATE = Vector3.new(-33.0, 72.0, 16.5),
	ROAD_TURN_POINT = Vector3.new(-111.9, 72.0, 16.5),
	LOKET_STAND = Vector3.new(-111.9, 71.0, -4.5),
	LOKET_LOOK_AT = Vector3.new(-111.9, 71.0, -11.0),
	ACCEPT_CAMPUS_DEST = Vector3.new(-165.0, 72.0, 16.5),
	REJECT_OUTSIDE_DEST = Vector3.new(-30.0, 72.0, 16.5),

	-- Posisi prompt interaksi di dalam Pos Satpam
	LOKET_PROMPT_POS = Vector3.new(-111.9, 71.3, -9.2),
	PC_BELAKANG_PROMPT_POS = Vector3.new(-117.6, 71.0, -33.2),
	FALLBACK_LAPTOP_POS = Vector3.new(-115.2, 71.1, -9.1),
	FALLBACK_TRAFO_POS = Vector3.new(-183.0, 71.5, 42.9),

	-- Engsel daun gerbang kiri & kanan supaya gerbang membuka dari tengah
	GATE_CENTER_Z = 16.49,
	RIGHT_GATE_HINGE = CFrame.new(-45.25, 72.0, 1.75),
	LEFT_GATE_HINGE = CFrame.new(-45.25, 72.0, 31.23),

	-- Fallback arah kamera CCTV jika model Camera 3D tidak ditemukan
	DEFAULT_CCTV_CFRAMES = {
		[1] = CFrame.lookAt(Vector3.new(-87.3, 78.0, -4.8), Vector3.new(-45.2, 70.5, 16.5)),
		[2] = CFrame.lookAt(Vector3.new(-122.8, 78.2, -5.3), Vector3.new(-160.0, 71.0, 7.0)),
		[3] = CFrame.lookAt(Vector3.new(-118.7, 76.8, -33.2), Vector3.new(-100.0, 70.0, -18.0)),
		[4] = CFrame.lookAt(Vector3.new(-119.2, 76.9, -39.3), Vector3.new(-105.0, 68.0, -70.0)),
	},
}

return MapWaypoints
