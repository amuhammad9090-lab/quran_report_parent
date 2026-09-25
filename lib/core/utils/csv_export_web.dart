import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

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
