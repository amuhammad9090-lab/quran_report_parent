import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/csv_export.dart';
import '../../../data/services/admin_account_service.dart';
import '../../widgets/misc_widgets.dart';

/// Kelola akun login santri untuk orang tua — buat baru & nonaktifkan.
/// Semua operasi lewat [AdminAccountService], LANGSUNG ke Firestore
/// (bukan Cloud Functions) — aman karena diproteksi `firestore.rules`
/// (`isAdmin()`, cek email admin yang sedang login), sengaja didesain
/// begini supaya tidak butuh plan Blaze (lihat README.md).
class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  final AdminAccountService _service = AdminAccountService();

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final students = await _service.listStudents();
      final accounts = await _service.listAccounts();
      setState(() {
        _students = students;
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Gagal memuat data — cek koneksi, atau firestore.rules belum di-deploy. ($e)';
        _loading = false;
      });
    }
  }

  Set<String> get _studentIdsWithAccount =>
      _accounts.map((a) => a['studentId'] as String).toSet();

  List<Map<String, dynamic>> get _pendingStudents =>
      _students.where((s) => !_studentIdsWithAccount.contains(s['id'])).toList();

  /// Buat akun buat SEMUA santri yang belum punya, satu-satu (bukan
  /// paralel — jaga-jaga biar nggak kena rate-limit Firebase Auth kalau
  /// bikin ratusan akun beruntun dari 1 sesi browser). Nggak nunjukin
  /// dialog kredensial per-santri kayak [_createAccountFor] (nggak
  /// masuk akal buat ratusan akun) — semua hasil dikumpulin, lalu di
  /// akhir langsung ke-download sebagai 1 file CSV (Nama, Kelas,
  /// Halaqoh, Username, Password) yang password-nya BENERAN aktif di
  /// Firebase (bukan contoh/placeholder).
  Future<void> _bulkCreateAccounts() async {
    final pending = _pendingStudents;
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
    if (confirmed != true || !mounted) return;

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

      final baseUsername = _suggestUsername(student['nama'] as String);
      final password = _generatePassword();
      Map<String, String>? result;
      for (var attempt = 0; attempt < 5 && result == null; attempt++) {
        final candidate =
            attempt == 0 ? baseUsername : '$baseUsername${Random.secure().nextInt(90) + 10}';
        try {
          result = await _service.createAccount(
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

    if (!mounted) return;
    Navigator.pop(context); // tutup dialog progress

    if (results.isNotEmpty) {
      final buffer = StringBuffer('Nama,Kelas,Halaqoh,Username,Password\n');
      for (final r in results) {
        buffer.writeln(
          '${_csvField(r['nama']!)},${_csvField(r['kelas']!)},${_csvField(r['halaqoh']!)},'
          '${_csvField(r['username']!)},${_csvField(r['password']!)}',
        );
      }
      await downloadCsv(
        'kredensial_akun_ortu_${DateTime.now().millisecondsSinceEpoch}.csv',
        buffer.toString(),
      );
    }

    await _load();
    if (!mounted) return;

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

  String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _createAccountFor(Map<String, dynamic> student) async {
    final baseUsername = _suggestUsername(student['nama'] as String);
    final password = _generatePassword();

    // Coba username "bersih" dulu (tanpa suffix angka), baru kalau
    // bentrok (mis. ada santri lain dengan nama depan-khas yang sama,
    // makin mungkin sekarang karena usernamenya dipendekin) coba lagi
    // dengan suffix angka acak — sama seperti pola retry di
    // [_resetAccountFor].
    Map<String, String>? result;
    Object? lastError;
    for (var attempt = 0; attempt < 5 && result == null; attempt++) {
      final candidate =
          attempt == 0 ? baseUsername : '$baseUsername${Random.secure().nextInt(90) + 10}';
      try {
        result = await _service.createAccount(
          studentId: student['id'] as String,
          username: candidate,
          password: password,
        );
      } catch (e) {
        lastError = e; // kemungkinan username bentrok — coba lagi
      }
    }

    if (result == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat akun: $lastError')),
      );
      return;
    }

    await _load();
    if (!mounted) return;
    await _showCredentialDialog(
      namaSantri: student['nama'] as String,
      username: result['username']!,
      password: result['password']!,
    );
  }

  Future<void> _showCredentialDialog({
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

  Future<void> _toggleActive(Map<String, dynamic> account) async {
    try {
      await _service.setAccountActive(account['id'] as String, !(account['isActive'] as bool));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: $e')),
      );
    }
  }

  // <-- BARU: seluruh method ini. "Reset" di sini artinya: akun LAMA
  // dinonaktifkan (password lama otomatis gak bisa dipake lagi, walau
  // secara teknis akun Firebase Auth-nya masih ada, nganggur), lalu
  // dibuatkan akun BARU (username+password baru) buat santri yang sama.
  // Ini BUKAN literal "ganti password akun yang sama" — soalnya Firebase
  // gak ngasih cara ganti password akun ORANG LAIN dari client app tanpa
  // Cloud Functions/Blaze plan (baca README.md). Efeknya ke orang tua
  // sama aja: dikasih kredensial baru yang langsung bisa dipake.
  Future<bool> _confirmReset(String namaSantri) async {
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

  Future<void> _resetAccountFor(Map<String, dynamic> account) async {
    final studentId = account['studentId'] as String;
    final namaSantri = _studentNameFor(studentId);

    if (!await _confirmReset(namaSantri)) return;

    try {
      // Nonaktifkan akun lama dulu.
      await _service.setAccountActive(account['id'] as String, false);

      // Username baru: base dari nama + suffix angka acak, dicoba
      // beberapa kali kalau kebetulan bentrok sama username lain.
      final baseUsername = _suggestUsername(namaSantri);
      final password = _generatePassword();
      Map<String, String>? result;
      Object? lastError;
      for (var attempt = 0; attempt < 5 && result == null; attempt++) {
        final candidate = '$baseUsername${Random.secure().nextInt(90) + 10}';
        try {
          result = await _service.createAccount(
            studentId: studentId,
            username: candidate,
            password: password,
          );
        } catch (e) {
          lastError = e; // kemungkinan username bentrok — coba lagi
        }
      }
      if (result == null) throw lastError ?? StateError('Gagal buat akun baru setelah beberapa percobaan');

      await _load();
      if (!mounted) return;
      await _showCredentialDialog(
        namaSantri: namaSantri,
        username: result['username']!,
        password: result['password']!,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal reset akun: $e')),
      );
    }
  }

  /// Daftar kata umum di nama santri (gelar keislaman/prefix/connector)
  /// yang DILEWATI saat cari kata "khas" buat username — soalnya kalau
  /// dipake, gampang banget bentrok antar santri (banyak yang namanya
  /// diawali "Muhammad"/"Ahmad" atau ada "Al"/"Bin" di tengah). Sengaja
  /// hardcode di sini (bukan dari data) — cukup 1 tempat kalau mau
  /// nambah kata baru.
  static const _commonNameWords = {
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
  String _suggestUsername(String nama) {
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

  String _generatePassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789'; // tanpa karakter ambigu (l/1/o/0)
    final rnd = Random.secure();
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Akun Orang Tua'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        const SectionLabel('Santri Belum Punya Akun'),
                        if (_pendingStudents.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _bulkCreateAccounts,
                              icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                              label: Text('Buat Akun Massal (${_pendingStudents.length})'),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_pendingStudents.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Semua santri sudah punya akun.'),
                            ),
                          )
                        else
                          Card(
                            child: Column(
                              children: [
                                for (final s in _students.where(
                                    (s) => !_studentIdsWithAccount.contains(s['id'])))
                                  ListTile(
                                    leading: const Icon(Icons.person_add_alt_1_rounded),
                                    title: Text(s['nama'] as String),
                                    subtitle: Text('Kelas ${s['kelas']} • Halaqoh ${s['halaqoh']}'),
                                    trailing: FilledButton(
                                      onPressed: () => _createAccountFor(s),
                                      child: const Text('Buat Akun'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        const SectionLabel('Akun Terdaftar'),
                        if (_accounts.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Belum ada akun dibuat.'),
                            ),
                          )
                        else
                          Card(
                            child: Column(
                              children: [
                                for (final a in _accounts)
                                  ListTile(
                                    leading: Icon(
                                      (a['isActive'] as bool)
                                          ? Icons.check_circle_rounded
                                          : Icons.block_rounded,
                                      color: (a['isActive'] as bool) ? Colors.green : Colors.grey,
                                    ),
                                    title: Text(a['username'] as String),
                                    subtitle: Text(_studentNameFor(a['studentId'] as String)),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'toggle') {
                                          _toggleActive(a);
                                        } else if (value == 'reset') {
                                          _resetAccountFor(a);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Text((a['isActive'] as bool) ? 'Nonaktifkan' : 'Aktifkan'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'reset',
                                          child: Text('Reset Akun (password baru)'),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  String _studentNameFor(String studentId) {
    try {
      return _students.firstWhere((s) => s['id'] == studentId)['nama'] as String;
    } catch (_) {
      return 'Santri tidak ditemukan';
    }
  }
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
