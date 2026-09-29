import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../../core/utils/web_update.dart';
import '../../data/services/app_update_service.dart';

/// Panggil sekali setelah login (mis. di initState MainShell):
///   WidgetsBinding.instance.addPostFrameCallback(
///     (_) => checkForAppUpdate(context));
/// Nomor build web yang sedang jalan, di-set saat build:
///   flutter build web --release --dart-define=APP_BUILD=2
/// (samakan dengan angka setelah "+" di pubspec). Kalau tidak di-set (0),
/// cek update web dilewati.
const int kRunningWebBuild = int.fromEnvironment('APP_BUILD', defaultValue: 0);

Future<void> _checkWebUpdate(BuildContext context) async {
  if (kRunningWebBuild <= 0) return;
  final latest = await fetchLatestWebBuild();
  if (latest == null || latest <= kRunningWebBuild || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Versi baru tersedia'),
      content: const Text(
          'Ada pembaruan aplikasi. Muat ulang sekarang untuk memakai versi terbaru?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Nanti'),
        ),
        FilledButton(
          onPressed: () => reloadToLatest(),
          child: const Text('Muat ulang'),
        ),
      ],
    ),
  );
}

Future<void> checkForAppUpdate(BuildContext context) async {
  if (kIsWeb) return _checkWebUpdate(context);
  final info = await AppUpdateService.check();
  if (info == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: !info.forced,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  double _progress = 0;
  String? _error;
  StreamSubscription<OtaEvent>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });

    _sub = OtaUpdate()
        .execute(
          widget.info.apkUrl,
          destinationFilename: 'quran_report_parent.apk',
        )
        .listen(
      (event) {
        if (!mounted) return;
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            setState(() => _progress =
                (double.tryParse(event.value ?? '0') ?? 0) / 100);
          case OtaStatus.INSTALLING:
            // Android menampilkan layar install sendiri.
            setState(() => _progress = 1);
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            _fail('Izin "Install aplikasi tidak dikenal" belum diberikan.');
          default:
            _fail('Gagal mengunduh update. Cek koneksi lalu coba lagi.');
        }
      },
      onError: (_) => _fail('Gagal mengunduh update. Coba lagi.'),
    );
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final title = info.latestVersionName.isEmpty
        ? 'Update tersedia'
        : 'Update ${info.latestVersionName} tersedia';

    return PopScope(
      canPop: !info.forced && !_busy,
      child: AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.forced
                ? 'Versi ini sudah tidak didukung. Silakan update untuk melanjutkan.'
                : 'Versi baru aplikasi sudah tersedia. Mau update sekarang?'),
            if (info.changelog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(info.changelog),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 6),
              Text(_progress >= 1
                  ? 'Membuka installer…'
                  : 'Mengunduh… ${(_progress * 100).toInt()}%'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          if (!info.forced && !_busy)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nanti'),
            ),
          FilledButton(
            onPressed: _busy ? null : _start,
            child: Text(_error != null ? 'Coba lagi' : 'Update sekarang'),
          ),
        ],
      ),
    );
  }
}
