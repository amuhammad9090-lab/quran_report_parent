import 'package:flutter/foundation.dart';

import '../data/models/enums.dart';
import '../data/models/santri_record.dart';
import '../data/models/student.dart';
import '../data/repositories/report_repository.dart';

/// Menyiapkan data dashboard untuk SATU santri (santri yang sedang login,
/// dari [ParentAccessScope]). Read-only murni — tidak ada method
/// mutate/create/delete sama sekali.
class DashboardProvider extends ChangeNotifier {
  final ReportRepository reportRepository;

  DashboardProvider({required this.reportRepository});

  bool isLoading = false;
  List<SantriRecord> records = [];

  Future<void> load(Student student) async {
    isLoading = true;
    notifyListeners();
    records = await reportRepository.getRecordsForStudent(student);
    isLoading = false;
    notifyListeners();
  }

  /// Laporan paling baru (records sudah terurut terbaru dulu dari
  /// repository), null kalau belum pernah ada laporan sama sekali.
  SantriRecord? get latest => records.isEmpty ? null : records.first;

  /// Catatan guru dari laporan terakhir yang punya catatan (bukan cuma
  /// laporan paling baru — kalau laporan terakhir kebetulan tidak diisi
  /// catatan, ambil catatan terbaru yang tersedia).
  String? get latestCatatanGuru {
    for (final r in records) {
      if (r.catatan != null && r.catatan!.trim().isNotEmpty) return r.catatan;
    }
    return null;
  }

  /// Distribusi `keterangan` (Hadir/Sakit/Izin/dst) dari SELURUH laporan
  /// yang ada — ini satu-satunya data kehadiran yang benar-benar ada di
  /// app guru (per-laporan, bukan rekap kehadiran harian terpisah), jadi
  /// dipakai apa adanya, bukan mengarang sistem kehadiran baru.
  Map<Keterangan, int> get keteranganDistribution {
    final map = <Keterangan, int>{};
    for (final r in records) {
      map[r.keterangan] = (map[r.keterangan] ?? 0) + 1;
    }
    return map;
  }

  double keteranganRatio(Keterangan k) {
    if (records.isEmpty) return 0;
    return (keteranganDistribution[k] ?? 0) / records.length;
  }

  /// % laporan berketerangan Hadir dari seluruh laporan — dipakai untuk
  /// card ringkasan "Kehadiran" di dashboard.
  double get kehadiranRatio => keteranganRatio(Keterangan.hadir);

  /// Total baris tahfizh yang tercapai sepanjang riwayat laporan
  /// (agregat totalBaris semua laporan status Tahfizh/Tahsin+Tahfizh).
  /// Ini angka MENTAH dari data existing (bukan persentase — persentase
  /// per-juz baru dihitung di STEP 6, lihat ProgressCalculationService).
  int get totalBarisTercapai =>
      records.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));
}
