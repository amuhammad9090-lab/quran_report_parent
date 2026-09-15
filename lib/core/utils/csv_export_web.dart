import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Trigger download file CSV lewat browser. Prefix BOM (`\uFEFF`) biar
/// Excel baca sebagai UTF-8 dengan benar (banyak nama santri pakai
/// huruf non-ASCII) — tanpa BOM, Excel sering nge-render karakter aneh.
///
/// Migrasi dari `dart:html` (deprecated) ke `package:web` +
/// `dart:js_interop` — API lama (`dart:html`) sudah ditandai deprecated
/// oleh Dart SDK dan analyzer memperingatkan "avoid_web_libraries_in_flutter"
/// karena tidak seharusnya dipakai di luar plugin Flutter web murni.
/// Perilakunya SAMA PERSIS (bikin Blob CSV, buat object URL sementara,
/// klik elemen `<a download>` secara terprogram, lalu revoke URL-nya) —
/// cuma cara manggil API JS-nya yang beda.
Future<void> downloadCsv(String filename, String csvContent) async {
  final bytes = utf8.encode('\uFEFF$csvContent');
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
