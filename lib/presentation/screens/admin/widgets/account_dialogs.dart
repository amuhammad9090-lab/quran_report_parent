import 'dart:math';

import 'package:flutter/material.dart';

/// Helper murni (username/password generation, CSV escaping) + dialog
/// kredensial & konfirmasi reset akun — diekstrak dari
/// `manage_accounts_screen.dart` (dulu 1 file 551 baris) supaya di bawah
/// 300 baris. Semua fungsi di sini STATELESS (terima [BuildContext] +
/// parameter lain secara eksplisit, bukan baca field dari State manapun)
/// jadi aman dipanggil dari `manage_accounts_screen.dart` maupun file
/// aksi lain (`bulk_create_accounts.dart`, `account_create_reset.dart`).

/// Daftar kata umum di nama santri (gelar keislaman/prefix/connector)
/// yang DILEWATI saat cari kata "khas" buat username — soalnya kalau
/// dipake, gampang banget bentrok antar santri (banyak yang namanya
/// diawali "Muhammad"/"Ahmad" atau ada "Al"/"Bin" di tengah). Sengaja
/// hardcode di sini (bukan dari data) — cukup 1 tempat kalau mau
/// nambah kata baru.
const _commonNameWords = {
  'muhammad', 'mohammad', 'mohamad', 'muhamad',
  'ahmad', 'achmad',
  'siti', 'nur', 'nurul',
  'al', 'bin', 'binti',
  'abdul', 'abdur', 'abdurrahman',
};

/// Username SINGKAT dari 1 kata paling "khas" di nama — bukan lagi
/// "depan.belakang" (mis. "muhammad.khairi"). Contoh: "Muhammad
/// Zakwan Al Khairi" -> lewatin "muhammad" (umum) & "al" (connector),
/// ambil "zakwan". Kalau semua kata di nama itu kata umum (jarang
/// terjadi), fallback ke kata pertama apa adanya.
String suggestUsername(String nama) {
  final parts = nama
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((p) => p.replaceAll(RegExp(r'[^a-z]'), ''))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'santri';

  return parts.firstWhere(
    (p) => !_commonNameWords.contains(p),
    orElse: () => parts.first,
  );
}

String generatePassword() {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789'; // tanpa karakter ambigu (l/1/o/0)
  final rnd = Random.secure();
  return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
}

Future<void> showCredentialDialogFor(
  BuildContext context, {
  required String namaSantri,
  required String username,
  required String password,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Akun $namaSantri dibuat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catat & sampaikan ke orang tua sekarang — password TIDAK bisa dilihat lagi setelah ini ditutup.',
            style: TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          _CredentialRow(label: 'Username', value: username),
          const SizedBox(height: 6),
          _CredentialRow(label: 'Password', value: password),
        ],
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Sudah dicatat')),
      ],
    ),
  );
}

// <-- BARU: seluruh method ini. "Reset" di sini artinya: akun LAMA
// dinonaktifkan (password lama otomatis gak bisa dipake lagi, walau
// secara teknis akun Firebase Auth-nya masih ada, nganggur), lalu
// dibuatkan akun BARU (username+password baru) buat santri yang sama.
// Ini BUKAN literal "ganti password akun yang sama" — soalnya Firebase
// gak ngasih cara ganti password akun ORANG LAIN dari client app tanpa
// Cloud Functions/Blaze plan (baca README.md). Efeknya ke orang tua
// sama aja: dikasih kredensial baru yang langsung bisa dipake.
Future<bool> confirmResetDialog(BuildContext context, String namaSantri) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset akun?'),
      content: Text(
        'Password LAMA punya $namaSantri akan langsung berhenti berfungsi, '
        'lalu dibuatkan username & password BARU. Lanjutkan?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Reset')),
      ],
    ),
  );
  return confirmed ?? false;
}

String csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12.5))),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
