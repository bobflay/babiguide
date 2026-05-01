import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

class BgChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool inkSelected;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const BgChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.inkSelected = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final bg = selected
        ? (inkSelected ? p.ink : p.orange)
        : p.card;
    final fg = selected
        ? (inkSelected ? p.bg : Colors.white)
        : p.ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: p.cardBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: BgFonts.body(
                size: 13,
                weight: FontWeight.w600,
                color: fg,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
