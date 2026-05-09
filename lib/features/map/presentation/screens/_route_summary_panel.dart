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
    required this.onToggleComplete,
  });

  final List<RouteSegment> segments;
  final bool isLoading;
  final String? errorMessage;
  final int? focusedIndex;
  final ValueChanged<int> onTapSegment;
  final VoidCallback onDismissFocus;
  final ValueChanged<int> onToggleComplete;

  static const Color _green = Color(0xFF16A34A);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _gray = Color(0xFF9CA3AF);

  Color _statusColor(RouteTaskStatus s) {
    switch (s) {
      case RouteTaskStatus.completed:
        return _green;
      case RouteTaskStatus.current:
        return _blue;
      case RouteTaskStatus.pending:
        return _gray;
    }
  }

  String _statusLabel(RouteTaskStatus s) {
    switch (s) {
      case RouteTaskStatus.completed:
        return 'Дууссан';
      case RouteTaskStatus.current:
        return 'Идэвхтэй';
      case RouteTaskStatus.pending:
        return 'Хүлээгдэж буй';
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
    final completedCount =
        segments.where((s) => s.status == RouteTaskStatus.completed).length;

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
                    if (segments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$completedCount/${segments.length}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _green,
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
                    color: _statusColor(focused.status),
                    statusLabel: _statusLabel(focused.status),
                    onToggleComplete: () => onToggleComplete(focused.index),
                  ),
                ] else if (segments.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _summaryChip(
                        Icons.flag_rounded,
                        '${segments.length} ажил',
                      ),
                      _summaryChip(
                        Icons.straighten_rounded,
                        '${(totalDistance / 1000).toStringAsFixed(1)} км',
                      ),
                      _summaryChip(
                        Icons.schedule_rounded,
                        '${((totalDuration + totalDelay) / 60).round()} мин',
                      ),
                      if (totalDelay > 0)
                        _summaryChip(
                          Icons.traffic_rounded,
                          '+${(totalDelay / 60).round()} мин түгжрэл',
                          color: const Color(0xFFD97706),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      itemCount: segments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final s = segments[index];
                        return _TaskRow(
                          segment: s,
                          color: _statusColor(s.status),
                          statusLabel: _statusLabel(s.status),
                          onTap: () => onTapSegment(index),
                          onToggleComplete: () => onToggleComplete(index),
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

  Widget _summaryChip(IconData icon, String text, {Color? color}) {
    final c = color ?? AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: c,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.segment,
    required this.color,
    required this.statusLabel,
    required this.onTap,
    required this.onToggleComplete,
  });

  final RouteSegment segment;
  final Color color;
  final String statusLabel;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = segment.status == RouteTaskStatus.completed;
    final isCurrent = segment.status == RouteTaskStatus.current;

    final bg = isCompleted
        ? color.withValues(alpha: 0.12)
        : isCurrent
            ? color.withValues(alpha: 0.10)
            : Colors.white;
    final borderColor = isCurrent
        ? color
        : isCompleted
            ? color.withValues(alpha: 0.45)
            : Colors.black.withValues(alpha: 0.06);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isCurrent ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : Text(
                        '${segment.taskOrder}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            segment.toLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor:
                                  AppColors.textMuted.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _StatusBadge(label: statusLabel, color: color),
                      ],
                    ),
                    if (segment.toAddress.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          segment.toAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          _metric(
                            Icons.straighten_rounded,
                            '${segment.distanceKm.toStringAsFixed(1)} км',
                          ),
                          _metric(
                            Icons.schedule_rounded,
                            '${segment.durationMinutes} мин',
                          ),
                          if (segment.trafficDelaySeconds > 0)
                            _metric(
                              Icons.traffic_rounded,
                              '+${segment.trafficDelayMinutes} мин',
                              color: const Color(0xFFD97706),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onToggleComplete,
                visualDensity: VisualDensity.compact,
                tooltip:
                    isCompleted ? 'Дуусаагүй болгох' : 'Дууссан гэж тэмдэглэх',
                icon: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isCompleted ? color : AppColors.textMuted,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String text, {Color? color}) {
    final c = color ?? AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: c,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _FocusedTaskCard extends StatelessWidget {
  const _FocusedTaskCard({
    required this.segment,
    required this.color,
    required this.statusLabel,
    required this.onToggleComplete,
  });
  final RouteSegment segment;
  final Color color;
  final String statusLabel;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = segment.status == RouteTaskStatus.completed;
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
                child: isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : Text(
                        '${segment.taskOrder}',
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
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    decoration:
                        isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StatusBadge(label: statusLabel, color: color),
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
              if (segment.trafficDelaySeconds > 0) ...[
                const SizedBox(width: 14),
                const Icon(Icons.traffic_rounded,
                    size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 4),
                Text(
                  '+${segment.trafficDelayMinutes} мин',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onToggleComplete,
              icon: Icon(
                isCompleted
                    ? Icons.refresh_rounded
                    : Icons.check_circle_rounded,
                size: 18,
              ),
              label: Text(
                isCompleted ? 'Дуусаагүй болгох' : 'Дууссан гэж тэмдэглэх',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
