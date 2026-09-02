import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/parent_note.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/models/student.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/weekly_target.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/parent_note_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/status_badge.dart';

/// Dashboard — "Seberapa jauh perkembangan hafalan anak saya?" dijawab
/// dalam satu layar, sesuai brief. Semua data dari [DashboardProvider]
/// (tidak ada angka hardcode). Responsive: grid ringkasan pakai
/// [LayoutBuilder] — 2 kolom di mobile, 4 kolom begitu lebar cukup
/// (tablet/desktop), bukan cuma layout mobile yang di-scale.
///
/// Header pakai [WelcomeHeroCard] — kartu gradien dengan avatar inisial
/// santri + ringkasan "Capaian Pekan Ini" (lihat [_DashboardHero]). Di
/// paling bawah ada kartu "Catatan untuk Guru" ([_ParentNoteComposer])
/// — satu-satunya bagian portal ini yang MENULIS data (lihat
/// `parent_note_provider.dart`), semua yang lain tetap murni baca.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent!;
    final dash = context.watch<DashboardProvider>();

    if (dash.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContentWidth(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                  child: _DashboardHero(student: student, dash: dash),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                sliver: SliverToBoxAdapter(
                  child: dash.records.isEmpty
                      ? const _NoRecordsCard()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SummaryGrid(dash: dash, student: student),
                            const SizedBox(height: 22),
                            const SectionLabel('Setoran Terakhir'),
                            _LatestSetoranCard(dash: dash),
                            const SizedBox(height: 22),
                            const SectionLabel('Catatan Guru'),
                            _CatatanGuruCard(dash: dash),
                          ],
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Catatan untuk Guru'),
                      _ParentNoteComposer(latestRecord: dash.latest),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header sambutan Dashboard — eyebrow selalu "Assalamu'alaikum" (bukan
/// sapaan jam), sapaan yang menyesuaikan jam device (Pagi/Siang/Sore/
/// Malam) ada di baris subtitle di bawah nama. Banner juga dilebarkan
/// buat menampung ringkasan "Capaian Pekan Ini" (baris tercapai vs
/// target mingguan halaqoh + progress bar) lewat
/// [WelcomeHeroCard.weeklyRecap].
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
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final baris = dash.barisTercapaiPekanIni;
    final target = weeklyTargetBarisForHalaqoh(student.halaqoh);
    final ratio = (target != null && target > 0) ? (baris / target).clamp(0.0, 1.0) : null;

    return WelcomeHeroCard(
      eyebrow: "Assalamu'alaikum 👋",
      title: student.nama,
      subtitle: '$_greeting • Kelas ${student.kelas} • Halaqoh ${student.halaqoh}',
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        child: Text(
          _initials,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      weeklyRecap: dash.records.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$baris',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
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
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ],
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
          subtitle: 'Laporan perkembangan akan muncul di sini setelah guru pembimbing menginput setoran pertama.',
        ),
      ),
    );
  }
}

/// Grid 4 kartu ringkasan:
/// 1. "Baris Pekan Ini" — capaian anak dalam sepekan berjalan (raw,
///    lihat [DashboardProvider.barisTercapaiPekanIni]).
/// 2. "Progres Hafalan" — baris tercapai pekan ini dibanding target
///    mingguan per halaqoh ([weeklyTargetBarisForHalaqoh]: A=15, B=12,
///    C/D=10 baris). "-" kalau halaqoh nggak dikenali (BUKAN 0%).
/// 3. "Rekap Terakhir" — tanggal laporan paling baru DI PEKAN INI
///    (biasanya dirampungkan guru Jumat/Sabtu terakhir pekan itu).
/// 4. "Kehadiran" — persentase sepanjang riwayat (tidak berubah), tap
///    buat lihat rincian Sakit/Izin/Tdk Setoran/dll lewat bottom sheet.
class _SummaryGrid extends StatelessWidget {
  final DashboardProvider dash;
  final Student student;
  const _SummaryGrid({required this.dash, required this.student});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final barisPekanIni = dash.barisTercapaiPekanIni;
    final target = weeklyTargetBarisForHalaqoh(student.halaqoh);
    final progressValue = target == null
        ? '-'
        : '${((barisPekanIni / target).clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';

    final rekapTerakhir = dash.tanggalRekapTerakhirPekanIni;

