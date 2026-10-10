import 'package:flutter/material.dart';

class SmpitLogoBadge extends StatelessWidget {
  final double size;
  final bool withBackground;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const SmpitLogoBadge({
    super.key,
    this.size = 56,
    this.withBackground = true,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset('assets/images/logo_smpit.png', fit: BoxFit.contain);

    if (!withBackground) {
      return SizedBox(width: size, height: size, child: logo);
    }

    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: logo,
    );
  }
}

/// Icon app (ilustrasi ortu+guru baca laporan, ala ikon aplikasi).
class AppIconMark extends StatelessWidget {
  final double size;
  final double borderRadius;
  const AppIconMark({super.key, this.size = 84, this.borderRadius = 22});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset('assets/images/app_icon.png', width: size, height: size, fit: BoxFit.cover),
    );
  }
}

/// Satu opsi format export (PDF/Word/Excel) di bottom sheet export.
class ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const ExportOptionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu baris distribusi keterangan (mis. "Hadir • 12 laporan • 80%" +
/// bar progres) — dipakai [StatistikTab] & [RekapBulananScreen] (dulu
/// ke-copy identik di dua tempat, sekarang cukup satu sumber di sini).
class DistribusiRow extends StatelessWidget {
  final String label;
  final int count;
  final double ratio;
  final Color color;

  const DistribusiRow({
    super.key,
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Text(
              '$count laporan • ${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}