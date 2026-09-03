import 'package:flutter/services.dart';

/// Fallback non-web: platform ini nggak bisa trigger download file
/// langsung dari browser, jadi disalin ke clipboard aja.
Future<void> downloadCsv(String filename, String csvContent) async {
  await Clipboard.setData(ClipboardData(text: csvContent));
}
