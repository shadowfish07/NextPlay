import 'package:flutter/foundation.dart';

/// Stable identifiers shared by Flutter tests and Android accessibility tools.
abstract final class AppKeys {
  static const onboardingScreen = ValueKey('onboarding.screen');
  static const onboardingNext = ValueKey('onboarding.next');
  static const onboardingPrevious = ValueKey('onboarding.previous');
  static const onboardingApiKey = ValueKey('onboarding.apiKey');
  static const onboardingSteamId = ValueKey('onboarding.steamId');
  static const onboardingSyncState = ValueKey('onboarding.syncState');
  static const onboardingFinish = ValueKey('onboarding.finish');
  static const onboardingRetry = ValueKey('onboarding.retry');

  static const mainNavigation = ValueKey('main.navigation');
  static const discoverDestination = ValueKey('main.discover');
  static const libraryDestination = ValueKey('main.library');
  static const settingsDestination = ValueKey('main.settings');
  static const discoverScreen = ValueKey('discover.screen');
  static const discoverLoading = ValueKey('discover.loading');
  static const discoverError = ValueKey('discover.error');
  static const discoverRetry = ValueKey('discover.retry');
  static const discoverEmpty = ValueKey('discover.empty');
  static const discoverRecommendation = ValueKey('discover.recommendation');
  static const libraryScreen = ValueKey('library.screen');
  static const librarySearch = ValueKey('library.search');
  static const libraryLoading = ValueKey('library.loading');
  static const libraryError = ValueKey('library.error');
  static const libraryRetry = ValueKey('library.retry');
  static const libraryEmpty = ValueKey('library.empty');
  static const settingsScreen = ValueKey('settings.screen');
  static const settingsError = ValueKey('settings.error');
  static const settingsSync = ValueKey('settings.sync');
  static const detailsScreen = ValueKey('details.screen');
  static const detailsLoading = ValueKey('details.loading');
  static const detailsError = ValueKey('details.error');
  static const detailsRetry = ValueKey('details.retry');
  static const detailsStatus = ValueKey('details.status');
  static const detailsWishlist = ValueKey('details.wishlist');

  static ValueKey<String> libraryItem(int appId) =>
      ValueKey('library.item.$appId');

  static ValueKey<String> recommendation(int appId) =>
      ValueKey('discover.recommendation.$appId');
}
