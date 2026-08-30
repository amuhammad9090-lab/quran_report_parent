import '../models/santri_record.dart';
import 'juz_boundaries.dart';
import 'quran_engine_service.dart';

/// Hasil perhitungan progress satu juz untuk satu santri.
class JuzProgress {
  final int juz;
  final int totalBarisJuz; // penyebut: total baris fisik juz ini di dataset
  final int barisTercapai; // pembilang: baris yang sudah pernah disetorkan santri

  const JuzProgress({
    required this.juz,
    required this.totalBarisJuz,
    required this.barisTercapai,
  });

  /// Dataset untuk juz ini tidak tersedia (baik karena juz 11–25 yang
  /// memang belum ada engine-nya, ATAU karena file
  /// assets/data/quran_line_dataset_*.json belum di-upload ke project
  /// ini — dua kasus itu sengaja diperlakukan SAMA: tampilkan "belum
  /// tersedia", JANGAN tampilkan 0%, karena 0% menyiratkan "santri belum
  /// hafal apa-apa" padahal yang sebenarnya terjadi adalah "datanya
  /// belum bisa dihitung".
  bool get datasetAvailable => totalBarisJuz > 0;

  double get ratio => datasetAvailable ? (barisTercapai / totalBarisJuz).clamp(0, 1) : 0;
}

/// FINAL (STEP 6) — keputusan formula: BARIS-BASED (opsi B dari skeleton
/// sebelumnya), bukan surah-count. Alasan: surah dalam 1 juz jumlah
/// barisnya sangat timpang (juz 30 isi puluhan surah pendek, juz lain
/// bisa cuma sebagian dari 1 surah panjang) — hitung per-surah akan
/// menyesatkan untuk juz selain 26–30. Baris-based konsisten dengan
/// satuan yang SUDAH dipakai app guru (`totalBaris`), cuma diagregasi
/// per-juz di sini (agregasi ini genuinely baru, app guru tidak pernah
/// melakukan ini — sesuai keputusan Anda, TIDAK ditambahkan ke app guru).
///
/// PENTING: TIDAK mengubah `QuranEngineService` (file shared, verbatim
/// dari app guru) — kelas ini murni KONSUMEN dari method publik yang
/// sudah ada (`generateLines`), menambah agregasi per-juz di layer ini
/// saja lewat [kJuzBoundaries] (data baku Al-Qur'an, lihat
/// `juz_boundaries.dart`).
class ProgressCalculationService {
  final QuranEngineService engine;

  const ProgressCalculationService({required this.engine});

  /// Semua `lineId` fisik yang termasuk juz [juz] menurut dataset engine
  /// (dipanggil sekali per juz — pemanggil sebaiknya cache hasilnya
  /// kalau dipakai berulang, lihat [HafalanProvider]).
  Set<String> _lineIdsForJuz(int juz) {
    final ids = <String>{};
    for (final seg in surahRangesForJuz(juz)) {
      final result = engine.generateLines(
        surah: seg.surah,
        start: seg.ayahStart,
        end: seg.ayahEnd,
      );
      ids.addAll(result.newLineIds);
    }
    return ids;
  }

  /// Progress juz [juz] untuk santri dengan riwayat [records]. Baris
  /// tercapai dihitung dari IRISAN `lineIds` tiap segmen Tahfizh dengan
  /// baris milik juz ini — bukan `totalBaris` mentah — supaya laporan
  /// yang (jarang terjadi) menyeberang batas juz tidak salah atribusi
  /// 100% ke satu juz.
  JuzProgress calculateJuzProgress({
    required int juz,
    required List<SantriRecord> records,
  }) {
    final juzLineIds = _lineIdsForJuz(juz);

    final achieved = <String>{};
    for (final r in records) {
      for (final seg in r.tahfizhSegmentsEffective) {
        achieved.addAll(seg.lineIds.where(juzLineIds.contains));
      }
    }

    return JuzProgress(
      juz: juz,
      totalBarisJuz: juzLineIds.length,
      barisTercapai: achieved.length,
    );
  }

  /// Semua nomor juz yang "disentuh" riwayat [records] — dipakai supaya
  /// Hafalan screen hanya menampilkan juz yang relevan buat santri ini,
  /// bukan render 30 juz sekaligus (mayoritas kosong buat santri baru).
  List<int> juzTouchedBy(List<SantriRecord> records) {
    final juzSet = <int>{};
    for (final r in records) {
      for (final seg in r.tahfizhSegmentsEffective) {
        final j = juzForSurahAyah(seg.surahNumber, seg.ayatMulai);
        if (j != null) juzSet.add(j);
      }
    }
    final list = juzSet.toList()..sort();
    return list;
  }
}
