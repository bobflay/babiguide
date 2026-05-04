import 'package:flutter/material.dart';
import 'api/api_error.dart';
import 'api/auth_api.dart';
import 'api/chat_api.dart';
import 'api/client.dart';
import 'api/favorites_api.dart';
import 'api/feed_api.dart';
import 'api/me_api.dart';
import 'api/media_api.dart';
import 'api/media_social_api.dart';
import 'api/models.dart';
import 'api/places_api.dart';
import 'api/reviews_api.dart';
import 'api/token_storage.dart';
import 'theme.dart';

enum BgLang { fr, en }

enum SessionStatus { unknown, signedOut, signedIn }

class AppState extends ChangeNotifier {
  BgLang lang;
  bool dark;

  final TokenStorage _tokens;
  final ApiClient client;
  final AuthApi authApi;
  final MeApi meApi;
  final PlacesApi placesApi;
  final ReviewsApi reviewsApi;
  final FavoritesApi favoritesApi;
  final MediaApi mediaApi;
  final MediaSocialApi mediaSocialApi;
  final FeedApi feedApi;
  final ChatApi chatApi;

  SessionStatus _session = SessionStatus.unknown;
  User? _user;
  String? _token;
  bool _onboarded = false;
  final Set<String> _favoriteIds = {};

  AppState._({
    required this.lang,
    required this.dark,
    required TokenStorage tokens,
    required this.client,
  })  : _tokens = tokens,
        authApi = AuthApi(client),
        meApi = MeApi(client),
        placesApi = PlacesApi(client),
        reviewsApi = ReviewsApi(client),
        favoritesApi = FavoritesApi(client),
        mediaApi = MediaApi(client),
        mediaSocialApi = MediaSocialApi(client),
        feedApi = FeedApi(client),
        chatApi = ChatApi(client);

  factory AppState({
    BgLang lang = BgLang.fr,
    bool dark = false,
    TokenStorage? tokenStorage,
    ApiClient? apiClient,
  }) {
    final tokens = tokenStorage ?? TokenStorage();
    final client = apiClient ?? ApiClient(tokens);
    return AppState._(
      lang: lang,
      dark: dark,
      tokens: tokens,
      client: client,
    );
  }

  BgPalette get palette => dark ? BgPalette.dark : BgPalette.light;

  SessionStatus get session => _session;
  User? get user => _user;
  String? get token => _token;
  bool get isSignedIn => _session == SessionStatus.signedIn;
  bool get hasCompletedOnboarding => _onboarded;

  bool isFavorite(String placeId) => _favoriteIds.contains(placeId);

  /// Optimistic toggle: flip the cached state, fire the API, roll back on
  /// error. Returns the resulting boolean.
  Future<bool> toggleFavorite(String placeId) async {
    final wasFav = _favoriteIds.contains(placeId);
    if (wasFav) {
      _favoriteIds.remove(placeId);
    } else {
      _favoriteIds.add(placeId);
    }
    notifyListeners();
    try {
      if (wasFav) {
        await favoritesApi.remove(placeId);
      } else {
        await favoritesApi.add(placeId);
      }
      return !wasFav;
    } catch (_) {
      if (wasFav) {
        _favoriteIds.add(placeId);
      } else {
        _favoriteIds.remove(placeId);
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshFavorites() async {
    if (!isSignedIn) return;
    try {
      final list = await favoritesApi.list();
      _favoriteIds
        ..clear()
        ..addAll(list.map((p) => p.id));
      notifyListeners();
    } on ApiError {
      // Best-effort; keep stale cache.
    }
  }

  /// Read the persisted token, validate it via `/me`, and set the session
  /// state accordingly. Safe to call multiple times.
  Future<void> bootstrap() async {
    _onboarded = await _tokens.readOnboarded();
    final stored = await _tokens.read();
    if (stored == null || stored.isEmpty) {
      _setSignedOut();
      return;
    }
    _token = stored;
    client.setToken(stored);
    try {
      final user = await authApi.me();
      _user = user;
      _session = SessionStatus.signedIn;
      _applyServerPreferences(user);
      notifyListeners();
      // Pull favorites in the background; don't block bootstrap.
      refreshFavorites();
    } on ApiError catch (e) {
      if (e.isUnauthorized) {
        await _tokens.clear();
        _token = null;
        client.setToken(null);
      }
      _setSignedOut();
    }
  }

  Future<void> applyAuthResult(AuthResult result) async {
    _token = result.token;
    _user = result.user;
    _session = SessionStatus.signedIn;
    await _tokens.write(result.token);
    client.setToken(result.token);
    _applyServerPreferences(result.user);
    notifyListeners();
    refreshFavorites();
  }

  Future<void> markOnboardingDone() async {
    if (_onboarded) return;
    _onboarded = true;
    await _tokens.writeOnboarded(true);
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      if (_token != null) await authApi.logout();
    } on ApiError {
      // best-effort: still clear local state
    }
    _token = null;
    _user = null;
    _session = SessionStatus.signedOut;
    _favoriteIds.clear();
    await client.clearToken();
    notifyListeners();
  }

  void updateUser(User user) {
    _user = user;
    _applyServerPreferences(user);
    notifyListeners();
  }

  void _applyServerPreferences(User user) {
    final serverLang = user.preferences.lang == 'en' ? BgLang.en : BgLang.fr;
    if (serverLang != lang) lang = serverLang;
    if (user.preferences.darkMode != dark) dark = user.preferences.darkMode;
  }

  void _setSignedOut() {
    _user = null;
    _token = null;
    _session = SessionStatus.signedOut;
    notifyListeners();
  }

  void setLang(BgLang l) {
    if (lang != l) {
      lang = l;
      notifyListeners();
    }
  }

  void toggleDark() {
    dark = !dark;
    notifyListeners();
  }

  void setDark(bool v) {
    if (dark != v) {
      dark = v;
      notifyListeners();
    }
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }
}