    final items = <({String label, String value, IconData icon, Color color, VoidCallback? onTap})>[
      (
        label: 'Baris Pekan Ini',
        value: '$barisPekanIni baris',
        icon: Icons.edit_note_rounded,
        color: cs.primary,
        onTap: null,
      ),
      (
        label: 'Progres Hafalan',
        value: progressValue,
        icon: Icons.timeline_rounded,
        color: const Color(0xFF6C5CE7),
        onTap: null,
      ),
      (
        label: 'Rekap Terakhir',
        value: rekapTerakhir != null ? DateFormat('d MMM', 'id_ID').format(rekapTerakhir) : '-',
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF2F80B4),
        onTap: null,
      ),
      (
        label: 'Kehadiran',
        value: '${(dash.kehadiranRatio * 100).toStringAsFixed(0)}%',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF2E9E5B),
        onTap: () => _showKehadiranDetail(context, dash),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            for (final it in items)
              SummaryStatCard(
                label: it.label,
                value: it.value,
                icon: it.icon,
                color: it.color,
                onTap: it.onTap,
              ),
          ],
        );
      },
    );
  }
}

/// Rincian kehadiran (Hadir/Sakit/Izin/Tdk Setoran/dll) sepanjang
/// riwayat — dibuka dari tap card "Kehadiran". Pakai
/// [DashboardProvider.keteranganDistribution] yang sudah ada, cuma
/// belum pernah ditampilkan di portal ortu.
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface),
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
                          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
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

class _LatestSetoranCard extends StatelessWidget {
  final DashboardProvider dash;
  const _LatestSetoranCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final latest = dash.latest;
    if (latest == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(status: latest.status),
                const Spacer(),
                KeteranganChip(keterangan: latest.keterangan, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              latest.capaianText,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(latest.tanggal),
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CatatanGuruCard extends StatelessWidget {
  final DashboardProvider dash;
  const _CatatanGuruCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    final catatan = dash.latestCatatanGuru;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoftIconBox(icon: Icons.forum_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                (catatan == null || catatan.trim().isEmpty)
                    ? 'Belum ada catatan dari guru pembimbing.'
                    : catatan,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: (catatan == null || catatan.trim().isEmpty)
                      ? cs.onSurfaceVariant
                      : cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu "Catatan untuk Guru" — orang tua menulis feedback singkat
/// (mis. "Ananda semalam demam, mohon dimaklumi kalau setorannya belum
/// lancar") yang tersimpan ke koleksi `parentNotes` (lihat
/// `parent_note_provider.dart` & `firestore_parent_note_repository.dart`).
/// Di bawah kolom tulis ada daftar ringkas catatan yang sudah pernah
/// dikirim, dengan status "Terkirim" / "Sudah dibaca guru".
class _ParentNoteComposer extends StatefulWidget {
  final SantriRecord? latestRecord;
  const _ParentNoteComposer({required this.latestRecord});

  @override
  State<_ParentNoteComposer> createState() => _ParentNoteComposerState();
}

class _ParentNoteComposerState extends State<_ParentNoteComposer> {
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
      _controller.clear();
      FocusScope.of(context).unfocus();
      showAppSnackbar(context, 'Catatan terkirim ke guru pembimbing.');
    } else if (notes.error != null) {
      showAppSnackbar(context, notes.error!, icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final notes = context.watch<ParentNoteProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftIconBox(icon: Icons.edit_note_rounded, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ada yang ingin disampaikan ke guru pembimbing? Catatan ini akan '
                    'langsung muncul sebagai notifikasi di aplikasi guru.',
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              enabled: !notes.isSending,
              decoration: InputDecoration(
                hintText: 'Tulis catatan untuk guru pembimbing…',
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                counterStyle: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: notes.isSending ? null : () => _submit(notes),
                icon: notes.isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 17),
                label: Text(notes.isSending ? 'Mengirim…' : 'Kirim Catatan'),
              ),
            ),
            if (notes.recent.isNotEmpty) ...[
              const SizedBox(height: 6),
              Divider(color: Theme.of(context).dividerTheme.color),
              const SizedBox(height: 6),
              Text(
                'RIWAYAT TERKIRIM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              for (final note in notes.recent) ...[
                _SentNoteRow(note: note),
                if (note != notes.recent.last) const SizedBox(height: 12),
              ],
            ],
          ],
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
                  if (createdAt != null) DateFormat('d MMM, HH:mm', 'id_ID').format(createdAt),
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
