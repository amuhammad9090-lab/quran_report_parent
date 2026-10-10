
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/responsive.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/misc_widgets.dart';
import 'widgets/avatar_with_edit_button.dart';
import 'widgets/change_password_dialog.dart';

/// Layar "Akun" — isinya PERSIS konten yang dulu ada di tab bottom-nav
/// "Profil" (Data Santri, Ganti Password, Keluar), MINUS kartu pemilih
/// tema (itu sudah pindah ke tab "Pengaturan", lihat
/// `settings/settings_screen.dart`). Diakses dengan TAP bulatan akun di
/// hero Beranda (lihat `DashboardHero` di `dashboard_screen.dart`) —
/// bukan lagi tab tersendiri, sesuai permintaan supaya bottom-nav cuma
/// 3 slot: Beranda, Perkembangan, Pengaturan.
///
/// Tetap READ-ONLY terhadap data akademik santri (Nama/Kelas/Halaqoh) —
/// satu-satunya hal yang BISA diubah orang tua dari sini adalah hal
/// yang MEMANG milik akun login mereka sendiri: password & foto profil.
///
/// --- CATATAN BUG "abis logout, layar nge-blank/pudar sampai di-swipe" ---
/// `AccountScreen` ini dibuka lewat `Navigator.push` DI ATAS `_AuthGate`
/// (lihat `app.dart`) — artinya dia jadi route TERPISAH yang numpuk di
/// atas `MainShell`. `_AuthGate` sendiri cuma widget biasa yang swap
/// `MainShell` <-> `LoginScreen` berdasarkan `auth.status`, BUKAN lewat
/// Navigator push/pop — jadi begitu [AuthProvider.logout] dipanggil,
/// `_AuthGate` di BAWAH langsung ganti ke `LoginScreen`, tapi route
/// `AccountScreen` di ATASnya TETAP nempel di layar (tidak ke-pop
/// otomatis oleh apa pun). Orang tua jadi kelihatannya "nyangkut", dan
/// baru kelihatan pindah ke `LoginScreen` kalau route ini di-pop MANUAL
/// (mis. swipe-back Android, yang preview animasinya kelihatan pudar/
/// abu-abu pas transisi — itu Predictive Back bawaan Android, bukan
/// sesuatu yang dirender aplikasi ini).
///
/// FIX: [_confirmLogout] SEKARANG pop route ini balik ke root DULU
/// (`popUntil((route) => route.isFirst)`), BARU panggil `logout()` —
/// supaya `_AuthGate` di bawah sudah kelihatan (nge-render `LoginScreen`)
/// begitu route ini hilang, tanpa perlu swipe manual sama sekali. Kalau
/// nanti ada layar lain yang di-push via `Navigator.push` di atas
/// `MainShell`, urutan pop-dulu-baru-logout yang sama ini WAJIB diikuti
/// di titik logout mana pun (jangan taruh `logout()` sebelum pop).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final student = auth.currentStudent;
    final cs = Theme.of(context).colorScheme;

    // Jaring pengaman TAMBAHAN (di luar fix utama di [_confirmLogout]
    // di atas): kalau karena sebab lain `currentStudent` sempat null
    // SEMENTARA layar ini masih ke-render (mis. race condition lain di
    // masa depan), tampilkan spinner sebentar alih-alih crash dengan
    // null-check operator (`!`) seperti sebelumnya — layar ini akan
    // langsung ke-pop begitu frame berikutnya jalan (lihat listener di
    // bawah).
    if (student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContentWidth(
          maxWidth: 560,
          child: CustomScrollView(
            slivers: [
              const PushedPageHeader(title: 'Akun', titleFontSize: 18),
              SliverPadding(
                padding: const EdgeInsets.all(18),
                sliver: SliverList.list(
                  children: [
                    Center(
                      child: Column(
                        children: [
                          AvatarWithEditButton(
                            photoBase64: auth.profilePhotoBase64,
                            initials: _initials(student.nama),
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
    if (confirmed != true || !context.mounted) return;

    // URUTAN INI PENTING — lihat catatan panjang di atas class ini.
    // Pop DULU balik ke root (lepas route AccountScreen ini dari atas
    // MainShell), BARU panggil logout(). Kalau dibalik (logout dulu
    // baru pop), sempat ada 1 frame di mana AuthProvider sudah null-kan
    // currentStudent SEMENTARA AccountScreen masih jadi route teratas
    // — itu penyebab bug "layar nyangkut sampai di-swipe manual".
    Navigator.of(context).popUntil((route) => route.isFirst);
    context.read<AuthProvider>().logout();
  }

  Future<void> _openChangePassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (changed == true && context.mounted) {
      showAppSnackbar(context, 'Password berhasil diganti.');
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// Bulatan foto profil BESAR + badge kamera kecil di pojok kanan-bawah
/// buat ganti/hapus foto. Tap badge -> `_showPhotoOptionsSheet`.
///
/// Logic ketahanan foto (SENGAJA sama seperti Ganti Password): begitu
/// dipilih, foto dikompres kecil oleh `ImagePicker` sendiri
/// (`maxWidth`/`maxHeight`/`imageQuality` — tanpa perlu package
/// image-processing tambahan), lalu diupload ke Firestore lewat
/// `AuthProvider.updateProfilePhoto`. Karena sumber kebenarannya di
/// server (BUKAN file cache lokal HP), foto TIDAK akan hilang walau:
///  - aplikasi cache-nya dibersihkan lewat aplikasi "RAM/junk cleaner", atau
///  - aplikasinya di-uninstall lalu dipasang ulang (tinggal login lagi,
///    foto otomatis kebaca ulang dari Firestore).
