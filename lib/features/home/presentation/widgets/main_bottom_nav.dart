import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      active: Icons.home_rounded,
      label: 'Нүүр',
    ),
    _NavItem(
      icon: Icons.bookmark_border_rounded,
      active: Icons.bookmark_rounded,
      label: 'Хадгалсан',
    ),
    _NavItem(
      icon: Icons.map_outlined,
      active: Icons.map_rounded,
      label: 'Маршрут',
    ),
    _NavItem(
      icon: Icons.emoji_events_outlined,
      active: Icons.emoji_events_rounded,
      label: 'Шагнал',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
      label: 'Профайл',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final barHeight = compact ? 84.0 : 92.0;
    final selectedIconBox = compact ? 46.0 : 52.0;
    final idleIconBox = compact ? 36.0 : 40.0;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(compact ? 12 : 18, 0, compact ? 12 : 18, 12),
      child: Container(
        height: barHeight,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(44),
          border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final selected = i == currentIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: selected ? selectedIconBox : idleIconBox,
                      height: selected ? selectedIconBox : idleIconBox,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        selected ? item.active : item.icon,
                        size: compact ? 25 : 29,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF9AA3B2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        height: 1.05,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: selected
                            ? AppColors.primary
                            : const Color(0xFF9AA3B2),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData active;
  final String label;

  const _NavItem({
    required this.icon,
    required this.active,
    required this.label,
  });
}
