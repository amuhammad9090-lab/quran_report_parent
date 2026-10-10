import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../data/services/admin_account_service.dart';
import 'account_dialogs.dart';

/// Alur "Buat Akun" (1 santri) & "Reset Akun" — diekstrak dari
/// `manage_accounts_screen.dart` (dulu 1 file 551 baris) supaya di bawah
/// 300 baris. STATELESS sama seperti `bulk_create_accounts.dart`.

Future<void> createAccountFor(
  BuildContext context, {
  required AdminAccountService service,
  required Map<String, dynamic> student,
  required Future<void> Function() reload,
}) async {
  final baseUsername = suggestUsername(student['nama'] as String);
  final password = generatePassword();

  // Coba username "bersih" dulu (tanpa suffix angka), baru kalau
  // bentrok (mis. ada santri lain dengan nama depan-khas yang sama,
  // makin mungkin sekarang karena usernamenya dipendekin) coba lagi
  // dengan suffix angka acak — sama seperti pola retry di
  // [resetAccountFor].
  Map<String, String>? result;
  Object? lastError;
  for (var attempt = 0; attempt < 5 && result == null; attempt++) {
    final candidate =
        attempt == 0 ? baseUsername : '$baseUsername${Random.secure().nextInt(90) + 10}';
    try {
      result = await service.createAccount(
        studentId: student['id'] as String,
        username: candidate,
        password: password,
      );
    } catch (e) {
      lastError = e; // kemungkinan username bentrok — coba lagi
    }
  }

  if (result == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal membuat akun: $lastError')),
    );
    return;
  }

  await reload();
  if (!context.mounted) return;
  await showCredentialDialogFor(
    context,
    namaSantri: student['nama'] as String,
    username: result['username']!,
    password: result['password']!,
  );
}

Future<void> resetAccountFor(
  BuildContext context, {
  required AdminAccountService service,
  required Map<String, dynamic> account,
  required String namaSantri,
  required Future<void> Function() reload,
}) async {
  final studentId = account['studentId'] as String;

  if (!await confirmResetDialog(context, namaSantri)) return;

  try {
    // Nonaktifkan akun lama dulu.
    await service.setAccountActive(account['id'] as String, false);

    // Username baru: base dari nama + suffix angka acak, dicoba
    // beberapa kali kalau kebetulan bentrok sama username lain.
    final baseUsername = suggestUsername(namaSantri);
    final password = generatePassword();
    Map<String, String>? result;
    Object? lastError;
    for (var attempt = 0; attempt < 5 && result == null; attempt++) {
      final candidate = '$baseUsername${Random.secure().nextInt(90) + 10}';
      try {
        result = await service.createAccount(
          studentId: studentId,
          username: candidate,
          password: password,
        );
      } catch (e) {
        lastError = e; // kemungkinan username bentrok — coba lagi
      }
    }
    if (result == null) throw lastError ?? StateError('Gagal buat akun baru setelah beberapa percobaan');

    await reload();
    if (!context.mounted) return;
    await showCredentialDialogFor(
      context,
      namaSantri: namaSantri,
      username: result['username']!,
      password: result['password']!,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal reset akun: $e')),
    );
  }
}
