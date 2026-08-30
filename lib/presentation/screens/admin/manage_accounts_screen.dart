import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/santri_account.dart';
import '../../../data/models/student.dart';
import '../../../data/repositories/santri_account_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/services/auth_hash_service.dart';
import '../../widgets/misc_widgets.dart';

/// Kelola akun login santri untuk orang tua — buat baru & nonaktifkan.
/// TIDAK ADA fitur ubah/reset password di sini secara sengaja untuk
/// STEP 10 versi awal ini (generate ulang password = mudah disalin
/// polanya untuk fitur berikutnya, tapi belum krusial buat MVP).
///
/// Repository yang dipakai masih `Mock*` (in-memory, hilang saat
/// refresh) — begitu backend production siap, cukup ganti instance yang
/// di-provide di `main.dart`, layar ini tidak perlu diubah sama sekali.
class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({
    super.key,
    this.studentRepository,
    this.accountRepository,
  });

  final StudentRepository? studentRepository;
  final SantriAccountRepository? accountRepository;

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  // Dibuat lokal (bukan lewat Provider) karena rute /admin sengaja
  // dipisah total dari tree Provider milik portal orang tua (lihat
  // app.dart) — supaya area admin tidak bergantung sama sekali pada
  // sesi AuthProvider orang tua yang mungkin sedang aktif/tidak.
  late final StudentRepository _studentRepo = widget.studentRepository ?? MockStudentRepository();
  late final SantriAccountRepository _accountRepo =
      widget.accountRepository ?? MockSantriAccountRepository();

  List<Student> _students = [];
  List<SantriAccount> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final students = await _studentRepo.getAll();
    final accounts = await _accountRepo.getAll();
    setState(() {
      _students = students;
      _accounts = accounts;
      _loading = false;
    });
  }

  Set<String> get _studentIdsWithAccount => _accounts.map((a) => a.studentId).toSet();

  Future<void> _createAccountFor(Student student) async {
    final username = _suggestUsername(student.nama);
    final password = _generatePassword();

    final account = SantriAccount(
      id: const Uuid().v4(),
      studentId: student.id,
      username: username,
      passwordHash: AuthHashService.instance.hash(password),
      createdAt: DateTime.now(),
    );
    await _accountRepo.create(account);
    await _load();

    if (!mounted) return;
    await _showCredentialDialog(student: student, username: username, password: password);
  }

  Future<void> _showCredentialDialog({
    required Student student,
    required String username,
    required String password,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Akun ${student.nama} dibuat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Catat & sampaikan ke orang tua sekarang — password TIDAK bisa dilihat lagi setelah ini ditutup (cuma tersimpan dalam bentuk hash).',
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

  Future<void> _toggleActive(SantriAccount account) async {
    await _accountRepo.setActive(account.id, !account.isActive);
    await _load();
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
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const SectionLabel('Santri Belum Punya Akun'),
                    if (_students.where((s) => !_studentIdsWithAccount.contains(s.id)).isEmpty)
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
                            for (final s in _students.where((s) => !_studentIdsWithAccount.contains(s.id)))
                              ListTile(
                                leading: const Icon(Icons.person_add_alt_1_rounded),
                                title: Text(s.nama),
                                subtitle: Text('Kelas ${s.kelas} • Halaqoh ${s.halaqoh}'),
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
                                  a.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
                                  color: a.isActive ? Colors.green : Colors.grey,
                                ),
                                title: Text(a.username),
                                subtitle: Text(_studentNameFor(a.studentId)),
                                trailing: TextButton(
                                  onPressed: () => _toggleActive(a),
                                  child: Text(a.isActive ? 'Nonaktifkan' : 'Aktifkan'),
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
      return _students.firstWhere((s) => s.id == studentId).nama;
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
