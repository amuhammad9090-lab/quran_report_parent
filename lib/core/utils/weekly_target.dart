import 'text_utils.dart';

/// Target baris Tahfizh per PEKAN berdasarkan halaqoh santri — pedoman
/// internal pesantren (bukan hasil hitungan dari data), jadi angkanya
/// di-hardcode di sini. Kalau pedomannya berubah, cukup ubah di satu
/// tempat ini.
///
/// Halaqoh dicocokkan dari HURUF PERTAMA nilai `student.halaqoh` setelah
/// dinormalisasi (lihat [normalizeHalaqoh]) — jadi tetap match walau
/// formatnya "A" polos atau "Halaqoh A". Return null kalau hurufnya
/// nggak dikenali (bukan A/B/C/D) — pemanggil harus nampilin "-",
/// BUKAN 0%, biar nggak menyesatkan (lihat pola yang sama di
/// [JuzProgress.datasetAvailable]).
int? weeklyTargetBarisForHalaqoh(String halaqoh) {
  final normalized = normalizeHalaqoh(halaqoh).trim().toUpperCase();
  if (normalized.isEmpty) return null;
  switch (normalized[0]) {
    case 'A':
      return 15;
    case 'B':
      return 12;
    case 'C':
    case 'D':
      return 10;
    default:
      return null;
  }
}
