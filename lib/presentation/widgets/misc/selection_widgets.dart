import 'dart:async';

import 'package:flutter/material.dart';

class SelectionAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final bool filled;

  const SelectionAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.filled = false,
  });
}

class _SelectionActionButton extends StatelessWidget {
  final SelectionAction action;
  const _SelectionActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = action.destructive ? cs.error : cs.primary;
    if (action.filled) {
      return FilledButton.icon(
        onPressed: action.onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(action.icon, size: 17),
        label: Text(action.label, overflow: TextOverflow.ellipsis, maxLines: 1),
      );
    }
    return OutlinedButton.icon(
      onPressed: action.onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.4),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(action.icon, size: 17),
      label: Text(action.label, overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }
}

/// Bar aksi mode pilih-banyak (centang) — dipakai di halaman Laporan &
/// Folder.
class SelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final ValueChanged<bool> onSelectAllChanged;
  final VoidCallback onCancel;
  final List<SelectionAction> actions;

  const SelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAllChanged,
    required this.onCancel,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allSelected = totalCount > 0 && selectedCount == totalCount;

    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.18),
      color: Theme.of(context).cardTheme.color ?? cs.surface,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Checkbox(
                  value: allSelected,
                  onChanged: totalCount == 0 ? null : (v) => onSelectAllChanged(v ?? false),
                ),
                Expanded(
                  child: Text(
                    selectedCount == 0 ? 'Pilih Semua' : '$selectedCount dipilih',
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Batal',
                  visualDensity: VisualDensity.compact,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 2),
                child: Row(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _SelectionActionButton(action: actions[i])),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Snackbar seragam (ikon + pesan, rounded) dipakai di seluruh app — ganti
/// [SnackBar] polos bawaan.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackbar(
    BuildContext context,
    String message, {
      IconData icon = Icons.check_circle_rounded,
      ValueChanged<bool>? onFabVisibilityChanged,
    }) {
  final cs = Theme.of(context).colorScheme;
  onFabVisibilityChanged?.call(false);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: cs.primary),
          const SizedBox(width: 10),
          Flexible(child: Text(message)),
        ],
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ),
  );
  controller.closed.then((_) => onFabVisibilityChanged?.call(true));
  return controller;
}

/// Mixin buat nampilin pesan singkat (pengganti SnackBar) sebagai BAGIAN
/// dari Column konten sheet sendiri, bukan lewat ScaffoldMessenger —
/// dipakai di bottom sheet yang gak punya Scaffold sendiri (mis. export
/// sheet).
mixin InlineMessageMixin<T extends StatefulWidget> on State<T> {
  String? inlineMessage;
  Timer? _inlineMessageTimer;

  void showInlineMessage(String message) {
    _inlineMessageTimer?.cancel();
    setState(() => inlineMessage = message);
    _inlineMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => inlineMessage = null);
    });
  }

  @override
  void dispose() {
    _inlineMessageTimer?.cancel();
    super.dispose();
  }
}

/// Banner pesan singkat inline — lihat [InlineMessageMixin].
class InlineMessageBanner extends StatelessWidget {
  final String message;
  const InlineMessageBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: cs.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(message, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

/// Logo SMPIT Al Madinah — ukurannya SELALU persegi (1:1) di semua
/// tempat biar konsisten.
