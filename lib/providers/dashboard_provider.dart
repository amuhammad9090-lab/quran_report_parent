import 'dart:async';

import 'package:flutter/material.dart';

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
  String? error;
  List<SantriRecord> records = [];
  StreamSubscription<List<SantriRecord>>? _subscription;

  Future<void> load(Student student) {
    isLoading = true;
    error = null;
    notifyListeners();

    final completer = Completer<void>();
    _subscription?.cancel();
    _subscription = reportRepository.watchRecordsForStudent(student).listen(
      (data) {
        records = data;
        isLoading = false;
        error = null;
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('DashboardProvider.load GAGAL: $e\n$st');
        error = e.toString();
        records = [];
        isLoading = false;
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  SantriRecord? get latest => records.isEmpty ? null : records.first;
  String? get latestCatatanGuru => latestRecordWithCatatan?.catatan;

  SantriRecord? get latestRecordWithCatatan {
    for (final r in records) {
      if (r.catatan != null && r.catatan!.trim().isNotEmpty) return r;
    }
    return null;
  }

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
  double get kehadiranRatio {
    if (records.isEmpty) return 0;
    final hadirCount = records
        .where((r) => r.keterangan == Keterangan.hadir || r.keterangan.isSanksiTanpaSetoran)
        .length;
    return hadirCount / records.length;
  }

  /// Laporan Tahsin (murni atau bagian dari Tahsin+Tahfizh) PALING BARU
  /// sepanjang riwayat — sumber ringkasan "Tahsin Terakhir" di hero
  /// Beranda.
  SantriRecord? get latestTahsinRecord {
    for (final r in records) {
      if (r.status == HafalanStatus.tahsin ||
          r.status == HafalanStatus.tahsinTahfizh) {
        return r;
      }
    }
    return null;
  }

  /// Total baris tahfizh yang tercapai sepanjang riwayat laporan
  /// (agregat totalBaris semua laporan status Tahfizh/Tahsin+Tahfizh).
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
  /// dari [totalBarisTercapai] yang akumulasi sepanjang riwayat.
  int get barisTercapaiPekanIni =>
      recordsThisWeek.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));

  /// Tanggal laporan PALING BARU di pekan berjalan — null kalau belum
  /// ada laporan sama sekali di pekan ini.
  DateTime? get tanggalRekapTerakhirPekanIni {
    if (recordsThisWeek.isEmpty) return null;
    return recordsThisWeek.map((r) => r.tanggal).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  // ---------------------------------------------------------------------
  // Perbandingan pekan ini vs pekan lalu — SEMUA dari [records] yang
  // sudah ter-load sekali per sesi (tidak ada query tambahan). Dipakai
  // untuk kartu "dibanding pekan lalu" di Beranda.
  // ---------------------------------------------------------------------

  DateTime get _prevWeekStart => _weekStart.subtract(const Duration(days: 7));
  DateTime get _prevWeekEnd => _weekStart.subtract(const Duration(days: 1));

  bool _isInPreviousWeek(DateTime tanggal) {
    final d = DateTime(tanggal.year, tanggal.month, tanggal.day);
    return !d.isBefore(_prevWeekStart) && !d.isAfter(_prevWeekEnd);
  }

  /// Subset [records] pekan SEBELUM pekan berjalan.
  List<SantriRecord> get recordsPreviousWeek =>
      records.where((r) => _isInPreviousWeek(r.tanggal)).toList();

  int get barisTercapaiPekanLalu =>
      recordsPreviousWeek.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));

  /// Selisih baris pekan ini vs pekan lalu.
  int? get barisDeltaVsPekanLalu {
    if (recordsPreviousWeek.isEmpty) return null;
    return barisTercapaiPekanIni - barisTercapaiPekanLalu;
  }

  // ---------------------------------------------------------------------
  // Insight Minggu Ini — kalimat pendek yang disimpulkan LANGSUNG dari
  // data existing di atas (tidak ada data yang dikarang). Maksimal 3
  // insight, diurutkan dari yang paling relevan/actionable.
  // ---------------------------------------------------------------------

  List<DashboardInsight> get insights {
    if (records.isEmpty) return const [];
    final list = <DashboardInsight>[];

    final delta = barisDeltaVsPekanLalu;
    if (delta != null && delta != 0) {
      list.add(DashboardInsight(
        icon: delta > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        positive: delta > 0,
        text: delta > 0
            ? 'Naik $delta baris dibanding pekan lalu — pertahankan ritmenya.'
            : 'Turun ${delta.abs()} baris dibanding pekan lalu. Ajak ananda murojaah lebih rutin.',
      ));
    } else if (delta == null && barisTercapaiPekanIni > 0) {
      list.add(DashboardInsight(
        icon: Icons.auto_awesome_rounded,
        positive: true,
        text: 'Pekan pertama dengan laporan — $barisTercapaiPekanIni baris tercatat.',
      ));
    }

    final thisWeekAlpaIzin = recordsThisWeek
        .where((r) =>
            r.keterangan != Keterangan.hadir && !r.keterangan.isSanksiTanpaSetoran)
        .length;
    if (thisWeekAlpaIzin > 0) {
      list.add(DashboardInsight(
        icon: Icons.event_busy_rounded,
        positive: false,
        text: thisWeekAlpaIzin == 1
            ? 'Ada 1 pertemuan pekan ini dengan status izin/tidak hadir.'
            : 'Ada $thisWeekAlpaIzin pertemuan pekan ini dengan status izin/tidak hadir.',
      ));
    }

    final rekapTerakhir = tanggalRekapTerakhirPekanIni;
    if (rekapTerakhir == null && records.isNotEmpty) {
      final lastAny = records.first.tanggal;
      final days = DateTime.now().difference(lastAny).inDays;
      if (days >= 7) {
        list.add(DashboardInsight(
          icon: Icons.info_outline_rounded,
          positive: false,
          text: 'Belum ada laporan baru dalam $days hari terakhir.',
        ));
      }
    }

    if (list.isEmpty && kehadiranRatio >= 0.9 && records.length >= 3) {
      list.add(DashboardInsight(
        icon: Icons.emoji_events_rounded,
        positive: true,
        text: 'Kehadiran ananda sangat konsisten, ${(kehadiranRatio * 100).toStringAsFixed(0)}% sepanjang riwayat.',
      ));
    }

    return list.take(3).toList();
  }
}

/// Satu baris insight yang tampil di kartu "Insight Minggu Ini" —
/// [positive] menentukan warna (hijau/amber), bukan makna wajib
/// baik/buruk (mis. "izin sakit" tetap netral-informatif).
class DashboardInsight {
  final IconData icon;
  final String text;
  final bool positive;
  const DashboardInsight({required this.icon, required this.text, required this.positive});
}
