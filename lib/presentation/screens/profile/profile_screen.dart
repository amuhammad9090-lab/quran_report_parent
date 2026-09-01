import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/responsive.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Profil santri — READ-ONLY total (sesuai brief: "Tidak ada editing
/// data"). Cuma menampilkan Nama, Kelas, Halaqoh. "Nama
/// pembimbing/guru" DISENGAJAKAN tidak ditampilkan — brief bilang
/// "jika memang tersedia", dan [Student] (model shared, tidak diubah)
/// memang tidak menyimpan referensi ke guru pembimbing. Kalau nanti
/// data itu tersedia dari backend (STEP 10), tinggal tambah 1 baris di
/// sini, tidak perlu ubah struktur.
///
/// Satu-satunya aksi di layar ini adalah **logout** — bukan mutasi data,
/// jadi tidak melanggar prinsip read-only.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final student = auth.currentStudent!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), centerTitle: false),
      body: SafeArea(
        child: ResponsiveContentWidth(
          maxWidth: 560,
          child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(
                      _initials(student.nama),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cs.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    student.nama,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kelas ${student.kelas} • Halaqoh ${student.halaqoh}',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionLabel('Data Santri'),
            Card(
              child: Column(
                children: [
                  _ProfileRow(icon: Icons.badge_rounded, label: 'Nama', value: student.nama),
                  const Divider(height: 1),
                  _ProfileRow(icon: Icons.class_rounded, label: 'Kelas', value: student.kelas),
                  const Divider(height: 1),
                  _ProfileRow(icon: Icons.groups_rounded, label: 'Halaqoh', value: student.halaqoh),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Tampilan'),
            const _ThemeModeCard(),
            const SizedBox(height: 20),
            const InlineMessageBanner(
              message:
                  'Akun ini hanya bisa melihat data. Untuk perubahan data santri, silakan hubungi guru pembimbing.',
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Keluar'),
              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda perlu login kembali untuk melihat perkembangan santri.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthProvider>().logout();
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// Pemilih Terang / Gelap / Ikuti Sistem — lihat [ThemeProvider].
/// Ditaruh di tab Profil (satu-satunya "pengaturan" yang dimiliki
/// portal ini) supaya pilihan tampilan gampang ditemukan tanpa
/// menambah tab baru.
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

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SoftIconBox(icon: icon, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}
