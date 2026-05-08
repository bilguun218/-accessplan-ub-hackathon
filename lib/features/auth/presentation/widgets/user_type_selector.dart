import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

class UserTypeSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  const UserTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.userType,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: errorText != null ? AppColors.error : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: const Text('Сонгох',
                  style: TextStyle(color: AppColors.textMuted)),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textMuted),
              items: AppStrings.userTypeLabels.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(errorText!,
              style: const TextStyle(color: AppColors.error, fontSize: 12)),
        ],
      ],
    );
  }
}
