
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final newPw = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || newPw.isEmpty) {
      setState(() => _error = 'Semua kolom wajib diisi.');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _error = 'Password baru minimal 6 karakter.');
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = 'Konfirmasi password baru tidak cocok.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await context.read<AuthProvider>().changePassword(
          currentPassword: current,
          newPassword: newPw,
        );

    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Ganti Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: 'Password Lama',
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscureNew,
              enabled: !_submitting,
              decoration: const InputDecoration(labelText: 'Konfirmasi Password Baru'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

