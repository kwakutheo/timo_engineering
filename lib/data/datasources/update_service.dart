import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../features/invoice/widgets/update_dialog.dart';
import '../models/update_info.dart';

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  bool _isChecking = false;

  /// Queries Supabase for the latest published update for the current platform.
  /// Returns [UpdateInfo] if a newer version is available, or null otherwise.
  Future<UpdateInfo?> checkForUpdate() async {
    if (_isChecking) return null;
    _isChecking = true;

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('app_updates')
          .select()
          .order('build_number', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      final update = UpdateInfo.fromMap(response.first as Map<String, dynamic>);
      if (update.downloadUrl == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (update.isNewerThan(currentVersion, currentBuild)) {
        return update;
      }
      return null;
    } catch (e) {
      debugPrint('Update check note (offline-safe): $e');
      return null;
    } finally {
      _isChecking = false;
    }
  }

  /// Downloads and launches the update installer for the current OS.
  Future<void> downloadAndInstall({
    required UpdateInfo update,
    required void Function(double progress, String status) onProgress,
  }) async {
    final downloadUrl = update.downloadUrl;
    if (downloadUrl == null) {
      throw Exception('No download URL available for this platform.');
    }

    final tempDir = await getTemporaryDirectory();
    final ext = Platform.isWindows ? 'exe' : 'apk';
    final safeVer = update.version.replaceAll(RegExp(r'[^0-9.]'), '_');
    final filePath = '${tempDir.path}${Platform.pathSeparator}timo_update_$safeVer.$ext';

    final targetFile = File(filePath);
    if (await targetFile.exists()) {
      try {
        await targetFile.delete();
      } catch (_) {}
    }

    onProgress(0.0, 'Connecting to download server...');

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(downloadUrl));
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw Exception(
          'Download failed with HTTP status code ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength;
      final sink = targetFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final progress = contentLength > 0
            ? (receivedBytes / contentLength).clamp(0.0, 1.0)
            : 0.0;

        final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
        final mbTotal = contentLength > 0
            ? (contentLength / (1024 * 1024)).toStringAsFixed(1)
            : '?';

        onProgress(progress, 'Downloading: $mbReceived MB / $mbTotal MB');
      }

      await sink.flush();
      await sink.close();

      onProgress(1.0, 'Launching installer...');

      if (Platform.isWindows) {
        // Launch installer detached and exit the current app process
        await Process.start(
          targetFile.path,
          [],
          runInShell: true,
          mode: ProcessStartMode.detached,
        );
        exit(0);
      } else if (Platform.isAndroid) {
        // Prompt the Android OS to install the downloaded APK
        final result = await OpenFilex.open(
          targetFile.path,
          type: 'application/vnd.android.package-archive',
        );

        if (result.type != ResultType.done) {
          throw Exception(result.message);
        }
      }
    } finally {
      client.close();
    }
  }

  /// Checks for updates and displays the Update Dialog if an update is available.
  /// If [showNoUpdateNotice] is true, shows a snackbar when already up to date.
  Future<void> checkAndPrompt(
    BuildContext context, {
    bool showNoUpdateNotice = false,
  }) async {
    final update = await checkForUpdate();
    if (!context.mounted) return;

    if (update != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: !update.isMandatory,
        builder: (_) => UpdateDialog(update: update),
      );
    } else if (showNoUpdateNotice) {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "You are using the latest version (v${packageInfo.version}).",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
