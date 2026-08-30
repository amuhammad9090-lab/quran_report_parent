import 'package:flutter/material.dart';

import 'manage_accounts_screen.dart';

/// Gerbang PIN sebelum masuk ke [ManageAccountsScreen]. Rute ini
/// (`/admin`) SENGAJA tidak ada link/tombol apa pun ke sini dari UI
/// orang tua (dashboard/nav) — cuma bisa diakses kalau guru/admin tahu
/// URL-nya langsung, sesuai keputusan Anda supaya app guru tidak perlu
/// disentuh sama sekali untuk fitur kelola akun.
///
/// ⚠️ PIN di bawah ini HARDCODE & PLACEHOLDER — TIDAK aman untuk
/// production. Begitu STEP 10 (backend) benar-benar jalan, ganti dengan
/// mekanisme auth admin yang proper (mis. reuse credential guru/admin
/// yang sudah ada di app guru, lewat backend yang sama).
class AdminPinGate extends StatefulWidget {
  const AdminPinGate({super.key});

  @override
  State<AdminPinGate> createState() => _AdminPinGateState();
}

class _AdminPinGateState extends State<AdminPinGate> {
  static const _placeholderPin = '246810'; // TODO: ganti mekanisme auth admin di STEP 10 backend.

  final _pinCtrl = TextEditingController();
  String? _error;
  bool _unlocked = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pinCtrl.text.trim() == _placeholderPin) {
      setState(() => _unlocked = true);
    } else {
      setState(() => _error = 'PIN salah.');
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
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'PIN Admin',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('Masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
