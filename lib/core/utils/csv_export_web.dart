import 'dart:convert';
import 'dart:html' as html;

/// Trigger download file CSV lewat browser. Prefix BOM (`\uFEFF`) biar
/// Excel baca sebagai UTF-8 dengan benar (banyak nama santri pakai
/// huruf non-ASCII) — tanpa BOM, Excel sering nge-render karakter aneh.
Future<void> downloadCsv(String filename, String csvContent) async {
  final bytes = utf8.encode('\uFEFF$csvContent');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
