import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/models/weekly_recap.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/weekly_recap_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/status_badge.dart';

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
                _WeeklyRecapSection(
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
      builder: (ctx) => _RecordDetailSheet(record: record),
    );
  }
}

/// Detail 1 laporan — dibuka dari tap [RecordSummaryRow] di daftar
/// riwayat. Murni menampilkan field [SantriRecord] yang sudah di-load,
/// tidak ada query tambahan.
class _RecordDetailSheet extends StatelessWidget {
  final SantriRecord record;
  const _RecordDetailSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Row(
              children: [
                StatusBadge(status: record.status),
                const Spacer(),
                KeteranganChip(keterangan: record.keterangan, compact: true),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(record.tanggal),
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text('Capaian', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(record.capaianText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4)),
            if (record.totalBaris != null && record.totalBaris! > 0) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '${record.totalBaris} baris tercatat',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
            if ((record.catatan ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Catatan Guru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(record.catatan!.trim(), style: const TextStyle(fontSize: 13.5, height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyRecapSection extends StatelessWidget {
  final WeeklyRecapProvider provider;
  // Hasil FILTER dari `provider.recaps` (jaring pengaman staleness —
  // lihat `weeklyRecapIsLikelyStale` & catatan panjang di
  // `WeeklyRecap`), dihitung sekali di `_HistoryScreenState.build`
  // supaya tidak dihitung ulang tiap rebuild section ini.
  final List<WeeklyRecap> visibleRecaps;
  /// Id rekap yang terdeteksi kedaluwarsa — lihat `weeklyRecapIsOutdated`.
  final Set<String> outdatedRecapIds;
  const _WeeklyRecapSection({
    required this.provider,
    required this.visibleRecaps,
    required this.outdatedRecapIds,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoftIconBox(icon: Icons.fact_check_rounded, color: cs.primary, size: 16, padding: 8, radius: 10),
              const SizedBox(width: 10),
              const Text(
                'Rekap Pekanan dari Guru',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (provider.isLoading)
            const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visibleRecaps.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _WeeklyRecapCard(
                  recap: visibleRecaps[i],
                  isOutdated: outdatedRecapIds.contains(visibleRecaps[i].id),
                ),
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _WeeklyRecapCard extends StatelessWidget {
  final WeeklyRecap recap;
  final bool isOutdated;
  const _WeeklyRecapCard({required this.recap, required this.isOutdated});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 176,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetail(context, recap),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pekan ${recap.weekIndex}',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: cs.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  recap.bulanLabel,
                  style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // <-- BERUBAH: "0 baris" cuma bener buat pekan yang
                // capaiannya Tahfizh (baris = ayat baru dihafal). Kalau
                // pekan itu isinya Tahsin/Muroja'ah doang, totalBaris
                // MEMANG 0 secara wajar — nampilinnya sebagai "0 baris"
                // kelihatan kayak "gak ada progress sama sekali", padahal
                // progresnya cuma diukur bukan pakai satuan baris. Jadi
                // baris ini disembunyikan total kalau totalBaris == 0,
                // biar gak menyesatkan.
                if (recap.totalBaris > 0)
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${recap.totalBaris} baris',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                const SizedBox(height: 2),
                if (isOutdated)
                  // Badge kecil — jangan sembunyikan kartunya, karena
                  // catatan guru di dalamnya tetap berguna; cukup beri
                  // tahu bahwa angkanya belum diperbarui.
                  Row(
                    children: [
                      Icon(Icons.update_rounded, size: 12, color: cs.tertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Belum diperbarui',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: cs.tertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.touch_app_rounded, size: 12, color: cs.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Lihat detail',
                        style: TextStyle(fontSize: 10.5, color: cs.primary.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WeeklyRecap r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _WeeklyRecapDetailSheet(recap: r, isOutdated: isOutdated),
    );
  }
}

class _WeeklyRecapDetailSheet extends StatelessWidget {
  final WeeklyRecap recap;
  final bool isOutdated;
  const _WeeklyRecapDetailSheet({required this.recap, required this.isOutdated});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              'Rekap Pekan ${recap.weekIndex} — ${recap.bulanLabel}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 2),
            Text(
              recap.periode,
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            if (isOutdated) ...[
              // Peringatan JUJUR, bukan menyembunyikan data: isi rekap
              // di bawah adalah snapshot lama buatan guru, sementara
              // daftar laporan harian di layar belakang sudah versi
              // terbaru. Portal ini read-only jadi tidak menghitung
              // ulang sendiri — lihat `weeklyRecapIsOutdated`.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.update_rounded, size: 17, color: cs.tertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rekap ini dibuat sebelum laporan harian terakhir '
                        'diperbarui guru, jadi angkanya mungkin belum sesuai. '
                        'Daftar laporan harian di halaman ini yang paling baru.',
                        style: TextStyle(fontSize: 12.5, height: 1.45, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _detailRow(context, 'Capaian', recap.capaian),
            if (recap.keterangan.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailRow(context, 'Keterangan', recap.keterangan),
            ],
            if (recap.catatan.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailRow(context, 'Catatan Guru', recap.catatan),
            ],
            // Sama seperti mini card: sembunyikan total (+ gap-nya)
            // kalau memang 0 (pekan Tahsin/Muroja'ah doang) — lihat
            // catatan panjang di widget kartu mini-nya.
            if (recap.totalBaris > 0) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Total ${recap.totalBaris} baris sepekan',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
            if ((recap.guruPembimbing ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Guru Pembimbing: ${recap.guruPembimbing}',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, height: 1.4)),
      ],
    );
  }
}
