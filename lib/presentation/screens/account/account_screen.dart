import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/responsive.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Layar "Akun" — isinya PERSIS konten yang dulu ada di tab bottom-nav
/// "Profil" (Data Santri, Ganti Password, Keluar), MINUS kartu pemilih
/// tema (itu sudah pindah ke tab "Pengaturan", lihat
/// `settings/settings_screen.dart`). Diakses dengan TAP bulatan akun di
/// hero Beranda (lihat `_DashboardHero` di `dashboard_screen.dart`) —
/// bukan lagi tab tersendiri, sesuai permintaan supaya bottom-nav cuma
/// 3 slot: Beranda, Perkembangan, Pengaturan.
///
/// Tetap READ-ONLY terhadap data akademik santri (Nama/Kelas/Halaqoh) —
/// satu-satunya hal yang BISA diubah orang tua dari sini adalah hal
/// yang MEMANG milik akun login mereka sendiri: password & foto profil.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final student = auth.currentStudent!;
    final cs = Theme.of(context).colorScheme;

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
                          _AvatarWithEditButton(
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
                          _ProfileRow(icon: Icons.badge_rounded, label: 'Nama', value: student.nama),
                          const Divider(height: 1),
                          _ProfileRow(icon: Icons.class_rounded, label: 'Kelas', value: student.kelas),
                          const Divider(height: 1),
                          _ProfileRow(icon: Icons.groups_rounded, label: 'Halaqoh', value: student.halaqoh),
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
    if (confirmed == true && context.mounted) {
      context.read<AuthProvider>().logout();
    }
  }

  Future<void> _openChangePassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
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
class _AvatarWithEditButton extends StatefulWidget {
  final String? photoBase64;
  final String initials;
  const _AvatarWithEditButton({required this.photoBase64, required this.initials});

  @override
  State<_AvatarWithEditButton> createState() => _AvatarWithEditButtonState();
}

class _AvatarWithEditButtonState extends State<_AvatarWithEditButton> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    Navigator.of(context).pop(); // tutup bottom sheet opsi dulu
    try {
      final picker = ImagePicker();
      // maxWidth/maxHeight/imageQuality: kompresi dilakukan ImagePicker
      // sendiri SEBELUM byte-nya sampai ke app (hemat, tidak perlu
      // package image-processing tambahan) — hasil akhir jauh di bawah
      // limit 1 dokumen Firestore (1 MiB) walau nanti di-encode base64
      // (base64 nambah ukuran ~33%).
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 70,
      );
      if (picked == null || !mounted) return;

      final Uint8List bytes = await picked.readAsBytes();
      setState(() => _busy = true);
      final error = await context.read<AuthProvider>().updateProfilePhoto(bytes);
      if (!mounted) return;
      setState(() => _busy = false);
      if (error != null) {
        showAppSnackbar(context, error, icon: Icons.error_outline_rounded);
      } else {
        showAppSnackbar(context, 'Foto profil berhasil diperbarui.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnackbar(context, 'Gagal mengambil foto. Coba lagi.', icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _removePhoto() async {
    Navigator.of(context).pop();
    setState(() => _busy = true);
    final error = await context.read<AuthProvider>().removeProfilePhoto();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      showAppSnackbar(context, error, icon: Icons.error_outline_rounded);
    } else {
      showAppSnackbar(context, 'Foto profil dihapus.');
    }
  }

  void _showOptions() {
    final hasPhoto = widget.photoBase64 != null && widget.photoBase64!.isNotEmpty;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Ambil dari Kamera'),
              onTap: () => _pick(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Pilih dari Galeri'),
              onTap: () => _pick(ImageSource.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
                title: Text('Hapus Foto', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: _removePhoto,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ProfileAvatar(
            photoBase64: widget.photoBase64,
            initials: widget.initials,
            radius: 48,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            foregroundColor: cs.primary,
          ),
          if (_busy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: cs.primary,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _busy ? null : _showOptions,
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Form ganti password — minta password LAMA dulu (buat re-autentikasi,
/// syarat Firebase Auth buat operasi sensitif), password BARU, dan
/// konfirmasinya. Lihat [AuthProvider.changePassword] — beneran
/// mengganti password di server Firebase Auth, jadi TIDAK akan balik ke
/// password lama walau cache browser/aplikasi dihapus.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final newPw = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || newPw.isEmpty) {
      setState(() => _error = 'Semua kolom wajib diisi.');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _error = 'Password baru minimal 6 karakter.');
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = 'Konfirmasi password baru tidak cocok.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await context.read<AuthProvider>().changePassword(
          currentPassword: current,
          newPassword: newPw,
        );

    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Ganti Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: 'Password Lama',
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscureNew,
              enabled: !_submitting,
              decoration: const InputDecoration(labelText: 'Konfirmasi Password Baru'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan'),
        ),
      ],
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
