import 'package:flutter/foundation.dart';
import 'package:flutter_release_updater/flutter_release_updater.dart';
import 'package:result_dart/result_dart.dart';

import 'package:nextplay/data/service/api_key_storage.dart';
import 'package:nextplay/data/service/igdb_game_service.dart';
import 'package:nextplay/data/service/steam_api_service.dart';
import 'package:nextplay/domain/models/game/game.dart';
import 'package:nextplay/domain/models/game/igdb_game_data.dart';

class FakeApiKeyStorage implements ApiKeyStorage {
  FakeApiKeyStorage({this.value});

  String? value;
  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;
  int writeCount = 0;

  @override
  Future<String?> read() async {
    if (failReads) {
      throw StateError('Fake secure read failure');
    }
    return value;
  }

  @override
  Future<void> write(String apiKey) async {
    writeCount += 1;
    if (failWrites) {
      throw StateError('Fake secure write failure');
    }
    value = apiKey;
  }

  @override
  Future<void> delete() async {
    if (failDeletes) {
      throw StateError('Fake secure delete failure');
    }
    value = null;
  }
}

class FakeReleaseUpdater extends ChangeNotifier implements ReleaseUpdater {
  FakeReleaseUpdater({
    this.installedVersion = '1.5.0',
    this.status = UpdateStatus.upToDate,
    this.availableUpdate,
    this.errorMessage = '',
    this.downloadProgress,
    this.nextInstallStatus = UpdateStatus.installerOpened,
  });

  @override
  String installedVersion;

  @override
  UpdateStatus status;

  @override
  AppUpdate? availableUpdate;

  @override
  DateTime? lastCheckAt;

  @override
  String errorMessage;

  @override
  double? downloadProgress;

  UpdateStatus nextInstallStatus;
  int startCount = 0;
  int checkCount = 0;
  int installCount = 0;

  @override
  bool get isBusy =>
      status == UpdateStatus.checking || status == UpdateStatus.downloading;

  @override
  Future<void> start() async {
    startCount += 1;
  }

  @override
  Future<void> checkIfDue() => checkNow();

  @override
  Future<void> checkNow() async {
    checkCount += 1;
    lastCheckAt = DateTime.now();
    status = availableUpdate == null
        ? UpdateStatus.upToDate
        : UpdateStatus.available;
    notifyListeners();
  }

  @override
  Future<void> downloadAndInstall() async {
    if (availableUpdate == null || isBusy) return;
    installCount += 1;
    status = nextInstallStatus;
    notifyListeners();
  }

  void publishUpdate(AppUpdate update) {
    availableUpdate = update;
    status = UpdateStatus.available;
    errorMessage = '';
    notifyListeners();
  }
}

enum FakeServiceMode { success, empty, failure }

class FakeSteamApiService extends SteamApiService {
  FakeSteamApiService({
    this.mode = FakeServiceMode.success,
    this.softwareCatalogMode = FakeServiceMode.success,
    this.delay = Duration.zero,
    List<Game>? games,
    Set<int>? softwareAppIds,
  }) : games = games ?? const [],
       softwareAppIds = softwareAppIds ?? const {};

  FakeServiceMode mode;
  FakeServiceMode softwareCatalogMode;
  final Duration delay;
  final List<Game> games;
  final Set<int> softwareAppIds;

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<Result<List<Game>, String>> getOwnedGames({
    required String apiKey,
    required String steamId,
    bool includeAppInfo = true,
    bool includePlayedFreeGames = true,
    int maxRetries = 3,
  }) async {
    await _wait();
    return switch (mode) {
      FakeServiceMode.success => Success(List<Game>.from(games)),
      FakeServiceMode.empty => const Success(<Game>[]),
      FakeServiceMode.failure => const Failure('fixture Steam failure'),
    };
  }

  @override
  Future<Result<Set<int>, String>> getSoftwareAppIds({
    required String apiKey,
  }) async {
    await _wait();
    return switch (softwareCatalogMode) {
      FakeServiceMode.success => Success(Set<int>.from(softwareAppIds)),
      FakeServiceMode.empty => const Success(<int>{}),
      FakeServiceMode.failure => const Failure(
        'fixture software catalog failure',
      ),
    };
  }

