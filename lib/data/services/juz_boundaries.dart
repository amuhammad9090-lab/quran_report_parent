/// Batas 30 juz standar mushaf (surah:ayat awal → surah:ayat akhir). Ini
/// DATA BAKU Al-Qur'an (sama di setiap mushaf cetak), bukan sesuatu yang
/// diasumsikan/diketik ulang khusus app ini — cocok dijadikan sumber
/// perhitungan "total baris per juz" karena [QuranEngineService] sendiri
/// (file shared, TIDAK diubah) belum menyimpan info juz per baris —
/// datanya cuma per-halaman/per-ayat (lihat catatan di
/// `quran_engine_service.dart`).
///
/// Contoh: Juz 30 = An-Naba (78) ayat 1 s.d. An-Nas (114) ayat 6.
class JuzBoundary {
  final int juz;
  final int startSurah;
  final int startAyah;
  final int endSurah;
  final int endAyah;
  const JuzBoundary(this.juz, this.startSurah, this.startAyah, this.endSurah, this.endAyah);
}

const List<JuzBoundary> kJuzBoundaries = [
  JuzBoundary(1, 1, 1, 2, 141),
  JuzBoundary(2, 2, 142, 2, 252),
  JuzBoundary(3, 2, 253, 3, 92),
  JuzBoundary(4, 3, 93, 4, 23),
  JuzBoundary(5, 4, 24, 4, 147),
  JuzBoundary(6, 4, 148, 5, 81),
  JuzBoundary(7, 5, 82, 6, 110),
  JuzBoundary(8, 6, 111, 7, 87),
  JuzBoundary(9, 7, 88, 8, 40),
  JuzBoundary(10, 8, 41, 9, 92),
  JuzBoundary(11, 9, 93, 11, 5),
  JuzBoundary(12, 11, 6, 12, 52),
  JuzBoundary(13, 12, 53, 14, 52),
  JuzBoundary(14, 15, 1, 16, 128),
  JuzBoundary(15, 17, 1, 18, 74),
  JuzBoundary(16, 18, 75, 20, 135),
  JuzBoundary(17, 21, 1, 22, 78),
  JuzBoundary(18, 23, 1, 25, 20),
  JuzBoundary(19, 25, 21, 27, 55),
  JuzBoundary(20, 27, 56, 29, 45),
  JuzBoundary(21, 29, 46, 33, 30),
  JuzBoundary(22, 33, 31, 36, 27),
  JuzBoundary(23, 36, 28, 39, 31),
  JuzBoundary(24, 39, 32, 41, 46),
  JuzBoundary(25, 41, 47, 45, 37),
  JuzBoundary(26, 46, 1, 51, 30),
  JuzBoundary(27, 51, 31, 57, 29),
  JuzBoundary(28, 58, 1, 66, 12),
  JuzBoundary(29, 67, 1, 77, 50),
  JuzBoundary(30, 78, 1, 114, 6),
];

/// Juz yang memuat surah+ayat tertentu — dipakai untuk mengelompokkan
/// segmen laporan santri ke juz yang relevan (pakai ayat AWAL segmen
/// sebagai representasi; segmen yang menyeberang 2 juz sekaligus, kasus
/// sangat jarang, otomatis masuk ke juz tempat ayat awalnya berada).
int? juzForSurahAyah(int surah, int ayah) {
  for (final b in kJuzBoundaries) {
    final afterStart = surah > b.startSurah || (surah == b.startSurah && ayah >= b.startAyah);
    final beforeEnd = surah < b.endSurah || (surah == b.endSurah && ayah <= b.endAyah);
    if (afterStart && beforeEnd) return b.juz;
  }
  return null;
}

/// Pecah rentang satu juz jadi segmen per-surah (surah, ayatAwal,
/// ayatAkhir) — dipakai memanggil `QuranEngineService.generateLines()`
/// per surah. `ayahEnd: 999` sengaja dipakai untuk surah yang TIDAK
/// diakhiri di juz itu (bukan surah terakhir juz) — `generateLines`
/// cuma mencocokkan ayat yang benar-benar ada di dataset, jadi angka
/// besar ini aman dipakai sebagai "sampai ayat terakhir surah itu" TANPA
/// perlu tabel jumlah-ayat-per-surah terpisah.
List<({int surah, int ayahStart, int ayahEnd})> surahRangesForJuz(int juz) {
  final b = kJuzBoundaries.firstWhere((e) => e.juz == juz, orElse: () => kJuzBoundaries[0]);
  if (b.startSurah == b.endSurah) {
    return [(surah: b.startSurah, ayahStart: b.startAyah, ayahEnd: b.endAyah)];
  }
  final segs = <({int surah, int ayahStart, int ayahEnd})>[
    (surah: b.startSurah, ayahStart: b.startAyah, ayahEnd: 999),
  ];
  for (var s = b.startSurah + 1; s < b.endSurah; s++) {
    segs.add((surah: s, ayahStart: 1, ayahEnd: 999));
  }
  segs.add((surah: b.endSurah, ayahStart: 1, ayahEnd: b.endAyah));
  return segs;
}
