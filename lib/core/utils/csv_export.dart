/// Unduh teks CSV sebagai file — HANYA dipakai admin utility (bulk-create
/// akun di `manage_accounts_screen.dart`), BUKAN oleh orang tua, jadi
/// tidak melanggar prinsip "portal ortu read-only, tanpa fitur export"
/// (lihat catatan dependency di pubspec.yaml — sengaja tidak nambah
/// package `csv`/`excel`, CSV dibikin manual sebagai string biasa).
///
/// Implementasi beda per platform: browser (web) trigger download file
/// beneran lewat `dart:html`; platform lain (io) fallback ke clipboard
/// karena portal ini pada praktiknya cuma dijalankan sebagai web app
/// lewat Firebase Hosting — path `io` jarang kepake, cuma jaga-jaga
/// biar tidak gagal build kalau suatu saat di-build ke platform lain.
library;

export 'csv_export_io.dart' if (dart.library.html) 'csv_export_web.dart';
