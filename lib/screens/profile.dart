import 'package:flutter/material.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback? onSignIn;

  const ProfileScreen({super.key, this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);
    final user = state.user;

    return Container(
      color: p.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 6),
            child: Text(
              l.tabProfile,
              style: BgFonts.display(
                size: 26,
                weight: FontWeight.w700,
                color: p.ink,
                letterSpacing: -0.6,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: p.orangeSoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initial(user?.name),
                      style: BgFonts.display(
                        size: 18,
                        weight: FontWeight.w700,
                        color: p.orangeDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? l.pick('Invité', 'Guest'),
                          style: BgFonts.display(
                            size: 16,
                            weight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? user?.phone ??
                              l.pick(
                                  'Aucun compte connecté', 'No account connected'),
                          style: BgFonts.body(size: 12, color: p.inkMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!state.isSignedIn)
                    GestureDetector(
                      onTap: onSignIn,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: p.orange,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l.pick('Se connecter', 'Sign in'),
                          style: BgFonts.body(
                            size: 12,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader(text: l.pick('Préférences', 'Preferences'), p: p),
          _SettingsCard(
            p: p,
            children: [
              _SettingsRow(
                icon: Icons.translate,
                label: l.pick('Langue', 'Language'),
                trailing: _LanguageToggle(state: state),
                p: p,
              ),
              _SettingsRow(
                icon: Icons.dark_mode_outlined,
                label: l.pick('Mode sombre', 'Dark mode'),
                trailing: Switch(
                  value: state.dark,
                  activeThumbColor: p.orange,
                  onChanged: (v) => state.setDark(v),
                ),
                p: p,
              ),
            ],
          ),
          if (state.isSignedIn) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () async {
                  await state.signOut();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l.pick('Se déconnecter', 'Sign out'),
                    style: BgFonts.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: p.orangeDeep,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _initial(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name.trim().substring(0, 1).toUpperCase();
  }
}

class _LanguageToggle extends StatelessWidget {
  final AppState state;
  const _LanguageToggle({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = state.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final lang in BgLang.values) ...[
          GestureDetector(
            onTap: () => state.setLang(lang),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: state.lang == lang ? p.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                lang == BgLang.fr ? 'FR' : 'EN',
                style: BgFonts.body(
                  size: 12,
                  weight: FontWeight.w700,
                  color: state.lang == lang ? p.bg : p.ink,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final BgPalette p;
  const _SectionHeader({required this.text, required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      child: Text(
        text.toUpperCase(),
        style: BgFonts.body(
          size: 11,
          weight: FontWeight.w700,
          color: p.inkMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final BgPalette p;
  final List<Widget> children;
  const _SettingsCard({required this.p, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.cardBorder),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final BgPalette p;
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: p.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: p.orangeDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: BgFonts.body(size: 14, color: p.ink),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
