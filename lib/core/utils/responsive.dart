import 'package:flutter/material.dart';

/// Membungkus konten layar supaya tidak melebar penuh di layar lebar
/// (desktop/tablet landscape) — brief eksplisit minta "jangan hanya
/// membuat layout desktop yang diperkecil di mobile", jadi sebaliknya
/// juga berlaku: jangan biarkan layout mobile melebar mentah-mentah di
/// desktop. Di layar sempit (mobile), [maxWidth] otomatis tidak
/// berpengaruh karena layar sudah lebih sempit dari itu.
class ResponsiveContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContentWidth({super.key, required this.child, this.maxWidth = 900});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Breakpoint sederhana dipakai konsisten di seluruh portal — di bawah
/// ini dianggap "mobile/tablet sempit" (bottom navigation), di atas ini
/// "desktop/tablet lebar" (rail navigation di sisi kiri).
const double kDesktopBreakpoint = 800;
