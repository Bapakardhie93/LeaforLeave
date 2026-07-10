<p align="center">
  <img src="Documentation/Brand/LeafOrLeave-Logo.png" width="360" alt="LeafOrLeave logo">
</p>

# LeafOrLeave

LeafOrLeave adalah browser produktivitas native untuk macOS yang dibangun menggunakan SwiftUI, WebKit, dan framework Apple. Proyek ini berfokus pada pengalaman belajar, coding, media, serta perlindungan terhadap kehilangan input saat koneksi jaringan terganggu.

> **Status: tahap awal / experimental.** LeafOrLeave belum siap digunakan sebagai browser utama atau untuk ujian penting. Beberapa fitur masih membutuhkan validasi keamanan, pengujian website nyata, optimasi memori, dan penyempurnaan UX.

## Tujuan produk

- Menyediakan browser macOS native tanpa Chromium atau Electron.
- Mengorganisasi aktivitas melalui workspace Study, Coding, Media, dan workspace custom.
- Mempertahankan tab, media, dan sesi tanpa reload yang tidak diperlukan.
- Membantu mengurangi kehilangan input ketika jaringan terputus.
- Memberikan kontrol performa dan privasi yang mudah dipahami.

## Fitur yang sudah tersedia

### Browser dan tab

- Multi-tab dengan satu `WKWebView` per tab.
- Create, close, duplicate, reopen, move, dan pin tab.
- Session restore dan persistent website data.
- Popup dan OAuth window handling.
- Favicon, loading state, media indicator, dan keyboard shortcuts.
- Native new-tab page.

### Exam Protection dan jaringan

- Pemantauan konektivitas memakai `Network.framework`.
- Recovery overlay tanpa reload atau submit otomatis.
- Snapshot lokal terbatas untuk field formulir aman.
- Password, hidden field, file content, dan payment field tidak direkam.
- Konfirmasi close/quit untuk protected tab.

Exam Protection **tidak** dapat memperpanjang timeout LMS, mengubah keputusan server, menjamin jawaban tersimpan, atau menggantikan mekanisme autosave milik platform ujian.

### Workspace dan download

- Workspace Study, Coding, Media, dan custom.
- Workspace persistence dan tab mapping.
- Native sidebar.
- WebKit download history, safe filename handling, open, dan reveal in Finder.

### Media

- Event-driven HTML5 audio/video status.
- Mini media panel, per-tab mute, mute all, dan Picture in Picture.
- AirPlay melalui kemampuan WebKit.
- Equalizer Web Audio eksperimental untuk media yang kompatibel.

Equalizer tidak mencoba melewati DRM dan tidak dijamin bekerja pada Spotify atau protected media.

### Performa dan pengaturan

- Tab lifecycle: active, background, sleeping, frozen, dan discarded.
- Memory-pressure monitoring dan smart suspension.
- Playing media, PiP, download/upload, dan protected tab dikecualikan.
- Typed persistent Settings, privacy controls, theme tokens, diagnostics, dan onboarding.

## Persyaratan pengembangan

- macOS dengan versi yang didukung oleh deployment target proyek.
- Xcode terbaru yang kompatibel dengan SDK proyek.
- Swift 5 atau versi yang disediakan Xcode.
- Tidak membutuhkan dependency pihak ketiga.

## Menjalankan proyek

1. Clone repository:

   ```bash
   git clone https://github.com/Bapakardhie93/LeaforLeave.git
   cd LeaforLeave
   ```

2. Buka `LeafOrLeave.xcodeproj` menggunakan Xcode.
3. Pilih scheme `LeafOrLeave` dan destination **My Mac**.
4. Atur Signing Team serta bundle identifier bila diperlukan.
5. Jalankan dengan `⌘R`.

Build dari terminal:

```bash
xcodebuild \
  -project LeafOrLeave.xcodeproj \
  -scheme LeafOrLeave \
  -configuration Debug \
  -sdk macosx \
  build CODE_SIGNING_ALLOWED=NO
```

Menjalankan unit test:

```bash
xcodebuild test \
  -project LeafOrLeave.xcodeproj \
  -scheme LeafOrLeave \
  -destination 'platform=macOS' \
  -only-testing:LeafOrLeaveTests \
  CODE_SIGNING_ALLOWED=NO
```

## Struktur proyek

```text
LeafOrLeave/
├── App/                    # App lifecycle dan dependency environment
├── Core/
│   ├── Browser/            # WebKit configuration dan lifecycle
│   ├── Networking/         # Connectivity monitoring/recovery
│   └── Persistence/        # Session persistence
├── DesignSystem/           # Warna, theme, spacing, components
└── Features/
    ├── Browser/            # Browser shell dan WKWebView container
    ├── Downloads/          # Download manager
    ├── Equalizer/          # Experimental Web Audio equalizer
    ├── ExamProtection/     # Protected tab dan form snapshot
    ├── Media/              # Media bridge dan mini panel
    ├── Performance/        # Suspension dan inspector
    ├── Settings/           # Typed settings dan onboarding
    ├── Sidebar/            # Native sidebar
    ├── Tabs/               # Tab model/manager/UI
    └── Workspace/          # Workspace model dan persistence
```

