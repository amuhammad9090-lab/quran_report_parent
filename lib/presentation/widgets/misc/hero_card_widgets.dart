import 'dart:convert';

import 'package:flutter/material.dart';

import 'primitives.dart';

class ProfileAvatar extends StatelessWidget {
  final String? photoBase64;
  final String initials;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;

  const ProfileAvatar({
    super.key,
    required this.photoBase64,
    required this.initials,
    required this.radius,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        image = MemoryImage(base64Decode(photoBase64!));
      } catch (_) {
        image = null;
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundImage: image,
      child: image == null
          ? Text(
              initials,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.7,
              ),
            )
          : null,
    );
  }
}

class WelcomeHeroCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? actions;
  final String? tagline;
  final Widget? leading;
  final String? eyebrow;
  final Widget? weeklyRecap;

  const WelcomeHeroCard({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.eyebrow,
    this.weeklyRecap,
    this.tagline,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitleBlock = eyebrow != null || title != null || subtitle != null;

    final titleColumn = !hasTitleBlock
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (title != null) ...[
                Text(
                  title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
              ],
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              if (tagline != null) ...[
                const SizedBox(height: 6),
                Text(
                  tagline!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          );

    // [title] null tapi [tagline] diisi -> tagline jadi teks mandiri di
    // posisi paling atas kartu (dipakai di hero Beranda sekarang).
    final standaloneTagline = (!hasTitleBlock && tagline != null)
        ? Text(
            tagline!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          )
        : null;

    final hasHeaderContent = titleColumn != null || standaloneTagline != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3B2E), Color(0xFF0E5C46)],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -14,
            top: -6,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 96,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasHeaderContent)
                if (titleColumn == null)
                  standaloneTagline!
                else if (leading == null)
                  titleColumn
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leading!,
                      const SizedBox(width: 14),
                      Expanded(child: titleColumn),
                    ],
                  ),
              if (weeklyRecap != null) ...[
                if (hasHeaderContent) ...[
                  const SizedBox(height: 18),
                  Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
                  const SizedBox(height: 16),
                ],
                weeklyRecap!,
              ],
              if (actions != null) ...[
                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
                const SizedBox(height: 18),
                actions!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Item aksi cepat di dalam [WelcomeHeroCard] (mis. "Tambah Laporan").
class HeroActionItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const HeroActionItem({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SoftIconBox(
                icon: icon,
                color: Colors.white,
                background: Colors.white.withValues(alpha: 0.16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu putih dengan judul + tautan "Lihat Semua" — bungkus untuk section
/// seperti "Ringkasan Hari Ini" dan "Kategori Cepat".
