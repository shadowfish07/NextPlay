import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/data/service/igdb_game_service.dart';

void main() {
  test('VGC rating request bounds connection and response phases', () async {
    final dio = Dio();
    late RequestOptions captured;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<void>(requestOptions: options, statusCode: 404),
          );
        },
      ),
    );
    final service = IgdbGameService(dio: dio);

    await service.getVgcRating(620);

    expect(captured.connectTimeout, const Duration(seconds: 5));
    expect(captured.receiveTimeout, const Duration(seconds: 15));
  });
}
