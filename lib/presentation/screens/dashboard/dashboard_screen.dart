import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/weekly_target.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/parent_note.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/models/student.dart';
import '../../../data/services/progress_calculation_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/hafalan_provider.dart';
import '../../../providers/parent_note_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/status_badge.dart';

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

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContentWidth(
          // AnimatedSwitcher: transisi halus skeleton -> konten asli
          // begitu isLoading selesai, bukan potongan kasar spinner ->
          // layar penuh.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: dash.isLoading
                ? const _DashboardSkeleton(key: ValueKey('skeleton'))
                : _DashboardContent(
                    key: const ValueKey('content'),
                    student: student,
                    dash: dash,
                    hafalan: hafalan,
                    onSeeAllActivity: onSeeAllActivity,
                  ),
          ),
        ),
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
      return const CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                // ignore: unnecessary_const
                child: const EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Gagal memuat data',
                  subtitle: 'Periksa koneksi internet, lalu coba lagi.',
                ),
              ),
            ),
          ),
        ],
      );
    }

    final noRecords = dash.records.isEmpty;

    // Urutan "master" dipakai buat delay stagger konsisten, terlepas dari
    // disusun 1 kolom (mobile) atau 2 kolom (desktop) di bawah.
    final hero = _DashboardHero(student: student, dash: dash);
    final quickStats = noRecords ? null : _QuickStatsRow(dash: dash);
    final progress = noRecords
        ? const _NoRecordsCard()
        : _ProgressHafalanSection(dash: dash, hafalan: hafalan);
    final insight = (!noRecords && dash.insights.isNotEmpty)
        ? _InsightSection(insights: dash.insights)
        : null;
    final timeline = noRecords
        ? null
        : _ActivityTimelineSection(
            dash: dash, onSeeAllActivity: onSeeAllActivity);
    final catatan = _CatatanGuruSection(dash: dash);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                var i = 0;
                Widget staggered(Widget child) =>
                    _StaggeredEntrance(index: i++, child: child);

                // Di layar sempit (mobile/tablet potret): 1 kolom, urutan
                // sesuai brief (progress -> insight -> aktivitas -> catatan).
                if (constraints.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      staggered(hero),
                      const SizedBox(height: 22),
                      if (quickStats != null) ...[
                        staggered(quickStats),
                        const SizedBox(height: 22)
                      ],
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

                // Layar lebar (desktop/tablet lanskap, konten sudah dibatasi
                // ResponsiveContentWidth): 2 kolom — kiri data utama
                // (progress + aktivitas), kanan pelengkap (insight +
                // catatan) — supaya layar lebar tidak cuma jadi 1 kolom
                // sempit yang memanjang ke bawah.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    staggered(hero),
                    const SizedBox(height: 22),
                    if (quickStats != null) ...[
                      staggered(quickStats),
                      const SizedBox(height: 22)
                    ],
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

// ---------------------------------------------------------------------
// Micro-interaction: fade + slide-up ringan, staggered per section, agar
// Beranda terasa "hidup" tanpa dependency animasi tambahan.
// ---------------------------------------------------------------------
class _StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  const _StaggeredEntrance({required this.child, this.index = 0});

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.035),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Skeleton loading — dipakai selama DashboardProvider.isLoading, ganti
// full-screen spinner supaya bentuk layar akhir sudah kebayang dari awal.
// ---------------------------------------------------------------------
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      children: const [
        _PulsingBox(
            height: 168, borderRadius: BorderRadius.all(Radius.circular(24))),
        SizedBox(height: 22),
        _PulsingBox(height: 18, width: 140),
        SizedBox(height: 10),
        _PulsingBox(
            height: 150, borderRadius: BorderRadius.all(Radius.circular(20))),
        SizedBox(height: 22),
        _PulsingBox(height: 18, width: 160),
        SizedBox(height: 10),
        _PulsingBox(
            height: 88, borderRadius: BorderRadius.all(Radius.circular(20))),
        SizedBox(height: 22),
        _PulsingBox(height: 18, width: 150),
        SizedBox(height: 10),
        _PulsingBox(
            height: 120, borderRadius: BorderRadius.all(Radius.circular(20))),
      ],
    );
  }
}

