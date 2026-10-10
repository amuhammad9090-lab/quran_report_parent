import 'package:flutter/material.dart';

import '../../../../data/models/weekly_recap.dart';
import '../../../../providers/weekly_recap_provider.dart';
import '../../../widgets/misc_widgets.dart';
import 'weekly_recap_detail_sheet.dart';

class WeeklyRecapSection extends StatelessWidget {
  final WeeklyRecapProvider provider;
  // Hasil FILTER dari `provider.recaps` (jaring pengaman staleness —
  // lihat `weeklyRecapIsLikelyStale` & catatan panjang di
  // `WeeklyRecap`), dihitung sekali di `_HistoryScreenState.build`
  // supaya tidak dihitung ulang tiap rebuild section ini.
  final List<WeeklyRecap> visibleRecaps;
  /// Id rekap yang terdeteksi kedaluwarsa — lihat `weeklyRecapIsOutdated`.
  final Set<String> outdatedRecapIds;
  const WeeklyRecapSection({
    super.key,
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
      builder: (ctx) => WeeklyRecapDetailSheet(recap: r, isOutdated: isOutdated),
    );
  }
}

