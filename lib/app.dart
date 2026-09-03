import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'presentation/main_shell.dart';
import 'presentation/screens/admin/admin_login_gate.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';

/// Root widget. Theme di-reuse 100% dari [AppTheme] (file di-share apa
/// adanya dari app guru) — light & dark mode tersedia, dan orang tua
/// bisa memilih sendiri lewat [ThemeProvider] (default: ikut sistem,
/// sama seperti sebelumnya, lihat switcher di tab Profil).
///
/// Routing sengaja pakai 2 rute independen:
///  - `/` : alur orang tua (login -> MainShell), lewat [_AuthGate].
///  - `/admin` : [AdminLoginGate] -> [ManageAccountsScreen]. TIDAK ada
///    link ke sini dari UI orang tua sama sekali — cuma bisa diakses
///    kalau tahu URL-nya langsung (`.../#/admin` dengan default hash
///    routing Flutter Web). Ini yang menggantikan opsi menambah layar
///    ke app guru, sesuai keputusan Anda.
class ParentWebApp extends StatelessWidget {
  const ParentWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    return MaterialApp(
      title: 'Quran Report — Portal Orang Tua',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const _AuthGate(),
        '/admin': (context) => const AdminLoginGate(),
      },
    );
  }
}

/// Gate sesi: [AuthProvider.restoreSession] dipanggil SEKALI di awal
/// (initState) buat cek apakah ada sesi Firebase Auth yang masih
/// tersimpan di browser — supaya refresh/pull-to-refresh TIDAK
/// nge-lempar balik ke [LoginScreen] selama orang tua belum logout
/// manual. Selagi status masih unknown/loading, tampilkan spinner
/// (bukan langsung nembak ke LoginScreen) biar nggak ada "kedip" ke
/// login sebelum sesi selesai dicek.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AuthProvider>().restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.status == AuthStatus.loggedIn) {
      return const MainShell();
    }
    if (auth.status == AuthStatus.unknown || auth.status == AuthStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const LoginScreen();
  }
}
