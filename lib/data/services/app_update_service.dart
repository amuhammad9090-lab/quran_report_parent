import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/utils/app_config.dart';

/// Data update dari dokumen Firestore:
/// schools/{kSchoolId}/appConfig/parent_android
///
/// Field:
///  - latestVersionCode (int)  : angka setelah "+" di pubspec (build number)
///  - latestVersionName (str)  : mis. "1.2.0"
///  - minVersionCode    (int)  : di bawah ini => update WAJIB (tanpa tombol "Nanti")
///  - apkUrl            (str)  : link langsung ke file .apk
///  - changelog         (str)  : teks singkat "apa yang baru"
class AppUpdateInfo {
  final int latestVersionCode;
  final String latestVersionName;
  final String apkUrl;
  final String changelog;
  final bool forced;

  const AppUpdateInfo({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.apkUrl,
    required this.changelog,
    required this.forced,
  });
}

class AppUpdateService {
  AppUpdateService._();

  static const _docPath = 'appConfig/parent_android';

  /// Return [AppUpdateInfo] kalau ada versi lebih baru, selain itu null.
  /// Sengaja "fail silent": gagal cek update tidak boleh ganggu app.
  static Future<AppUpdateInfo?> check() async {
    // Hanya Android (APK). Web otomatis selalu versi terbaru.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = int.tryParse(pkg.buildNumber) ?? 0;

      final snap = await FirebaseFirestore.instance
          .doc('schools/$kSchoolId/$_docPath')
          .get()
          .timeout(const Duration(seconds: 8));
      final d = snap.data();
      if (d == null) return null;

      final latest = (d['latestVersionCode'] as num?)?.toInt() ?? 0;
      final min = (d['minVersionCode'] as num?)?.toInt() ?? 0;
      final url = (d['apkUrl'] as String?)?.trim() ?? '';
      if (latest <= current || url.isEmpty) return null;

      return AppUpdateInfo(
        latestVersionCode: latest,
        latestVersionName: (d['latestVersionName'] as String?) ?? '',
        apkUrl: url,
        changelog: (d['changelog'] as String?) ?? '',
        forced: current < min,
      );
    } catch (_) {
      return null;
    }
  }
}
