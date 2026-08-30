# Quran Report — Portal Orang Tua

Companion Flutter Web read-only untuk app guru **Quran Report**. Status:
**STEP 1-9 selesai**, STEP 10 (integrasi backend) **UI-nya selesai**,
tinggal implementasi Firestore-nya (lihat bagian paling bawah).

## Yang di-*share* apa adanya dari app guru (TIDAK diubah, copy verbatim)
- `lib/core/theme/app_colors.dart`, `app_theme.dart`
- `lib/core/utils/text_utils.dart`
- `lib/data/models/enums.dart`, `santri_record.dart`, `student.dart`
- `lib/data/services/quran_engine_service.dart`, `auth_hash_service.dart`
- `lib/presentation/widgets/misc_widgets.dart`, `status_badge.dart`

**Disinkronkan terakhir:** 30 Agustus 2026, ikut update app guru
terbaru (`app_colors.dart` & `enums.dart` — nambah 3 keterangan baru
"Tidak Setoran/Tahsin/Murojaah"; `quran_engine_service.dart` — sekarang
baca 1 file dataset gabungan, API publik tidak berubah). Kalau app guru
update lagi salah satu file ini, tinggal copy ulang ke sini (atau,
lebih baik jangka panjang: extract jadi package Dart terpisah yang
di-`import` kedua app).

## Yang baru dibuat (tidak ada di app guru, murni untuk portal ini)
- `lib/data/models/santri_account.dart` — akun login santri, FK ke `Student.id`
- `lib/core/access/parent_access_scope.dart` — scope 1 santri per sesi login
- `lib/data/repositories/*` — `StudentRepository`, `SantriAccountRepository`,
  `ReportRepository` — interface + implementasi `Mock*` (in-memory, seed demo)
- `lib/data/services/juz_boundaries.dart` — batas 30 juz standar mushaf (data baku)
- `lib/data/services/progress_calculation_service.dart` — **FINAL**: formula
  baris-based per-juz (lihat dokumentasi di file itu untuk alasan)
- `lib/providers/{auth,dashboard,hafalan}_provider.dart`
- `lib/presentation/screens/{auth,dashboard,hafalan,history,profile}/*` — 5 layar orang tua, semua sudah full UI
- `lib/presentation/screens/admin/{admin_pin_gate,manage_accounts_screen}.dart` — area admin di rute `/admin`
- `lib/presentation/main_shell.dart` — nav adaptif (bottom bar mobile / rail desktop)
- `lib/core/utils/responsive.dart` — pembatas lebar konten di layar besar

## Assets
- `assets/data/quran_line_dataset_juz1-10_juz26-30_schema.json` ✅ sudah ada
  (Juz 1-10 & 26-30 tersedia; Juz 11-25 memang belum ada dataset-nya di
  app guru sendiri — kartu progress juz itu otomatis menampilkan
  "Dataset belum tersedia", bukan 0%)
- `assets/images/app_icon.png`, `logo_smpit.png` ✅ sudah ada

## Cara jalanin
```
flutter pub get
flutter run -d chrome
```
Akun demo (data dari `MockReportRepository`/`MockSantriAccountRepository`,
hilang tiap refresh — lihat bagian STEP 10 di bawah):
- `ahmad.fauzan` / `demo123` — ada 3 laporan contoh
- `siti.aisyah` / `demo123` — belum ada laporan (buat test empty state)

Area admin (buat akun santri baru): buka `/#/admin` di browser, PIN
placeholder `246810` (lihat catatan keamanan di `admin_pin_gate.dart`
— WAJIB diganti sebelum production).

## STEP 10 — Integrasi Backend (Firestore) — status: rules & repository siap, MENUNGGU project Firebase

**Approval Anda:** Firestore, rencana migrasi additive ke app guru — **disetujui**.

### ⚠️ 1 pergeseran desain yang perlu Anda tahu (soal password)

