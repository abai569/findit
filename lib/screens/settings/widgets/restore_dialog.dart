import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';

class RestoreDialog extends StatefulWidget {
  const RestoreDialog({super.key});

  @override
  State<RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<RestoreDialog> {
  bool _isLoading = true;
  bool _isRestoring = false;
  List<String> _backups = [];
  String? _selectedBackup;
  String? _loadError;
  String? _restoreMessage;
  bool _restoreSucceeded = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final provider = context.read<AppProvider>();
      _backups = await provider.listBackups();
      if (_backups.isNotEmpty) {
        _selectedBackup = _backups.first;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = '加载备份列表失败：$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isRestoring,
      child: AlertDialog(
        title: const Text('恢复数据'),
        content: SizedBox(
          width: double.maxFinite,
          child: _buildContent(),
        ),
        actions: [
          if (!_isRestoring)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_restoreMessage == null ? '取消' : '关闭'),
            ),
          if (!_isRestoring && _restoreMessage == null)
            FilledButton.icon(
              onPressed: (_isLoading ||
                      _backups.isEmpty ||
                      _selectedBackup == null)
                  ? null
                  : () => _startRestore(),
              icon: const Icon(Icons.restore),
              label: const Text('恢复'),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isRestoring) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('恢复中...'),
        ],
      );
    }
    if (_restoreMessage != null) return _buildRestoreResult();
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) return _buildLoadError();
    if (_backups.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('没有找到备份文件', style: TextStyle(color: Colors.grey[600])),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('选择要恢复的备份:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _backups.length,
            itemBuilder: (context, index) {
              final backup = _backups[index];
              return RadioListTile<String>(
                value: backup,
                groupValue: _selectedBackup,
                onChanged: (value) => setState(() => _selectedBackup = value),
                title: Text(
                  backup,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '恢复将覆盖当前所有数据，请谨慎操作',
                  style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadError() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: colorScheme.error, size: 40),
        const SizedBox(height: 12),
        Text(
          _loadError!,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.error),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loadBackups,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ],
    );
  }

  Widget _buildRestoreResult() {
    final color = _restoreSucceeded
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _restoreSucceeded ? Icons.check_circle_outline : Icons.error_outline,
          color: color,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          _restoreMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(color: color),
        ),
      ],
    );
  }

  Future<void> _startRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text(
          '恢复操作将覆盖当前所有数据！\n\n请确认你已经做好备份，确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _isRestoring = true;
      _restoreMessage = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final result = await provider.restoreFromWebDAV(_selectedBackup);

      if (mounted) {
        setState(() {
          _restoreSucceeded = true;
          _restoreMessage = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _restoreSucceeded = false;
          _restoreMessage = '恢复失败：$e';
        });
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }
}
