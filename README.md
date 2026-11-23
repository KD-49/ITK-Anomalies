# ITK-Anomalies (Progress ~50% — Modular Architecture)

Game horor investigasi shift malam di Pos Satpam Utama **Institut Teknologi Kalimantan (ITK)** dengan arsitektur modular **Services & Controllers** berbasis **Rojo**.

## Arsitektur Proyek (`src/`)

- **`src/shared/`** (`ReplicatedStorage.Shared`)
  - **`Config/`**: [`GameConfig.luau`](src/shared/Config/GameConfig.luau) & [`CampusDatabase.luau`](src/shared/Config/CampusDatabase.luau)
  - **`Constants/`**: [`RemoteNames.luau`](src/shared/Constants/RemoteNames.luau) & [`MapWaypoints.luau`](src/shared/Constants/MapWaypoints.luau)
  - **`Utilities/`**: [`VisitorGenerator.luau`](src/shared/Utilities/VisitorGenerator.luau) & [`R6AvatarBuilder.luau`](src/shared/Utilities/R6AvatarBuilder.luau)
- **`src/server/`** (`ServerScriptService.Server`)
  - [`init.server.luau`](src/server/init.server.luau) — Entry point utama Server
  - **`Services/`**:
    - [`ShiftService.luau`](src/server/Services/ShiftService.luau) — Siklus shift (`WaitingForGate`, `Active`, `Result`, `GameOver`), jam kerja (`22:00–06:00`), penilaian, dan validasi `RemoteEvent`
    - [`VisitorService.luau`](src/server/Services/VisitorService.luau) — Antrean pengunjung satu per satu, *spawning* Avatar R6 lengkap, animasi langkah, dan penghindaran pemain
    - [`AnomalyService.luau`](src/server/Services/AnomalyService.luau) — Event mati lampu (*Blackout*) dan konsekuensi anomali (*WeirdEvent* kedipan lampu & *JumpscareKill*)
    - [`SanityService.luau`](src/server/Services/SanityService.luau) — Pelacakan *Sanity* (`0–100%`) yang persisten antar shift serta pengurangan berkala saat mati lampu
    - [`EnvironmentService.luau`](src/server/Services/EnvironmentService.luau) — Animasi 2 daun pintu Gerbang Utama ITK, interaksi Gardu Listrik (`Workspace.Furnitur.Transformator`), *Highlight* kuning saat gelap, Laptop, dan node 3D CCTV
    - [`InvestigationService.luau`](src/server/Services/InvestigationService.luau) — Fondasi pelacakan investigasi & bukti (*evidence*) Gedung A dan Gedung B
- **`src/client/`** (`StarterPlayer.StarterPlayerScripts.Client`)
  - [`init.client.luau`](src/client/init.client.luau) — Entry point utama Client
  - **`Controllers/`**:
    - [`UIController.luau`](src/client/Controllers/UIController.luau) — Seluruh tampilan HUD, Sanity Bar, Dialog Loket, Kartu Identitas, Laptop 4-Tab, Bar CCTV, Mini-Game Sambung Kabel 4 Warna, Jumpscare, dan Laporan Shift
    - [`CameraController.luau`](src/client/Controllers/CameraController.luau) — Kamera CCTV 1–4, *camera sway*, dan efek guncangan kamera (*camera shake*)
    - [`InteractionController.luau`](src/client/Controllers/InteractionController.luau) — Input tombol pemain (`Escape`, panah `Kiri`/`Kanan`) dan jembatan komunikasi `RemoteEvent`
    - [`AudioController.luau`](src/client/Controllers/AudioController.luau) — Pemutaran efek suara lokal (*Jumpscare* & atmosfer)

## Cara Menjalankan
1. Buka file place `ITK-Anomalies.rbxlx` di Roblox Studio.
2. Jalankan `rojo serve` di terminal dan hubungkan plugin Rojo di Roblox Studio.
3. Tekan **Play**.
