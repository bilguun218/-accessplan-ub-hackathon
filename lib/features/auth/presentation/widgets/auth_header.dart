import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

class AuthHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final bool compact;

  const AuthHeader({super.key, this.title, this.subtitle, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.lightGreenBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.eco, color: AppColors.primary, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          title ?? AppStrings.appName,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(
            subtitle ?? AppStrings.appSubtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
