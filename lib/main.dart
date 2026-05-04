import 'package:flutter/material.dart';
import 'app_state.dart';
import 'data.dart';
import 'screens/auth.dart';
import 'screens/chat.dart';
import 'screens/detail.dart';
import 'screens/foryou.dart';
import 'screens/home.dart';
import 'screens/map_view.dart';
import 'screens/media.dart'; 
import 'screens/onboarding.dart';
import 'screens/profile.dart';
import 'screens/review.dart';
import 'screens/saved.dart';
import 'screens/search.dart';
import 'screens/splash.dart';
import 'widgets/ios_frame.dart';
import 'widgets/tab_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BabiGuideApp());
}

class BabiGuideApp extends StatefulWidget {
  const BabiGuideApp({super.key});

  @override
  State<BabiGuideApp> createState() => _BabiGuideAppState();
}

class _BabiGuideAppState extends State<BabiGuideApp> {
  final AppState _state = AppState();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          return MaterialApp(
            title: 'BabiGuide',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: _state.dark ? Brightness.dark : Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFF37221),
                brightness: _state.dark ? Brightness.dark : Brightness.light,
              ),
              scaffoldBackgroundColor: _state.palette.bg,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
            ),
            home: const _Root(),
          );
        },
      ),
    );
  }
}

enum _Route {
  splash,
  auth,
  onboarding0,
  onboarding1,
  home,
  search,
  searchFilter,
  map,
  foryou,
  foryouComments,
  detail,
  review,
  media,
  mediaLightbox,
  saved,
  profile,
  chat,
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  _Route _route = _Route.splash;
  TabKey _activeTab = TabKey.home;
  bool _splashMinElapsed = false;
  bool _bootstrapped = false;
  String? _detailSlug;
  DetailPlace? _detailPlace;
  _Route? _authReturnRoute;
  VoidCallback? _pendingAuthAction;
  String? _searchInitialQuery;
  String? _searchInitialNeighborhoodId;
  int? _searchInitialSortIndex;
  int _mediaInitialIndex = 0;
  bool _mediaOpenLightbox = false;

  void _go(_Route r) => setState(() => _route = r);

  void _openSearch({
    String? query,
    String? neighborhoodId,
    int? sortIndex,
  }) {
    setState(() {
      _searchInitialQuery = query;
      _searchInitialNeighborhoodId = neighborhoodId;
      _searchInitialSortIndex = sortIndex;
      _route = _Route.search;
    });
  }

  void _openNeighborhood(Neighborhood n) {
    _openSearch(query: n.name, neighborhoodId: n.id);
  }

  void _openMediaAt(int index, {bool lightbox = false}) {
    setState(() {
      _mediaInitialIndex = index;
      _mediaOpenLightbox = lightbox;
      _route = _Route.media;
    });
  }

  void _openDetail(String slug) {
    setState(() {
      _detailSlug = slug;
      _detailPlace = null;
      _route = _Route.detail;
    });
  }

