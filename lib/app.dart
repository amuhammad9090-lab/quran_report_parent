import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'presentation/main_shell.dart';
import 'presentation/screens/admin/admin_pin_gate.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'providers/auth_provider.dart';

/// Root widget. Theme di-reuse 100% dari [AppTheme] (file di-share apa
/// adanya dari app guru) — light & dark mode otomatis ikut sistem, sama
/// seperti app guru.
///
/// Routing sengaja pakai 2 rute independen:
///  - `/` : alur orang tua (login -> MainShell), lewat [_AuthGate].
///  - `/admin` : [AdminPinGate] -> [ManageAccountsScreen]. TIDAK ada
///    link ke sini dari UI orang tua sama sekali — cuma bisa diakses
///    kalau tahu URL-nya langsung (`.../#/admin` dengan default hash
///    routing Flutter Web). Ini yang menggantikan opsi menambah layar
///    ke app guru, sesuai keputusan Anda.
class ParentWebApp extends StatelessWidget {
  const ParentWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran Report — Portal Orang Tua',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const _AuthGate(),
        '/admin': (context) => const AdminPinGate(),
      },
    );
  }
}

/// Gate sederhana: belum login -> [LoginScreen], sudah login ->
/// [MainShell]. Logic penuh (loading/error state visual) menyusul di
/// STEP 4 bersama implementasi [LoginScreen].
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.status == AuthStatus.loggedIn) {
      return const MainShell();
    }
    return const LoginScreen();
  }
}
