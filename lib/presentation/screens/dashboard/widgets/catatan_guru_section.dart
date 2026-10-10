import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/parent_note.dart';
import '../../../../data/models/santri_record.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../../providers/parent_note_provider.dart';
import '../../../widgets/misc_widgets.dart';
import 'reply_composer_sheet.dart';

// ---------------------------------------------------------------------
// Catatan Guru — lebih menonjol, dengan tombol "Balas Catatan" yang
// membuka composer (tetap lewat ParentNoteProvider.sendNote yang sudah
// ada, cuma UX-nya dibikin terasa seperti membalas, bukan menulis dari
// nol).
// ---------------------------------------------------------------------
class CatatanGuruSection extends StatelessWidget {
  final DashboardProvider dash;
  const CatatanGuruSection({super.key, required this.dash});

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<ParentNoteProvider>();
    // <-- BERUBAH: dulu pakai `dash.latestRecordWithCatatan`, yang
    // nyari MUNDUR ke laporan mana pun (bisa berhari-hari lalu) yang
    // kebetulan ada catatannya. Efeknya ortu bisa disangka lagi lihat
    // catatan HARI INI padahal itu catatan lama, dan tombol "Balas
    // Catatan" di bawahnya makin nguatin kesan salah itu (dikira ada
    // percakapan aktif). Sekarang selalu merujuk ke LAPORAN TERAKHIR
    // (`dash.latest`) — kalau laporan itu memang tidak ada catatannya,
    // tampilkan kosong + indikator jelas, BUKAN diam-diam nampilin
    // catatan lama tanpa konteks.
    final latestRecord = dash.latest;
    final catatan = latestRecord?.catatan;
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
                    SoftIconBox(
                      icon: hasCatatan ? Icons.forum_rounded : Icons.forum_outlined,
                      color: hasCatatan ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tanggal SELALU ditampilkan kalau ada laporan
                          // terakhir — baik ada catatannya maupun
                          // tidak — sesuai kebiasaan tampilan yang
                          // sudah ada, cuma sekarang jujur soal
                          // laporan tanggal berapa yang lagi ditunjuk.
                          if (latestRecord != null) ...[
                            Text(
                              DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                                  .format(latestRecord.tanggal),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: hasCatatan ? cs.primary : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            hasCatatan
                                ? catatan
                                : (latestRecord == null
                                    ? 'Belum ada laporan dari guru pembimbing.'
                                    : 'Tidak ada catatan dari guru untuk laporan ini.'),
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight:
                                  hasCatatan ? FontWeight.w500 : FontWeight.w400,
                              color:
                                  hasCatatan ? cs.onSurface : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
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
      // PENTING: showModalBottomSheet push route BARU ke root Navigator,
      // yang levelnya di ATAS MultiProvider (MultiProvider dibuat di
      // dalam MainShell, bukan membungkus MaterialApp/Navigator)
      builder: (ctx) => ChangeNotifierProvider.value(
        value: notes,
        child: ReplyComposerSheet(latestRecord: latestRecord),
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
