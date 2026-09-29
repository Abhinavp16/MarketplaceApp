class AppUpdateConfig {
  const AppUpdateConfig({
    required this.enabled,
    this.latestBuildNumber,
    this.latestVersion,
    this.storeUri,
    this.title,
    this.message,
  });

  final bool enabled;
  final int? latestBuildNumber;
  final String? latestVersion;
  final Uri? storeUri;
  final String? title;
  final String? message;

  factory AppUpdateConfig.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    if (enabled is! bool) {
      throw const FormatException('Missing update enabled flag');
    }
    if (!enabled) return const AppUpdateConfig(enabled: false);

    final latestBuildNumber = _parseBuildNumber(json['latestBuildNumber']);
    final latestVersion = json['latestVersion'];
    final storeUrl = json['storeUrl'];
    final title = json['title'];
    final message = json['message'];
    final storeUri = storeUrl is String ? Uri.tryParse(storeUrl.trim()) : null;

    if (latestBuildNumber == null ||
        latestVersion is! String ||
        latestVersion.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        message is! String ||
        message.trim().isEmpty ||
        storeUri == null ||
        storeUri.scheme != 'https' ||
        !storeUri.hasAuthority) {
      throw const FormatException('Invalid mandatory update configuration');
    }

    return AppUpdateConfig(
      enabled: true,
      latestBuildNumber: latestBuildNumber,
      latestVersion: latestVersion.trim(),
      storeUri: storeUri,
      title: title.trim(),
      message: message.trim(),
    );
  }

  static int? _parseBuildNumber(Object? value) {
    if (value is int) return value > 0 ? value : null;
    if (value is String && RegExp(r'^\d+$').hasMatch(value.trim())) {
      final parsed = int.tryParse(value.trim());
      return parsed != null && parsed > 0 ? parsed : null;
    }
    return null;
  }
}

class AppUpdateRequirement {
  const AppUpdateRequirement({
    required this.currentVersion,
    required this.latestVersion,
    required this.storeUri,
    required this.title,
    required this.message,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri storeUri;
  final String title;
  final String message;
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult.success(this.requirement) : succeeded = true;

  const AppUpdateCheckResult.unavailable()
    : succeeded = false,
      requirement = null;

  final bool succeeded;
  final AppUpdateRequirement? requirement;
}
