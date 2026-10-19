# ITK-Anomalies (Progress UTS ~33% — Fitur Esensial Inti)

Implementasi tahap awal (Prototype / UTS) untuk game **ITK Anomalies** yang berfokus pada **4 fitur esensial utama (33,3% dari 12 fitur GDD)**:

1. **Alur Shift & Kedatangan Pengunjung Satu per Satu**:
   - Pengunjung datang satu per satu menuju loket Pos Satpam.
   - Pengunjung berikutnya baru akan *spawn* setelah pengunjung saat ini diberi keputusan (**Terima** atau **Tolak**) dan selesai berjalan pergi.
2. **Dialog Pemeriksaan Pengunjung di Loket**:
   - Muncul ketika pemain menekan **`E`** pada pengunjung atau meja loket.
   - Mencakup sapaan pengunjung, pertanyaan (*Lihat Kartu*, *Tanya Tujuan*, *Tanya Kondisi*), serta keputusan **Terima** (gerbang terbuka) atau **Tolak**.
3. **Pemeriksaan Kartu Identitas (KTM / ID Staf)**:
   - Menampilkan kartu identitas pengunjung untuk dibandingkan dengan data di komputer.
4. **Komputer Data Kampus ITK & Penilaian Shift**:
   - Terbuka saat pemain menekan **`E`** pada meja komputer di ruang belakang Pos Satpam (berisi tab *Penghuni Asrama*, *Peminjaman Ruang*, *Kegiatan Malam*, dan *Dosen & Staf*).
   - Di akhir shift (setelah 5 pengunjung diproses), sistem menampilkan evaluasi akurasi, peringkat (S/A/B/C/D), dan gaji *coins*.

## Cara Menjalankan
1. Buka `ITK-Anomalies.rbxlx` di Roblox Studio.
2. Pastikan Rojo tersambung (`rojo serve`).
3. Tekan **Play**.