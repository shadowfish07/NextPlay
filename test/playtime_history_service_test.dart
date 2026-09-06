import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/data/service/playtime_history_service.dart';
import 'support/fake_services.dart';
import 'support/history_fixture.dart';

void main() {
  test(
    'history reads use existing credentials and reject account changes in flight',
    () async {
      var account = 'alice';
      var changeAccount = false;
      final dio = Dio();
      final keys = FakeApiKeyStorage();
      await keys.write('existing-key');
      final calls = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls.add(request);
            expect(request.uri.host, 'igdb.zqydev.me');
            if (request.path.endsWith('/session')) {
              expect(request.headers['Authorization'], 'SteamKey existing-key');
              expect(request.headers['X-Steam-Id'], 'alice');
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {'steamId': 'alice', 'token': 'a' * 32},
                ),
              );
            } else {
              expect(request.headers['Authorization'], 'Bearer ${'a' * 32}');
              expect(request.queryParameters, {'range': 30, 'appid': 620});
              if (changeAccount) account = 'bob';
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: historyFixture(range: 30, appId: 620),
                ),
              );
            }
          },
        ),
      );
      final service = PlaytimeHistoryService(
        account: () => account,
        apiKeyStorage: keys,
        dio: dio,
      );
      addTearDown(service.dispose);
      expect((await service.load(range: 30, appId: 620)).name, 'Portal 2');
      expect(calls.length, 2);
      changeAccount = true;
      await expectLater(service.load(range: 30, appId: 620), throwsStateError);
    },
  );
}
