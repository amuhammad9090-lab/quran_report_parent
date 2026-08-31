import 'dart:math';

import 'package:flutter/material.dart';

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

  Future<void> _createAccountFor(Map<String, dynamic> student) async {
    final username = _suggestUsername(student['nama'] as String);
    final password = _generatePassword();

    try {
      final result = await _service.createAccount(
        studentId: student['id'] as String,
        username: username,
        password: password,
      );
      await _load();
      if (!mounted) return;
      await _showCredentialDialog(
        namaSantri: student['nama'] as String,
        username: result['username']!,
        password: result['password']!,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat akun: $e')),
      );
    }
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

  String _suggestUsername(String nama) {
    final parts = nama.trim().toLowerCase().split(RegExp(r'\s+'));
    final base = parts.length >= 2 ? '${parts.first}.${parts.last}' : parts.first;
    return base.replaceAll(RegExp(r'[^a-z.]'), '');
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
                        if (_students.where((s) => !_studentIdsWithAccount.contains(s['id'])).isEmpty)
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
