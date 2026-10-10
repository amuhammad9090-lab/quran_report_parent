import 'package:flutter/material.dart';

import '../../../../data/models/santri_record.dart';
import 'hero_icon_badge.dart';

class BarisBigPill extends StatelessWidget {
  final int baris;
  final int? target;
  // <-- BARU: dulu widget ini cuma terima angka baris+target (bukan
  // record), jadi gak ada cara nampilin [SantriRecord.nilai] punya
  // laporan terakhir. Dibikin OPSIONAL (nullable) biar pemanggil lama
  // yang mungkin belum sempat diupdate tetap kompile.
  final SantriRecord? record;
  const BarisBigPill({super.key, required this.baris, required this.target, this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      alignment: Alignment.center,
      decoration: HeroStatBox.decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const HeroIconBadge(icon: Icons.auto_stories_rounded),
          const SizedBox(height: 6),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: baris),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '$value',
              style: HeroStatBox.valueStyle,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            target != null ? '/ $target baris' : 'baris tercapai',
            style: HeroStatBox.labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _NilaiBadge(nilai: record?.nilai),
        ],
      ),
    );
  }
}

/// Kartu — ringkasan Tahsin (WAFA level+halaman ATAU Tilawah surah+ayat,
/// otomatis sesuai [record.tahsinMode]) jadi focal point hero saat laporan
/// terakhir statusnya Tahsin.
class TahsinBigCard extends StatelessWidget {
  final SantriRecord record;
  const TahsinBigCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      alignment: Alignment.center,
      decoration: HeroStatBox.decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const HeroIconBadge(icon: Icons.menu_book_rounded),
          const SizedBox(height: 6),
          Text(
            record.tahsinSummaryText,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HeroStatBox.valueStyle,
          ),
          const SizedBox(height: 1),
          Text(
            'Tahsin',
            style: HeroStatBox.labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _NilaiBadge(nilai: record.nilai),
        ],
      ),
    );
  }
}

/// Kartu — fokus hero saat laporan terakhir statusnya Muroja'ah/Tasmi'.
/// Beda dari [TahsinBigCard]: Muroja'ah punya satuan yang gampang
/// dihitung (ayat yang diulang, [SantriRecord.jumlahAyat]), jadi angkanya
/// dipakai sebagai fokus utama (mirip [BarisBigPill]), dengan surah+ayat
/// ([record.murojaahSummaryText]) sebagai label.
class MurojaahBigCard extends StatelessWidget {
  final SantriRecord record;
  const MurojaahBigCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final ayat = record.jumlahAyat;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      alignment: Alignment.center,
      decoration: HeroStatBox.decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const HeroIconBadge(icon: Icons.repeat_rounded),
          const SizedBox(height: 6),
          if (ayat > 0) ...[
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: ayat),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                '$value',
                style: HeroStatBox.valueStyle,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'ayat diulang',
              style: HeroStatBox.labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            Text(
              record.murojaahSummaryText,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HeroStatBox.valueStyle,
            ),
            const SizedBox(height: 1),
            Text(
              "Muroja'ah",
              style: HeroStatBox.labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          _NilaiBadge(nilai: record.nilai),
        ],
      ),
    );
  }
}

/// Badge kecil "Nilai: ..." di bawah 3 kartu mode hero — cuma tampil
/// kalau [nilai] ada isinya (laporan lama/belum dinilai guru = null,
/// jangan tampilin apa-apa, bukan "Nilai: -"). Style disamain sama
/// badge nilai di app guru sendiri (`santri_report_card.dart`): bg
/// tertiaryContainer, teks bold kecil — biar ortu langsung ngeh ini
/// konsep yang sama kayak yang guru lihat.
class _NilaiBadge extends StatelessWidget {
  final String? nilai;
  const _NilaiBadge({required this.nilai});

  @override
  Widget build(BuildContext context) {
    final value = nilai?.trim();
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Nilai $value',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: cs.onTertiaryContainer,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

