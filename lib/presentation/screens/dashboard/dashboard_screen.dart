import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/responsive.dart';
import '../../../data/models/student.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/hafalan_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../account/account_screen.dart';
import 'widgets/activity_timeline_section.dart';
import 'widgets/catatan_guru_section.dart';
import 'widgets/dashboard_hero.dart';
import 'widgets/dashboard_skeleton.dart';
import 'widgets/insight_section.dart';
import 'widgets/no_records_card.dart';
import 'widgets/progress_hafalan_section.dart';

/// Beranda — "Parent Progress Journey". Dijawab sekali lihat: bagaimana
/// perkembangan anak minggu ini, progres hafalan (visual+interaktif),
/// aktivitas terbaru, perbandingan minggu lalu, insight, dan catatan
/// guru + balasnya. Semua data dari [DashboardProvider]/[HafalanProvider]/
/// [ParentNoteProvider] (tidak ada angka hardcode/dummy). Tab "Perkembangan"
/// (lihat [onSeeAllActivity]) tetap jadi tempat riwayat lengkap — Beranda
/// ini cuma cuplikan supaya tidak menuh-menuhin satu layar.
class DashboardScreen extends StatelessWidget {
  final VoidCallback onSeeAllActivity;
  const DashboardScreen({super.key, required this.onSeeAllActivity});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent!;
    final dash = context.watch<DashboardProvider>();
    final hafalan = context.watch<HafalanProvider>();
    final photoBase64 = context.watch<AuthProvider>().profilePhotoBase64;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContentWidth(
          child: Column(
            children: [
              _AccountHeaderBar(student: student, photoBase64: photoBase64),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: dash.isLoading
                      ? const DashboardSkeleton(key: ValueKey('skeleton'))
                      : _DashboardContent(
                          key: const ValueKey('content'),
                          student: student,
                          dash: dash,
                          hafalan: hafalan,
                          onSeeAllActivity: onSeeAllActivity,
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

/// Header identitas santri, statis di atas hero — pola SAMA PERSIS
/// dengan header Beranda app guru (bulatan akun + "Assalamu'alaikum" +
/// nama, lihat screenshot referensi yang dikasih user).
class _AccountHeaderBar extends StatelessWidget {
  final Student student;
  final String? photoBase64;
  const _AccountHeaderBar({required this.student, required this.photoBase64});

  String get _initials {
    final parts = student.nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ProfileAvatar(
                  photoBase64: photoBase64,
                  initials: _initials,
                  radius: 22,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  foregroundColor: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Assalamu'alaikum 👋",
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 2),
                Text(
                  student.nama,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Kelas ${student.kelas} • Halaqoh ${student.halaqoh}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final Student student;
  final DashboardProvider dash;
  final HafalanProvider hafalan;
  final VoidCallback onSeeAllActivity;

  const _DashboardContent({
    super.key,
    required this.student,
    required this.dash,
    required this.hafalan,
    required this.onSeeAllActivity,
  });

  @override
  Widget build(BuildContext context) {
    if (dash.error != null && dash.records.isEmpty) {
      // Kasus "guru pembimbing belum ditugaskan" BEDA dari error koneksi
      // biasa — bukan sesuatu yang bisa diperbaiki orang tua dengan
      // "coba lagi", jadi pesannya juga harus beda (dan lebih akurat)
      // dari EmptyState wifi-off generik di bawah.
      final emptyState = dash.isGuruBelumDitugaskan
          ? const EmptyState(
              icon: Icons.assignment_late_rounded,
              title: 'Guru pembimbing belum ditugaskan',
              subtitle:
                  'Kelas/halaqoh ananda belum ada guru pembimbingnya di sistem. '
                  'Silakan hubungi pihak sekolah untuk menugaskan guru pembimbing.',
            )
          : const EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Gagal memuat data',
              subtitle: 'Periksa koneksi internet, lalu coba lagi.',
            );
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: emptyState,
              ),
            ),
          ),
        ],
      );
    }

    final noRecords = dash.records.isEmpty;

    // Urutan "master" dipakai buat delay stagger konsisten, terlepas dari
    // disusun 1 kolom (mobile) atau 2 kolom (desktop) di bawah.
    final hero = DashboardHero(student: student, dash: dash);
    final progress = noRecords
        ? const NoRecordsCard()
        : ProgressHafalanSection(dash: dash, hafalan: hafalan);
    final insight = (!noRecords && dash.insights.isNotEmpty)
        ? InsightSection(insights: dash.insights)
        : null;
    final timeline = noRecords
        ? null
        : ActivityTimelineSection(
            dash: dash, onSeeAllActivity: onSeeAllActivity);
    final catatan = CatatanGuruSection(dash: dash);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                var i = 0;
                Widget staggered(Widget child) =>
                    StaggeredEntrance(index: i++, child: child);
                if (constraints.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      staggered(hero),
                      const SizedBox(height: 22),
                      staggered(progress),
                      if (insight != null) ...[
                        const SizedBox(height: 22),
                        staggered(insight)
                      ],
                      if (timeline != null) ...[
                        const SizedBox(height: 22),
                        staggered(timeline)
                      ],
                      const SizedBox(height: 22),
                      staggered(catatan),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    staggered(hero),
                    const SizedBox(height: 22),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                staggered(progress),
                                if (timeline != null) ...[
                                  const SizedBox(height: 22),
                                  staggered(timeline)
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (insight != null) ...[
                                  staggered(insight),
                                  const SizedBox(height: 22)
                                ],
                                staggered(catatan),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
