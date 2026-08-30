import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/progress_calculation_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/hafalan_provider.dart';
import '../../widgets/misc_widgets.dart';

/// "Capaian Hafalan" — progress per-juz untuk juz yang pernah disentuh
/// santri, dihitung dari [ProgressCalculationService] (formula final
/// STEP 6: baris-based, lihat dokumentasi class itu).
///
/// Dataset baris Qur'an (assets/data/quran_line_dataset_*.json) mungkin
/// belum tersedia untuk sebagian/semua juz — kartu untuk juz semacam
/// itu SENGAJA menampilkan "Dataset belum tersedia", bukan progress bar
/// 0%, supaya tidak menyesatkan (lihat [JuzProgress.datasetAvailable]).
class HafalanScreen extends StatelessWidget {
  const HafalanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final progressService = context.read<ProgressCalculationService>();

    if (dash.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hafalan = HafalanProvider(progressService: progressService)
      ..computeFrom(dash.records);

    return Scaffold(
      appBar: AppBar(title: const Text('Capaian Hafalan'), centerTitle: false),
      body: SafeArea(
        child: ResponsiveContentWidth(
          child: hafalan.juzProgress.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: EmptyState(
                    icon: Icons.auto_stories_rounded,
                    title: 'Belum ada capaian hafalan',
                    subtitle: 'Progress akan muncul di sini setelah ada laporan Tahfizh dari guru pembimbing.',
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: hafalan.juzProgress.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  // Tampilkan juz terbaru dulu (urutan touched juz ascending
                  // dari provider -> dibalik supaya paling relevan di atas).
                  final progress = hafalan.juzProgress.reversed.toList()[i];
                  return _JuzProgressCard(progress: progress);
                },
              ),
          ),
      ),
    );
  }
}

class _JuzProgressCard extends StatelessWidget {
  final JuzProgress progress;
  const _JuzProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SoftIconBox(icon: Icons.bookmark_rounded, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Juz ${progress.juz}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                if (progress.datasetAvailable)
                  Text(
                    '${(progress.ratio * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cs.primary),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (progress.datasetAvailable) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.ratio,
                  minHeight: 10,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${progress.barisTercapai} dari ${progress.totalBarisJuz} baris',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
            ] else
              InlineMessageBanner(
                message:
                    'Dataset baris untuk Juz ${progress.juz} belum tersedia di portal ini, jadi persentase belum bisa dihitung. Laporan tetap tercatat normal.',
              ),
          ],
        ),
      ),
    );
  }
}
