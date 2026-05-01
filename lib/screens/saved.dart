import 'package:flutter/material.dart';
import '../api/api_error.dart';
import '../app_state.dart';
import '../data.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/star_row.dart';

class SavedScreen extends StatefulWidget {
  final ValueChanged<String>? onOpenRestaurant;
  final VoidCallback? onSignIn;

  const SavedScreen({super.key, this.onOpenRestaurant, this.onSignIn});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  Future<List<Place>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  void _load() {
    final state = AppScope.of(context);
    if (!state.isSignedIn) {
      setState(() => _future = Future.value(const <Place>[]));
      return;
    }
    setState(() {
      _future = state.favoritesApi.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);

    return Container(
      color: p.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 6),
            child: Text(
              l.tabSaved,
              style: BgFonts.display(
                size: 26,
                weight: FontWeight.w700,
                color: p.ink,
                letterSpacing: -0.6,
              ),
            ),
          ),
          if (!state.isSignedIn)
            _SignInPrompt(p: p, l: l, onSignIn: widget.onSignIn)
          else
            FutureBuilder<List<Place>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(p.orange),
                        ),
                      ),
                    ),
                  );
                }
                if (snap.hasError) {
                  final msg = snap.error is ApiError
                      ? (snap.error as ApiError).message
                      : l.pick("Erreur de chargement",
                          "Failed to load favorites");
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        msg,
                        style: BgFonts.body(size: 13, color: p.inkMuted),
                      ),
                    ),
                  );
                }
                final items = snap.data ?? const <Place>[];
                if (items.isEmpty) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.bookmark_border,
                              size: 32, color: p.inkMuted),
                          const SizedBox(height: 10),
                          Text(
                            l.pick(
                              "Aucun favori pour l'instant",
                              "No favorites yet",
                            ),
                            textAlign: TextAlign.center,
                            style: BgFonts.body(
                                size: 14, color: p.inkMuted, height: 1.4),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.pick(
                              'Touchez le cœur sur une fiche pour la sauvegarder.',
                              'Tap the heart on a place to save it.',
                            ),
                            textAlign: TextAlign.center,
                            style: BgFonts.body(
                                size: 12, color: p.inkMuted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final pl in items) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: () => widget.onOpenRestaurant?.call(pl.id),
                          child: _SavedRow(p: pl, l: l),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  final BgPalette p;
  final L l;
  final VoidCallback? onSignIn;
  const _SignInPrompt({required this.p, required this.l, this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
      child: Column(
        children: [
          Icon(Icons.bookmark_border, size: 32, color: p.inkMuted),
          const SizedBox(height: 10),
          Text(
            l.pick(
              'Connectez-vous pour sauvegarder des adresses.',
              'Sign in to save your favorite places.',
            ),
            textAlign: TextAlign.center,
            style: BgFonts.body(size: 14, color: p.ink, height: 1.4),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onSignIn,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: p.orange,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l.pick('Se connecter', 'Sign in'),
                style: BgFonts.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedRow extends StatelessWidget {
  final Place p;
  final L l;
  const _SavedRow({required this.p, required this.l});

  @override
  Widget build(BuildContext context) {
    final pal = AppScope.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.cardBorder),
      ),
      child: Row(
        children: [
          PhotoPlaceholder(
            seed: p.seed,
            label: p.photoLabel,
            width: 80,
            height: 80,
            borderRadius: BorderRadius.circular(11),
            photoUrl: p.photoUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.name,
                  style: BgFonts.display(
                    size: 15,
                    weight: FontWeight.w700,
                    color: pal.ink,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  p.cuisine,
                  style: BgFonts.body(size: 12, color: pal.inkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StarRow(value: p.rating, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      l.reviewsCount(p.reviews),
                      style: BgFonts.body(size: 11, color: pal.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
