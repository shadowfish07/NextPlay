import 'package:dio/dio.dart';
import 'package:result_dart/result_dart.dart';

import '../../domain/models/update/app_update.dart';
import '../../utils/logger.dart';

/// The update source contract used by the application and its test fakes.
abstract class ReleaseService {
  Future<Result<UpdateCheckResult, String>> checkForUpdate({
    required String currentVersion,
  });

  void dispose() {}
}

/// Reads the latest stable release from GitHub Releases.
class GitHubReleaseService extends ReleaseService {
  GitHubReleaseService({
    Dio? dio,
    this.repository = 'shadowfish07/NextPlay',
    this.apiBaseUrl = 'https://api.github.com',
  }) : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  final Dio _dio;
  final String repository;
  final String apiBaseUrl;

  @override
  Future<Result<UpdateCheckResult, String>> checkForUpdate({
    required String currentVersion,
  }) async {
    try {
      final normalizedCurrentVersion = VersionComparator.normalize(
        currentVersion,
      );
      final response = await _dio.get<dynamic>(
        '${apiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/repos/$repository/releases/latest',
        options: Options(
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'NextPlay-update-check',
          },
          validateStatus: (status) => status != null,
        ),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode != 200) {
        final message = switch (statusCode) {
          403 => 'GitHub 更新服务请求过于频繁，请稍后再试',
          404 => 'GitHub 暂无可用的正式版本',
          _ => 'GitHub 更新检查失败（HTTP $statusCode）',
        };
        AppLogger.warning(message);
        return Failure(message);
      }

      final data = response.data;
      if (data is! Map) {
        return const Failure('GitHub 更新响应格式无效');
      }

      final tagName = data['tag_name'];
      if (tagName is! String || tagName.trim().isEmpty) {
        return const Failure('GitHub Release 缺少版本号');
      }

      final releaseVersion = VersionComparator.normalize(tagName);
      if (VersionComparator.compare(releaseVersion, normalizedCurrentVersion) <=
          0) {
        return const Success(UpdateCheckResult());
      }

      final releaseUrl = data['html_url'];
      if (releaseUrl is! String ||
          Uri.tryParse(releaseUrl)?.hasScheme != true) {
        return const Failure('GitHub Release 缺少有效的下载页面');
      }

      final title =
          data['name'] is String && (data['name'] as String).trim().isNotEmpty
          ? (data['name'] as String).trim()
          : 'NextPlay $releaseVersion';
      final releaseNotes = data['body'] is String
          ? (data['body'] as String).trim()
          : '';

      return Success(
        UpdateCheckResult(
          update: AppUpdate(
            version: releaseVersion,
            title: title,
            releaseNotes: releaseNotes,
            releaseUrl: releaseUrl,
            apkUrl: _findApkUrl(data['assets']),
            publishedAt: _parseDate(data['published_at']),
          ),
        ),
      );
    } on FormatException catch (error) {
      AppLogger.warning('Invalid GitHub release version: ${error.message}');
      return Failure('GitHub Release 版本号无效');
    } on DioException catch (error, stackTrace) {
      AppLogger.error('Failed to check GitHub release', error, stackTrace);
      return const Failure('暂时无法检查更新，请检查网络连接');
    } catch (error, stackTrace) {
      AppLogger.error('Unexpected GitHub release error', error, stackTrace);
      return const Failure('暂时无法检查更新');
    }
  }

  String? _findApkUrl(dynamic assets) {
    if (assets is! List) return null;

    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is String &&
          url is String &&
          name.toLowerCase().endsWith('.apk')) {
        return url;
      }
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  @override
  void dispose() {
    _dio.close(force: true);
  }
}

/// Small SemVer comparator for release tags and package versions.
///
/// GitHub's latest-release endpoint excludes drafts and prereleases, but the
/// comparator still understands prerelease identifiers so test and local
/// builds are ordered consistently.
abstract final class VersionComparator {
  static int compare(String left, String right) {
    final leftVersion = _ReleaseVersion.parse(left);
    final rightVersion = _ReleaseVersion.parse(right);

    final coreComparison = leftVersion.compareCoreTo(rightVersion);
    if (coreComparison != 0) return coreComparison;
    return leftVersion.comparePrereleaseTo(rightVersion);
  }

  static bool isNewer(String candidate, String current) =>
      compare(candidate, current) > 0;

  static String normalize(String version) =>
      _ReleaseVersion.parse(version).normalized;
}

class _ReleaseVersion {
  _ReleaseVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prerelease,
  });

  factory _ReleaseVersion.parse(String input) {
    final match = RegExp(
      r'^[vV]?(\d+)\.(\d+)\.(\d+)'
      r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
      r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
    ).firstMatch(input.trim());
    if (match == null) {
      throw FormatException('Invalid semantic version: $input');
    }

    return _ReleaseVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      prerelease: match.group(4)?.split('.') ?? const [],
    );
  }

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  String get normalized {
    final core = '$major.$minor.$patch';
    return prerelease.isEmpty ? core : '$core-${prerelease.join('.')}';
  }

  int compareCoreTo(_ReleaseVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) return majorComparison;
    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) return minorComparison;
    return patch.compareTo(other.patch);
  }

  int comparePrereleaseTo(_ReleaseVersion other) {
    if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
    if (prerelease.isEmpty) return 1;
    if (other.prerelease.isEmpty) return -1;

    final length = prerelease.length > other.prerelease.length
        ? prerelease.length
        : other.prerelease.length;
    for (var index = 0; index < length; index++) {
      if (index >= prerelease.length) return -1;
      if (index >= other.prerelease.length) return 1;

      final leftIdentifier = prerelease[index];
      final rightIdentifier = other.prerelease[index];
      final leftNumber = int.tryParse(leftIdentifier);
      final rightNumber = int.tryParse(rightIdentifier);

      if (leftNumber != null && rightNumber != null) {
        final comparison = leftNumber.compareTo(rightNumber);
        if (comparison != 0) return comparison;
      } else if (leftNumber != null) {
        return -1;
      } else if (rightNumber != null) {
        return 1;
      } else {
        final comparison = leftIdentifier.compareTo(rightIdentifier);
        if (comparison != 0) return comparison;
      }
    }
    return 0;
  }
}
