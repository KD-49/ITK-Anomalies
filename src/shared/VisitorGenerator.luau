--!strict
-- VisitorGenerator.luau
-- Membuat data pengunjung normal dan anomali dengan percakapan yang nyambung serta konsekuensi anomali

local CampusDatabase = require(script.Parent.CampusDatabase)

local VisitorGenerator = {}

export type CardData = {
	cardType: string,
	institusi: string,
	nama: string,
	nomorId: string,
	labelNomorId: string,
	prodiAtauUnit: string,
	angkatanAtauRuang: string,
	masaBerlaku: string,
}

export type VisitorProfile = {
	uid: string,
	visitorType: string,
	displayName: string,
	shirtColor: Color3,
	greeting: string,

	-- Pertanyaan Satpam & Jawaban Pengunjung agar dialog selalu nyambung
	cardQuestion: string,
	cardResponse: string,

	reasonQuestion: string,
	reasonResponse: string,

	quirkQuestion: string,
	quirkResponse: string,

	card: CardData,

	-- Rahasia Server (tidak pernah ditampilkan lewat notifikasi saat bermain)
	isAnomaly: boolean,
	anomalyType: string?,
	consequenceIfAccepted: "None" | "WeirdEvent" | "JumpscareKill",
	explanation: string,
}

local counter = 0
local function nextUid(): string
	counter += 1
	return "NPC_" .. tostring(counter)
end