  /// Run [onSuccess] if the user is signed in, otherwise present the auth
  /// screen and run [onSuccess] once they complete sign in / sign up. The
  /// previous route is remembered so the back button returns the user to
  /// where they came from.
  void _requireAuth({required VoidCallback onSuccess}) {
    final state = AppScope.of(context);
    if (state.isSignedIn) {
      onSuccess();
      return;
    }
    setState(() {
      _authReturnRoute = _route;
      _pendingAuthAction = onSuccess;
      _route = _Route.auth;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).bootstrap().whenComplete(() {
        if (!mounted) return;
        _bootstrapped = true;
        _maybeLeaveSplash();
      });
    });
  }

  void _maybeLeaveSplash() {
    if (!mounted || _route != _Route.splash) return;
    if (!_splashMinElapsed || !_bootstrapped) return;
    final state = AppScope.of(context);
    if (state.isSignedIn || state.hasCompletedOnboarding) {
      _go(_Route.home);
    } else {
      _go(_Route.onboarding0);
    }
  }

  Future<void> _finishOnboarding() async {
    await AppScope.of(context).markOnboardingDone();
    if (!mounted) return;
    setState(() {
      _activeTab = TabKey.home;
      _route = _Route.home;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppFrame(
        child: Stack(
          children: [
            Positioned.fill(child: _buildScreen()),
            if (_showsTabBar(_route))
              BgTabBar(
                active: _activeTab,
                onTap: (k) {
                  if (k == TabKey.add) {
                    if (_detailSlug == null) {
                      _go(_Route.search);
                    } else {
                      _requireAuth(onSuccess: () => _go(_Route.review));
                    }
                    return;
                  }
                  setState(() {
                    _activeTab = k;
                    if (k == TabKey.home) _route = _Route.home;
                    if (k == TabKey.discover) _route = _Route.foryou;
                    if (k == TabKey.saved) _route = _Route.saved;
                    if (k == TabKey.profile) _route = _Route.profile;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _showsTabBar(_Route r) =>
      r == _Route.home ||
      r == _Route.map ||
      r == _Route.foryou ||
      r == _Route.foryouComments ||
      r == _Route.detail ||
      r == _Route.saved ||
      r == _Route.profile;

  Widget _buildScreen() {
    switch (_route) {
      case _Route.splash:
        return SplashScreen(onContinue: () {
          _splashMinElapsed = true;
          _maybeLeaveSplash();
        });
      case _Route.onboarding0:
        return OnboardingScreen(
          initialStep: 0,
          onFinish: () => _go(_Route.onboarding1),
        );
      case _Route.auth:
        return AuthScreen(
          onAuthenticated: () {
            final cb = _pendingAuthAction;
            final back = _authReturnRoute;
            _pendingAuthAction = null;
            _authReturnRoute = null;
            if (cb != null) {
              cb();
            } else {
              _go(back ?? _Route.home);
            }
          },
          onBack: () {
            final back = _authReturnRoute;
            _pendingAuthAction = null;
            _authReturnRoute = null;
            _go(back ?? _Route.home);
          },
        );
      case _Route.onboarding1:
        return OnboardingScreen(
          initialStep: 1,
          onFinish: _finishOnboarding,
        );
      case _Route.home:
        return HomeScreen(
          onOpenRestaurant: _openDetail,
          onOpenSearch: () => _openSearch(),
          onOpenNeighborhood: _openNeighborhood,
          onSeeAllTrending: () => _openSearch(sortIndex: 1),
          onSeeAllNew: () => _openSearch(sortIndex: 3),
          onSeeAllNeighborhoods: () => _openSearch(),
        );
      case _Route.search:
        return SearchScreen(
          onBack: () => _go(_Route.home),
          onOpenRestaurant: _openDetail,
          initialQuery: _searchInitialQuery,
          initialNeighborhoodId: _searchInitialNeighborhoodId,
          initialSortIndex: _searchInitialSortIndex,
        );
      case _Route.searchFilter:
        return SearchScreen(
          onBack: () => _go(_Route.home),
          showFilterSheet: true,
          onOpenRestaurant: _openDetail,
          initialQuery: _searchInitialQuery,
          initialNeighborhoodId: _searchInitialNeighborhoodId,
          initialSortIndex: _searchInitialSortIndex,
        );
      case _Route.map:
        return MapScreen(
          onBack: () => _go(_Route.foryou),
          onOpenRestaurant: _openDetail,
        );
      case _Route.foryou:
        return ForYouScreen(
          onOpenMap: () => _go(_Route.map),
          onOpenPlace: _openDetail,
          onRequireAuth: () =>
              _requireAuth(onSuccess: () => _go(_Route.foryou)),
        );
      case _Route.foryouComments:
        return ForYouScreen(
          initialCommentsOpen: true,
          onOpenMap: () => _go(_Route.map),
          onOpenPlace: _openDetail,
          onRequireAuth: () =>
              _requireAuth(onSuccess: () => _go(_Route.foryou)),
        );
      case _Route.detail:
        return DetailScreen(
          slug: _detailSlug,
          onBack: () => _go(_Route.home),
          onWriteReview: () =>
              _requireAuth(onSuccess: () => _go(_Route.review)),
          onOpenMedia: () => _openMediaAt(0, lightbox: false),
          onOpenMediaAt: (i) => _openMediaAt(i, lightbox: true),
          onLoaded: (place) => _detailPlace = place,
          onRequireAuthForFavorite: () => _requireAuth(
            onSuccess: () async {
              if (_detailSlug != null) {
                await AppScope.of(context).toggleFavorite(_detailSlug!);
              }
              _go(_Route.detail);
            },
          ),
          onOpenChat: () =>
              _requireAuth(onSuccess: () => _go(_Route.chat)),
        );
      case _Route.review:
        return ReviewScreen(
          slug: _detailSlug,
          placeName: _detailPlace?.name,
          placeNeighborhood: _detailPlace?.neighborhood,
          coverPhotoUrl: _detailPlace?.coverPhotoUrl,
          onCancel: () => _go(_Route.detail),
          onPublish: () => _go(_Route.detail),
        );
      case _Route.media:
        return MediaScreen(
          slug: _detailSlug,
          placeName: _detailPlace?.name,
          placeNeighborhood: _detailPlace?.neighborhood,
          placeCuisine: _detailPlace?.cuisine,
          placePhotoUrl: _detailPlace?.coverPhotoUrl,
          onBack: () => _go(_Route.detail),
          initialIndex: _mediaInitialIndex,
          initialLightbox: _mediaOpenLightbox,
          onRequireAuth: () =>
              _requireAuth(onSuccess: () => _go(_Route.media)),
        );
      case _Route.mediaLightbox:
        return MediaScreen(
          slug: _detailSlug,
          placeName: _detailPlace?.name,
          placeNeighborhood: _detailPlace?.neighborhood,
          placeCuisine: _detailPlace?.cuisine,
          placePhotoUrl: _detailPlace?.coverPhotoUrl,
          onBack: () => _go(_Route.detail),
          initialLightbox: true,
          onRequireAuth: () =>
              _requireAuth(onSuccess: () => _go(_Route.mediaLightbox)),
        );
      case _Route.saved:
        return SavedScreen(
          onOpenRestaurant: _openDetail,
          onSignIn: () =>
              _requireAuth(onSuccess: () => _go(_Route.saved)),
        );
      case _Route.profile:
        return ProfileScreen(
          onSignIn: () =>
              _requireAuth(onSuccess: () => _go(_Route.profile)),
        );
      case _Route.chat:
        return ChatScreen(
          slug: _detailSlug ?? '',
          placeName: _detailPlace?.name,
          onBack: () => _go(_Route.detail),
        );
    }
  }
}
