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
    required this.onTapSegment,
    required this.onDismissFocus,
  });

  final List<RouteSegment> segments;
  final bool isLoading;
  final String? errorMessage;
  final int? focusedIndex;
  final ValueChanged<int> onTapSegment;
  final VoidCallback onDismissFocus;

  static const List<Color> _segmentColors = <Color>[
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
    Color(0xFF65A30D),
  ];

  Color _segmentColorFor(int index) =>
      _segmentColors[index % _segmentColors.length];

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

    final focused = focusedIndex != null &&
            focusedIndex! >= 0 &&
            focusedIndex! < segments.length
        ? segments[focusedIndex!]
        : null;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Маршрут',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (focused != null)
                      IconButton(
                        onPressed: onDismissFocus,
                        tooltip: 'Хаах',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                if (isLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (focused != null) ...[
                  const SizedBox(height: 6),
                  _FocusedTaskCard(
                    segment: focused,
                    color: _segmentColorFor(focused.index),
                  ),
                ] else if (segments.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${segments.length} ажил  ·  ${(totalDistance / 1000).toStringAsFixed(1)} км  ·  ${(totalDuration / 60).round()} мин',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      itemCount: segments.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
                      itemBuilder: (context, index) {
                        final s = segments[index];
                        return InkWell(
                          onTap: () => onTapSegment(index),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _segmentColorFor(index),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.toLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      if (s.toAddress.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            s.toAddress,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${s.distanceKm.toStringAsFixed(1)} км · ${s.durationMinutes} мин',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.center_focus_strong_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
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

class _FocusedTaskCard extends StatelessWidget {
  const _FocusedTaskCard({required this.segment, required this.color});
  final RouteSegment segment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${segment.index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  segment.toLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          if (segment.toAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    segment.toAddress,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (segment.toCategory.isNotEmpty || segment.toTimeText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (segment.toCategory.isNotEmpty)
                  _chip(Icons.category_rounded, segment.toCategory),
                if (segment.toTimeText.isNotEmpty)
                  _chip(Icons.schedule_rounded, segment.toTimeText),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.straighten_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${segment.distanceKm.toStringAsFixed(2)} км',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.schedule_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${segment.durationMinutes} мин',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
