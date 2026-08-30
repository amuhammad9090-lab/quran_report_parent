import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/services/progress_calculation_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/hafalan_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/status_badge.dart';

/// Dashboard — "Seberapa jauh perkembangan hafalan anak saya?" dijawab
/// dalam satu layar, sesuai brief. Semua data dari [DashboardProvider]
/// (tidak ada angka hardcode). Responsive: grid ringkasan pakai
/// [LayoutBuilder] — 2 kolom di mobile, 4 kolom begitu lebar cukup
/// (tablet/desktop), bukan cuma layout mobile yang di-scale.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent!;
    final dash = context.watch<DashboardProvider>();
    final progressService = context.read<ProgressCalculationService>();
    final cs = Theme.of(context).colorScheme;

    if (dash.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContentWidth(
          child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Assalamu'alaikum 👋",
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.nama,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kelas ${student.kelas} • Halaqoh ${student.halaqoh}',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              sliver: SliverToBoxAdapter(
                child: dash.records.isEmpty
                    ? const _NoRecordsCard()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SummaryGrid(dash: dash, progressService: progressService),
                          const SizedBox(height: 22),
                          const SectionLabel('Setoran Terakhir'),
                          _LatestSetoranCard(dash: dash),
                          const SizedBox(height: 22),
                          const SectionLabel('Catatan Guru'),
                          _CatatanGuruCard(dash: dash),
                        ],
                      ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
          ),
        ),
      ),
    );
  }
}

class _NoRecordsCard extends StatelessWidget {
  const _NoRecordsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: EmptyState(
          icon: Icons.auto_stories_rounded,
          title: 'Belum ada laporan',
          subtitle: 'Laporan perkembangan akan muncul di sini setelah guru pembimbing menginput setoran pertama.',
        ),
      ),
    );
  }
}

/// Grid 4 kartu ringkasan: Total Hafalan, Progress Hafalan, Setoran
/// Terakhir, Kehadiran. "Progress Hafalan" (STEP 6, FINAL): persentase
/// juz dari laporan Tahfizh PALING BARU, dihitung
/// [ProgressCalculationService] (baris-based). Kalau dataset juz itu
/// belum tersedia, kartu menampilkan "-" + label "data blm tersedia"
/// (BUKAN 0%) — lihat [JuzProgress.datasetAvailable].
class _SummaryGrid extends StatelessWidget {
  final DashboardProvider dash;
  final ProgressCalculationService progressService;
  const _SummaryGrid({required this.dash, required this.progressService});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final latest = dash.latest;
    final hafalan = HafalanProvider(progressService: progressService)..computeFrom(dash.records);
    final primary = hafalan.primaryJuz;

    // Jumlah surah BERBEDA yang pernah tercatat di segmen Tahfizh —
    // indikator cakupan hafalan tambahan (di luar persentase per-juz).
    final surahSet = <String>{};
    for (final r in dash.records) {
      for (final seg in r.tahfizhSegmentsEffective) {
        surahSet.add(seg.surahName);
      }
    }

    final progressValue = primary == null
        ? '-'
        : (primary.datasetAvailable ? '${(primary.ratio * 100).toStringAsFixed(0)}%' : 'N/A');
    final progressLabel = primary == null ? 'Progress Hafalan' : 'Progress Juz ${primary.juz}';

    final items = [
      (
        label: 'Total Hafalan',
        value: '${surahSet.length} surah',
        icon: Icons.menu_book_rounded,
        color: cs.primary,
      ),
      (
        label: progressLabel,
        value: progressValue,
        icon: Icons.timeline_rounded,
        color: const Color(0xFF6C5CE7),
      ),
      (
        label: 'Setoran Terakhir',
        value: latest != null ? DateFormat('d MMM', 'id_ID').format(latest.tanggal) : '-',
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF2F80B4),
      ),
      (
        label: 'Kehadiran',
        value: '${(dash.kehadiranRatio * 100).toStringAsFixed(0)}%',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF2E9E5B),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            for (final it in items)
              SummaryStatCard(label: it.label, value: it.value, icon: it.icon, color: it.color),
          ],
        );
      },
    );
  }
}

class _LatestSetoranCard extends StatelessWidget {
  final DashboardProvider dash;
  const _LatestSetoranCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final latest = dash.latest;
    if (latest == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(status: latest.status),
                const Spacer(),
                KeteranganChip(keterangan: latest.keterangan, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              latest.capaianText,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(latest.tanggal),
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CatatanGuruCard extends StatelessWidget {
  final DashboardProvider dash;
  const _CatatanGuruCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    final catatan = dash.latestCatatanGuru;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoftIconBox(icon: Icons.forum_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                (catatan == null || catatan.trim().isEmpty)
                    ? 'Belum ada catatan dari guru pembimbing.'
                    : catatan,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: (catatan == null || catatan.trim().isEmpty)
                      ? cs.onSurfaceVariant
                      : cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
