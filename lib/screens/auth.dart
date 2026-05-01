import 'package:flutter/material.dart';
import '../api/api_error.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';

enum _Mode { signup, login }

class AuthScreen extends StatefulWidget {
  final VoidCallback? onAuthenticated;
  final VoidCallback? onBack;

  const AuthScreen({super.key, this.onAuthenticated, this.onBack});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.signup;
  final _name = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = {};

  @override
  void dispose() {
    _name.dispose();
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _isEmail(String s) => s.contains('@');

  Future<void> _submit() async {
    if (_busy) return;
    final state = AppScope.of(context);
    final l = L(state.lang);
    final id = _identifier.text.trim();
    final pwd = _password.text;
    final name = _name.text.trim();

    setState(() {
      _error = null;
      _fieldErrors = {};
      _busy = true;
    });

    try {
      if (_mode == _Mode.signup) {
        if (name.isEmpty) {
          throw ApiError(message: l.pick('Nom requis', 'Name required'));
        }
        if (id.isEmpty) {
          throw ApiError(
              message: l.pick('Email ou téléphone requis',
                  'Email or phone required'));
        }
        if (pwd.length < 8) {
          throw ApiError(
              message: l.pick('Mot de passe : 8 caractères minimum',
                  'Password: 8 characters minimum'));
        }
        final result = await state.authApi.signup(
          name: name,
          password: pwd,
          email: _isEmail(id) ? id : null,
          phone: _isEmail(id) ? null : id,
        );
        await state.applyAuthResult(result);
      } else {
        if (id.isEmpty || pwd.isEmpty) {
          throw ApiError(
              message: l.pick('Identifiants requis', 'Credentials required'));
        }
        final result = await state.authApi.login(
          email: _isEmail(id) ? id : null,
          phone: _isEmail(id) ? null : id,
          password: pwd,
        );
        await state.applyAuthResult(result);
      }
      if (!mounted) return;
      widget.onAuthenticated?.call();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);

    final isSignup = _mode == _Mode.signup;
    final idField = _identifier.text.trim();
    final identifierLabel = idField.isEmpty
        ? l.pick('Email ou téléphone', 'Email or phone')
        : (_isEmail(idField) ? l.pick('Email', 'Email') : l.pick('Téléphone', 'Phone'));

    return Container(
      color: p.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.cardBorder),
                      ),
                      child: Icon(Icons.chevron_left, size: 20, color: p.ink),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/babiguide-logo.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isSignup
                    ? l.pick('Créer un compte', 'Create your account')
                    : l.pick('Bon retour', 'Welcome back'),
                style: BgFonts.display(
                  size: 26,
                  weight: FontWeight.w700,
                  color: p.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isSignup
                    ? l.pick(
                        "Rejoignez la communauté BabiGuide pour sauvegarder vos adresses préférées et écrire des avis.",
                        'Join the BabiGuide community to save favorites and write reviews.')
                    : l.pick(
                        'Connectez-vous pour retrouver vos avis et favoris.',
                        'Sign in to access your reviews and favorites.'),
                style: BgFonts.body(size: 14, color: p.inkMuted, height: 1.45),
              ),
              const SizedBox(height: 22),
              _ModeToggle(
                mode: _mode,
                onChange: (m) => setState(() {
                  _mode = m;
                  _error = null;
                  _fieldErrors = {};
                }),
                l: l,
              ),
              const SizedBox(height: 18),
              if (isSignup) ...[
                _Field(
                  controller: _name,
                  label: l.pick('Nom', 'Name'),
                  textInputAction: TextInputAction.next,
                  error: _fieldErrors['name']?.first,
                ),
                const SizedBox(height: 12),
              ],
              _Field(
                controller: _identifier,
                label: identifierLabel,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                error: _fieldErrors['email']?.first ??
                    _fieldErrors['phone']?.first,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _password,
                label: l.pick('Mot de passe', 'Password'),
                obscure: !_showPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                error: _fieldErrors['password']?.first,
                trailing: GestureDetector(
                  onTap: () =>
                      setState(() => _showPassword = !_showPassword),
                  child: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: p.inkMuted,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x14C8551A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x33C8551A)),
                  ),
                  child: Text(
                    _error!,
                    style: BgFonts.body(
                      size: 13,
                      color: p.orangeDeep,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              GestureDetector(
                onTap: _busy ? null : _submit,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _busy ? p.orange.withValues(alpha: 0.6) : p.orange,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: p.orange.withValues(alpha: 0.5),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          isSignup
                              ? l.pick("S'inscrire", 'Sign up')
                              : l.pick('Se connecter', 'Log in'),
                          style: BgFonts.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                ),
              ),
              const Spacer(),
              if (widget.onBack != null)
                GestureDetector(
                  onTap: widget.onBack,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      l.pick('Annuler', 'Cancel'),
                      textAlign: TextAlign.center,
                      style: BgFonts.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: p.inkMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final _Mode mode;
  final ValueChanged<_Mode> onChange;
  final L l;
  const _ModeToggle({required this.mode, required this.onChange, required this.l});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    Widget tab(String label, _Mode m) {
      final on = m == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChange(m),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on ? p.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: BgFonts.body(
                size: 13,
                weight: FontWeight.w600,
                color: on ? p.bg : p.ink,
                height: 1,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.cardBorder),
      ),
      child: Row(
        children: [
          tab(l.pick("S'inscrire", 'Sign up'), _Mode.signup),
          tab(l.pick('Se connecter', 'Log in'), _Mode.login),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final String? error;

  const _Field({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null ? p.orangeDeep : p.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  style: BgFonts.body(size: 14, color: p.ink),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    labelText: label,
                    labelStyle: BgFonts.body(size: 13, color: p.inkMuted),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              error!,
              style: BgFonts.body(
                size: 11,
                weight: FontWeight.w600,
                color: p.orangeDeep,
              ),
            ),
          ),
      ],
    );
  }
}