function VisitorGenerator.CreateNormalVisitor(index: number): VisitorProfile
	local pick = ((index - 1) % 4) + 1

	if pick == 1 then
		local r = CampusDatabase.PeminjamanRuangan[1]
		return {
			uid = nextUid(),
			visitorType = "Mahasiswa",
			displayName = r.peminjam,
			shirtColor = r.warnaBaju,
			greeting = "Malam, Pak. Saya mau ambil laptop dan lanjut tugas sebentar di " .. r.ruang .. ".",
			cardQuestion = "Boleh saya periksa kartu identitasnya terlebih dahulu?",
			cardResponse = "Ini KTM saya, Pak. Silakan dicek.",
			reasonQuestion = "Malam-malam begini mau ke ruangan mana dan ada keperluan apa ya?",
			reasonResponse = "Saya sudah izin pinjam " .. r.ruang .. " untuk jam " .. r.jam .. " buat kompilasi tugas proyek, Pak.",
			quirkQuestion = "Wajah kamu kelihatan pucat dan mengantuk sekali, kondisi kamu baik-baik saja?",
			quirkResponse = "Hehe iya Pak, saya kurang tidur karena ngejar laporan praktikum dari kemarin sore, tapi saya sehat kok.",
			card = {
				cardType = "KTM (Kartu Tanda Mahasiswa)",
				institusi = "INSTITUT TEKNOLOGI KALIMANTAN",
				nama = r.peminjam,
				nomorId = r.nim,
				labelNomorId = "NIM",
				prodiAtauUnit = r.prodi,
				angkatanAtauRuang = "Angkatan " .. r.angkatan,
				masaBerlaku = r.masaBerlaku,
			},
			isAnomaly = false,
			consequenceIfAccepted = "None",
			explanation = "Pengunjung Normal: KTM dan izin peminjaman ruangan cocok dengan data di laptop.",
		}
	elseif pick == 2 then
		local r = CampusDatabase.PenghuniAsrama[1]
		return {
			uid = nextUid(),
			visitorType = "Penghuni Asrama",
			displayName = r.nama,
			shirtColor = r.warnaBaju,
			greeting = "Permisi Pak, saya anak asrama kamar " .. r.kamar .. ", baru balik beli makan.",
			cardQuestion = "Tolong tunjukkan KTM-nya dulu ya.",
			cardResponse = "Siap Pak, ini KTM saya.",
			reasonQuestion = "Habis dari mana tadi malam-malam begini?",
			reasonResponse = "Tadi jam 21:45 saya sudah izin keluar beli makan malam di depan, sekarang mau balik ke " .. r.kamar .. ".",
			quirkQuestion = "Kenapa dari tadi kamu berdiri sambil menggigil begitu?",
			quirkResponse = "Angin malam di Karang Joang dingin banget Pak, saya cuma lupa pakai jaket tadi waktu keluar.",
			card = {
				cardType = "KTM (Kartu Tanda Mahasiswa)",
				institusi = "INSTITUT TEKNOLOGI KALIMANTAN",
				nama = r.nama,
				nomorId = r.nim,
				labelNomorId = "NIM",
				prodiAtauUnit = r.prodi,
				angkatanAtauRuang = r.kamar,
				masaBerlaku = r.masaBerlaku,
			},
			isAnomaly = false,
			consequenceIfAccepted = "None",
			explanation = "Pengunjung Normal: KTM cocok dengan daftar Penghuni Asrama yang sedang izin keluar.",
		}
	elseif pick == 3 then
		local r = CampusDatabase.JadwalKegiatan[1]
		return {
			uid = nextUid(),
			visitorType = "Mahasiswa Organisasi",
			displayName = r.penanggungJawab,
			shirtColor = r.warnaBaju,
			greeting = "Malam Pak, saya dari " .. r.organisasi .. ", ada jadwal rapat malam ini.",
			cardQuestion = "Bisa lihat kartu identitas mahasiswanya?",
			cardResponse = "Ini KTM saya Pak, saya penanggung jawab rapat malam ini.",
			reasonQuestion = "Rapat organisasi apa dan di ruangan mana?",
			reasonResponse = "Kami ada " .. r.kegiatan .. " di " .. r.ruang .. " pukul " .. r.jam .. ", Pak.",
			quirkQuestion = "Suara kamu terdengar agak serak, kamu sedang sakit atau ada hal lain?",
			quirkResponse = "Oh, ini gara-gara kebanyakan bicara waktu memimpin rapat sore tadi Pak, kondisi saya aman kok.",
			card = {
				cardType = "KTM (Kartu Tanda Mahasiswa)",
				institusi = "INSTITUT TEKNOLOGI KALIMANTAN",
				nama = r.penanggungJawab,
				nomorId = r.nim,
				labelNomorId = "NIM",
				prodiAtauUnit = r.prodi,
				angkatanAtauRuang = "Angkatan " .. r.angkatan,
				masaBerlaku = r.masaBerlaku,
			},
			isAnomaly = false,
			consequenceIfAccepted = "None",
			explanation = "Pengunjung Normal: Nama PJ, NIM, dan ruangan rapat sesuai dengan Jadwal Kegiatan Malam.",
		}
	else
		local r = CampusDatabase.DosenDanStaf[1]
		return {
			uid = nextUid(),
			visitorType = "Dosen",
			displayName = r.nama,
			shirtColor = r.warnaBaju,
			greeting = "Selamat malam, Pak. Saya mau ambil berkas ujian di ruang dosen.",
			cardQuestion = "Selamat malam Pak, mohon izin memeriksa kartu identitas dosennya.",
			cardResponse = "Silakan Pak Satpam, ini kartu identitas dosen saya.",
			reasonQuestion = "Menuju ruang dosen di gedung mana dan sampai jam berapa, Pak?",
			reasonResponse = "Ruangan saya di " .. r.ruang .. ", jadwal lembur saya tercatat sampai pukul 23:30.",
			quirkQuestion = "Apakah ada kendala di jalan tadi Pak, kelihatannya Bapak agak terburu-buru?",
			quirkResponse = "Tidak apa-apa Pak Satpam, saya hanya ingin cepat mengambil naskah soal UTS untuk besok pagi.",
			card = {
				cardType = "ID Dosen / Staf",
				institusi = "INSTITUT TEKNOLOGI KALIMANTAN",
				nama = r.nama,
				nomorId = r.idStaf,
				labelNomorId = "NIP",
				prodiAtauUnit = r.unit,
				angkatanAtauRuang = r.ruang,
				masaBerlaku = r.masaBerlaku,
			},
			isAnomaly = false,
			consequenceIfAccepted = "None",
			explanation = "Pengunjung Normal: Identitas dosen dan jadwal sesuai dengan data Dosen dan Staf.",
		}
	end
end

