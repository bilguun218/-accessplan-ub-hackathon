import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF2EA),
            Color(0xFFFFFBF7),
            Color(0xFFF6F4FF),
            Color(0xFFEAF7FF),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: -126,
            top: 80,
            child: _Wash(size: 260, color: Color(0xFFFFB8A2)),
          ),
          const Positioned(
            right: -96,
            top: -80,
            child: _Wash(size: 220, color: Color(0xFFFFB8C8)),
          ),
          const Positioned(
            right: -150,
            top: 318,
            child: _Wash(size: 330, color: Color(0xFFC7B8FF)),
          ),
          const Positioned(
            left: -108,
            bottom: -88,
            child: _Wash(size: 285, color: Color(0xFFB7DEFF)),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Wash extends StatelessWidget {
  final double size;
  final Color color;

  const _Wash({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}
