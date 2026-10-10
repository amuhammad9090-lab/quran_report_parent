import 'package:flutter/material.dart';

// ---------------------------------------------------------------------
// Micro-interaction: fade + slide-up ringan, staggered per section, agar
// Beranda terasa "hidup" tanpa dependency animasi tambahan.
// ---------------------------------------------------------------------
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  const StaggeredEntrance({super.key, required this.child, this.index = 0});

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.035),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Skeleton loading — dipakai selama DashboardProvider.isLoading, ganti
// full-screen spinner supaya bentuk layar akhir sudah kebayang dari awal.
// ---------------------------------------------------------------------
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      children: const [
        _PulsingBox(
            height: 168, borderRadius: BorderRadius.all(Radius.circular(24))),
        SizedBox(height: 22),
        _PulsingBox(height: 18, width: 140),
        SizedBox(height: 10),
        _PulsingBox(
            height: 150, borderRadius: BorderRadius.all(Radius.circular(20))),
        SizedBox(height: 22),
        _PulsingBox(height: 18, width: 160),
        SizedBox(height: 10),
        _PulsingBox(
            height: 88, borderRadius: BorderRadius.all(Radius.circular(20))),
        SizedBox(height: 22),
        _PulsingBox(height: 18, width: 150),
        SizedBox(height: 10),
        _PulsingBox(
            height: 120, borderRadius: BorderRadius.all(Radius.circular(20))),
      ],
    );
  }
}

class _PulsingBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  const _PulsingBox({
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  State<_PulsingBox> createState() => _PulsingBoxState();
}

class _PulsingBoxState extends State<_PulsingBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.045 + 0.035 * t),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Hero — sapaan + identitas + capaian pekan ini (sama seperti sebelumnya,
// cuma sekarang jadi bagian dari alur staggered entrance).
// ---------------------------------------------------------------------
