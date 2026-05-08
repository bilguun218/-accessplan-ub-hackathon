import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class PlanningStatusItem {
  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String description;

  const PlanningStatusItem({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.description,
  });
}

class PlanningStatusCard extends StatelessWidget {
  final List<PlanningStatusItem> items;

  const PlanningStatusCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _Row(item: items[i]),
            if (i != items.length - 1)
              const Divider(
                height: 1,
                color: AppColors.border,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final PlanningStatusItem item;
  const _Row({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: item.accent,
            ),
          ),
        ],
      ),
    );
  }
}
