import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../organizations/data/models/business_post.dart';

class BusinessMarkerFactory {
  static Future<BitmapDescriptor> createGiftMarker({
    required BusinessPostType type,
    bool isSponsored = false,
  }) async {
    const size = 112.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);
    const radius = 42.0;
    final accent = _colorFor(type);

    canvas.drawCircle(
      Offset(center.dx, center.dy + 5),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(center, radius + 4, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius, Paint()..color = accent);
    canvas.drawCircle(
      center,
      radius - 7,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final giftPaint = Paint()..color = Colors.white;
    final ribbonPaint = Paint()..color = Colors.white.withValues(alpha: 0.88);
    final box = RRect.fromRectAndRadius(
      const Rect.fromLTWH(35, 50, 42, 28),
      const Radius.circular(6),
    );
    final lid = RRect.fromRectAndRadius(
      const Rect.fromLTWH(32, 42, 48, 12),
      const Radius.circular(5),
    );
    canvas.drawRRect(box, giftPaint);
    canvas.drawRRect(lid, giftPaint);
    canvas.drawRect(
      const Rect.fromLTWH(52, 42, 8, 36),
      Paint()..color = accent,
    );
    canvas.drawRect(
      const Rect.fromLTWH(35, 55, 42, 5),
      Paint()..color = accent,
    );
    canvas.drawOval(
      const Rect.fromLTWH(39, 29, 18, 16),
      ribbonPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawOval(const Rect.fromLTWH(55, 29, 18, 16), ribbonPaint);

    if (isSponsored) {
      canvas.drawCircle(
        const Offset(82, 30),
        17,
        Paint()..color = const Color(0xFFF59E0B),
      );
      canvas.drawCircle(
        const Offset(82, 30),
        17,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _drawStar(
        canvas,
        const Offset(82, 30),
        8.5,
        Paint()..color = Colors.white,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 48);
  }

  static Color _colorFor(BusinessPostType type) {
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
        return const Color(0xFF2563EB);
    }
  }

  static void _drawStar(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -1.5708 + i * 0.6283;
      final r = i.isEven ? radius : radius * 0.44;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
