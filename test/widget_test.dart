import 'package:flutter_test/flutter_test.dart';

import 'package:babiguide_mobile/app_state.dart';

void main() {
  test('AppState constructs with default API client', () {
    final state = AppState();
    expect(state.session, SessionStatus.unknown);
    expect(state.isSignedIn, isFalse);
    expect(state.hasCompletedOnboarding, isFalse);
    expect(state.client, isNotNull);
    expect(state.authApi, isNotNull);
    expect(state.placesApi, isNotNull);
    expect(state.reviewsApi, isNotNull);
    expect(state.favoritesApi, isNotNull);
    expect(state.mediaApi, isNotNull);
  });
}
