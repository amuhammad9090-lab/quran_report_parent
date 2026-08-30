import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/responsive.dart';
import '../data/repositories/report_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/hafalan/hafalan_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/profile/profile_screen.dart';

/// Shell navigasi utama portal orang tua — 4 tab sesuai brief
/// (Dashboard, Hafalan, Riwayat, Profil). Sengaja TIDAK membawa seluruh
/// navigation app guru (Laporan, Folder, Statistik, Export, dst) — portal
/// ini harus terasa ringan, cuma yang relevan buat orang tua.
///
/// `NavigationBar` di sini nanti otomatis ambil style dari `AppTheme`
/// (height 72, indicator radius 16, dll — sudah didefinisikan di
/// navigationBarTheme yang di-share dari app guru) begitu STEP 4+ jalan.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    // MainShell hanya pernah ditampilkan setelah AuthProvider.status ==
    // loggedIn (lihat _AuthGate di app.dart), jadi currentStudent selalu
    // sudah terisi di sini — DashboardProvider dibuat SATU KALI untuk
    // seluruh sesi (bukan per-tab), supaya data tidak di-fetch ulang
    // tiap pindah tab Dashboard/Hafalan/Riwayat.
    final student = context.read<AuthProvider>().currentStudent!;
    return ChangeNotifierProvider(
      create: (ctx) => DashboardProvider(
        reportRepository: ctx.read<ReportRepository>(),
      )..load(student),
      child: const _MainShellBody(),
    );
  }
}

class _MainShellBody extends StatefulWidget {
  const _MainShellBody();

  @override
  State<_MainShellBody> createState() => _MainShellBodyState();
}

class _MainShellBodyState extends State<_MainShellBody> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    HafalanScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  static const _destinations = [
    (icon: Icons.home_rounded, label: 'Dashboard'),
    (icon: Icons.auto_stories_rounded, label: 'Hafalan'),
    (icon: Icons.history_rounded, label: 'Riwayat'),
    (icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kDesktopBreakpoint;

        // Body dibungkus ResponsiveContentWidth supaya di layar lebar
        // (desktop/tablet) konten tetap nyaman dibaca, tidak melebar
        // penuh sampai tepi layar. Tiap screen (Dashboard/Hafalan/dst)
        // sudah bawa Scaffold sendiri (perlu AppBar per layar), jadi
        // dibungkus di sini lewat Builder supaya AppBar tetap full-width
        // tapi body-nya yang dibatasi.
        final content = _screens[_index];

        if (!isWide) {
          return Scaffold(
            body: content,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
          );
        }

        // Layar lebar: NavigationRail di kiri (menggantikan bottom nav),
        // sama komponennya cuma orientasi beda — bukan navigasi baru.
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}
