--!strict
-- CampusDatabase.luau
-- Data referensi kampus ITK untuk pemeriksaan kartu identitas dan komputer pos satpam

local CampusDatabase = {}

-- Tab 1: Penghuni Asrama
CampusDatabase.PenghuniAsrama = {
	{
		nama = "Rizky Pratama",
		nim = "11241015",
		prodi = "Informatika",
		angkatan = "2024",
		kamar = "Asrama Putra A-101",
		masaBerlaku = "Agu 2028",
		keterangan = "Izin keluar beli makan malam pukul 21:45",
		warnaBaju = Color3.fromRGB(45, 95, 165),
	},
	{
		nama = "Nadia Putri Maharani",
		nim = "10241022",
		prodi = "Sistem Informasi",
		angkatan = "2024",
		kamar = "Asrama Putri B-201",
		masaBerlaku = "Agu 2028",
		keterangan = "Sudah berada di dalam kamar sejak pukul 20:00 (Tidak keluar)",
		warnaBaju = Color3.fromRGB(165, 65, 105),
	},
	{
		nama = "Bagas Setiawan",
		nim = "04241008",
		prodi = "Teknik Elektro",
		angkatan = "2024",
		kamar = "Asrama Putra A-104",
		masaBerlaku = "Agu 2028",
		keterangan = "Istirahat di kamar A-104 (Sedang sakit)",
		warnaBaju = Color3.fromRGB(60, 130, 90),
	},
	{
		nama = "Aulia Rahma",
		nim = "12241030",
		prodi = "Teknik Industri",
		angkatan = "2024",
		kamar = "Asrama Putri B-105",
		masaBerlaku = "Agu 2028",
		keterangan = "Izin rapat kepanitiaan kampus sampai 23:30",
		warnaBaju = Color3.fromRGB(95, 70, 150),
	},
}

-- Tab 2: Peminjaman Ruangan
CampusDatabase.PeminjamanRuangan = {
	{
		ruang = "Lab Terpadu Lt. 2 (R.204)",
		peminjam = "Dimas Anggara",
		nim = "11231019",
		prodi = "Informatika",
		angkatan = "2023",
		masaBerlaku = "Agu 2027",
		jam = "21:00 - 23:30",
		keperluan = "Mengambil laptop dan kompilasi tugas proyek",
		warnaBaju = Color3.fromRGB(35, 80, 140),
	},
	{
		ruang = "Lab Elektronika Gedung E",
		peminjam = "Ilham Saputra",
		nim = "04221033",
		prodi = "Teknik Elektro",
		angkatan = "2022",
		masaBerlaku = "Agu 2026",
		jam = "20:00 - 23:00",
		keperluan = "Praktikum mikrokontroler dan ambil alat",
		warnaBaju = Color3.fromRGB(50, 110, 120),
	},
	{
		ruang = "Studio Gambar Gedung F",
		peminjam = "Siti Nurhaliza",
		nim = "08231011",
		prodi = "Perencanaan Wilayah & Kota",
		angkatan = "2023",
		masaBerlaku = "Agu 2027",
		jam = "21:30 - 00:30",
		keperluan = "Menyelesaikan maket tata kota",
		warnaBaju = Color3.fromRGB(145, 95, 55),
	},
}

-- Tab 3: Jadwal Kegiatan Malam
CampusDatabase.JadwalKegiatan = {
	{
		organisasi = "HMIF ITK",
		kegiatan = "Rapat Evaluasi KBM Malam",
		ruang = "Gedung B Ruang B-102",
		jam = "21:30 - 23:45",
		penanggungJawab = "Kevin Sanjaya",
		nim = "11221005",
		prodi = "Informatika",
		angkatan = "2022",
		masaBerlaku = "Agu 2026",
		warnaBaju = Color3.fromRGB(30, 60, 115),
	},
	{
		organisasi = "Panitia Dies Natalis ITK",
		kegiatan = "Persiapan Logistik & Panggung",
		ruang = "Auditorium Gedung A",
		jam = "22:00 - 01:00",
		penanggungJawab = "Reza Mahendra",
		nim = "12231027",
		prodi = "Teknik Industri",
		angkatan = "2023",
		masaBerlaku = "Agu 2027",
		warnaBaju = Color3.fromRGB(130, 50, 50),
	},
}

-- Tab 4: Dosen dan Staf
CampusDatabase.DosenDanStaf = {
	{
		nama = "Dr. Hendra Wijaya",
		idStaf = "NIP-19880412",
		tipe = "Dosen",
		unit = "Dosen Informatika",
		ruang = "Ruang Dosen Gedung E Lt. 3",
		jadwal = "21:00 - 23:30 (Ambil berkas ujian UTS)",
		masaBerlaku = "Des 2029",
		warnaBaju = Color3.fromRGB(65, 65, 75),
	},
	{
		nama = "Pak Slamet Riyadi",
		idStaf = "STAF-ITK-042",
		tipe = "Staf Kampus",
		unit = "Unit Kebersihan & Sarpras",
		ruang = "Gedung A & Koridor Utama",
		jadwal = "22:00 - 04:00 (Shift lembur kebersihan)",
		masaBerlaku = "Des 2028",
		warnaBaju = Color3.fromRGB(50, 90, 70),
	},
}

return CampusDatabase
