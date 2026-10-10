import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models/report_lifetime_stats.dart';
import '../data/models/santri_record.dart';
import '../data/models/student.dart';
import '../data/repositories/report_repository.dart';

// Perlu di-`import` (bukan cuma `export`) di sini juga, karena
// [latestCatatanGuru] di bawah manggil [latestRecordWithCatatan] yang
// sekarang jadi extension getter di file itu — `export` doang cuma
// nge-expose ke file LAIN yang import `dashboard_provider.dart`, tidak
// otomatis bikin kode di file INI SENDIRI bisa pakai extension-nya.
import 'dashboard_provider_insights.dart';

export 'dashboard_provider_insights.dart';

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

  // <-- Dua getter ini TETAP di dalam class (bukan di extension
  // `dashboard_provider_insights.dart`) karena butuh akses langsung ke
  // field privat [_lifetimeStats] — extension di file lain cuma bisa
  // menjangkau member PUBLIC dari class yang di-extend, jadi kalau
  // dipindah ke sana tidak akan kompile.

  /// % laporan yang santrinya HADIR secara fisik, dari SELURUH riwayat
  /// laporan — dipakai untuk card ringkasan "Kehadiran" di dashboard.
  /// Diambil dari [_lifetimeStats] (aggregate query, lihat
  /// [ReportRepository.getLifetimeStats]), bukan fold [records] (yang
  /// cuma jendela [_windowDays] hari).
  double get kehadiranRatio => _lifetimeStats.kehadiranRatio;

  /// Total baris tahfizh yang tercapai sepanjang riwayat laporan
  /// (agregat totalBaris semua laporan status Tahfizh/Tahsin+Tahfizh),
  /// dari [_lifetimeStats] (aggregate query server-side).
  int get totalBarisTercapai => _lifetimeStats.totalBarisTercapai;
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

