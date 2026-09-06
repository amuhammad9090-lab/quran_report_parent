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

/// "Riwayat Perkembangan" — daftar laporan berdasarkan tanggal, sesuai
/// brief. Pakai [DateGroupCard]/[RecordSummaryRow] (file di-share dari
/// app guru, tidak diubah) supaya visualnya identik dengan halaman
/// Detail Santri di app guru — bedanya di sini murni tampilan, tidak
/// ada `onTap` (tidak ada detail/edit, sesuai read-only).
///
/// <-- BARU: section "Rekap Pekanan dari Guru" di paling atas (kartu
/// horizontal-scroll) — nampilin rekap MINGGUAN yang guru "Deploy" dari
/// GenerateRekapPekananScreen (beda dari daftar harian di bawahnya yang
/// 1 baris = 1 laporan; ini 1 kartu = ringkasan 1 pekan penuh). Sengaja
/// TETAP di halaman ini (bukan tab baru) — sama alasan kayak tab
/// "Hafalan" yang dihapus dulu: portal ini harus tetap ringan, dan
/// "rekap pekanan" secara semantik masih bagian dari "riwayat
/// perkembangan", bukan fitur berdiri sendiri.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();

    if (dash.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (dash.records.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat Perkembangan'), centerTitle: false),
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

    // records dari DashboardProvider sudah terurut terbaru dulu, dan
    // grouping di bawah TIDAK mengubah urutan itu — cukup mengelompokkan
    // record dengan tanggal (y/m/d) yang sama persis ke 1 DateGroupCard,
    // mengikuti pola app guru.
    final groups = <DateTime, List<SantriRecord>>{};
    for (final r in dash.records) {
      final key = DateTime(r.tanggal.year, r.tanggal.month, r.tanggal.day);
      groups.putIfAbsent(key, () => []).add(r);
    }
    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final weeklyRecaps = context.watch<WeeklyRecapProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Perkembangan'), centerTitle: false),
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
              Expanded(
                child: ListView.separated(
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
