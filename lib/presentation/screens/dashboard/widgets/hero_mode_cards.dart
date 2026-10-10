import 'package:flutter/material.dart';

import '../../../../data/models/santri_record.dart';
import 'hero_icon_badge.dart';

class BarisBigPill extends StatelessWidget {
  final int baris;
  final int? target;
  const BarisBigPill({super.key, required this.baris, required this.target});

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
        ],
      ),
    );
  }
}

