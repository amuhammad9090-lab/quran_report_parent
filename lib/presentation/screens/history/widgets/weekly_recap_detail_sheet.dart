import 'package:flutter/material.dart';

import '../../../../data/models/weekly_recap.dart';

/// Sheet detail 1 kartu "Rekap Pekanan dari Guru" (dibuka dari
/// `_WeeklyRecapCard` / `WeeklyRecapSection` di `weekly_recap_widgets.dart`).
///
/// <-- BERUBAH (redesign): dulu semua field (Capaian/Keterangan/Catatan/
/// Baris/Guru Pembimbing) ditumpuk vertikal dengan gap tidak konsisten
/// (14/6/2px gantian) — makin berantakan begitu [WeeklyRecap.nilai] &
/// [WeeklyRecap.status] (field BARU, lihat model) ditambahkan dengan pola
/// yang sama. Sekarang dipisah 2 kelompok yang beda SIFAT datanya:
///   1. "Ringkasan pekan" — angka/status ringkas yang orang tua mau lihat
///      SEKALI PANDANG (Baris, Nilai, Ketuntasan) -> baris chip, bukan
///      paragraf, mirip gaya pill di Dashboard (HeroStatBox) tapi
///      di-adaptasi ke permukaan sheet (bukan di atas gradient).
///   2. Narasi guru (Capaian/Keterangan/Catatan) -> tetap label+teks,
///      tapi spacing-nya SERAGAM (bukan gantian 14/6/2).
/// Guru Pembimbing dipisah ke footer kecil di bawah divider, karena itu
/// metadata ("siapa yang bikin rekap ini"), bukan bagian dari isi rekap.
class WeeklyRecapDetailSheet extends StatelessWidget {
  final WeeklyRecap recap;
  final bool isOutdated;
  const WeeklyRecapDetailSheet({super.key, required this.recap, required this.isOutdated});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nilai = recap.nilai.trim();
    final status = recap.status.trim();
    // "-" dari StandarKetuntasan._label(null) = guru belum memutuskan --
    // secara makna SAMA dengan kosong, jangan ditampilkan sebagai chip
    // (chip isi "-" kelihatan kayak data rusak, bukan "belum ada").
    final hasStatus = status.isNotEmpty && status != '-';
    final hasBaris = recap.totalBaris > 0;
    final hasNilai = nilai.isNotEmpty;
    final hasRingkasan = hasBaris || hasNilai || hasStatus;
    final guruPembimbing = (recap.guruPembimbing ?? '').trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            if (hasRingkasan) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasBaris)
                    Expanded(
                      child: _SummaryChip(
                        icon: Icons.menu_book_rounded,
                        value: '${recap.totalBaris}',
                        label: 'Baris',
                      ),
                    ),
                  if (hasBaris && (hasNilai || hasStatus)) const SizedBox(width: 10),
                  if (hasNilai)
                    Expanded(
                      child: _SummaryChip(icon: Icons.star_rounded, value: nilai, label: 'Nilai'),
                    ),
                  if (hasNilai && hasStatus) const SizedBox(width: 10),
                  if (hasStatus)
                    Expanded(
                      child: _SummaryChip(
                        icon: status == 'Tuntas' ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
                        value: status,
                        label: 'Ketuntasan',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            _detailRow(context, 'Capaian', recap.capaian),
            if (recap.keterangan.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _detailRow(context, 'Keterangan', recap.keterangan),
            ],
            if (recap.catatan.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _detailRow(context, 'Catatan Guru', recap.catatan),
            ],
            if (guruPembimbing.isNotEmpty) ...[
              const SizedBox(height: 18),
              Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Guru Pembimbing: $guruPembimbing',
                      style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

/// Chip ringkasan (Baris/Nilai/Ketuntasan) di atas sheet — dipakai cuma
/// di sini (bukan `HeroStatBox`, yang didesain buat di ATAS gradient
/// gelap hero, warnanya putih translucent; permukaan sheet ini terang
/// normal, jadi butuh palet sendiri yang mengikuti `colorScheme`, bukan
/// `Colors.white` hardcoded).
class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _SummaryChip({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
