import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/responsive.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Tab "Pengaturan" — MENGGANTIKAN tab "Profil" yang lama di bottom-nav
/// (lihat `main_shell.dart`). Isinya SENGAJA cuma preferensi tampilan
/// aplikasi (tema) + info aplikasi, BUKAN lagi data akun/santri — itu
/// sekarang ada di `AccountScreen`, diakses lewat tap bulatan akun di
/// hero Beranda. Pemisahan ini niru pola umum: "Pengaturan" = preferensi
/// perangkat/aplikasi, "Akun" = identitas & kredensial orang tua.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        centerTitle: false,
        toolbarHeight: 68,
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
      ),
      body: SafeArea(
        child: ResponsiveContentWidth(
          maxWidth: 560,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: const [
              SectionLabel('Tampilan'),
              _ThemeModeCard(),
              SizedBox(height: 24),
              SectionLabel('Tentang Aplikasi'),
              _AboutAppCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pemilih Terang / Gelap / Ikuti Sistem — dipindah apa adanya dari tab
/// Profil lama (dulu di `profile_screen.dart`), cuma pindah tempat.
/// Lihat [ThemeProvider] untuk logic penyimpanannya.
class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard();

  static const _options = [
    (mode: ThemeMode.light, label: 'Terang', icon: Icons.light_mode_rounded),
    (mode: ThemeMode.dark, label: 'Gelap', icon: Icons.dark_mode_rounded),
    (mode: ThemeMode.system, label: 'Sistem', icon: Icons.smartphone_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            for (final opt in _options) ...[
              if (opt != _options.first) const SizedBox(width: 8),
              Expanded(
                child: _ThemeModeOption(
                  label: opt.label,
                  icon: opt.icon,
                  selected: themeProvider.mode == opt.mode,
                  color: cs.primary,
                  onTap: () => themeProvider.setMode(opt.mode),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : Colors.transparent, width: 1.4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: selected ? color : cs.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? color : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu info aplikasi — nama, versi, deskripsi singkat, & sekolah.
///
/// CATATAN IMPLEMENTASI: nomor versi di bawah ini masih HARDCODE
/// ('1.0.0') karena `pubspec.yaml` proyek ini tidak ikut diedit di sini
/// (hanya folder lib/ yang dikelola dari sesi ini). Supaya nomor versi
/// selalu akurat otomatis ikut `pubspec.yaml`, tinggal:
///   1) tambah dependency `package_info_plus` di pubspec.yaml, dan
///   2) ganti `_kAppVersion` di bawah dengan hasil
///      `PackageInfo.fromPlatform()` (async, bisa di-load di initState
///      sebuah StatefulWidget kecil pembungkus kartu ini).
/// Sebelum itu dilakukan, ingat update angka `_kAppVersion` manual tiap
/// rilis biar tidak menyesatkan orang tua yang mengecek versi aplikasi.
const _kAppVersion = '1.0.0';

class _AboutAppCard extends StatelessWidget {
  const _AboutAppCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIconMark(size: 52, borderRadius: 14),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Portal Orang Tua',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quran Report • Versi $_kAppVersion',
                        style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Portal ini memudahkan orang tua memantau perkembangan '
              'Tahsin, Tahfizh, dan Muroja\'ah ananda secara real-time — '
              'seluruh data bersumber langsung dari laporan yang diinput '
              'guru pembimbing di aplikasi Quran Report, sifatnya '
              'read-only (khusus untuk melihat, bukan mengubah data).',
              style: TextStyle(fontSize: 13, height: 1.5, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            const _AboutRow(icon: Icons.school_rounded, label: 'Sekolah', value: 'SMPIT Al Madinah, Tanjungpinang'),
            const SizedBox(height: 10),
            const _AboutRow(icon: Icons.support_agent_rounded, label: 'Bantuan', value: 'Hubungi guru pembimbing'),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _AboutRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
