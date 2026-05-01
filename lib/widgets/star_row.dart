import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

class StarRow extends StatelessWidget {
  final double value;
  final double size;

  const StarRow({super.key, required this.value, this.size = 13});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size + 2, color: p.orange),
        const SizedBox(width: 3),
        Text(
          value.toStringAsFixed(1),
          style: BgFonts.display(
            size: size,
            weight: FontWeight.w700,
            color: p.ink,
            letterSpacing: -0.1,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class StarsRow extends StatelessWidget {
  final int filled;
  final double size;
  final int total;

  const StarsRow({super.key, required this.filled, this.size = 12, this.total = 5});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        return Padding(
          padding: const EdgeInsets.only(right: 1),
          child: Icon(
            i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: p.orange,
          ),
        );
      }),
    );
  }
}
