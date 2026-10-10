import 'package:flutter/material.dart';

import '../../../../data/models/enums.dart';
import '../../../../data/models/santri_record.dart';
import '../../../../data/services/progress_calculation_service.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../../providers/hafalan_provider.dart';
import '../../../widgets/misc_widgets.dart';
import 'tahsin_card.dart';

// ---------------------------------------------------------------------
// Progress Hafalan — visual & interaktif. Juz utama (dari laporan
// Tahfizh terakhir) ditampilkan besar dengan ring, juz lain yang pernah
// disentuh jadi chip horizontal (tap untuk detail). Tahsin ditampilkan
// terpisah dari data laporan Tahsin terakhir, kalau ada.
// ---------------------------------------------------------------------
class ProgressHafalanSection extends StatelessWidget {
  final DashboardProvider dash;
  final HafalanProvider hafalan;
  const ProgressHafalanSection({super.key, required this.dash, required this.hafalan});

  TahfizhSegment? get _latestTahfizhSegment {
    for (final r in dash.records) {
      final segs = r.tahfizhSegmentsEffective;
      if (segs.isNotEmpty) return segs.first;
    }
    return null;
  }

  SantriRecord? get _latestTahsinRecord {
    for (final r in dash.records) {
      if (r.status == HafalanStatus.tahsin ||
          r.status == HafalanStatus.tahsinTahfizh) {
        return r;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primary = hafalan.primaryJuz;
    final segment = _latestTahfizhSegment;
    final tahsinRecord = _latestTahsinRecord;
    final otherJuz = hafalan.juzProgress
        .where((j) => j.juz != primary?.juz)
        .toList()
      ..sort((a, b) => b.juz.compareTo(a.juz));

    if (primary == null && tahsinRecord == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(primary != null ? 'Progress Hafalan' : 'Progress Tahsin'),
        if (primary != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _JuzProgressRing(progress: primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Juz ${primary.juz}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        if (segment != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            segment.partText,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          primary.datasetAvailable
                              ? '${primary.barisTercapai} / ${primary.totalBarisJuz} baris'
                              : 'Data juz ini belum tersedia',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (otherJuz.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: otherJuz.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _JuzChip(progress: otherJuz[i]),
              ),
            ),
          ],
        ],
        if (tahsinRecord != null) ...[
          if (primary != null) const SizedBox(height: 10),
          TahsinCard(record: tahsinRecord),
        ],
      ],
    );
  }
}

class _JuzProgressRing extends StatelessWidget {
  final JuzProgress progress;
  const _JuzProgressRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percent = (progress.ratio * 100).toStringAsFixed(0);
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(
                begin: 0, end: progress.datasetAvailable ? progress.ratio : 0),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: progress.datasetAvailable ? value : null,
                strokeWidth: 7,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
          ),
          Text(
            progress.datasetAvailable ? '$percent%' : '-',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15, color: cs.primary),
          ),
        ],
      ),
    );
  }
}

class _JuzChip extends StatelessWidget {
  final JuzProgress progress;
  const _JuzChip({required this.progress});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Juz ${progress.juz}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 10),
                if (progress.datasetAvailable) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.ratio,
                      minHeight: 9,
                      backgroundColor: cs.primary.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(cs.primary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${progress.barisTercapai} dari ${progress.totalBarisJuz} baris tercapai '
                    '(${(progress.ratio * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ] else
                  Text(
                    'Data detail juz ini belum tersedia.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Juz ${progress.juz}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: cs.primary)),
              const SizedBox(height: 4),
              SizedBox(
                width: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.datasetAvailable ? progress.ratio : 0,
                    minHeight: 4,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

