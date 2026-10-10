import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'primitives.dart';

class DateGroupCard extends StatelessWidget {
  final DateTime date;
  final List<Widget> rows;

  const DateGroupCard({super.key, required this.date, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SoftIconBox(
                  icon: Icons.calendar_today_rounded,
                  color: cs.primary,
                  size: 14,
                  padding: 7,
                  radius: 10,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${rows.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ),
              ],
            ),
            for (final row in rows) ...[
              Divider(height: 22, color: Theme.of(context).dividerTheme.color),
              row,
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Baris ringkas laporan tahfizh/tahsin di dalam [DateGroupCard]
class RecordSummaryRow extends StatelessWidget {
  final IconData statusIcon;
  final Color statusColor;
  final String statusLabel;
  final String capaianText;
  final Widget keteranganChip;
  final VoidCallback? onTap;
  final String? notePreview;

  const RecordSummaryRow({
    super.key,
    required this.statusIcon,
    required this.statusColor,
    required this.statusLabel,
    required this.capaianText,
    required this.keteranganChip,
    this.onTap,
    this.notePreview,
  });

  @override
  Widget build(BuildContext context) {
    final hasNote = notePreview != null && notePreview!.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoftIconBox(icon: statusIcon, color: statusColor, size: 15, padding: 7, radius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    capaianText,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasNote) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.chat_bubble_rounded,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            notePreview!.trim(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // <-- BARU: cuplikan catatan di atas kepotong 1
                        // baris + italic — dari tampilannya doang, ortu
                        // gak ada tanda kalau itu bisa di-tap buat baca
                        // lengkap (dikira cuma teks biasa). Label kecil
                        // ini nunjukkin ada isi lebih lanjut yang bisa
                        // dibuka.
                        Text(
                          'Selengkapnya',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            keteranganChip,
          ],
        ),
      ),
    );
  }
}

/// Baris ringkas 1 santri di dalam [DateGroupCard] — dipakai di halaman
/// Kehadiran (siapa hadir/izin/alpa per tanggal).
class SantriAttendanceRow extends StatelessWidget {
  final String nama;
  final String kelas;
  final String halaqoh;
  final Widget keteranganChip;
  final VoidCallback? onTap;

  const SantriAttendanceRow({
    super.key,
    required this.nama,
    required this.kelas,
    required this.halaqoh,
    required this.keteranganChip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: cs.primaryContainer,
              child: Text(
                nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Kelas $kelas • Halaqoh $halaqoh',
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            keteranganChip,
          ],
        ),
      ),
    );
  }
}

/// Header pinned seragam untuk halaman non-Home yang dibuka lewat push
/// (Daftar Santri, Detail Santri, Kehadiran, Rekap Bulanan)
