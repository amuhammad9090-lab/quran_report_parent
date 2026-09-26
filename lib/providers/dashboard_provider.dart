import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models/enums.dart';
import '../data/models/report_lifetime_stats.dart';
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
  // <-- BARU: exception ASLI (bukan cuma `.toString()`-nya di [error])
  // supaya UI (`dashboard_screen.dart`) bisa cek TIPE errornya secara
  // type-safe lewat [isGuruBelumDitugaskan] — perlu buat bedain "guru
  // pembimbing belum di-assign" (bukan salah orang tua, gak ada yang
  // bisa mereka lakukan selain hubungi sekolah) dari error koneksi biasa
  // (yang masih relevan disuruh "coba lagi").
  Object? rawError;

  // <-- BERUBAH (audit biaya Firestore read): [records] SEKARANG cuma
  // berisi laporan dalam [_windowDays] hari terakhir, BUKAN sepanjang
  // riwayat — supaya listener live yang nyala sepanjang sesi ini punya
  // plafon biaya, gak terus membesar seiring bertambahnya laporan
  // santri. Insight/perbandingan pekan ini-vs-lalu semuanya cuma butuh
  // data terkini, jadi tidak terdampak. 2 angka yang MEMANG didefinisikan
  // "sepanjang riwayat" ([totalBarisTercapai], [kehadiranRatio]) TETAP
  // akurat lifetime lewat [_lifetimeStats] (aggregate query, lihat
  // [ReportRepository.getLifetimeStats]) — bukan dihitung dari [records].
  // Filter "Semua" di layar Perkembangan yang butuh detail laporan LEBIH
  // LAMA dari jendela ini pakai [ensureFullHistoryLoaded]/[allRecords]
  // di bawah, dipanggil lazy cuma kalau benar-benar dipilih.
  static const _windowDays = 180;

  List<SantriRecord> records = [];
  ReportLifetimeStats _lifetimeStats = ReportLifetimeStats.empty;
  StreamSubscription<List<SantriRecord>>? _subscription;
  Student? _student;

  List<SantriRecord>? _olderRecords;
  bool isLoadingOlder = false;

  /// True kalau [error] sekarang ini spesifik karena guru pembimbing
  /// santri belum ditugaskan di app guru ([GuruBelumDitugaskanException])
  /// — bukan gangguan koneksi/server biasa. Dipakai `dashboard_screen.dart`
  /// buat milih pesan yang akurat.
  bool get isGuruBelumDitugaskan => rawError is GuruBelumDitugaskanException;

  Future<void> load(Student student) {
    isLoading = true;
    error = null;
    rawError = null;
    _student = student;
    _olderRecords = null;
    notifyListeners();

    final since = DateTime.now().subtract(const Duration(days: _windowDays));

    final completer = Completer<void>();
    _subscription?.cancel();
    _subscription = reportRepository.watchRecentRecordsForStudent(student, since: since).listen(
      (data) {
        records = data;
        isLoading = false;
        error = null;
        rawError = null;
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('DashboardProvider.load GAGAL: $e\n$st');
        error = e.toString();
        rawError = e;
        records = [];
        isLoading = false;
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      },
    );

    // Statistik lifetime — query terpisah (aggregate, murah), gagalnya
    // TIDAK menggagalkan load() secara keseluruhan (dashboard tetap bisa
    // tampil dengan data pekan berjalan meski statistik lifetime gagal
    // dimuat, mis. lagi offline) — cukup dibiarkan [ReportLifetimeStats.empty].
    reportRepository.getLifetimeStats(student).then((stats) {
      _lifetimeStats = stats;
      notifyListeners();
    }).catchError((Object e, StackTrace st) {
      debugPrint('DashboardProvider.load: getLifetimeStats gagal (nonfatal): $e');
    });

    return completer.future;
  }

  /// Dipanggil LAZY dari layar Perkembangan/History cuma pas orang tua
  /// benar-benar pilih filter "Semua" (yang butuh laporan lebih lama
  /// dari [_windowDays] hari default) — TIDAK dipanggil otomatis di
  /// [load]. Idempotent: pemanggilan berikutnya setelah sukses langsung
  /// no-op (tidak fetch ulang), lihat [allRecords].
  Future<void> ensureFullHistoryLoaded() async {
    if (_olderRecords != null || isLoadingOlder || _student == null) return;
    isLoadingOlder = true;
    notifyListeners();
    try {
      final since = DateTime.now().subtract(const Duration(days: _windowDays));
      _olderRecords = await reportRepository.getRecordsForStudentBefore(_student!, before: since);
    } catch (e, st) {
      debugPrint('DashboardProvider.ensureFullHistoryLoaded gagal: $e\n$st');
      // Dibiarkan null (bukan list kosong) supaya percobaan berikutnya
      // (mis. orang tua toggle filter lagi) BOLEH coba fetch ulang,
      // bukan dianggap "sudah dicoba dan hasilnya kosong".
      _olderRecords = null;
    } finally {
      isLoadingOlder = false;
      notifyListeners();
    }
  }

  /// [records] (jendela [_windowDays] hari) digabung [_olderRecords]
  /// (kalau sudah pernah dimuat lewat [ensureFullHistoryLoaded]) — buat
  /// filter "Semua" di History. Tetap terurut terbaru dulu.
  List<SantriRecord> get allRecords =>
      _olderRecords == null ? records : [...records, ..._olderRecords!];

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  SantriRecord? get latest => records.isEmpty ? null : records.first;
  String? get latestCatatanGuru => latestRecordWithCatatan?.catatan;

  // <-- CATATAN (audit biaya Firestore read): [latestRecordWithCatatan] &
  // [latestTahsinRecord] di bawah dicari dari [records], yang SEKARANG
  // cuma jendela [_windowDays] (~6 bulan) hari terakhir — bukan lagi
  // benar-benar "sepanjang riwayat" seperti sebelumnya. Ini trade-off
  // yang disengaja: kalau ada santri yang catatan/laporan Tahsin
  // TERAKHIRnya lebih lama dari itu, keduanya bakal balik null padahal
  // sebetulnya ada versi lebih lama. Dalam praktiknya (laporan masuk
  // beberapa kali seminggu) kasus ini jarang kejadian. Kalau ternyata
  // perlu 100% akurat lifetime juga, bisa ditambah query khusus 1
  // dokumen (mis. `.orderBy('tanggal', descending:true).limit(1)` dengan
  // filter tambahan) di [FirestoreReportRepository] — sengaja belum
  // dibikin sekarang karena butuh index komposit baru di Firestore,
  // dampaknya kecil, dan scope perbaikan ini fokus ke biaya read.
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

  /// % laporan yang santrinya HADIR secara fisik, dari SELURUH laporan —
  /// dipakai untuk card ringkasan "Kehadiran" di dashboard.
  ///
  /// <-- BERUBAH (audit biaya Firestore read): dulu di-fold dari
  /// [records] (yang waktu itu = SELURUH riwayat, tanpa batas tanggal).
  /// Sekarang [records] cuma jendela [_windowDays] hari, jadi angka
  /// lifetime yang akurat diambil dari [_lifetimeStats] (aggregate
  /// query, lihat [ReportRepository.getLifetimeStats]) — bukan fold
  /// dokumen di client. Hasilnya SAMA PERSIS, cuma beda cara hitung.
  double get kehadiranRatio => _lifetimeStats.kehadiranRatio;

  /// Laporan Tahsin (murni atau bagian dari Tahsin+Tahfizh) PALING BARU
  /// dalam jendela [_windowDays] hari terakhir (lihat catatan di atas
  /// [latestRecordWithCatatan] soal kenapa bukan lagi "sepanjang
  /// riwayat") — sumber ringkasan "Tahsin Terakhir" di hero Beranda.
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
  ///
  /// <-- BERUBAH (audit biaya Firestore read): sama alasannya seperti
  /// [kehadiranRatio] di atas — diambil dari [_lifetimeStats] (aggregate
  /// query server-side), bukan fold [records] yang sekarang cuma
  /// jendela [_windowDays] hari.
  int get totalBarisTercapai => _lifetimeStats.totalBarisTercapai;

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
