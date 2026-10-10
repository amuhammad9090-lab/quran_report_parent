import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../data/services/admin_account_service.dart';
import '../../../../core/utils/csv_export.dart';
import 'account_dialogs.dart';

/// Alur "Buat Akun Massal" — diekstrak dari `manage_accounts_screen.dart`
/// (dulu 1 file 551 baris) supaya di bawah 300 baris. STATELESS: semua
/// dependency (service, data, cara reload) diterima sebagai parameter,
/// bukan baca field State manapun — lihat pemanggilnya di
/// `manage_accounts_screen.dart`.

Future<void> runBulkCreateAccounts(
  BuildContext context, {
  required AdminAccountService service,
  required List<Map<String, dynamic>> pending,
  required Future<void> Function() reload,
}) async {
  if (pending.isEmpty) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Buat akun massal?'),
      content: Text(
        'Ini akan membuat ${pending.length} akun sekaligus (satu per satu ke '
        'Firebase — bisa makan waktu beberapa menit, jangan tutup tab ini '
        'selama proses berjalan). Setelah selesai, daftar username+password '
        'otomatis terunduh sebagai file CSV — SIMPAN baik-baik, password '
        'tidak bisa dilihat lagi setelah itu.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mulai')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final progress = ValueNotifier<(int done, int total, String currentName)>(
    (0, pending.length, pending.first['nama'] as String),
  );

  unawaited(
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Membuat akun…'),
        content: ValueListenableBuilder(
          valueListenable: progress,
          builder: (ctx, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: value.$2 == 0 ? null : value.$1 / value.$2),
              const SizedBox(height: 12),
              Text(
                '${value.$1} / ${value.$2}${value.$3.isEmpty ? '' : ' — ${value.$3}'}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  final results = <Map<String, String>>[];
  final failed = <String>[];

  for (var i = 0; i < pending.length; i++) {
    final student = pending[i];
    progress.value = (i, pending.length, student['nama'] as String);

    final baseUsername = suggestUsername(student['nama'] as String);
    final password = generatePassword();
    Map<String, String>? result;
    for (var attempt = 0; attempt < 5 && result == null; attempt++) {
      final candidate =
          attempt == 0 ? baseUsername : '$baseUsername${Random.secure().nextInt(90) + 10}';
      try {
        result = await service.createAccount(
          studentId: student['id'] as String,
          username: candidate,
          password: password,
        );
      } catch (_) {
        // Kemungkinan username bentrok — coba lagi dengan suffix di
        // percobaan berikutnya.
      }
    }

    if (result != null) {
      results.add({
        'nama': student['nama'] as String,
        'kelas': student['kelas'] as String,
        'halaqoh': student['halaqoh'] as String,
        'username': result['username']!,
        'password': result['password']!,
      });
    } else {
      failed.add(student['nama'] as String);
    }

    // Jeda kecil antar request Firebase Auth.
    await Future.delayed(const Duration(milliseconds: 250));
  }

  progress.value = (pending.length, pending.length, '');

  if (!context.mounted) return;
  Navigator.pop(context); // tutup dialog progress

  if (results.isNotEmpty) {
    final buffer = StringBuffer('Nama,Kelas,Halaqoh,Username,Password\n');
    for (final r in results) {
      buffer.writeln(
        '${csvField(r['nama']!)},${csvField(r['kelas']!)},${csvField(r['halaqoh']!)},'
        '${csvField(r['username']!)},${csvField(r['password']!)}',
      );
    }
    await downloadCsv(
      'kredensial_akun_ortu_${DateTime.now().millisecondsSinceEpoch}.csv',
      buffer.toString(),
    );
  }

  await reload();
  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Selesai'),
      content: Text(
        failed.isEmpty
            ? '${results.length} akun berhasil dibuat. File CSV sudah terunduh — '
                'cek folder Downloads di browser.'
            : '${results.length} akun berhasil dibuat, ${failed.length} GAGAL:\n'
                '${failed.join(', ')}\n\nCoba buat manual satu-satu untuk yang gagal '
                '(tombol "Buat Akun" di daftar).',
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}
