import 'package:flutter/material.dart';

class HeroIconBadge extends StatelessWidget {
  final IconData icon;
  const HeroIconBadge({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 13, color: Colors.white),
    );
  }
}

/// Style bersama buat semua kartu stat di hero (Kehadiran & capaian) —
/// SEMUA translucent putih di atas gradient hero (bukan pill solid mint/
/// putih lagi kayak sebelumnya), biar modelnya konsisten satu sama lain.
///
/// Public (bukan `_HeroStatBox`) karena dipakai lintas file oleh
/// `dashboard_hero.dart` dan `hero_mode_cards.dart`.
abstract class HeroStatBox {
  static BoxDecoration get decoration => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      );
  static const valueStyle = TextStyle(
      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800);
  static TextStyle get labelStyle => TextStyle(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      );
}

/// Kartu capaian — angka baris Tahfizh pekan ini vs target, jadi focal
/// point hero saat mode Tahfizh.
