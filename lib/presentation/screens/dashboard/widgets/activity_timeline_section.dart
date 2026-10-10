import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/santri_record.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../widgets/misc_widgets.dart';
import '../../../widgets/status_badge.dart';
// ---------------------------------------------------------------------
// Aktivitas Terbaru — cuplikan timeline (maks 4 laporan terakhir), "Lihat
// Semua" pindah ke tab Perkembangan (tanpa query tambahan, data yang
// sama sudah ada di DashboardProvider).
// ---------------------------------------------------------------------
class ActivityTimelineSection extends StatelessWidget {
  final DashboardProvider dash;
  final VoidCallback onSeeAllActivity;
  const ActivityTimelineSection(
      {super.key, required this.dash, required this.onSeeAllActivity});

  @override
  Widget build(BuildContext context) {
    final recent = dash.records.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'Aktivitas Terbaru',
          trailing: TextButton(
            onPressed: onSeeAllActivity,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: const Text('Lihat Semua',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < recent.length; i++)
                  _TimelineRow(
                      record: recent[i], isLast: i == recent.length - 1),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final SantriRecord record;
  final bool isLast;
  const _TimelineRow({required this.record, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = AppColors.statusOn(context, record.status);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 12 : 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                if (!isLast)
                  Expanded(
                      child: Container(width: 1.6, color: cs.outlineVariant)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          DateFormat('d MMM', 'id_ID').format(record.tanggal),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: record.status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      record.capaianText,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    KeteranganChip(
                        keterangan: record.keterangan, compact: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

