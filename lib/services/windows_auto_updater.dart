import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../config/api_client.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory;

  AppUpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isMandatory = false,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latest_version'] ?? json['version'] ?? '1.0.0',
      downloadUrl: json['download_url'] ?? json['url'] ?? '',
      releaseNotes: json['release_notes'] ?? json['notes'] ?? 'General improvements and bug fixes.',
      isMandatory: json['is_mandatory'] ?? json['mandatory'] ?? false,
    );
  }
}

class WindowsAutoUpdater {
  static const String githubRepo = 'naiyo-24/SirfBill_Printer';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    // Only execute update checking on Windows (or allow debug test)
    if (!kIsWeb && !Platform.isWindows) return null;

    try {
      // 1. Try Backend API first
      try {
        final response = await ApiClient().dio.get('/api/app-version');
        if (response.statusCode == 200 && response.data != null) {
          final updateInfo = AppUpdateInfo.fromJson(Map<String, dynamic>.from(response.data));
          final packageInfo = await PackageInfo.fromPlatform();
          if (_isNewerVersion(packageInfo.version, updateInfo.latestVersion)) {
            return updateInfo;
          }
        }
      } catch (_) {}

      // 2. Direct GitHub Releases fallback (using clean Dio client without backend headers)
      final ghResponse = await Dio().get(
        'https://api.github.com/repos/$githubRepo/releases/latest',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );

      if (ghResponse.statusCode == 200 && ghResponse.data != null) {
        final data = ghResponse.data;
        final tagName = (data['tag_name'] ?? '').toString().replaceAll('v', '').trim();
        final body = (data['body'] ?? 'New release available.').toString();
        
        final assets = data['assets'] as List? ?? [];
        String downloadUrl = '';
        for (var asset in assets) {
          final name = (asset['name'] ?? '').toString().toLowerCase();
          if (name.endsWith('.exe')) {
            downloadUrl = asset['browser_download_url'] ?? '';
            break;
          }
        }

        if (downloadUrl.isNotEmpty && tagName.isNotEmpty) {
          final packageInfo = await PackageInfo.fromPlatform();
          if (_isNewerVersion(packageInfo.version, tagName)) {
            return AppUpdateInfo(
              latestVersion: tagName,
              downloadUrl: downloadUrl,
              releaseNotes: body,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Update check skipped or failed: $e');
    }
    return null;
  }

  static bool _isNewerVersion(String current, String latest) {
    try {
      final cParts = current.split('+')[0].split('.').map(int.parse).toList();
      final lParts = latest.split('+')[0].split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final l = i < lParts.length ? lParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> showUpdateDialog(BuildContext context, AppUpdateInfo info) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: !info.isMandatory,
      builder: (ctx) => _UpdateDialog(info: info),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';

  Future<void> _startDownloadAndInstall() async {
    if (widget.info.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download URL is empty!')),
      );
      return;
    }

    // On Windows desktop, download the installer and launch it
    if (!kIsWeb && Platform.isWindows) {
      setState(() {
        _isDownloading = true;
        _progress = 0.0;
        _statusText = 'Downloading update installer...';
      });

      try {
        final tempDir = await getTemporaryDirectory();
        final isZip = widget.info.downloadUrl.toLowerCase().endsWith('.zip');
        final fileExtension = isZip ? 'zip' : 'exe';
        final filePath = '${tempDir.path}\\app-update.$fileExtension';

        await ApiClient().dio.download(
          widget.info.downloadUrl,
          filePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              setState(() {
                _progress = received / total;
                _statusText = 'Downloading: ${(_progress * 100).toStringAsFixed(0)}%';
              });
            }
          },
        );

        setState(() {
          _statusText = 'Starting update...';
        });

        final app = File(Platform.resolvedExecutable);

        if (isZip) {
          // Launch standalone updater.exe to replace running files with backup & rollback
          final updaterFile = File('${app.parent.path}\\updater.exe');
          if (await updaterFile.exists()) {
            await Process.start(
              updaterFile.path,
              [
                '--wait-pid', '$pid',
                '--install-dir', app.parent.path,
                '--package', filePath,
                '--restart-exe', app.path,
              ],
              mode: ProcessStartMode.detached,
            );
            exit(0);
          }
        }

        // Direct installer fallback
        await Process.start(filePath, [], runInShell: true, mode: ProcessStartMode.detached);
        exit(0);
      } catch (e) {
        setState(() {
          _isDownloading = false;
          _statusText = 'Error downloading update: $e';
        });
      }
    } else {
      // Fallback: open download URL in browser
      final uri = Uri.parse(widget.info.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF166534).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.system_update_rounded, color: Color(0xFF166534), size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            'New Version Available! (v${widget.info.latestVersion})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A new update is ready for SirfBill. Installing updates ensures you have the latest stability and feature enhancements.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(widget.info.releaseNotes, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 8),
              Center(child: Text(_statusText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ],
        ),
      ),
      actions: _isDownloading
          ? []
          : [
              if (!widget.info.isMandatory)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later', style: TextStyle(color: Colors.grey)),
                ),
              ElevatedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Update & Restart Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF166534),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _startDownloadAndInstall,
              ),
            ],
    );
  }
}
