import 'package:flutter/material.dart';

import '../../../../data/models/weekly_recap.dart';
class WeeklyRecapDetailSheet extends StatelessWidget {
  final WeeklyRecap recap;
  final bool isOutdated;
  const WeeklyRecapDetailSheet({super.key, required this.recap, required this.isOutdated});

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
            if (isOutdated) ...[
              // Peringatan JUJUR, bukan menyembunyikan data: isi rekap
              // di bawah adalah snapshot lama buatan guru, sementara
              // daftar laporan harian di layar belakang sudah versi
              // terbaru. Portal ini read-only jadi tidak menghitung
              // ulang sendiri — lihat `weeklyRecapIsOutdated`.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.update_rounded, size: 17, color: cs.tertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rekap ini dibuat sebelum laporan harian terakhir '
                        'diperbarui guru, jadi angkanya mungkin belum sesuai. '
                        'Daftar laporan harian di halaman ini yang paling baru.',
                        style: TextStyle(fontSize: 12.5, height: 1.45, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _detailRow(context, 'Capaian', recap.capaian),
            if (recap.keterangan.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailRow(context, 'Keterangan', recap.keterangan),
            ],
            if (recap.catatan.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailRow(context, 'Catatan Guru', recap.catatan),
            ],
            // Sama seperti mini card: sembunyikan total (+ gap-nya)
            // kalau memang 0 (pekan Tahsin/Muroja'ah doang) — lihat
            // catatan panjang di widget kartu mini-nya.
            if (recap.totalBaris > 0) ...[
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
            ],
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