Rencana awal: `SantriAccount.passwordHash` disimpan di Firestore,
diverifikasi client-side pakai `AuthHashService` yang sama kayak
sekarang. **Ternyata ini bermasalah di Firestore**: supaya password bisa
dicek SEBELUM login (client baca dulu hash-nya, baru dibandingkan),
dokumen `santriAccounts` itu harus bisa dibaca oleh siapa saja yang
belum login — artinya password hash SEMUA akun (bukan cuma milik
pembaca) jadi bisa diintip siapa saja lewat DevTools browser.

**Solusi yang saya usulkan:** pindah verifikasi password ke **Firebase
Authentication** (email/password, pakai email sintetis
`username@quranreport-parent.app`) — password-nya dipegang penuh oleh
Firebase, tidak pernah masuk Firestore sama sekali. `SantriAccount` di
Firestore jadi cuma metadata (`studentId`, `isActive`), dan Security
Rules cukup cek `request.auth.uid` — jauh lebih simpel & aman
(lihat `firestore_integration/firestore.rules`).

**Konsekuensi:** `AuthProvider.login()` nanti perlu diubah jadi manggil
`FirebaseAuth.instance.signInWithEmailAndPassword()` dulu, baru ambil
metadata. **Belum saya ubah** file `auth_provider.dart` yang di `lib/`
sekarang — sengaja nunggu project Firebase-nya ada dulu supaya saya
bisa test alurnya beneran, bukan nulis kode buta yang belum tentu jalan.

### Isi folder `firestore_integration/` (di LUAR `lib/`, sengaja)

Supaya project sekarang **tetap bisa di-build & demo** tanpa Firebase
(pubspec belum nambah `cloud_firestore`), semua kode Firestore saya taruh
terpisah dulu:
- `firestore_student_repository.dart`, `firestore_report_repository.dart`,
  `firestore_santri_account_repository.dart` — implementasi siap pakai,
  tinggal pindah ke `lib/data/repositories/firestore/` begitu deps aktif
- `firestore.rules` — draf Security Rules (belum di-deploy)
- `GURU_APP_PATCH_storage_service.dart` — **usulan** patch minimal buat
  `StorageService` app guru (mirror-write ke Firestore, Hive tetap sumber
  utama & tetap jalan 100% offline kalau Firestore gagal). Baris
  Firestore-nya masih di-comment — aktifkan setelah deps & config ada.
  **Belum saya apply ke repo guru Anda** — ini draf untuk direview dulu.

  Catatan: `Student` (data master santri) app guru **saat ini cuma seed
  lokal** (`kSeedStudentsJson`, dibaca oleh `LocalStudentRepository`) —
  belum ada fitur guru edit/tambah santri via UI. Jadi belum ada
  write-path Student yang bisa di-mirror; kalau Firestore jadi sumber,
  data santri perlu di-upload manual sekali (one-time import), bukan
  otomatis ter-mirror kayak SantriRecord.

### Yang perlu Anda siapkan (baru saya bisa lanjut coding beneran)

1. **Bikin project Firebase**: buka [console.firebase.google.com](https://console.firebase.google.com) →
   "Add project" → aktifkan **Firestore Database** (mode production,
   pilih region terdekat mis. `asia-southeast2`) → aktifkan
   **Authentication** → provider **Email/Password**.
2. Jalankan `flutterfire configure` di root project `quran_report_parent_web`
   (butuh Firebase CLI: `npm install -g firebase-tools` lalu `firebase login`)
   — ini generate `lib/firebase_options.dart` otomatis.
3. Kirim `project ID` Firebase-nya ke saya (tidak perlu kirim API key/secret
   apa pun — `firebase_options.dart` isinya memang publik/aman di-commit).
4. Konfirmasi: mau saya apply `GURU_APP_PATCH_storage_service.dart` ke repo
   guru beneran setelah ini, atau Anda yang apply manual?

Begitu #1-3 ada, saya: pindahkan 3 file repository ke `lib/`, uncomment
dependency, deploy rules (perlu Anda jalankan `firebase deploy --only
firestore:rules` karena butuh akses project Anda), dan ubah
`auth_provider.dart` ke alur Firebase Auth.

