import 'package:flutter/material.dart';

import '../../../core/utils/parent_auth_constants.dart';
import '../../../data/services/admin_account_service.dart';
import 'manage_accounts_screen.dart';

/// Login admin SUNGGUHAN (Firebase Auth email/password) sebelum masuk
/// [ManageAccountsScreen] — pengganti PIN lokal versi sebelumnya. Rute
/// ini (`/admin`) SENGAJA tidak ada link/tombol apa pun ke sini dari UI
/// orang tua (dashboard/nav) — cuma bisa diakses kalau guru/admin tahu
/// URL-nya langsung.
///
/// Enforcement keamanan yang SEBENARNYA ada di `firestore.rules`
/// (`isAdmin()`, cek `request.auth.token.email`) — bukan di layar ini.
/// Login gagal di sini cuma berarti gagal MASUK UI-nya; kalaupun ada
/// yang bypass UI ini somehow, mereka tetap tidak bisa baca/tulis
/// koleksi admin di Firestore tanpa email yang match rules.
class AdminLoginGate extends StatefulWidget {
  const AdminLoginGate({super.key});

  @override
  State<AdminLoginGate> createState() => _AdminLoginGateState();
}

class _AdminLoginGateState extends State<AdminLoginGate> {
  final _emailCtrl = TextEditingController(text: kAdminEmail);
  final _passwordCtrl = TextEditingController();
  final _authService = AdminAuthService();

  bool _loading = false;
  bool _unlocked = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      setState(() {
        _unlocked = true;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Email atau password admin salah.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return const ManageAccountsScreen();

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.admin_panel_settings_rounded, size: 40, color: cs.primary),
                const SizedBox(height: 12),
                const Text(
                  'Area Admin',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kelola akun login orang tua/santri.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailCtrl,
                  enabled: !_loading,
                  decoration: const InputDecoration(
                    labelText: 'Email Admin',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  enabled: !_loading,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