function VisitorGenerator.CreateAnomalyVisitor(index: number): VisitorProfile
	local pick = ((index - 1) % 4) + 1

	if pick == 1 then
		-- Anomali 1: Mahasigma (Data NIM & Prodi palsu -> memicu kejadian aneh lampu berkedip jika lolos)
		local r = CampusDatabase.PeminjamanRuangan[1]
		return {
			uid = nextUid(),
			visitorType = "Mahasiswa",
			displayName = r.peminjam,
			shirtColor = Color3.fromRGB(45, 75, 130),
			greeting = "Malam, Pak. Mau ambil laptop yang ketinggalan di lab.",
			cardQuestion = "Boleh saya periksa kartu identitasnya terlebih dahulu?",
			cardResponse = "Ini KTM saya, Pak.",
			reasonQuestion = "Malam-malam begini mau ke ruangan mana dan atas nama siapa?",
			reasonResponse = "Mau ke Lab Terpadu Lt. 2 (R.204), atas nama Dimas Anggara.",
			quirkQuestion = "Dari tadi saya perhatikan tatapan kamu kosong dan tidak berkedip sama sekali, kamu kenapa?",
			quirkResponse = "Berkedip? Oh... maaf Pak, saya lupa kalau manusia biasa harus sering berkedip saat berbicara.",
			card = {
				cardType = "KTM (Kartu Tanda Mahasiswa)",
				institusi = "INSTITUT TEKNOLOGI KALIMANTAN",
				nama = "Dimas Anggara",
				nomorId = "11231099", -- Salah digit (di laptop: 11231019)
				labelNomorId = "NIM",
				prodiAtauUnit = "Teknik Mesin", -- Salah prodi (di laptop: Informatika)
				angkatanAtauRuang = "Angkatan 2023",
				masaBerlaku = "Agu 2027",
			},
			isAnomaly = true,
			anomalyType = "Mahasigma",
			consequenceIfAccepted = "WeirdEvent",
			explanation = "Anomali Mahasigma: NIM (11231099) dan Prodi (Teknik Mesin) di KTM berbeda dengan data laptop (11231019 - Informatika).",
		}
	elseif pick == 2 then
		-- Anomali 2: Mimic / Skinwalker Agresif (Menyamar sebagai Nadia Putri B-201 yang sebenarnya tidak keluar kamar -> JUMPSCARE & MATI jika diterima!)
		local r = CampusDatabase.PenghuniAsrama[2]
		return {
			uid = nextUid(),
			visitorType = "Penghuni Asrama",
			displayName = r.nama,
			shirtColor = r.warnaBaju,
			greeting = "Pak, saya anak asrama kamar B-201, tadi habis keluar beli makan.",
			cardQuestion = "Tolong tunjukkan KTM-nya dulu ya.",
			cardResponse = "Ini KTM saya, Pak.",
			reasonQuestion = "Mau kembali ke kamar asrama nomor berapa?",
			reasonResponse = "Saya Nadia Putri, mau balik ke kamar Asrama Putri B-201.",
			quirkQuestion = "Cara bicara dan senyummu kelihatan kaku sekali, kamu benar Nadia penghuni kamar B-201?",
			quirkResponse = "Saya benar Nadia dari kamar B-201... wajah dan suara ini sudah saya tiru dengan pas kok, Pak.",
			card = {
				cardType = "KTM (Kartu Tanda Mahasiswa)",
				institusi = "INSTITUT TEKNOLOGI KALIMANTAN",
				nama = r.nama,
				nomorId = r.nim,
				labelNomorId = "NIM",
				prodiAtauUnit = r.prodi,
				angkatanAtauRuang = r.kamar,
				masaBerlaku = r.masaBerlaku,
			},
			isAnomaly = true,
			anomalyType = "Mimic Berbahaya",
			consequenceIfAccepted = "JumpscareKill",
			explanation = "Anomali Mimic: Di data Penghuni Asrama tercatat Nadia Putri sudah berada di dalam kamar B-201 sejak pukul 20:00 dan tidak pernah keluar.",
		}
	elseif pick == 3 then
		-- Anomali 3: Salah Kampus (Memicu kejadian aneh jika lolos)
		return {
			uid = nextUid(),
			visitorType = "Mahasiswa Organisasi",
			displayName = "Aldo Wijaya",
			shirtColor = Color3.fromRGB(135, 50, 50),
			greeting = "Permisi Pak, kami ada rapat panitia malam ini, boleh masuk?",
			cardQuestion = "Bisa lihat kartu identitas mahasiswanya?",
			cardResponse = "Ini kartu mahasiswa saya, Pak.",
			reasonQuestion = "Rapat organisasi apa dan di gedung mana?",
			reasonResponse = "Mau rapat di Gedung Z Ruang Bawah Tanah jam 23:00, Pak.",
			quirkQuestion = "Jaket almamater yang kamu pakai warnanya beda sendiri, kamu yakin mahasiswa ITK?",
			quirkResponse = "Loh, bukannya ini kampus Institut Teknologi Kegelapan ya Pak? Kok gedungnya beda sama di peta saya?",
			card = {
				cardType = "KTM (Kartu Tanda Mahasiswa)",
				institusi = "INSTITUT TEKNOLOGI KEGELAPAN",
				nama = "Aldo Wijaya",
				nomorId = "99241088",
				labelNomorId = "NIM",
				prodiAtauUnit = "Teknik Misteri",
				angkatanAtauRuang = "Angkatan 2024",
				masaBerlaku = "Agu 2028",
			},
			isAnomaly = true,
			anomalyType = "Salah Kampus",
			consequenceIfAccepted = "WeirdEvent",
			explanation = "Anomali Salah Kampus: Institusi pada kartu tertulis 'Institut Teknologi Kegelapan' dan tujuannya Gedung Z yang tidak ada di ITK.",
		}
	else
		-- Anomali 4: Anomali Agresif (Kartu kedaluwarsa & tidak terdaftar -> JUMPSCARE & MATI jika diterima!)
		return {
			uid = nextUid(),
			visitorType = "Mahasiswa",
			displayName = "Raka Pratama",
			shirtColor = Color3.fromRGB(140, 45, 45),
			greeting = "Pak, cepat buka gerbangnya sekarang, saya harus masuk ke gedung!",
			cardQuestion = "Tunggu sebentar, tunjukkan kartu identitasnya dulu.",
			cardResponse = "Ini kartu saya! Cepat buka gerbangnya, Pak!",
			reasonQuestion = "Ada urusan apa malam-malam begini memaksa masuk?",
			reasonResponse = "Urusan saya di semua gedung! Saya sudah ditunggu di dalam!",
			quirkQuestion = "Kenapa napas kamu terengah-engah dan tangan kamu gemetar seperti menahan marah begitu?",
			quirkResponse = "Jangan banyak tanya Pak Satpam... buka saja gerbangnya kalau Bapak masih ingin selamat malam ini!",
			card = {
				cardType = "KTM (Kartu Tanda Mahasiswa)",
				institusi = "INSTITUT TEKNOLOGI KALIMANTAN",
				nama = "Raka Pratama",
				nomorId = "11180000",
				labelNomorId = "NIM",
				prodiAtauUnit = "Informatika",
				angkatanAtauRuang = "Angkatan 2018",
				masaBerlaku = "Agu 2022 (KEDALUWARSA)",
			},
			isAnomaly = true,
			anomalyType = "Anomali Agresif",
			consequenceIfAccepted = "JumpscareKill",
			explanation = "Anomali Agresif: Masa berlaku KTM sudah habis (2022), nama tidak terdaftar di data peminjaman ruangan, dan menunjukkan gelagat mengancam.",
		}
	end
