import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Login untuk PORTAL ORANG TUA. Struktur & style sengaja meniru persis
/// `login_screen.dart` app guru (icon mark + divider + logo, judul,
/// field username/password dengan `fieldDecoration()`, tombol Masuk) —
/// beda hanya di teks (konteks orang tua, bukan guru) dan sumber data
/// login (`AuthProvider` di sini pakai [SantriAccount], bukan
/// `UserAccount`).
///
/// Responsive: form dibungkus [ConstrainedBox] max-width 420 supaya di
/// desktop/tablet tidak melebar penuh layar (bukan cuma layout mobile
/// yang diperkecil) — di mobile otomatis pas karena layar sudah sempit.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    // Tidak perlu Navigator push manual — _AuthGate di app.dart otomatis
    // pindah ke MainShell begitu auth.status jadi loggedIn, jadi
    // login_screen cukup fokus pada form + feedback.
    await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const AppIconMark(size: 68, borderRadius: 18),
                          const SizedBox(width: 14),
                          Container(
                              height: 40, width: 1, color: cs.outlineVariant),
                          const SizedBox(width: 14),
                          const SmpitLogoBadge(size: 64, borderRadius: 14),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Portal Orang Tua',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Pantau perkembangan hafalan dan capaian Al-Qur'an ananda.",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _usernameCtrl,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      decoration: fieldDecoration(
                        context,
                        icon: Icons.person_outline_rounded,
                        label: 'Username',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      enabled: !isLoading,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: fieldDecoration(
                        context,
                        icon: Icons.lock_outline_rounded,
                        label: 'Kata Sandi',
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                          onPressed: isLoading
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    if (auth.status == AuthStatus.error) ...[
                      const SizedBox(height: 14),
                      InlineMessageBanner(
                        message: auth.errorMessage ?? 'Login gagal.',
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Masuk'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gunakan username & kata sandi yang diberikan oleh guru pembimbing. Akun ini hanya bisa melihat, tidak bisa mengubah data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11.5,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
