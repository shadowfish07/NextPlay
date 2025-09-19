import 'package:package_info_plus/package_info_plus.dart';
import 'package:result_dart/result_dart.dart';
import '../../utils/exceptions.dart';
import '../../utils/logger.dart';

/// 应用信息异常
class AppInfoException extends AppException {
  const AppInfoException(super.message, {super.code, super.details});
}

/// 应用信息服务
///
/// 负责获取应用的版本信息、包名等基础信息
/// 遵循项目的Service层规范：无状态、单一职责、返回Result类型
class AppInfoService {
  // 缓存PackageInfo实例，避免重复调用平台接口
  static PackageInfo? _cachedPackageInfo;

/// 获取包信息
  ///
  /// Returns: [Result] containing PackageInfo with complete application information
  static Future<Result<PackageInfo, AppInfoException>> getPackageInfo() async {
    try {
      // 如果已缓存则直接返回
      if (_cachedPackageInfo != null) {
        AppLogger.info('Returning cached package info');
        return Result.success(_cachedPackageInfo!);
      }

      AppLogger.info('Fetching package info from platform');
      _cachedPackageInfo = await PackageInfo.fromPlatform();

      AppLogger.info('Package info retrieved: ${_cachedPackageInfo!.appName} v${_cachedPackageInfo!.version}+${_cachedPackageInfo!.buildNumber}');
      return Result.success(_cachedPackageInfo!);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get package info', e, stackTrace);
      return Result.failure(
        AppInfoException(
          'Failed to retrieve package information',
          details: e,
        ),
      );
    }
  }

  /// 获取应用名称
  ///
  /// Returns: [Result] containing application name
  static Future<Result<String, AppInfoException>> getAppName() async {
    final result = await getPackageInfo();
    return result.map((info) => info.appName);
  }

  /// 获取包名
  ///
  /// Returns: [Result] containing package name
  static Future<Result<String, AppInfoException>> getPackageName() async {
    final result = await getPackageInfo();
    return result.map((info) => info.packageName);
  }

  /// 获取版本号
  ///
  /// Returns: [Result] containing version number (e.g. "1.0.0")
  static Future<Result<String, AppInfoException>> getVersion() async {
    final result = await getPackageInfo();
    return result.map((info) => info.version);
  }

  /// 获取构建号
  ///
  /// Returns: [Result] containing build number
  static Future<Result<String, AppInfoException>> getBuildNumber() async {
    final result = await getPackageInfo();
    return result.map((info) => info.buildNumber);
  }

  /// 获取完整版本字符串
  ///
  /// Returns: [Result] in format: version+buildNumber (e.g. "1.0.0+123")
  static Future<Result<String, AppInfoException>> getVersionString() async {
    final result = await getPackageInfo();
    return result.map((info) => '${info.version}+${info.buildNumber}');
  }

  /// 获取用于显示的版本字符串
  ///
  /// Returns: [Result] in format: v{version} ({buildNumber}) (e.g. "v1.0.0 (123)")
  static Future<Result<String, AppInfoException>> getDisplayVersion() async {
    final result = await getPackageInfo();
    return result.map((info) => 'v${info.version} (${info.buildNumber})');
  }

  /// 清除缓存
  ///
  /// 用于测试或需要强制重新获取包信息的场景
  static void clearCache() {
    AppLogger.info('Clearing package info cache');
    _cachedPackageInfo = null;
  }
}