  @override
  Future<Result<Map<String, dynamic>, String>> getPlayerSummaries({
    required String apiKey,
    required String steamId,
  }) async {
    await _wait();
    if (mode == FakeServiceMode.failure) {
      return const Failure('fixture Steam failure');
    }
    return Success({'steamid': steamId, 'personaname': 'Fixture Player'});
  }

  @override
  Future<Result<bool, String>> validateCredentials({
    required String apiKey,
    required String steamId,
  }) async {
    await _wait();
    return mode == FakeServiceMode.failure
        ? const Failure('fixture Steam failure')
        : const Success(true);
  }

  @override
  Future<Result<AchievementSummary, String>> getPlayerAchievements({
    required String apiKey,
    required String steamId,
    required int appId,
  }) async {
    await _wait();
    return mode == FakeServiceMode.failure
        ? const Failure('fixture achievement failure')
        : const Success(AchievementSummary(total: 10, unlocked: 4));
  }
}

class FakeIgdbGameService extends IgdbGameService {
  FakeIgdbGameService({
    this.mode = FakeServiceMode.success,
    this.delay = Duration.zero,
    List<IgdbGameData>? games,
    Map<String, List<IgdbGameData>>? gamesByLanguage,
  }) : games = games ?? const [],
       gamesByLanguage = gamesByLanguage ?? const {};

  FakeServiceMode mode;
  final Duration delay;
  final List<IgdbGameData> games;
  final Map<String, List<IgdbGameData>> gamesByLanguage;
  String? lastLanguage;

  @override
  Future<Result<IgdbBatchResponse, String>> getBatchGameInfo(
    List<int> steamIds, {
    bool forceRefresh = false,
    String language = 'en',
    void Function(int completed, int total)? onProgress,
  }) async {
    lastLanguage = language;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (mode == FakeServiceMode.failure) {
      return const Failure('fixture IGDB failure');
    }
    if (mode == FakeServiceMode.empty) {
      onProgress?.call(steamIds.length, steamIds.length);
      return Success(
        IgdbBatchResponse(
          games: const [],
          notFound: List<int>.from(steamIds),
          errors: const [],
        ),
      );
    }

    final languageGames = gamesByLanguage[language] ?? games;
    final selected = languageGames
        .where((game) => steamIds.contains(game.steamId))
        .map(
          (game) => language.startsWith('en')
              ? game
              : game.copyWith(
                  localizedNameSource: game.localizedName == null
                      ? null
                      : 'steam_store',
                  summarySource: game.summary == null ? null : 'steam_store',
                  localizationLanguage: language,
                ),
        )
        .toList();
    final foundIds = selected.map((game) => game.steamId).toSet();
    onProgress?.call(steamIds.length, steamIds.length);
    return Success(
      IgdbBatchResponse(
        games: selected,
        notFound: steamIds.where((id) => !foundIds.contains(id)).toList(),
        errors: const [],
      ),
    );
  }

  @override
  Future<Result<OfficialLocalizationResponse, String>> getOfficialLocalizations(
    List<int> steamIds, {
    required String language,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (mode == FakeServiceMode.failure) {
      return const Failure('fixture official localization failure');
    }

    final languageGames = gamesByLanguage[language] ?? const <IgdbGameData>[];
    final selected = languageGames
        .where((game) => steamIds.contains(game.steamId))
        .toList();
    final foundIds = selected.map((game) => game.steamId).toSet();
    final notFound = steamIds.where((id) => !foundIds.contains(id)).toList();
    final items = selected
        .map(
          (game) => OfficialLocalizationItem(
            steamId: game.steamId,
            name: game.localizedName,
            summary: game.summary,
            stale: false,
          ),
        )
        .toList();

    return Success(
      OfficialLocalizationResponse(
        items: items,
        pending: const [],
        retrying: const [],
        notFound: notFound,
        status: OfficialLocalizationStatus(
          requested: steamIds.length,
          ready: items.length,
          pending: 0,
          retrying: 0,
          notFound: notFound.length,
          stale: 0,
        ),
      ),
    );
  }
}
