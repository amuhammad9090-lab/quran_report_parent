import 'package:flutter/material.dart';

import '../data/models/enums.dart';
import '../data/models/santri_record.dart';
import 'dashboard_provider.dart';

/// Getter "turunan" (computed dari [DashboardProvider.records]/
/// [DashboardProvider.kehadiranRatio] dkk, bukan state baru) — diekstrak
/// jadi extension di file terpisah supaya `dashboard_provider.dart`
/// (dulu 1 file 349 baris) di bawah 300 baris. Dipakai PERSIS seperti
/// getter instance biasa (`dash.barisTercapaiPekanIni`, `dash.insights`,
/// dst) di mana pun `dashboard_provider.dart` di-import — lihat `export`
/// di file itu.
extension DashboardProviderInsights on DashboardProvider {
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

  // [kehadiranRatio] dipindah ke dalam class `DashboardProvider` itu
  // sendiri (`dashboard_provider.dart`) karena butuh akses langsung ke
  // field privat [_lifetimeStats], yang tidak bisa dijangkau dari
  // extension di file ini.

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

  // [totalBarisTercapai] juga dipindah ke dalam class `DashboardProvider`
  // dengan alasan yang sama seperti [kehadiranRatio] di atas.

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
