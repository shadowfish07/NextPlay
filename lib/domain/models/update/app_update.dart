/// A published application update discovered from the release provider.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.title,
    required this.releaseNotes,
    required this.releaseUrl,
    this.apkUrl,
    this.publishedAt,
  });

  final String version;
  final String title;
  final String releaseNotes;
  final String releaseUrl;
  final String? apkUrl;
  final DateTime? publishedAt;
}

/// The successful result of an update check.
///
/// A null [update] is a successful check which found no newer release.
class UpdateCheckResult {
  const UpdateCheckResult({this.update});

  final AppUpdate? update;

  bool get hasUpdate => update != null;
}

enum UpdateCheckStatus { idle, checking, upToDate, available, failed }
