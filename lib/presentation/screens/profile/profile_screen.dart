import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/responsive.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/weekly_recap_provider.dart';
import '../../widgets/misc_widgets.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/profile_row.dart';

/// Profil santri — READ-ONLY total (sesuai brief: "Tidak ada editing
/// data"). Menampilkan Nama, Kelas, Halaqoh, dan (kalau datanya ada)
/// Guru Pembimbing.
///
/// "Guru Pembimbing" BUKAN dari [Student] (model shared, tidak diubah,
/// memang tidak menyimpan referensi ke guru) — diambil dari
/// [WeeklyRecapProvider.guruPembimbingNama] (field [WeeklyRecap.
/// guruPembimbing], dikirim guru pas "Deploy" rekap pekanan). Makanya
/// barisnya CUMA tampil kalau ada isinya: keluarga yang guru-nya belum
/// pernah deploy rekap pekanan sama sekali, atau baru mulai pakai app
/// ini, idak akan punya data ini dulu — itu kondisi normal, bukan bug.
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
    final guruNama = context.watch<WeeklyRecapProvider>().guruPembimbingNama;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
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
          children: [
            Center(
              child: Column(
                children: [
                  // BUG FIX: sebelumnya `CircleAvatar` polos di sini SELALU
                  // nampilin inisial doang, nggak pernah baca
                  // `auth.profilePhotoBase64` sama sekali — jadi kalau orang
                  // tua upload foto profil lewat tab Akun (`AvatarWithEdit
                  // Button`, yang udah bener), tab Profil ini tetap nampilin
                  // inisial terus, seolah fotonya nggak pernah ke-upload.
                  // Diganti ke `ProfileAvatar` yang sama persis dipakai di
                  // tab Akun, biar kedua tempat selalu sinkron (read-only,
                  // nggak ada tombol edit di sini — ganti foto tetap cuma
                  // lewat tab Akun).
                  ProfileAvatar(
                    photoBase64: auth.profilePhotoBase64,
                    initials: _initials(student.nama),
                    radius: 40,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    foregroundColor: cs.primary,
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
                  ProfileRow(icon: Icons.badge_rounded, label: 'Nama', value: student.nama),
                  const Divider(height: 1),
                  ProfileRow(icon: Icons.class_rounded, label: 'Kelas', value: student.kelas),
                  const Divider(height: 1),
                  ProfileRow(icon: Icons.groups_rounded, label: 'Halaqoh', value: student.halaqoh),
                  // Cuma tampil kalau datanya ada -- lihat doc comment
                  // [ProfileScreen] di atas kenapa ini bisa null.
                  if (guruNama != null) ...[
                    const Divider(height: 1),
                    ProfileRow(
                      icon: Icons.person_rounded,
                      label: 'Guru Pembimbing',
                      value: guruNama,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Akun'),
            Card(
              child: ListTile(
                leading: SoftIconBox(icon: Icons.lock_reset_rounded, color: cs.primary),
                title: const Text('Ganti Password'),
                subtitle: const Text('Ganti password login akun ini', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openChangePassword(context),
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

  Future<void> _openChangePassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diganti.')),
      );
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// Form ganti password — minta password LAMA dulu (buat re-autentikasi,
/// syarat Firebase Auth buat operasi sensitif), password BARU, dan
/// konfirmasinya. Lihat [AuthProvider.changePassword] — beneran
/// mengganti password di server Firebase Auth, jadi TIDAK akan balik ke
/// password lama walau cache browser dihapus.
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

