import 'package:flutter/material.dart';

import '../../../../data/models/enums.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../widgets/misc_widgets.dart';
import '../../../widgets/status_badge.dart';
class NoRecordsCard extends StatelessWidget {
  const NoRecordsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: EmptyState(
          icon: Icons.auto_stories_rounded,
          title: 'Belum ada laporan',
          subtitle:
              'Laporan perkembangan akan muncul di sini setelah guru pembimbing menginput setoran pertama.',
        ),
      ),
    );
  }
}

/// Rincian kehadiran (Hadir/Sakit/Izin/Tdk Setoran/dll) sepanjang riwayat
/// — dibuka dari tap item "Kehadiran".
///
/// Public (bukan `_showKehadiranDetail`) karena dipanggil dari
/// `_KehadiranMiniStat` di `dashboard_hero.dart`.
void showKehadiranDetail(BuildContext context, DashboardProvider dash) {
  final dist = dash.keteranganDistribution;
  final total = dash.records.length;

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
              Text(
                'Rincian Kehadiran',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Dari $total laporan sepanjang riwayat',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              for (final k in Keterangan.values)
                if ((dist[k] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        KeteranganChip(keterangan: k, compact: true),
                        const Spacer(),
                        Text(
                          '${dist[k]}x',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: cs.onSurface),
                        ),
                      ],
                    ),
                  ),
              if (total == 0)
                Text(
                  'Belum ada laporan.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      );
    },
  );
}

