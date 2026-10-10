import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/models/weekly_recap.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/weekly_recap_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/status_badge.dart';
import 'widgets/record_detail_sheet.dart';
import 'widgets/weekly_recap_widgets.dart';

/// "Perkembangan" — rekap mingguan dari guru + riwayat laporan lengkap
/// (dikelompokkan per tanggal) + filter periode + detail laporan (tap
/// satu baris buka bottom sheet).
///
/// <-- BERUBAH (audit biaya Firestore read): dulu SEMUA filter di sini
/// murni client-side terhadap [DashboardProvider.records], yang waktu
/// itu = SELURUH riwayat laporan (tanpa batas tanggal). Sekarang
/// [DashboardProvider.records] cuma jendela ~6 bulan terakhir (lihat
/// catatan di `DashboardProvider`) — filter "Pekan Ini"/"Bulan Ini"/"3
/// Bulan Terakhir" TETAP murni client-side terhadap `records` (selalu
/// tercakup penuh di jendela itu, tidak memicu query baru). KHUSUS
/// filter "Semua", yang butuh laporan lebih lama dari jendela itu, layar
/// ini manggil [DashboardProvider.ensureFullHistoryLoaded] (one-time
/// fetch, lazy — cuma jalan pas filter ini beneran dipilih) lalu pakai
/// [DashboardProvider.allRecords] sebagai gantinya.
///
/// Section "Rekap Pekanan dari Guru" di paling atas (kartu
/// horizontal-scroll) — nampilin rekap MINGGUAN yang guru "Deploy" dari
/// GenerateRekapPekananScreen (beda dari daftar harian di bawahnya yang
/// 1 baris = 1 laporan; ini 1 kartu = ringkasan 1 pekan penuh).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum _PeriodFilter { semua, pekanIni, bulanIni, tigaBulan }

extension on _PeriodFilter {
  String get label => switch (this) {
        _PeriodFilter.semua => 'Semua',
        _PeriodFilter.pekanIni => 'Pekan Ini',
        _PeriodFilter.bulanIni => 'Bulan Ini',
        _PeriodFilter.tigaBulan => '3 Bulan Terakhir',
      };
}

class _HistoryScreenState extends State<HistoryScreen> {
  _PeriodFilter _filter = _PeriodFilter.semua;

  // <-- PERBAIKAN: SEBELUMNYA trigger [ensureFullHistoryLoaded] ditaruh
  // di `initState()` di sini, dengan asumsi "initState cuma jalan kalau
  // tab ini dibuka". Ternyata SALAH untuk shell ini — `MainShell`
  // nyimpen SEMUA tab (Beranda/Perkembangan/Pengaturan) di satu `Stack`
  // sekaligus (`for (int i = 0; ...) Positioned.fill(...)`), bukan
  // lazy-build per-tab, supaya scroll position & filter tiap tab tidak
  // hilang waktu pindah-pindah. Efeknya `HistoryScreen.initState()`
  // JALAN LANGSUNG begitu sesi dimulai, terlepas dari tab mana yang
  // sedang dilihat orang tua -- jadi trigger di situ SELALU ketembak
  // tiap buka app, sama sekali TIDAK lazy, dan justru menghilangkan
  // manfaat pembatasan jendela di `DashboardProvider`.
  //
  // Diperbaiki dengan memindah trigger-nya ke `MainShell` (dipanggil
  // pas orang tua BENERAN pindah ke tab index 1), bukan lifecycle
  // widget ini -- lihat `MainShell._setIndex`.

