# Quran Report — Portal Orang Tua

Companion Flutter Web read-only untuk app guru **Quran Report**.
**STEP 1-10 semua sudah diimplementasikan.** Backend: **Firestore**,
project `quran-reportweb`.

## Yang di-*share* apa adanya dari app guru (TIDAK diubah, copy verbatim)
- `lib/core/theme/app_colors.dart`, `app_theme.dart`
- `lib/core/utils/text_utils.dart`
- `lib/data/models/enums.dart`, `santri_record.dart`, `student.dart`
- `lib/data/services/quran_engine_service.dart`, `auth_hash_service.dart`
  (`auth_hash_service.dart` sudah tidak dipakai lagi di alur login —
  lihat bagian Auth di bawah — tapi tetap disimpan, siapa tahu berguna)
- `lib/presentation/widgets/misc_widgets.dart`, `status_badge.dart`

**Disinkronkan terakhir:** 30 Agustus 2026.

## Assets — semua sudah ada
- `assets/data/quran_line_dataset_juz1-10_juz26-30_schema.json`
- `assets/images/app_icon.png`, `logo_smpit.png`

## Backend: Firestore (project `quran-reportweb`)

### Struktur data
```
schools/{schoolId}/
  students/{studentId}       — Student.toJson(), read-only dari client
  santriRecords/{recordId}   — SantriRecord.toJson(), read-only dari client
  santriAccounts/{uid}       — {studentId, username, isActive, createdAt}
                                 id dokumen = UID Firebase Auth
```
`schoolId` sekarang di-hardcode `smpit_al_madinah_tanjungpinang` (harus
SAMA PERSIS dengan `schoolId` di data seed app guru — lihat
`lib/core/utils/app_config.dart`) — single-tenant, 1 sekolah.

### Auth: Firebase Authentication, BUKAN passwordHash

Login santri pakai Firebase Auth (email/password), dengan email SINTETIS
`username@quranreport-parent.app` (lihat `lib/core/utils/parent_auth_constants.dart`).
**Kenapa bukan `AuthHashService` + baca `passwordHash` dari Firestore
seperti rencana awal**: supaya password bisa dicek client-side SEBELUM
login, dokumennya harus bisa dibaca publik — artinya hash SEMUA akun
jadi bisa diintip siapa saja. Firebase Auth menghindari masalah ini
total (password tidak pernah masuk Firestore).

### Security Rules (`firestore_integration/firestore.rules`)
- `santriAccounts/{uid}`: santri baca dokumennya sendiri; **admin** (email
  cocok daftar di `isAdmin()`) baca+tulis semua.
- `students/{id}`: santri baca datanya sendiri; admin baca semua. Tidak
  ada write sama sekali (diisi lewat script seed).
- `santriRecords/{id}`: santri baca kalau kelas+halaqoh+namaAnak cocok
  dengan `Student` miliknya (dicek di rules, bukan cuma filter query
  client).

**Belum di-deploy** — jalankan dari root project:
```
firebase deploy --only firestore:rules
```

### Area Admin (`ManageAccountsScreen`, rute `/admin`) — TIDAK BUTUH BLAZE

Awalnya saya desain area admin lewat Cloud Functions (Admin SDK) supaya
bisa bypass rules dengan aman — tapi Cloud Functions generasi-2 WAJIB
plan Blaze (pay-as-you-go), jadi saya desain ulang supaya **semuanya
jalan di plan Spark (gratis)**:

- Admin login pakai **Firebase Auth beneran** (email/password), BUKAN
  PIN lokal lagi. Buat 1 akun admin manual sekali: Firebase Console →
  Authentication → Add user → email `admin@quranreport-parent-admin.local`
  (HARUS PERSIS — dicek di `firestore.rules`) + password pilihan Anda.
- `firestore.rules` (`isAdmin()`) izinkan email itu baca+tulis
  `students`/`santriAccounts` LANGSUNG — enforcement beneran di rules,
  bukan di UI.
- Bikin akun santri baru (`AdminAccountService.createAccount`) pakai
  **secondary Firebase App instance** (trik client-side, bukan Admin
  SDK) supaya proses `createUserWithEmailAndPassword` tidak
  menggantikan sesi login admin yang aktif.
- Nonaktifkan akun cukup lewat field `isActive` di Firestore — santri
  yang dinonaktifkan tetap gagal login (`AuthProvider` cek `isActive`
  setelah sign-in Firebase Auth berhasil, langsung sign-out paksa kalau
  false).

**Mau tambah/hapus admin?** Edit daftar email di `isAdmin()`
(`firestore_integration/firestore.rules`), lalu `firebase deploy --only
firestore:rules` lagi.

### Data awal (seed) — `students` sudah siap diimpor, `santriRecords` masih manual

`Student` (data master santri) di app guru **saat ini cuma seed lokal**
(`kSeedStudentsJson`, 302 santri, dibaca `LocalStudentRepository`) —
belum ada UI guru buat tambah/edit santri, apalagi sinkron ke Firestore.
Jadi:
- **`students`**: sudah saya extract ke `scripts/students_seed.json`
  (302 santri, persis sama dengan data app guru per 30 Agustus 2026) +
  script `scripts/seed_students.js` buat upload sekali ke Firestore.
  Cara pakai:
  ```bash
  cd scripts
  npm install
  # download service account key dari Firebase Console -> Project
  # Settings -> Service Accounts -> Generate new private key -> simpan
  # sebagai scripts/service-account.json
  node seed_students.js
  ```
  Catatan: script ini pakai Admin SDK tapi dijalankan LOKAL sekali lewat
  `node` (bukan Cloud Function yang di-deploy/hosting) — tetap TIDAK
  butuh plan Blaze.
  Aman dijalankan ulang (pakai `.set()`, overwrite bukan duplikat).
- **`santriRecords`** akan otomatis ter-mirror begitu
  `GURU_APP_PATCH_storage_service.dart` (lihat folder
  `firestore_integration/`) diterapkan ke app guru — **belum
  diterapkan**, masih draf/usulan, nunggu konfirmasi Anda siapa yang apply.

## Cara jalanin (setelah rules di-deploy + students di-seed + akun admin dibuat)
```
flutter pub get
flutter run -d chrome
```
Buka `/#/admin`, login pakai akun admin yang dibuat di Firebase Console,
klik "Buat Akun" untuk santri yang mau dibuatkan login orang tua-nya.

## Checklist yang masih perlu Anda lakukan
1. `firebase deploy --only firestore:rules`
2. Buat 1 akun admin: Firebase Console → Authentication → Add user →
   `admin@quranreport-parent-admin.local` + password pilihan Anda
3. `cd scripts && npm install && node seed_students.js` (butuh
   `scripts/service-account.json` dari Firebase Console — lihat bagian
   "Data awal" di atas) — upload 302 data Student ke Firestore
4. Putuskan siapa yang apply `GURU_APP_PATCH_storage_service.dart` ke repo app guru