## Shortcut utama

| Shortcut | Aksi |
|---|---|
| `⌘T` | Tab baru |
| `⌘W` | Tutup tab |
| `⌘⇧T` | Buka kembali tab tertutup |
| `⌘L` | Fokus address bar |
| `⌃Tab` / `⌃⇧Tab` | Tab berikutnya/sebelumnya |
| `⌘1…⌘9` | Pilih tab |
| `⌘⇧1…⌘⇧3` | Study/Coding/Media workspace |
| `⌘⇧S` | Tampilkan/sembunyikan sidebar |

## Tahapan yang masih perlu dilakukan

### P0 — sebelum aplikasi dipakai secara serius

- Menurunkan dan menetapkan deployment target macOS yang realistis untuk distribusi.
- Audit menyeluruh terhadap lifecycle `WKWebView`, retain cycle, dan penggunaan RAM memakai Instruments.
- Menguji login Google, Microsoft, GitHub, LMS, ChatGPT, Spotify, dan YouTube pada akun serta situs nyata.
- Menguji OAuth popup, cookie persistence, download besar, disk penuh, permission denied, dan jaringan putus-sambung.
- Memperkuat download cancel/resume/retry serta progress dan speed reporting.
- Menambah persistent history/bookmark yang nyata; sidebar saat ini masih menampilkan entry dasar.
- Menambah test khusus session corruption, workspace migration, protected tab, suspension, media event bridge, dan download destination.
- Menguji recovery form pada berbagai LMS tanpa menyimpan informasi sensitif.
- Menambahkan privacy policy, threat model, dan dokumentasi batasan Exam Protection.

### P1 — quality dan product readiness

- Menyelesaikan UI workspace editor, drag-and-drop tab, duplicate/export workspace, dan warning protected workspace.
- Menghubungkan seluruh typed Settings ke behavior aplikasi; beberapa setting saat ini baru disimpan sebagai preferensi UI.
- Menyempurnakan theme system untuk System/Light/Dark dan reduced motion/transparency.
- Menambahkan history, bookmarks, per-site data viewer, serta clear-data granular.
- Menambahkan diagnostics preview/export melalui save panel.
- Menambahkan About, Help, Report Issue, dan acknowledgements yang final.
- Melakukan pengujian VoiceOver, keyboard-only navigation, contrast, dan Dynamic Type.
- Menambah localization, dimulai dari Bahasa Indonesia dan English.

### P2 — distribusi

- Menentukan versi aplikasi dan strategi semantic versioning.
- Menyiapkan Apple Developer signing certificate dan hardened runtime.
- Menentukan kebutuhan App Sandbox serta entitlement download/network yang tepat.
- Melakukan archive, code signing, notarization, dan Gatekeeper validation.
- Menyiapkan DMG atau distribusi Mac App Store beserta screenshot dan metadata.
- Menambahkan CI untuk build, unit test, static checks, dan release artifact.
- Menjalankan beta terbatas dan mengumpulkan crash/feedback yang tetap menjaga privasi.

## Keterbatasan penting

- LeafOrLeave tidak dapat melewati DRM, LMS timeout, authentication rules, atau keputusan server.
- Restored/discarded tab tidak menjamin pemulihan dynamic JavaScript state.
- PiP, AirPlay, autoplay, dan equalizer bergantung pada WebKit serta kebijakan website.
- Website dapat menolak custom browser behavior atau mengubah kompatibilitas tanpa pemberitahuan.
- Jangan gunakan build awal ini untuk ujian atau pekerjaan kritis tanpa backup dan pengujian sendiri.

## Kontribusi

Issue dan pull request dipersilakan. Untuk perubahan besar, jelaskan masalah, behavior yang diharapkan, langkah reproduksi, versi macOS/Xcode, dan dampak privasi atau keamanan.

Sebelum mengirim pull request:

1. Pastikan proyek build.
2. Jalankan unit test.
3. Jangan commit token, cookie, credential, DerivedData, atau `xcuserdata`.
4. Tambahkan test untuk behavior baru.
5. Dokumentasikan perubahan dan batasannya.

## Keamanan

Jangan membuka issue publik yang berisi credential, authentication token, exam answer, atau data pribadi. Untuk saat ini belum tersedia kanal security disclosure khusus; kanal tersebut harus dibuat sebelum public beta.

## Lisensi

Lisensi open-source belum ditentukan. Sampai file `LICENSE` ditambahkan, seluruh hak tetap dimiliki oleh pemilik repository dan penggunaan ulang belum otomatis diizinkan.

## Logo

Logo asli disediakan oleh pemilik proyek. App icon merupakan adaptasi tanpa wordmark agar tetap terbaca pada ukuran ikon macOS.
