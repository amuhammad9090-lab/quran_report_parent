import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi tampilan orang tua: Terang / Gelap / Ikuti Sistem.
///
/// Sebelumnya `themeMode` di [ParentWebApp] hardcode ke
/// `ThemeMode.system` — otomatis ikut pengaturan perangkat tapi orang
/// tua tidak bisa memilih sendiri. Provider ini menambah pilihan manual
/// (switcher di tab Profil, lihat `profile_screen.dart`) dan
/// menyimpannya lokal lewat [SharedPreferences] supaya pilihan tetap
/// sama tiap kali app dibuka lagi. Default tetap [ThemeMode.system] —
/// perilaku lama tidak berubah untuk orang tua yang belum pernah
/// memilih apa pun.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'parent_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeProvider() {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (prefs.getString(_prefsKey)) {
        case 'light':
          _mode = ThemeMode.light;
        case 'dark':
          _mode = ThemeMode.dark;
        default:
          _mode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {
      // Storage lokal tidak tersedia (jarang, mis. mode privat browser) —
      // diamkan, tetap pakai default ThemeMode.system.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (_) {
      // Gagal menyimpan — tidak fatal, pilihan tetap berlaku sampai
      // sesi/tab ini ditutup, hanya tidak diingat sesi berikutnya.
    }
  }
}
