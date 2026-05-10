import 'package:flutter/material.dart';

const double kBusinessTextScale = 0.88;

class BusinessTextScale extends StatelessWidget {
  final Widget child;

  const BusinessTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(kBusinessTextScale)),
      child: child,
    );
  }
}
