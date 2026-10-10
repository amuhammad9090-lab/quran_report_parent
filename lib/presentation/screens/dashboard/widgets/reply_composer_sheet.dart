import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/santri_record.dart';
import '../../../../providers/parent_note_provider.dart';
import '../../../widgets/misc_widgets.dart';
class ReplyComposerSheet extends StatefulWidget {
  final SantriRecord? latestRecord;
  const ReplyComposerSheet({super.key, required this.latestRecord});

  @override
  State<ReplyComposerSheet> createState() => _ReplyComposerSheetState();
}

class _ReplyComposerSheetState extends State<ReplyComposerSheet> {
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

