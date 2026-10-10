import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/santri_record.dart';
import '../../../widgets/status_badge.dart';

class RecordDetailSheet extends StatelessWidget {
  final SantriRecord record;
  const RecordDetailSheet({super.key, required this.record});

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
            if ((record.nilai ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.military_tech_rounded, size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Nilai: ${record.nilai!.trim()}',
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

