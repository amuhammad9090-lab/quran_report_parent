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
/// satu baris buka bottom sheet). SEMUA filter di sini murni client-side
/// terhadap [DashboardProvider.records] yang sudah di-fetch SEKALI per
/// sesi di [MainShell] — filter periode TIDAK memicu query Firestore
/// baru sama sekali, cukup narrow subset yang sudah ada di memori.
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

    if (dash.records.isEmpty) {
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

    final filtered = _applyFilter(dash.records);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perkembangan'),
        centerTitle: false,
        toolbarHeight: 68,
        // Override ukuran default tema (headlineSmall ~24) — khusus di
        // sini aja (bukan appBarTheme global) supaya AppBar Beranda*/
        // Profil nggak ikut membesar, cuma "Perkembangan" sesuai
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
              if (weeklyRecaps.isLoading || weeklyRecaps.recaps.isNotEmpty)
                _WeeklyRecapSection(provider: weeklyRecaps),
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
  const _WeeklyRecapSection({required this.provider});

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
                itemCount: provider.recaps.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _WeeklyRecapCard(recap: provider.recaps[i]),
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
  const _WeeklyRecapCard({required this.recap});

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
      builder: (ctx) => _WeeklyRecapDetailSheet(recap: r),
    );
  }
}

class _WeeklyRecapDetailSheet extends StatelessWidget {
  final WeeklyRecap recap;
  const _WeeklyRecapDetailSheet({required this.recap});

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
            _detailRow(context, 'Capaian', recap.capaian),
            if (recap.keterangan.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailRow(context, 'Keterangan', recap.keterangan),
            ],
            if (recap.catatan.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailRow(context, 'Catatan Guru', recap.catatan),
            ],
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
