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

  // ---------------------------------------------------------------------
  // Rekap Pekanan — dipakai buat banner Dashboard + card "Baris Pekan
  // Ini" / "Progres Hafalan" / "Rekap Terakhir". Pekan berjalan = Senin
  // 00:00 s/d Minggu 23:59 (pekan kalender, Senin hari pertama). Ini
  // CUMA soal kapan pekan itu sendiri mulai/berakhir — beda dari kapan
  // guru biasanya "nutup"/merampungkan rekapnya (Jumat/Sabtu), yang
  // otomatis kelihatan dari [tanggalRekapTerakhirPekanIni] di bawah.
  // ---------------------------------------------------------------------

  DateTime get _weekStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  bool _isInCurrentWeek(DateTime tanggal) {
    final d = DateTime(tanggal.year, tanggal.month, tanggal.day);
    return !d.isBefore(_weekStart) && !d.isAfter(_weekEnd);
  }

  /// Subset [records] yang tanggalnya jatuh di pekan berjalan, tetap
  /// terurut terbaru dulu.
  List<SantriRecord> get recordsThisWeek =>
      records.where((r) => _isInCurrentWeek(r.tanggal)).toList();

  /// Total baris Tahfizh yang tercapai DI PEKAN BERJALAN SAJA — beda
  /// dari [totalBarisTercapai] yang akumulasi sepanjang riwayat. Ini
  /// yang dibandingkan ke target mingguan per halaqoh
  /// ([weeklyTargetBarisForHalaqoh]) buat card "Progres Hafalan", dan
  /// ditampilkan mentah di card "Baris Pekan Ini" + banner Dashboard.
  int get barisTercapaiPekanIni =>
      recordsThisWeek.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));

  /// Tanggal laporan PALING BARU di pekan berjalan — null kalau belum
  /// ada laporan sama sekali di pekan ini. Dipakai buat card "Rekap
  /// Terakhir" (biasanya jatuh Jumat/Sabtu, tergantung guru).
  DateTime? get tanggalRekapTerakhirPekanIni {
    if (recordsThisWeek.isEmpty) return null;
    return recordsThisWeek.map((r) => r.tanggal).reduce((a, b) => a.isAfter(b) ? a : b);
  }
}
