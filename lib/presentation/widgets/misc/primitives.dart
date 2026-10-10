import 'package:flutter/material.dart';

/// Kotak ikon bertinta lembut — satu-satunya sumber gaya "ikon dalam kotak
/// warna soft" yang dipakai di SELURUH aplikasi (Home, form laporan,
/// pengaturan, tentang aplikasi). Jangan bikin versi manual lain di file
/// screen, biar seragam.
class SoftIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? background;
  final double size;
  final double padding;
  final double radius;

  const SoftIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.background,
    this.size = 20,
    this.padding = 9,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: size, color: color),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Ikon di dalam kotak bulat bertinta warna — dipakai sebagai leading/prefix
/// yang seragam di semua kolom form (tanggal, dropdown, input teks) biar
/// "satu bahasa desain" dari atas sampai bawah.

class PushedPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double titleFontSize;

  const PushedPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleFontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 3,
      shadowColor: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.10,
      ),
      toolbarHeight: subtitle != null ? 68 : 56,
      titleSpacing: 4,
      title: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Satu tombol aksi di dalam [SelectionActionBar] — kalau [filled] true jadi
/// tombol solid warna [destructive] error / primary, kalau enggak jadi
/// outline.
