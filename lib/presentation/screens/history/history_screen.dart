import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/dashboard_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/status_badge.dart';

/// "Riwayat Perkembangan" — daftar laporan berdasarkan tanggal, sesuai
/// brief. Pakai [DateGroupCard]/[RecordSummaryRow] (file di-share dari
/// app guru, tidak diubah) supaya visualnya identik dengan halaman
/// Detail Santri di app guru — bedanya di sini murni tampilan, tidak
/// ada `onTap` (tidak ada detail/edit, sesuai read-only).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();

    if (dash.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (dash.records.isEmpty) {
      return const Scaffold(
        body: Center(
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

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Perkembangan'), centerTitle: false),
      body: SafeArea(
        child: ResponsiveContentWidth(
          child: ListView.separated(
          padding: const EdgeInsets.all(18),
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
      ),
    );
  }
}
