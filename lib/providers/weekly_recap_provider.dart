import 'package:flutter/foundation.dart';

import '../data/models/student.dart';
import '../data/models/weekly_recap.dart';
import '../data/repositories/weekly_recap_repository.dart';

/// State daftar rekap pekanan milik 1 santri — dipakai kartu "Rekap
/// Pekanan dari Guru" di HistoryScreen. Pola sama persis seperti
/// [ParentNoteProvider]/[DashboardProvider]: dibuat sekali per sesi di
/// MainShell, load sekali saat dibuat.
class WeeklyRecapProvider extends ChangeNotifier {
  final WeeklyRecapRepository repository;
  final Student student;

  WeeklyRecapProvider({required this.repository, required this.student});

  bool isLoading = false;
  String? error;
  List<WeeklyRecap> recaps = [];

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      recaps = await repository.getRecentForStudent(student);
    } catch (e) {
      // Sama seperti ParentNoteProvider.loadRecent -- rekap pekanan
      // sifatnya pelengkap di HistoryScreen (histori laporan harian di
      // bawahnya tetap tampil), jadi kegagalan di sini TIDAK boleh bikin
      // seluruh HistoryScreen kelihatan error. Cukup dicatat, dan
      // section-nya sendiri yang nampilin state kosong/gagal.
      debugPrint('WeeklyRecapProvider.load GAGAL: $e');
      error = 'Gagal memuat rekap pekanan.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
