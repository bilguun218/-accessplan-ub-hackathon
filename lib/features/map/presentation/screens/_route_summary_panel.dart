import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/route_segment.dart';

class RouteSummaryPanel extends StatelessWidget {
  const RouteSummaryPanel({
    super.key,
    required this.segments,
    required this.isLoading,
    required this.errorMessage,
    required this.focusedIndex,
    required this.savedTaskIds,
    required this.onTapSegment,
    required this.onSaveSegment,
    required this.onDismissFocus,
    required this.onToggleComplete,
  });

  final List<RouteSegment> segments;
  final bool isLoading;
  final String? errorMessage;
  final int? focusedIndex;
  final Set<String> savedTaskIds;
  final ValueChanged<int> onTapSegment;
  final ValueChanged<RouteSegment> onSaveSegment;
  final VoidCallback onDismissFocus;
  final ValueChanged<int> onToggleComplete;

  static const Color _green = Color(0xFF16A34A);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _gray = Color(0xFF94A3B8);
  static const Color _orange = Color(0xFFF59E0B);

  Color _statusColor(RouteTaskStatus s) {
    switch (s) {
      case RouteTaskStatus.completed:
        return _green;
      case RouteTaskStatus.current:
        return _orange;
      case RouteTaskStatus.pending:
        return _gray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDistance = segments.fold<int>(
      0,
      (sum, s) => sum + s.distanceMeters,
    );
    final totalDuration = segments.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final totalDelay = segments.fold<int>(
      0,
      (sum, s) => sum + s.trafficDelaySeconds,
    );
    final completed = segments
        .where((s) => s.status == RouteTaskStatus.completed)
        .toList();
    final activeSegments = segments
        .where((s) => s.status != RouteTaskStatus.completed)
        .toList();
    final visibleSegments =
        focusedIndex != null &&
            focusedIndex! >= 0 &&
            focusedIndex! < segments.length
        ? <RouteSegment>[segments[focusedIndex!]]
        : activeSegments;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DEE7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Өнөөдрийн маршрут',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${segments.length} ажил · ${((totalDuration + totalDelay) / 60).round()} мин · ${(totalDistance / 1000).toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: focusedIndex == null ? null : onDismissFocus,
                      icon: Icon(
                        focusedIndex == null
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.close_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 30,
                      ),
                    ),
                  ],
                ),
                if (isLoading) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const LinearProgressIndicator(
                      minHeight: 5,
                      color: _blue,
                      backgroundColor: Color(0xFFEFF6FF),
                    ),
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (completed.isNotEmpty && focusedIndex == null) ...[
                  const SizedBox(height: 18),
                  _CompletedStrip(segment: completed.first),
                ],
                if (visibleSegments.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      itemCount: visibleSegments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final segment = visibleSegments[index];
                        return _RouteTaskCard(
                          segment: segment,
                          color: _statusColor(segment.status),
                          saved: savedTaskIds.contains(segment.taskId),
                          onTap: () => onTapSegment(segment.index),
                          onSave: () => onSaveSegment(segment),
                          onToggleComplete: () =>
                              onToggleComplete(segment.index),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedStrip extends StatelessWidget {
  final RouteSegment segment;

  const _CompletedStrip({required this.segment});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF5BD98D),
            size: 25,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              segment.toLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9AA3B2),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Text(
            'Дууссан',
            style: TextStyle(
              color: Color(0xFFB8C0CC),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteTaskCard extends StatelessWidget {
  final RouteSegment segment;
  final Color color;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onToggleComplete;

  const _RouteTaskCard({
    required this.segment,
    required this.color,
    required this.saved,
    required this.onTap,
    required this.onSave,
    required this.onToggleComplete,
  });

  IconData _categoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('баримт') || lower.contains('document')) {
      return Icons.description_outlined;
    }
    if (lower.contains('хүнс') || lower.contains('shop')) {
      return Icons.shopping_cart_outlined;
    }
    if (lower.contains('эм') || lower.contains('pharmacy')) {
      return Icons.medication_outlined;
    }
    return Icons.place_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final title = segment.toLabel;
    final address = segment.toAddress.isNotEmpty
        ? segment.toAddress
        : segment.toCategory;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  '${segment.taskOrder}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                _categoryIcon(segment.toCategory),
                color: AppColors.textDark.withValues(alpha: 0.72),
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onSave,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: saved
                                ? AppColors.primary
                                : const Color(0xFFD1D7E1),
                            size: 25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 230;
                      final metric = Text(
                        '${segment.distanceKm.toStringAsFixed(1)} км · ${segment.durationMinutes} мин',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9AA3B2),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                      final action = SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: onToggleComplete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textDark,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: Text(
                            segment.status == RouteTaskStatus.completed
                                ? 'Буцаах'
                                : 'Дуусгах',
                          ),
                        ),
                      );

                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            metric,
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: action,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: metric),
                          const SizedBox(width: 8),
                          action,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
