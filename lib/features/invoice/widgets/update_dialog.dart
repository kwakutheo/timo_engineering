import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/update_service.dart';
import '../../../data/models/update_info.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo update;

  const UpdateDialog({
    super.key,
    required this.update,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;
  String _currentVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _currentVersion = 'v${info.version}');
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusText = 'Starting download...';
    });

    try {
      await UpdateService.instance.downloadAndInstall(
        update: widget.update,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _statusText = status;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Update error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;

    return PopScope(
      canPop: !update.isMandatory && !_isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Icon
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: AppColors.primaryBlack,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                const Text(
                  'Update Available!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlack,
                  ),
                ),
                const SizedBox(height: 6),

                // Version comparison badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.borderGrey.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '$_currentVersion  ➔  v${update.version}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlack,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Release notes if present
                if (update.releaseNotes.isNotEmpty) ...[
                  const Text(
                    "What's New:",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.borderGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        update.releaseNotes,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryBlack,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Downloading progress or error
                if (_isDownloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 8,
                      backgroundColor: AppColors.scaffoldBg,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryYellow,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Action buttons
                Row(
                  children: [
                    if (!update.isMandatory && !_isDownloading) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textGrey,
                            side: BorderSide(
                              color: AppColors.borderGrey.withValues(alpha: 0.6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Later',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading ? null : _startDownload,
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryBlack,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          _isDownloading ? 'Updating...' : 'Update Now',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryYellow,
                          foregroundColor: AppColors.primaryBlack,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
