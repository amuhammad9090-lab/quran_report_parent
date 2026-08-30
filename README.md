# STEP 3 — Struktur Project (Quran Report — Portal Orang Tua)

Scaffold ini hasil STEP 3. Belum ada UI final (itu STEP 4-8) — fokus
STEP 3 adalah struktur, wiring, dan bagian yang memang sudah bisa
langsung *reuse* dari app guru.

## Yang di-*share* apa adanya (copy verbatim dari app guru, TIDAK diubah)
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/utils/text_utils.dart`
- `lib/data/models/enums.dart`
- `lib/data/models/santri_record.dart` (+ `TahfizhSegment`, `TilawahSegment`)
- `lib/data/models/student.dart`
- `lib/data/services/quran_engine_service.dart`
- `lib/data/services/auth_hash_service.dart`

Kalau nanti app guru meng-update salah satu file ini, tinggal copy ulang
ke sini (atau — lebih baik — extract jadi package Dart terpisah yang
di-`import` kedua app, sesuai saran di brief awal).

## Yang baru dibuat (tidak ada di app guru, sesuai keputusan Anda)
- `lib/data/models/santri_account.dart` — entitas akun santri terpisah, FK ke `Student.id`
- `lib/core/access/parent_access_scope.dart` — scope 1 santri per sesi login
- `lib/data/repositories/*` — `StudentRepository`, `SantriAccountRepository`, `ReportRepository` (semua ada implementasi `Mock*` dulu)
- `lib/data/services/progress_calculation_service.dart` — **skeleton**, formula final diputuskan STEP 6
- `lib/providers/auth_provider.dart` — login pakai `SantriAccount`, hash pakai `AuthHashService` yang di-share
- `lib/presentation/screens/admin/manage_accounts_screen.dart` — placeholder halaman terkunci PIN untuk kelola akun (detail STEP 10)

## Placeholder (struktur siap, isi UI menyusul)
`login_screen.dart` (STEP 4), `dashboard_screen.dart` (STEP 5),
`hafalan_screen.dart` (STEP 6), `history_screen.dart` (STEP 7),
`profile_screen.dart` (STEP 8).

## ⚠️ Yang masih Anda perlu sediakan sebelum STEP 6 akurat
`QuranEngineService` butuh 2 file dataset yang **tidak ada di lib.zip**
yang Anda upload (karena itu hanya folder `lib/`):
- `assets/data/quran_line_dataset_legacy_juz1_10.json`
- `assets/data/quran_line_dataset_juz26_30.json`

Folder `assets/data/` sudah saya siapkan kosong. Tanpa 2 file ini,
engine tetap jalan (ada try/catch, tidak crash) tapi cakupan baris = 0,
jadi progress hafalan berbasis baris (opsi B di
`progress_calculation_service.dart`) tidak akan akurat sampai file ini
di-upload. Kalau Anda pilih opsi A (surah-count) di STEP 6, file ini
tidak wajib.

## Cara jalanin (setelah `flutter pub get`)
```
flutter run -d chrome
```

## Belum dikerjakan (menyusul step berikutnya sesuai rencana Anda)
~~STEP 4~~ → ~~STEP 5~~ → ~~STEP 6~~ → ~~STEP 7~~ → ~~STEP 8~~ → ~~STEP 9~~ →
**STEP 10 (integrasi backend) — lihat bagian di bawah, INI YANG BUTUH
KEPUTUSAN ANDA sebelum bisa benar-benar "selesai".**

## STEP 10 — Status & yang perlu diputuskan

**Yang sudah selesai (UI-level, jalan dengan Mock repository):**
- Rute `/admin` (`AdminPinGate` -> `ManageAccountsScreen`) — PIN gate
  terpisah total dari sesi orang tua, tidak ada link ke sana dari UI
  orang tua sama sekali.
- `ManageAccountsScreen`: lihat daftar santri belum punya akun, generate
  username+password (password random 8 karakter, tanpa karakter
  ambigu), lihat/nonaktifkan akun yang sudah ada.
- Semua sudah lewat interface `StudentRepository`/`SantriAccountRepository`
  yang sama dipakai bagian orang tua — tinggal ganti implementasi Mock
  jadi implementasi backend, TIDAK perlu ubah UI sama sekali.

**⚠️ Gap besar yang BELUM bisa saya selesaikan sendiri, butuh keputusan Anda:**

App guru **saat ini 100% menyimpan data secara lokal** di device guru
(Hive `Box<String>`, lihat audit STEP 1) — **tidak ada backend/cloud
sama sekali** yang bisa dibaca web parent dari device lain. Ini bukan
"belum diintegrasikan", ini "memang belum ada sumber data bersama sama
sekali". Supaya web parent bisa menampilkan data ASLI (bukan mock),
harus ada salah satu dari ini:

1. **Migrasi app guru ke cloud DB** (mis. Firestore) — app guru mulai
   menulis ke cloud, bukan cuma Hive lokal. Ini teknisnya *penambahan*
   (Hive bisa tetap jadi cache offline), tapi tetap **menyentuh app
   guru** — bertentangan dengan prinsip "jangan merombak", walau
   sifatnya additive bukan restructuring.
2. **Mekanisme sync/export terpisah** — mis. app guru export
   berkala/manual ke cloud storage, web parent baca dari situ. App guru
   tetap disentuh (perlu fitur export), tapi lebih minimal.
3. Opsi lain yang Anda punya di kepala tapi belum disebutkan di brief.

Saya **sengaja tidak memilih salah satu secara sepihak** karena ini
langsung berkaitan dengan aturan keras #1 Anda ("jangan merombak
aplikasi guru") — beda dengan keputusan SantriAccount/formula progress
sebelumnya yang bisa saya selesaikan tanpa menyentuh app guru sama
sekali, opsi manapun di sini **pasti** perlu app guru ditambah
sesuatu (walau kecil). Kalau Anda pilih salah satu, saya lanjutkan
implementasi repository backend-nya (`FirestoreStudentRepository`, dst)
— strukturnya sudah siap dari STEP 3, tinggal isi.

