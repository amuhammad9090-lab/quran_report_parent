import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/santri_record.dart';
import '../../../widgets/misc_widgets.dart';
class TahsinCard extends StatelessWidget {
  final SantriRecord record;
  const TahsinCard({super.key, required this.record});

  String get _label {
    final mode = record.tahsinMode ?? TahsinMode.wafa;
    if (mode == TahsinMode.tilawah) {
      final segs = record.tilawahSegmentsEffective;
      return segs.isEmpty
          ? 'Tilawah'
          : 'Tilawah • ${segs.map((s) => s.partText).join(' + ')}';
    }
    return '${record.wafaLevel?.label ?? '-'} • Halaman ${record.halamanWafa ?? '-'}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SoftIconBox(
                icon: Icons.menu_book_rounded,
                color: AppColors.statusOn(context, HafalanStatus.tahsin)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tahsin Terkini',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(_label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

