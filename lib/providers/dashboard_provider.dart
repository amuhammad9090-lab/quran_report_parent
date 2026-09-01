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
  // <-- BARU: sebelumnya gak ada try/catch di load() -- kalau query
  // Firestore gagal (index belum jadi, rules, dll), isLoading NGGAK
  // PERNAH balik ke false, jadi UI muter selama-lamanya tanpa pesan
  // error apa pun. Sekarang error ke-tangkep & disimpan di [error].
  String? error;
  List<SantriRecord> records = [];

  Future<void> load(Student student) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      records = await reportRepository.getRecordsForStudent(student);
    } catch (e, st) {
      // debugPrint biar tetap kelihatan jelas di console browser (F12),
      // gampang dibedain dari noise log Firebase yang lain.
      debugPrint('DashboardProvider.load GAGAL: $e\n$st');
      error = e.toString();
      records = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
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

  /// % laporan yang santrinya HADIR secara fisik, dari seluruh laporan —
  /// dipakai untuk card ringkasan "Kehadiran" di dashboard.
  ///
  /// PENTING (sinkron dengan app guru — lihat `records_provider.dart`
  /// `totalHadir`): "hadir" DI SINI BUKAN cuma `Keterangan.hadir`, tapi
  /// juga 3 keterangan "sanksi tanpa setoran" (`tidakSetoran`,
  /// `tidakTahsin`, `tidakMurojaah`, lihat `Keterangan.isSanksiTanpaSetoran`
  /// di enums.dart) — santri yang keterangannya itu SECARA FISIK hadir,
  /// cuma nggak setor/tahsin/murojaah (males/ketiduran/dll), beda dari
  /// Izin Sakit/Izin/Izin Lomba/Izin Pelatihan/Alpa yang memang nggak
  /// hadir. Kalau di sini cuma dihitung `Keterangan.hadir` saja, angka
  /// Kehadiran orang tua akan lebih RENDAH dari yang guru lihat di app
  /// guru untuk santri yang sama — jadi harus dijaga tetap sama definisi.
  double get kehadiranRatio {
    if (records.isEmpty) return 0;
    final hadirCount = records
        .where((r) => r.keterangan == Keterangan.hadir || r.keterangan.isSanksiTanpaSetoran)
        .length;
    return hadirCount / records.length;
  }

  /// Total baris tahfizh yang tercapai sepanjang riwayat laporan
  /// (agregat totalBaris semua laporan status Tahfizh/Tahsin+Tahfizh).
  /// Ini angka MENTAH dari data existing (bukan persentase — persentase
  /// per-juz baru dihitung di STEP 6, lihat ProgressCalculationService).
  int get totalBarisTercapai =>
      records.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));
}
