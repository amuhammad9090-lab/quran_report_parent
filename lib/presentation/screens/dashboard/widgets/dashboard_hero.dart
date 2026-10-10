import 'package:flutter/material.dart';

import '../../../../core/utils/weekly_target.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/student.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../widgets/misc_widgets.dart';
import 'hero_icon_badge.dart';
import 'hero_mode_cards.dart';
import 'no_records_card.dart';

enum HeroFocus { tahfizh, tahsin, murojaah }

class DashboardHero extends StatelessWidget {
  final Student student;
  final DashboardProvider dash;
  const DashboardHero({super.key, required this.student, required this.dash});

  @override
  Widget build(BuildContext context) {
    final baris = dash.barisTercapaiPekanIni;
    final target = weeklyTargetBarisForHalaqoh(student.halaqoh);
    final delta = dash.barisDeltaVsPekanLalu;
    final latest = dash.latest;
    final HeroFocus focus = switch (latest?.status) {
      HafalanStatus.tahsin => HeroFocus.tahsin,
      HafalanStatus.murojaahTasmi => HeroFocus.murojaah,
      _ => HeroFocus.tahfizh,
    };
    return WelcomeHeroCard(
      tagline: "Pantau perkembangan Tahsin, Tahfizh, dan Muroja'ah ananda 📖",
      weeklyRecap: dash.records.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      switch (focus) {
                        HeroFocus.tahsin => 'TAHSIN TERAKHIR',
                        HeroFocus.murojaah => "MUROJA'AH TERAKHIR",
                        HeroFocus.tahfizh => 'CAPAIAN PEKAN INI',
                      },
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (focus == HeroFocus.tahfizh && delta != null) ...[
                      const SizedBox(width: 8),
                      _DeltaPill(delta: delta),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // <-- BARU: grid 2x2 (bukan 1 baris lagi) — sekarang ada 4
                // stat (Kehadiran, Ketuntasan, Nilai, Capaian), dan 4 pill
                // sempit berjejer dalam 1 baris bakal kepotong teksnya di
                // layar HP. Grid 2 baris x 2 kolom tetap ngasih tiap pill
                // ruang yang cukup buat angka+label, dan polanya familiar
                // (mirip kartu statistik di app lain) jadi "kebaca" sekali
                // lihat tanpa perlu scroll horizontal.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _KehadiranMiniStat(dash: dash)),
                      const SizedBox(width: 12),
                      Expanded(child: _KetuntasanMiniStat(tuntas: latest?.tuntas)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _NilaiMiniStat(nilai: latest?.nilai)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: switch (focus) {
                          HeroFocus.tahsin => TahsinBigCard(record: latest!),
                          HeroFocus.murojaah =>
                            MurojaahBigCard(record: latest!),
                          HeroFocus.tahfizh =>
                            BarisBigPill(baris: baris, target: target),
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Kartu Kehadiran — digabung ke hero (bukan kartu ringkasan terpisah lagi),
/// selalu jadi slot kiri hero apapun mode fokusnya.
class _KehadiranMiniStat extends StatelessWidget {
  final DashboardProvider dash;
  const _KehadiranMiniStat({required this.dash});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showKehadiranDetail(context, dash),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          alignment: Alignment.center,
          decoration: HeroStatBox.decoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HeroIconBadge(icon: Icons.fact_check_rounded),
              const SizedBox(height: 6),
              Text(
                '${(dash.kehadiranRatio * 100).toStringAsFixed(0)}%',
                style: HeroStatBox.valueStyle,
              ),
              const SizedBox(height: 1),
              Text(
                'Kehadiran',
                style: HeroStatBox.labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill Ketuntasan — status setoran laporan TERAKHIR ([SantriRecord.
/// tuntas], denormalisasi field dari app guru). 3 kondisi, dibedakan lewat
/// IKON (bukan warna — tetap translucent putih biar konsisten sama pill
/// lain di hero, "Belum Tuntas" bukan kondisi error jadi sengaja tidak
/// dikasih warna merah): Tuntas (centang), Belum Tuntas (jam pasir), dan
/// "—" kalau laporan lama belum pernah dinilai ketuntasannya (null, BUKAN
/// otomatis dianggap "belum tuntas").
class _KetuntasanMiniStat extends StatelessWidget {
  final bool? tuntas;
  const _KetuntasanMiniStat({required this.tuntas});

  @override
  Widget build(BuildContext context) {
    final known = tuntas != null;
    final icon = !known
        ? Icons.remove_rounded
        : (tuntas! ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded);
    final value = !known ? '—' : (tuntas! ? 'Tuntas' : 'Belum');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      alignment: Alignment.center,
      decoration: HeroStatBox.decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HeroIconBadge(icon: icon),
          const SizedBox(height: 6),
          Text(value, style: HeroStatBox.valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Text(
            'Ketuntasan',
            style: HeroStatBox.labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Pill Nilai — [SantriRecord.nilai] dari laporan terakhir (teks bebas
/// dari guru, mis. "85" / "A" / "Mumtaz"). Dulu cuma badge kecil nempel di
/// kartu Capaian; sekarang jadi pill sendiri (permintaan user: "jadi 3
/// pill") biar sama tingkat pentingnya kayak Kehadiran/Ketuntasan/Capaian.
class _NilaiMiniStat extends StatelessWidget {
  final String? nilai;
  const _NilaiMiniStat({required this.nilai});

  @override
  Widget build(BuildContext context) {
    final value = nilai?.trim();
    final has = value != null && value.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      alignment: Alignment.center,
      decoration: HeroStatBox.decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HeroIconBadge(icon: Icons.star_rounded),
          const SizedBox(height: 6),
          Text(
            has ? value : '—',
            style: HeroStatBox.valueStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text('Nilai', style: HeroStatBox.labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Ikon dalam kotak translucent — dipakai SERAGAM di semua kartu stat hero
/// (Kehadiran & 3 varian capaian) supaya modelnya persis sama kayak ss app
/// guru (ikon + angka + label, bukan pill warna solid).
class _DeltaPill extends StatelessWidget {
  final int delta;
  const _DeltaPill({required this.delta});

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final flat = delta == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            flat
                ? Icons.remove_rounded
                : (positive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded),
            size: 11,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            flat ? 'sama' : '${delta.abs()}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

