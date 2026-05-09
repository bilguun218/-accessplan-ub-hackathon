import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF4FF), Color(0xFFE6F1FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(34, 40, 34, 38),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Container(
                  width: 146,
                  height: 146,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD5E6FF)),
                  ),
                  child: CustomPaint(painter: _SplashRoutePainter()),
                ),
                const SizedBox(height: 48),
                const Text(
                  'AccessPlan UB',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 39,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 34),
                const Text(
                  'Өдөр тутмын ажлаа ухаалгаар төлөвлөж,\nшаардлагагүй зорчилтыг багасгана.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 5),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    child: const Text('Эхлэх'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: OutlinedButton(
                    onPressed: () => context.go('/login'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    child: const Text('Нэвтрэх'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.32)
      ..cubicTo(
        size.width * 0.60,
        size.height * 0.30,
        size.width * 0.74,
        size.height * 0.36,
        size.width * 0.66,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.58,
        size.height * 0.60,
        size.width * 0.33,
        size.height * 0.58,
        size.width * 0.44,
        size.height * 0.70,
      )
      ..cubicTo(
        size.width * 0.52,
        size.height * 0.78,
        size.width * 0.70,
        size.height * 0.75,
        size.width * 0.78,
        size.height * 0.75,
      );

    canvas.drawPath(path, blue);
    canvas.drawCircle(
      Offset(size.width * 0.28, size.height * 0.32),
      24,
      Paint()..color = const Color(0xFF1F7AF7),
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.75),
      24,
      Paint()..color = const Color(0xFF12D174),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
