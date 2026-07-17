# Pulse

Monitor FPS/CPU/GPU realtime untuk game Android, dengan overlay
mengambang yang bisa dikustomisasi temanya. **Butuh device root**
(Magisk atau sejenisnya) untuk data yang akurat.

## Status project ini

Ini adalah **kode awal yang bisa dikembangkan**, bukan APK jadi yang
sudah diuji di device asli. Saya (Claude) menulis semua kode di
sandbox tanpa akses ke Flutter SDK maupun device Android, jadi:

- Sintaks Dart/Kotlin sudah ditulis mengikuti API resmi masing-masing
  package (sudah dicek ulang lewat dokumentasi `flutter_overlay_window`
  dan `device_apps`), tapi **belum pernah di-compile atau dijalankan**.
- Kemungkinan ada penyesuaian kecil yang perlu dilakukan saat pertama
  kali `flutter pub get` / build (versi package, nama field API yang
  berubah, dsb).
- Parsing shell (`dumpsys`, `/proc`, sysfs) di `metrics_service.dart`
  sudah ditulis berdasarkan format yang umum dipakai, tapi **path dan
  format persisnya bisa berbeda antar vendor/versi Android** - ini
  butuh kalibrasi langsung di device rooted sungguhan.

Anggap ini sebagai kerangka struktur + implementasi awal yang solid
untuk dilanjutkan, bukan produk final.

## Build via GitHub Actions (tanpa setup lokal)

Sudah disiapkan workflow di `.github/workflows/build.yml` yang otomatis:
1. Setup Java 17 + Flutter stable di runner Ubuntu
2. Kalau folder `android/` belum lengkap (belum ada `gradlew`), workflow
   otomatis generate scaffolding gradle dari template Flutter resmi,
   lalu menyelaraskan `applicationId`/`namespace` supaya cocok dengan
   `MainActivity.kt` yang sudah kita tulis manual (`com.pulse.app`)
3. `flutter pub get` → `flutter build apk --release`
4. Upload hasil APK sebagai artifact yang bisa didownload dari halaman Actions

**Cara pakai:**
1. Buat repo baru di GitHub, push seluruh isi folder ini (termasuk
   `.github/workflows/build.yml` dan `.gitignore`):
   ```
   git init
   git add .
   git commit -m "initial commit"
   git branch -M main
   git remote add origin <url-repo-kamu>
   git push -u origin main
   ```
2. Buka tab **Actions** di repo GitHub-nya — workflow "Build Pulse APK"
   otomatis jalan setelah push ke branch `main`.
3. Setelah selesai (biasanya beberapa menit), buka run yang sukses →
   scroll ke bagian **Artifacts** → download `pulse-app-release-apk`.
4. Extract zip artifact-nya, dapat file `app-release.apk`, tinggal
   `adb install app-release.apk` atau kirim ke HP secara manual.

**Catatan:**
- Kalau mau trigger build manual tanpa push, buka tab Actions → pilih
  workflow → "Run workflow" (sudah diaktifkan lewat `workflow_dispatch`).
- GitHub Actions cuma memastikan project **berhasil di-compile** - fitur
  yang butuh root (metrics, overlay) tetap harus dites manual di HP
  rooted asli, karena runner GitHub tidak punya device Android.
- Kalau build gagal di percobaan pertama, biasanya penyebabnya versi
  `flutter_overlay_window`/`device_apps` yang perlu disesuaikan dengan
  versi Flutter/AGP terbaru - cek log error di tab Actions, gampang
  ditelusuri dari situ.

## Cara menjalankan (lokal, alternatif kalau tidak pakai GitHub Actions)

1. Pastikan Flutter SDK sudah terpasang (`flutter doctor`).
2. Kalau folder `android/` di project ini belum lengkap (biasanya
   perlu file gradle dsb yang di-generate otomatis), jalankan dulu:
   ```
   flutter create --org com.pulse --project-name pulse_app .
   ```
   di root folder ini, lalu **jangan timpa** `lib/`, `pubspec.yaml`,
   `MainActivity.kt`, dan `AndroidManifest.xml` yang sudah ada -
   biarkan `flutter create` hanya mengisi bagian gradle/wrapper yang
   belum ada.
3. `flutter pub get`
4. Sambungkan device Android **yang sudah di-root** lewat USB (USB
   debugging aktif), lalu `flutter run`.
5. Saat pertama buka app, akan diminta izin overlay (SYSTEM_ALERT_WINDOW)
   - izinkan lewat dialog yang muncul.
6. Saat pertama kali memantau game, app akan menjalankan `su -c id`
   lewat shell - device akan menampilkan prompt Magisk untuk approve
   akses root untuk Pulse. Approve dengan "Grant".

## Struktur kode

```
lib/
  main.dart                  - entry point app utama
  overlay_entry.dart          - entry point ISOLATE overlay (terpisah dari app utama)
  models/                     - Metrics, OverlayThemeData, GameItem
  services/
    root_shell.dart            - jembatan MethodChannel ke MainActivity.kt
    metrics_service.dart       - parsing dumpsys/proc/sysfs jadi Metrics
    foreground_watcher.dart    - deteksi app yang sedang di depan (jaring pengaman)
    game_repository.dart       - persist daftar game (SharedPreferences)
    theme_repository.dart      - persist tema overlay terpilih
    overlay_controller.dart    - orkestrasi: launch game -> overlay -> auto-stop
  screens/                     - Dashboard, Games, Theme + HomeShell (nav mengambang)
  widgets/                     - FloatingNavBar, MetricCard, WaveformChart, OverlayWidgetView
android/app/src/main/
  kotlin/.../MainActivity.kt   - handler MethodChannel "pulse/root" (exec su)
  AndroidManifest.xml          - permission overlay, query package, dsb
```

## Batasan yang perlu diketahui (baca sebelum lapor "bug")

- **GPU busy% & frekuensi**: hanya berfungsi di chipset **Qualcomm
  Adreno** lewat path `/sys/class/kgsl/kgsl-3d0/...`. Di GPU lain
  (Mali/PowerVR/dst) field ini akan tampil "-" karena path sysfs-nya
  beda. Butuh deteksi vendor GPU + path alternatif untuk device lain.
- **GPU selalu system-wide**, bukan per-game - Android tidak memecah
  GPU busy% per proses di kebanyakan device.
- **FPS via `dumpsys gfxinfo framestats`**: format kolom CSV-nya bisa
  berubah antar versi Android. Kalau FPS selalu tampil 0 di device
  tertentu, cek dulu output mentah perintah itu manual lewat `adb
  shell dumpsys gfxinfo <package> framestats` dan sesuaikan index
  kolom di `_readFps()`.
- **Nama zona termal** (`thermal_zone*`) sangat bervariasi antar
  vendor - heuristik "mengandung kata cpu/gpu" di `_readTemps()`
  kemungkinan perlu disesuaikan manual per device.
- **Root prompt berulang**: setiap App baru minta akses root biasanya
  di-approve sekali lewat Magisk (opsi "remember"), tapi ini
  tergantung setting Magisk user.

## Langkah lanjutan yang masuk akal

1. Jalankan di device rooted, cek log `dumpsys` mentah untuk
   menyesuaikan parser.
2. Tambah layar Settings kecil untuk override manual path sysfs GPU
   (biar user Mali/PowerVR juga bisa isi path yang benar).
3. Tambah state persistence untuk overlay position terakhir (sekarang
   posisi overlay reset ke topLeft tiap sesi baru).
4. Pertimbangkan menyimpan riwayat sesi (durasi main, rata-rata FPS)
   biar dashboard bisa menampilkan riwayat, bukan cuma live.
