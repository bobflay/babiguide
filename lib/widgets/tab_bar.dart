import 'package:flutter/material.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';

enum TabKey { home, discover, add, saved, profile }

class BgTabBar extends StatelessWidget {
  final TabKey active;
  final ValueChanged<TabKey>? onTap;

  const BgTabBar({super.key, this.active = TabKey.home, this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);

    final items = [
      _TabItem(TabKey.home, l.tabHome, Icons.home_rounded, Icons.home_outlined),
      _TabItem(TabKey.discover, l.tabDiscover, Icons.explore, Icons.explore_outlined),
      _TabItem(TabKey.add, '', Icons.add_rounded, Icons.add_rounded, primary: true),
      _TabItem(TabKey.saved, l.tabSaved, Icons.bookmark_rounded, Icons.bookmark_outline),
      _TabItem(TabKey.profile, l.tabProfile, Icons.person_rounded, Icons.person_outline),
    ];

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          padding: const EdgeInsets.only(top: 10, bottom: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.bg.withValues(alpha: 0), p.bg.withValues(alpha: 0.9), p.bg],
              stops: const [0.0, 0.3, 1.0],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((it) {
              if (it.primary) {
                return GestureDetector(
                  onTap: () => onTap?.call(it.key),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: p.orange,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: p.orange.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                  ),
                );
              }
              final isActive = it.key == active;
              return GestureDetector(
                onTap: () => onTap?.call(it.key),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? it.iconActive : it.icon,
                      size: 22,
                      color: isActive ? p.ink : p.inkMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      it.label,
                      style: BgFonts.body(
                        size: 10,
                        weight: FontWeight.w600,
                        color: isActive ? p.ink : p.inkMuted,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final TabKey key;
  final String label;
  final IconData iconActive;
  final IconData icon;
  final bool primary;
  _TabItem(this.key, this.label, this.iconActive, this.icon, {this.primary = false});
}
