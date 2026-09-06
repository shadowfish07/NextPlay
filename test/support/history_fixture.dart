import 'package:nextplay/data/service/playtime_history_service.dart';
import 'package:nextplay/domain/models/history/playtime_history.dart';
import 'fake_services.dart';

Map<String, dynamic> historyFixture({int range = 7, int? appId}) {
  final count = range == 30 ? 30 : 7;
  final days = List.generate(count, (i) {
    final date = DateTime.utc(2026, 9, 7)
        .subtract(Duration(days: count - 1 - i))
        .toIso8601String()
        .substring(0, 10);
    final minutes = [40, 90, 0, 125, 55, 180, 70][i % 7];
    return {
      'date': date,
      'added': i == 0 ? null : minutes,
      'total': i == 0 ? null : 12000 + i * 120,
      'quality': i == 0 ? 'missing' : (i == count - 1 ? 'partial' : 'complete'),
      'games': minutes == 0 || i == 0
          ? <Map<String, dynamic>>[]
          : [
              {'appid': appId ?? 620, 'name': 'Portal 2', 'added': minutes},
            ],
    };
  });
  return {
    'name': appId == null ? null : 'Portal 2',
    'timezone': 'Asia/Shanghai',
    'firstObserved': 1788192000000,
    'lastObserved': 1788739200000,
    'total': 12720,
    'added': 520,
    'previousAdded': null,
    'comparisonAdded': null,
    'partial': true,
    'days': days,
    'games': [
      {'appid': appId ?? 620, 'name': 'Portal 2', 'added': 520},
    ],
  };
}

class FakePlaytimeHistoryService extends PlaytimeHistoryService {
  FakePlaytimeHistoryService()
    : super(account: () => 'fixture', apiKeyStorage: FakeApiKeyStorage());
  bool fail = false;
  bool empty = false;
  final List<(int, int?)> requests = [];
  @override
  Future<PlaytimeHistory> load({int range = 7, int? appId}) async {
    requests.add((range, appId));
    if (fail) throw StateError('Fixture unavailable');
    final data = historyFixture(range: range, appId: appId);
    if (empty) data['firstObserved'] = null;
    return PlaytimeHistory.fromJson(data);
  }
}
