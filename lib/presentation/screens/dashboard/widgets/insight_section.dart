import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../widgets/misc_widgets.dart';
// ---------------------------------------------------------------------
// Insight Minggu Ini — kalimat pendek dari DashboardProvider.insights.
// ---------------------------------------------------------------------
class InsightSection extends StatelessWidget {
  final List<DashboardInsight> insights;
  const InsightSection({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Insight Minggu Ini'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              children: [
                for (final insight in insights) ...[
                  ListTile(
                    dense: true,
                    leading: SoftIconBox(
                      icon: insight.icon,
                      color: insight.positive
                          ? AppColors.greenOn(context)
                          : AppColors.tahsinOn(context),
                      size: 17,
                    ),
                    title: Text(
                      insight.text,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (insight != insights.last)
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Theme.of(context).dividerTheme.color),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

