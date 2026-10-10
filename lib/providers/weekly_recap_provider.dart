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

  /// Nama guru pembimbing, diambil dari [WeeklyRecap.guruPembimbing] milik
  /// rekap PALING BARU yang field itu terisi (field-nya opsional — rekap
  /// lama sebelum app guru mulai mengirim field ini bakal null, jadi
  /// jangan cuma ambil [recaps].first mentah-mentah). Null kalau belum
  /// ada satu pun rekap pekanan yang pernah di-deploy guru buat santri
  /// ini, atau semuanya dari sebelum field ini ada — dipakai Profile
  /// buat nampilin "Guru Pembimbing" CUMA kalau datanya beneran ada.
  String? get guruPembimbingNama {
    for (final r in recaps) {
      final nama = r.guruPembimbing?.trim();
      if (nama != null && nama.isNotEmpty) return nama;
    }
    return null;
  }

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
