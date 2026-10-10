import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../../../widgets/misc_widgets.dart';

class AvatarWithEditButton extends StatefulWidget {
  final String? photoBase64;
  final String initials;
  const AvatarWithEditButton({super.key, required this.photoBase64, required this.initials});

  @override
  State<AvatarWithEditButton> createState() => _AvatarWithEditButtonState();
}

class _AvatarWithEditButtonState extends State<AvatarWithEditButton> {
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
      if (!mounted) return;
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

class ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const ProfileRow({super.key, required this.icon, required this.label, required this.value});

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

