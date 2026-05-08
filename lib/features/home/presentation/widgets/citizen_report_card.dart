import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class CitizenReportCard extends StatelessWidget {
  final VoidCallback? onReport;

  const CitizenReportCard({super.key, this.onReport});

  static const _badges = <_BadgeData>[
    _BadgeData(icon: Icons.warning_amber_rounded, text: 'Эвдэрсэн зам'),
    _BadgeData(icon: Icons.ac_unit, text: 'Цас, мөс'),
    _BadgeData(icon: Icons.lightbulb_outline, text: 'Гэрэлтүүлэг'),
    _BadgeData(icon: Icons.directions_bus_filled, text: 'Автобусны буудал'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Хотын асуудал мэдээлэх',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Эвдэрсэн зам, халтиргаа, гэрэлтүүлэг, хаалттай налуу зам зэрэг асуудлыг зурагтай мэдээлэх боломжтой.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                child: const Text('Асуудал мэдээлэх'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _badges
                .map((b) => _Chip(icon: b.icon, text: b.text))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _BadgeData {
  final IconData icon;
  final String text;
  const _BadgeData({required this.icon, required this.text});
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