class _PulsingBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  const _PulsingBox({
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  State<_PulsingBox> createState() => _PulsingBoxState();
}

class _PulsingBoxState extends State<_PulsingBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.045 + 0.035 * t),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Hero — sapaan + identitas + capaian pekan ini (sama seperti sebelumnya,
// cuma sekarang jadi bagian dari alur staggered entrance).
// ---------------------------------------------------------------------
class _DashboardHero extends StatelessWidget {
  final Student student;
  final DashboardProvider dash;
  const _DashboardHero({required this.student, required this.dash});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String get _initials {
    final parts = student.nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final baris = dash.barisTercapaiPekanIni;
    final target = weeklyTargetBarisForHalaqoh(student.halaqoh);
    final ratio = (target != null && target > 0)
        ? (baris / target).clamp(0.0, 1.0)
        : null;
    final delta = dash.barisDeltaVsPekanLalu;

    return WelcomeHeroCard(
      eyebrow: "Assalamu'alaikum 👋",
      title: student.nama,
      subtitle:
          '$_greeting • Kelas ${student.kelas} • Halaqoh ${student.halaqoh}',
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        child: Text(
          _initials,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      weeklyRecap: dash.records.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'CAPAIAN PEKAN INI',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (delta != null) ...[
                      const SizedBox(width: 8),
                      _DeltaPill(delta: delta),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$baris',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                    Text(
                      target != null ? ' / $target baris' : ' baris tercapai',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (ratio != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final int delta;
  const _DeltaPill({required this.delta});

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final flat = delta == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            flat
                ? Icons.remove_rounded
                : (positive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded),
            size: 11,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            flat ? 'sama' : '${delta.abs()}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _NoRecordsCard extends StatelessWidget {
  const _NoRecordsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: EmptyState(
          icon: Icons.auto_stories_rounded,
          title: 'Belum ada laporan',
          subtitle:
              'Laporan perkembangan akan muncul di sini setelah guru pembimbing menginput setoran pertama.',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Ringkasan cepat — Kehadiran & Total Baris (akumulasi sepanjang
// riwayat). Fitur ini sudah ada sebelumnya (DashboardProvider.
// keteranganDistribution/kehadiranRatio/totalBarisTercapai) — di sini
// ditampilkan ringkas sebagai 2 chip, bukan grid 4-kartu seperti versi
// lama, supaya tidak bersaing perhatian dengan Progress Hafalan sebagai
// fokus utama Beranda.
// ---------------------------------------------------------------------
class _QuickStatsRow extends StatelessWidget {
  final DashboardProvider dash;
  const _QuickStatsRow({required this.dash});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickStatChip(
            icon: Icons.fact_check_rounded,
            label: 'Kehadiran',
            value: '${(dash.kehadiranRatio * 100).toStringAsFixed(0)}%',
            color: AppColors.greenOn(context),
            onTap: () => _showKehadiranDetail(context, dash),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickStatChip(
            icon: Icons.menu_book_rounded,
            label: 'Total Baris',
            value: '${dash.totalBarisTercapai}',
            color: Theme.of(context).colorScheme.primary,
            onTap: null,
          ),
        ),
      ],
    );
  }
}

class _QuickStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _QuickStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color:
                    Theme.of(context).dividerTheme.color ?? Colors.transparent),
          ),
          child: Row(
            children: [
              SoftIconBox(
                  icon: icon, color: color, size: 16, padding: 8, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      label,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rincian kehadiran (Hadir/Sakit/Izin/Tdk Setoran/dll) sepanjang riwayat
/// — dibuka dari tap chip "Kehadiran". Logic dipertahankan apa adanya
/// dari versi sebelumnya (DashboardProvider.keteranganDistribution).
void _showKehadiranDetail(BuildContext context, DashboardProvider dash) {
  final dist = dash.keteranganDistribution;
  final total = dash.records.length;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rincian Kehadiran',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Dari $total laporan sepanjang riwayat',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              for (final k in Keterangan.values)
                if ((dist[k] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        KeteranganChip(keterangan: k, compact: true),
                        const Spacer(),
                        Text(
                          '${dist[k]}x',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: cs.onSurface),
                        ),
                      ],
                    ),
                  ),
              if (total == 0)
                Text(
                  'Belum ada laporan.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------
// Progress Hafalan — visual & interaktif. Juz utama (dari laporan
// Tahfizh terakhir) ditampilkan besar dengan ring, juz lain yang pernah
// disentuh jadi chip horizontal (tap untuk detail). Tahsin ditampilkan
// terpisah dari data laporan Tahsin terakhir, kalau ada.
// ---------------------------------------------------------------------
class _ProgressHafalanSection extends StatelessWidget {
  final DashboardProvider dash;
  final HafalanProvider hafalan;
  const _ProgressHafalanSection({required this.dash, required this.hafalan});

  TahfizhSegment? get _latestTahfizhSegment {
    for (final r in dash.records) {
      final segs = r.tahfizhSegmentsEffective;
      if (segs.isNotEmpty) return segs.first;
    }
    return null;
  }

  SantriRecord? get _latestTahsinRecord {
    for (final r in dash.records) {
      if (r.status == HafalanStatus.tahsin ||
          r.status == HafalanStatus.tahsinTahfizh) {
        return r;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primary = hafalan.primaryJuz;
    final segment = _latestTahfizhSegment;
    final tahsinRecord = _latestTahsinRecord;
    final otherJuz = hafalan.juzProgress
        .where((j) => j.juz != primary?.juz)
        .toList()
      ..sort((a, b) => b.juz.compareTo(a.juz));

    if (primary == null && tahsinRecord == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Progress Hafalan'),
        if (primary != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _JuzProgressRing(progress: primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Juz ${primary.juz}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        if (segment != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            segment.partText,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          primary.datasetAvailable
                              ? '${primary.barisTercapai} / ${primary.totalBarisJuz} baris'
                              : 'Data juz ini belum tersedia',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (otherJuz.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: otherJuz.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _JuzChip(progress: otherJuz[i]),
              ),
            ),
          ],
        ],
        if (tahsinRecord != null) ...[
          if (primary != null) const SizedBox(height: 10),
          _TahsinCard(record: tahsinRecord),
        ],
      ],
    );
  }
}

class _JuzProgressRing extends StatelessWidget {
  final JuzProgress progress;
  const _JuzProgressRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percent = (progress.ratio * 100).toStringAsFixed(0);
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(
                begin: 0, end: progress.datasetAvailable ? progress.ratio : 0),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: progress.datasetAvailable ? value : null,
                strokeWidth: 7,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
          ),
          Text(
            progress.datasetAvailable ? '$percent%' : '-',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15, color: cs.primary),
          ),
        ],
      ),
    );
  }
}

class _JuzChip extends StatelessWidget {
  final JuzProgress progress;
  const _JuzChip({required this.progress});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Juz ${progress.juz}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 10),
                if (progress.datasetAvailable) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.ratio,
                      minHeight: 9,
                      backgroundColor: cs.primary.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(cs.primary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${progress.barisTercapai} dari ${progress.totalBarisJuz} baris tercapai '
                    '(${(progress.ratio * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ] else
                  Text(
                    'Data detail juz ini belum tersedia.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Juz ${progress.juz}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: cs.primary)),
              const SizedBox(height: 4),
              SizedBox(
                width: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.datasetAvailable ? progress.ratio : 0,
                    minHeight: 4,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(cs.primary),
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

class _TahsinCard extends StatelessWidget {
  final SantriRecord record;
  const _TahsinCard({required this.record});

  String get _label {
    final mode = record.tahsinMode ?? TahsinMode.wafa;
    if (mode == TahsinMode.tilawah) {
      final segs = record.tilawahSegmentsEffective;
      return segs.isEmpty
          ? 'Tilawah'
          : 'Tilawah • ${segs.map((s) => s.partText).join(' + ')}';
    }
    return '${record.wafaLevel?.label ?? '-'} • Halaman ${record.halamanWafa ?? '-'}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SoftIconBox(
                icon: Icons.menu_book_rounded,
                color: AppColors.statusOn(context, HafalanStatus.tahsin)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tahsin Terkini',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(_label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Insight Minggu Ini — kalimat pendek dari DashboardProvider.insights.
// ---------------------------------------------------------------------
class _InsightSection extends StatelessWidget {
  final List<DashboardInsight> insights;
  const _InsightSection({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Insight Minggu Ini'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              children: [
                for (final insight in insights) ...[
                  ListTile(
                    dense: true,
                    leading: SoftIconBox(
                      icon: insight.icon,
                      color: insight.positive
                          ? AppColors.greenOn(context)
                          : AppColors.tahsinOn(context),
                      size: 17,
                    ),
                    title: Text(
                      insight.text,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (insight != insights.last)
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Theme.of(context).dividerTheme.color),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Aktivitas Terbaru — cuplikan timeline (maks 4 laporan terakhir), "Lihat
// Semua" pindah ke tab Perkembangan (tanpa query tambahan, data yang
// sama sudah ada di DashboardProvider).
// ---------------------------------------------------------------------
class _ActivityTimelineSection extends StatelessWidget {
  final DashboardProvider dash;
  final VoidCallback onSeeAllActivity;
  const _ActivityTimelineSection(
      {required this.dash, required this.onSeeAllActivity});

  @override
  Widget build(BuildContext context) {
    final recent = dash.records.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'Aktivitas Terbaru',
          trailing: TextButton(
            onPressed: onSeeAllActivity,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: const Text('Lihat Semua',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < recent.length; i++)
                  _TimelineRow(
                      record: recent[i], isLast: i == recent.length - 1),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final SantriRecord record;
  final bool isLast;
  const _TimelineRow({required this.record, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = AppColors.statusOn(context, record.status);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 12 : 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                if (!isLast)
                  Expanded(
                      child: Container(width: 1.6, color: cs.outlineVariant)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          DateFormat('d MMM', 'id_ID').format(record.tanggal),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: record.status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      record.capaianText,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    KeteranganChip(
                        keterangan: record.keterangan, compact: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Catatan Guru — lebih menonjol, dengan tombol "Balas Catatan" yang
// membuka composer (tetap lewat ParentNoteProvider.sendNote yang sudah
// ada, cuma UX-nya dibikin terasa seperti membalas, bukan menulis dari
// nol).
// ---------------------------------------------------------------------
class _CatatanGuruSection extends StatelessWidget {
  final DashboardProvider dash;
  const _CatatanGuruSection({required this.dash});

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<ParentNoteProvider>();
    final catatan = dash.latestCatatanGuru;
    final hasCatatan = catatan != null && catatan.trim().isNotEmpty;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Catatan Guru'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SoftIconBox(icon: Icons.forum_rounded, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasCatatan
                            ? catatan
                            : 'Belum ada catatan dari guru pembimbing.',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight:
                              hasCatatan ? FontWeight.w500 : FontWeight.w400,
                          color:
                              hasCatatan ? cs.onSurface : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        _openReplySheet(context, notes, dash.latest),
                    icon: const Icon(Icons.reply_rounded, size: 17),
                    label: Text(
                        hasCatatan ? 'Balas Catatan' : 'Kirim Catatan ke Guru'),
                  ),
                ),
                if (notes.recent.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(color: Theme.of(context).dividerTheme.color),
                  const SizedBox(height: 6),
                  Text(
                    'RIWAYAT TERKIRIM',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 10),
                  for (final note in notes.recent.take(3)) ...[
                    _SentNoteRow(note: note),
                    if (note != notes.recent.take(3).last)
                      const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openReplySheet(BuildContext context, ParentNoteProvider notes,
      SantriRecord? latestRecord) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ReplyComposerSheet(latestRecord: latestRecord),
    );
  }
}

class _ReplyComposerSheet extends StatefulWidget {
  final SantriRecord? latestRecord;
  const _ReplyComposerSheet({required this.latestRecord});

  @override
  State<_ReplyComposerSheet> createState() => _ReplyComposerSheetState();
}

class _ReplyComposerSheetState extends State<_ReplyComposerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(ParentNoteProvider notes) async {
    final message = _controller.text;
    final ok = await notes.sendNote(message, latestRecord: widget.latestRecord);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showAppSnackbar(context, 'Catatan terkirim ke guru pembimbing.');
    } else if (notes.error != null) {
      showAppSnackbar(context, notes.error!, icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<ParentNoteProvider>();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const Text('Balas ke Guru Pembimbing',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                'Catatan akan langsung muncul sebagai notifikasi di aplikasi guru.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                enabled: !notes.isSending,
                decoration: InputDecoration(
                  hintText:
                      'Contoh: Baik ustadz, insyaAllah akan kami bantu murojaah di rumah.',
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: notes.isSending ? null : () => _submit(notes),
                  icon: notes.isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 17),
                  label: Text(notes.isSending ? 'Mengirim…' : 'Kirim Balasan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentNoteRow extends StatelessWidget {
  final ParentNote note;
  const _SentNoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRead = note.isRead;
    final createdAt = note.createdAt;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isRead ? Icons.done_all_rounded : Icons.check_rounded,
          size: 15,
          color: isRead ? cs.primary : cs.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.message,
                style: const TextStyle(fontSize: 12.5, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (createdAt != null)
                    DateFormat('d MMM, HH:mm', 'id_ID').format(createdAt),
                  isRead ? 'Sudah dibaca guru' : 'Terkirim',
                ].join(' • '),
                style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
