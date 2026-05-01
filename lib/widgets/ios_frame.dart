import 'package:flutter/material.dart';
import '../app_state.dart';

class AppFrame extends StatelessWidget {
  final Widget child;
  const AppFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Container(color: p.bg, child: child);
  }
}
