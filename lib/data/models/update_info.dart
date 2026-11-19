import 'dart:io';

class UpdateInfo {
  final String id;
  final String version;
  final int buildNumber;
  final String releaseNotes;
  final String windowsUrl;
  final String androidUrl;
  final bool isMandatory;
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.id,
    required this.version,
    required this.buildNumber,
    this.releaseNotes = '',
    this.windowsUrl = '',
    this.androidUrl = '',
    this.isMandatory = false,
    this.publishedAt,
  });

  factory UpdateInfo.fromMap(Map<String, dynamic> map) {
    return UpdateInfo(
      id: map['id']?.toString() ?? '',
      version: map['version']?.toString().trim() ?? '1.0.0',
      buildNumber: (map['build_number'] as num?)?.toInt() ?? 0,
      releaseNotes: map['release_notes']?.toString().trim() ?? '',
      windowsUrl: map['windows_url']?.toString().trim() ?? '',
      androidUrl: map['android_url']?.toString().trim() ?? '',
      isMandatory: map['is_mandatory'] == true || map['is_mandatory'] == 1,
      publishedAt: map['published_at'] != null
          ? DateTime.tryParse(map['published_at'].toString())
          : null,
    );
  }

  /// Returns the appropriate download URL for the current operating system.
  String? get downloadUrl {
    if (Platform.isWindows) {
      return windowsUrl.isNotEmpty ? windowsUrl : null;
    }
    if (Platform.isAndroid) {
      return androidUrl.isNotEmpty ? androidUrl : null;
    }
    return null;
  }

  /// Determines if this update is newer than the currently installed app version.
  bool isNewerThan(String currentVersion, int currentBuildNumber) {
    if (buildNumber > 0 && currentBuildNumber > 0) {
      if (buildNumber > currentBuildNumber) return true;
      if (buildNumber < currentBuildNumber) return false;
    }

    return _compareSemVer(version, currentVersion) > 0;
  }

  static int _compareSemVer(String a, String b) {
    final cleanA = a.split('+').first.replaceAll(RegExp(r'[^0-9.]'), '');
    final cleanB = b.split('+').first.replaceAll(RegExp(r'[^0-9.]'), '');

    final partsA = cleanA.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = cleanB.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < maxLen; i++) {
      final numA = i < partsA.length ? partsA[i] : 0;
      final numB = i < partsB.length ? partsB[i] : 0;
      if (numA > numB) return 1;
      if (numA < numB) return -1;
    }
    return 0;
  }
}
