import 'package:flutter/foundation.dart';

import '../data/models/santri_record.dart';
import '../data/services/juz_boundaries.dart';
import '../data/services/progress_calculation_service.dart';

/// Menyiapkan daftar [JuzProgress] untuk juz-juz yang pernah disentuh
/// santri (dari [ProgressCalculationService.juzTouchedBy]). Read-only,
/// tidak ada method mutate.
class HafalanProvider extends ChangeNotifier {
  final ProgressCalculationService progressService;

  HafalanProvider({required this.progressService});

  List<JuzProgress> juzProgress = [];
  int? _primaryJuzNumber;
  bool isReady = false;

  void computeFrom(List<SantriRecord> records) {
    final juzList = progressService.juzTouchedBy(records);
    juzProgress = [
      for (final j in juzList) progressService.calculateJuzProgress(juz: j, records: records),
    ];

    // Juz dari laporan Tahfizh PALING BARU (records sudah terurut
    // terbaru dulu) — ini yang paling relevan ditampilkan ringkas di
    // Dashboard, BUKAN sekadar juz bernomor terbesar.
    _primaryJuzNumber = null;
    for (final r in records) {
      final segs = r.tahfizhSegmentsEffective;
      if (segs.isEmpty) continue;
      _primaryJuzNumber = juzForSurahAyah(segs.first.surahNumber, segs.first.ayatMulai);
      if (_primaryJuzNumber != null) break;
    }

    isReady = true;
    notifyListeners();
  }

  /// Progress juz dari laporan Tahfizh paling baru — null kalau santri
  /// belum pernah punya laporan Tahfizh sama sekali.
  JuzProgress? get primaryJuz {
    if (_primaryJuzNumber == null) return null;
    try {
      return juzProgress.firstWhere((p) => p.juz == _primaryJuzNumber);
    } catch (_) {
      return null;
    }
  }
}
