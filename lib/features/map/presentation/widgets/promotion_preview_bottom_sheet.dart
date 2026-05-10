import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../organizations/data/models/business_post.dart';
import '../../../organizations/data/models/map_promotion_item.dart';

class PromotionPreviewBottomSheet extends StatelessWidget {
  final MapPromotionItem item;
  final VoidCallback onViewDetails;
  final VoidCallback onAddToRoute;

  const PromotionPreviewBottomSheet({
    super.key,
    required this.item,
    required this.onViewDetails,
    required this.onAddToRoute,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9DEE7),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _typeColor(item.post.type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: _typeColor(item.post.type),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Badge(
                            businessPostTypeLabel(item.post.type),
                            _typeColor(item.post.type),
                          ),
                          if (item.post.isSponsored)
                            const _Badge('Онцлох', Color(0xFFF59E0B)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.businessName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 19,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (item.branchName != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.branchName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.post.title,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 17,
                height: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.post.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.38,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            _InfoLine(icon: Icons.place_outlined, text: item.address),
            if (item.distanceText != null) ...[
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.near_me_outlined,
                text: '${item.distanceText} зайтай',
              ),
            ],
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final details = OutlinedButton(
                  onPressed: onViewDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: const Text('Дэлгэрэнгүй харах'),
                );
                final add = ElevatedButton.icon(
                  onPressed: onAddToRoute,
                  icon: const Icon(Icons.alt_route_rounded, size: 18),
                  label: const Text('Маршрут нэмэх'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );

                if (constraints.maxWidth < 360) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: details),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: add),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 10),
                    Expanded(child: add),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Color _typeColor(BusinessPostType type) {
  switch (type) {
    case BusinessPostType.discount:
      return const Color(0xFFD97706);
    case BusinessPostType.event:
      return const Color(0xFF9333EA);
    case BusinessPostType.announcement:
    case BusinessPostType.serviceUpdate:
      return const Color(0xFF0891B2);
    case BusinessPostType.promotion:
    case BusinessPostType.general:
      return AppColors.primary;
  }
}
