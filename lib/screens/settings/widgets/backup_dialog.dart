import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';

class BackupDialog extends StatefulWidget {
  const BackupDialog({super.key});

  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  bool _isBackingUp = false;
  String? _lastBackupTime;
  int? _lastBackupVersion;

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    final provider = context.read<AppProvider>();
    final metadata = await provider.listBackups();
    if (metadata.isNotEmpty) {
      setState(() {
        _lastBackupTime = metadata.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('备份数据'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '备份说明:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildInfoItem('• 数据将加密后上传到 WebDAV'),
          _buildInfoItem('• 自动增量备份，节省空间'),
          _buildInfoItem('• 保留最近 5 个备份版本'),
          _buildInfoItem('• 每次添加/修改后自动备份'),
          const SizedBox(height: 16),
          if (_lastBackupTime != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '最新备份：$_lastBackupTime',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _isBackingUp ? null : () => _startBackup(),
          icon: _isBackingUp
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.backup),
          label: Text(_isBackingUp ? '备份中...' : '立即备份'),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[700],
          height: 1.5,
        ),
      ),
    );
  }

  Future<void> _startBackup() async {
    setState(() {
      _isBackingUp = true;
    });

    try {
      final provider = context.read<AppProvider>();
      final result = await provider.manualBackup();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            content: Text(result),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('完成'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Icon(
              Icons.error,
              color: Colors.red,
              size: 48,
            ),
            content: Text('备份失败：$e'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }
}
