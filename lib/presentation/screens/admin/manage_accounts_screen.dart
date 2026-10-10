import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/services/admin_account_service.dart';
import '../../widgets/misc_widgets.dart';
import 'widgets/account_create_reset.dart';
import 'widgets/bulk_create_accounts.dart';

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
                              onPressed: () => runBulkCreateAccounts(
                                context,
                                service: _service,
                                pending: _pendingStudents,
                                reload: _load,
                              ),
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
                                      onPressed: () => createAccountFor(
                                        context,
                                        service: _service,
                                        student: s,
                                        reload: _load,
                                      ),
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
                                          resetAccountFor(
                                            context,
                                            service: _service,
                                            account: a,
                                            namaSantri: _studentNameFor(a['studentId'] as String),
                                            reload: _load,
                                          );
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