  List<SantriRecord> _applyFilter(List<SantriRecord> records) {
    if (_filter == _PeriodFilter.semua) return records;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = switch (_filter) {
      _PeriodFilter.pekanIni => today.subtract(Duration(days: today.weekday - 1)),
      _PeriodFilter.bulanIni => DateTime(today.year, today.month, 1),
      _PeriodFilter.tigaBulan => DateTime(today.year, today.month - 2, 1),
      _PeriodFilter.semua => DateTime(1970),
    };
    return records.where((r) => !r.tanggal.isBefore(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();

    if (dash.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // <-- BERUBAH: dulu cek `dash.records.isEmpty` langsung berarti
    // "belum ada riwayat sama sekali". Sekarang `dash.records` cuma
    // jendela ~6 bulan terakhir, jadi kosong BELUM TENTU berarti
    // riwayatnya kosong — bisa jadi laporan lamanya ada tapi lebih tua
    // dari jendela itu. Tunggu [ensureFullHistoryLoaded] (dipicu di
    // [initState]) selesai dulu sebelum vonis "belum ada riwayat".
    if (dash.records.isEmpty && dash.isLoadingOlder) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (dash.records.isEmpty && dash.allRecords.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perkembangan'),
          centerTitle: false,
          toolbarHeight: 68,
          titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: EmptyState(
              icon: Icons.history_rounded,
              title: 'Belum ada riwayat',
              subtitle: 'Semua laporan yang diinput guru pembimbing akan muncul di sini.',
            ),
          ),
        ),
      );
    }

    // Filter "Semua" butuh [allRecords] (jendela default + laporan lama
    // yang di-lazy-load lewat [ensureFullHistoryLoaded]); filter periode
    // lain cukup [dash.records] (selalu tercakup penuh di jendela
    // default ~6 bulan) — lihat catatan panjang di kelas ini.
    final source = _filter == _PeriodFilter.semua ? dash.allRecords : dash.records;
    final filtered = _applyFilter(source);

    // records dari DashboardProvider sudah terurut terbaru dulu, dan
    // grouping di bawah TIDAK mengubah urutan itu — cukup mengelompokkan
    // record dengan tanggal (y/m/d) yang sama persis ke 1 DateGroupCard,
    // mengikuti pola app guru.
    final groups = <DateTime, List<SantriRecord>>{};
    for (final r in filtered) {
      final key = DateTime(r.tanggal.year, r.tanggal.month, r.tanggal.day);
      groups.putIfAbsent(key, () => []).add(r);
    }
    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final weeklyRecaps = context.watch<WeeklyRecapProvider>();
    // Jaring pengaman staleness (lihat `weeklyRecapIsLikelyStale` &
    // catatan panjang di `WeeklyRecap`) — hitung dari SEMUA
    // `dash.records` (bukan `filtered`/periode UI), supaya filter
    // periode di atas tidak ikut mempengaruhi validitas kartu rekap.
    final liveReportDates = dash.records.map((r) => r.tanggal).toList();
    // Pasangan tanggal+createdAt dipakai `weeklyRecapIsOutdated` untuk
    // mendeteksi rekap yang di-deploy SEBELUM koreksi terakhir guru.
    final liveReportTimes = dash.records
        .map((r) => (tanggal: r.tanggal, createdAt: r.createdAt))
        .toList();
    // Urutan penting: dedupe DULU (buang versi lama dari pekan yang
    // sama kalau guru deploy berkali-kali), BARU buang yang laporannya
    // sudah terhapus semua. Kalau dibalik, versi lama bisa lolos.
    final visibleRecaps = dedupeWeeklyRecaps(weeklyRecaps.recaps)
        .where((r) => !weeklyRecapIsLikelyStale(r, liveReportDates))
        .toList();
    final outdatedRecapIds = visibleRecaps
        .where((r) => weeklyRecapIsOutdated(r, liveReportTimes))
        .map((r) => r.id)
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perkembangan'),
        centerTitle: false,
        toolbarHeight: 68,
        // Override ukuran default tema (headlineSmall ~24) — khusus di
        // sini aja (bukan appBarTheme global) supaya AppBar Beranda/
        // Pengaturan nggak ikut membesar, cuma "Perkembangan" sesuai
        // permintaan.
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
      ),
      body: SafeArea(
        child: ResponsiveContentWidth(
          child: Column(
            children: [
              // Section rekap pekanan cuma ditampilkan kalau ada isinya
              // atau lagi loading -- kalau kosong/gagal, sembunyi total
              // (bukan nunjukin EmptyState) supaya tidak menuh-menuhin
              // layar dengan info "belum ada" untuk fitur yang memang
              // baru/opsional ini; daftar harian di bawah tetap jadi
              // fokus utama halaman.
              if (weeklyRecaps.isLoading || visibleRecaps.isNotEmpty)
                WeeklyRecapSection(
                  provider: weeklyRecaps,
                  visibleRecaps: visibleRecaps,
                  outdatedRecapIds: outdatedRecapIds,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _PeriodFilter.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = _PeriodFilter.values[i];
                      final selected = f == _filter;
                      return ChoiceChip(
                        label: Text(f.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _filter = f),
                        showCheckmark: false,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).chipTheme.backgroundColor,
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          // Sebelumnya pakai primaryContainer/onPrimaryContainer
                          // untuk state terpilih — di beberapa kondisi kontrasnya
                          // ambigu (teks nyaris tak kebaca, cuma checkmark yang
                          // kelihatan). Diganti ke primary (solid, lebih pekat)
                          // + putih, kombinasi yang pasti kontras di light MAUPUN
                          // dark mode.
                          color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: EmptyState(
                            icon: Icons.filter_alt_off_rounded,
                            title: 'Tidak ada laporan',
                            subtitle: 'Belum ada laporan pada periode ini. Coba pilih periode lain.',
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                        itemCount: sortedDates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final date = sortedDates[i];
                          final recordsOnDate = groups[date]!;
                          return DateGroupCard(
                            date: date,
                            rows: [
                              for (final r in recordsOnDate)
                                RecordSummaryRow(
                                  statusIcon: r.status.icon,
                                  statusColor: AppColors.statusOn(context, r.status),
                                  statusLabel: r.status.label,
                                  capaianText: r.capaianText,
                                  keteranganChip: KeteranganChip(keterangan: r.keterangan, compact: true),
                                  notePreview: r.catatan,
                                  onTap: () => _showRecordDetail(context, r),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordDetail(BuildContext context, SantriRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => RecordDetailSheet(record: record),
    );
  }
}

/// Detail 1 laporan — dibuka dari tap [RecordSummaryRow] di daftar
/// riwayat. Murni menampilkan field [SantriRecord] yang sudah di-load,
/// tidak ada query tambahan.
