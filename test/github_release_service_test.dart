import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nextplay/data/service/github_release_service.dart';

void main() {
  test('compares release versions using SemVer ordering', () {
    expect(VersionComparator.compare('v1.4.0', '1.3.9+15'), greaterThan(0));
    expect(VersionComparator.compare('1.3.0', '1.3.0+15'), 0);
    expect(VersionComparator.compare('1.3.0-rc.1', '1.3.0'), lessThan(0));
    expect(VersionComparator.compare('1.3.0-rc.2', '1.3.0-rc.10'), lessThan(0));
    expect(VersionComparator.normalize('v1.4.0+22'), '1.4.0');
  });

  test('parses the latest GitHub release and finds the APK asset', () async {
    RequestOptions? request;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'tag_name': 'v1.4.0',
                'name': 'NextPlay 1.4.0',
                'body': '修复同步问题',
                'html_url':
                    'https://github.com/shadowfish07/NextPlay/releases/tag/v1.4.0',
                'published_at': '2026-08-19T00:00:00Z',
                'assets': [
                  {
                    'name': 'checksums.txt',
                    'browser_download_url': 'https://example.com/checksums.txt',
                  },
                  {
                    'name': 'nextplay-1.4.0.apk',
                    'browser_download_url': 'https://example.com/nextplay.apk',
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    final service = GitHubReleaseService(dio: dio);
    final result = await service.checkForUpdate(currentVersion: '1.3.0+15');

    expect(result.isSuccess(), isTrue);
    final update = result.getOrNull()!.update!;
    expect(update.version, '1.4.0');
    expect(update.title, 'NextPlay 1.4.0');
    expect(update.releaseNotes, '修复同步问题');
    expect(update.apkUrl, 'https://example.com/nextplay.apk');
    expect(update.publishedAt, isNotNull);
    expect(request?.uri.path, '/repos/shadowfish07/NextPlay/releases/latest');
    expect(request?.headers['User-Agent'], 'NextPlay-update-check');

    service.dispose();
  });

  test('returns no update when latest release is not newer', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'tag_name': 'v1.3.0',
              'name': 'NextPlay 1.3.0',
              'html_url':
                  'https://github.com/shadowfish07/NextPlay/releases/tag/v1.3.0',
            },
          ),
        ),
      ),
    );

    final service = GitHubReleaseService(dio: dio);
    final result = await service.checkForUpdate(currentVersion: '1.3.0+15');

    expect(result.isSuccess(), isTrue);
    expect(result.getOrNull()!.hasUpdate, isFalse);
    service.dispose();
  });

  test('returns a user-facing failure for a GitHub error response', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 403,
            data: {'message': 'rate limit exceeded'},
          ),
        ),
      ),
    );

    final service = GitHubReleaseService(dio: dio);
    final result = await service.checkForUpdate(currentVersion: '1.3.0');

    expect(result.isError(), isTrue);
    expect(result.exceptionOrNull(), contains('请求过于频繁'));
    service.dispose();
  });
}
