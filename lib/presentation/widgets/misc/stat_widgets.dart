import 'package:flutter/material.dart';

import 'primitives.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.onSeeAll,
  });

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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                  ),
                ),
                if (onSeeAll != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSeeAll,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          'Lihat Semua',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Satu item statistik polos (ikon + angka + label), dipakai berjajar
/// dengan garis pemisah tipis di dalam [SectionCard].
class StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SoftIconBox(icon: icon, color: color),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Garis vertikal tipis pemisah antar [StatItem].
class VDivider extends StatelessWidget {
  const VDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 56,
      color: Theme.of(context).dividerTheme.color,
    );
  }
}

/// Kartu ringkas untuk baris "Ringkasan Hari Ini" — 3 kartu sejajar.
class SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const SummaryStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onTap != null)
          Positioned(
            top: 6,
            right: 6,
            child: Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
      ],
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Tile grid "Kategori Cepat" — pintasan filter yang sudah didukung provider.
class CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const CategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? color : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              SoftIconBox(icon: icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu kelompok per tanggal — dipakai di halaman Detail Santri,
/// Kehadiran, dan Rekap Bulanan (Statistik).
