import 'package:flutter/material.dart';

import '../../../widgets/misc_widgets.dart';

class ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const ProfileRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SoftIconBox(icon: icon, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}

