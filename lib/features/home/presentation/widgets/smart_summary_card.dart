import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SmartSummaryCard extends StatelessWidget {
  final int taskCount;
  final int minutesSaved;
  final int routeCount;
  final VoidCallback? onAddTask;

  const SmartSummaryCard({
    super.key,
    this.taskCount = 0,
    this.minutesSaved = 0,
    this.routeCount = 0,
    this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: SizedBox(
                width: 150,
                child: CustomPaint(painter: _SkylinePainter()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Өнөөдрийн төлөвлөгөө',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(
                  width: 210,
                  child: Text(
                    'Ажлаа оруулаад онлайнаар шийдэх боломж болон зайлшгүй очих маршрутаа тооцоолоорой.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                        icon: Icons.checklist,
                        text: '$taskCount ажил'),
                    _Pill(
                        icon: Icons.access_time,
                        text: '$minutesSaved мин хэмнэлт'),
                    _Pill(
                        icon: Icons.alt_route,
                        text: '$routeCount маршрут'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: onAddTask,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text(
                      'Ажил нэмэх',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final base = size.height * 0.85;
    final buildings = <Rect>[
      Rect.fromLTWH(8, base - 70, 18, 70),
      Rect.fromLTWH(30, base - 95, 22, 95),
      Rect.fromLTWH(56, base - 60, 16, 60),
      Rect.fromLTWH(74, base - 110, 26, 110),
      Rect.fromLTWH(102, base - 75, 18, 75),
      Rect.fromLTWH(122, base - 50, 14, 50),
    ];
    for (final r in buildings) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(2)),
        paint,
      );
    }

    // tree-ish dot for greenery
    final tree = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(20, base - 4), 6, tree);
    canvas.drawCircle(Offset(54, base - 4), 5, tree);
    canvas.drawCircle(Offset(98, base - 4), 6, tree);

    // ground line
    final ground = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, base), Offset(size.width, base), ground);
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) => false;
}