end

function VisitorGenerator.GenerateShiftList(count: number): { VisitorProfile }
	local list: { VisitorProfile } = {}
	for i = 1, count do
		-- Pengunjung 1: Normal, Pengunjung 2: Anomali Mahasigma (WeirdEvent), Pengunjung 3: Normal, Pengunjung 4: Anomali Mimic (JumpscareKill jika diterima), Pengunjung 5: Acak
		if i == 1 then
			table.insert(list, VisitorGenerator.CreateNormalVisitor(1))
		elseif i == 2 then
			table.insert(list, VisitorGenerator.CreateAnomalyVisitor(1))
		elseif i == 3 then
			table.insert(list, VisitorGenerator.CreateNormalVisitor(2))
		elseif i == 4 then
			table.insert(list, VisitorGenerator.CreateAnomalyVisitor(2))
		else
			if math.random() < 0.5 then
				table.insert(list, VisitorGenerator.CreateAnomalyVisitor(math.random(3, 4)))
			else
				table.insert(list, VisitorGenerator.CreateNormalVisitor(math.random(3, 4)))
			end
		end
	end
	return list
end

function VisitorGenerator.SanitizeForClient(v: VisitorProfile)
	return {
		uid = v.uid,
		visitorType = v.visitorType,
		displayName = v.displayName,
		greeting = v.greeting,
		cardQuestion = v.cardQuestion,
		cardResponse = v.cardResponse,
		reasonQuestion = v.reasonQuestion,
		reasonResponse = v.reasonResponse,
		quirkQuestion = v.quirkQuestion,
		quirkResponse = v.quirkResponse,
		card = v.card,
	}
end

return VisitorGenerator
