import 'package:flutter/material.dart';
import '../api/api_error.dart';
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
                    )
                  else
                    GestureDetector(
                      onTap: () => _openEditProfile(context, state, l),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: p.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 13, color: p.ink),
                            const SizedBox(width: 5),
                            Text(
                              l.pick('Modifier', 'Edit'),
                              style: BgFonts.body(
                                size: 12,
                                weight: FontWeight.w700,
                                color: p.ink,
                                height: 1,
                              ),
                            ),
                          ],
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

  void _openEditProfile(BuildContext context, AppState state, L l) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: state.palette.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _EditProfileSheet(state: state, l: l),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final AppState state;
  final L l;
  const _EditProfileSheet({required this.state, required this.l});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.state.user?.name ?? '');
    _email = TextEditingController(text: widget.state.user?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = widget.l;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l.pick('Le nom est requis', 'Name is required'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final user = await widget.state.meApi.updateProfile(
        name: name == widget.state.user?.name ? null : name,
        email: email.isEmpty || email == widget.state.user?.email ? null : email,
      );
      widget.state.updateUser(user);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.pick('Profil mis à jour', 'Profile updated')),
        behavior: SnackBarBehavior.floating,
      ));
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.state.palette;
    final l = widget.l;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l.pick('Modifier le profil', 'Edit profile'),
            style: BgFonts.display(
              size: 18,
              weight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 14),
          _Field(
            label: l.pick('Nom', 'Name'),
            controller: _name,
            p: p,
          ),
          const SizedBox(height: 12),
          _Field(
            label: l.pick('Email', 'Email'),
            controller: _email,
            p: p,
            keyboardType: TextInputType.emailAddress,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: BgFonts.body(
                size: 12,
                color: p.orangeDeep,
                weight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _busy ? null : _save,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _busy ? p.orange.withValues(alpha: 0.6) : p.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l.pick('Enregistrer', 'Save'),
                      style: BgFonts.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final BgPalette p;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    required this.p,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: BgFonts.body(
            size: 11,
            weight: FontWeight.w700,
            color: p.inkMuted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: BgFonts.body(size: 14, color: p.ink),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
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
