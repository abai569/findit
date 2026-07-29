import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';

class WebDAVConfigDialog extends StatefulWidget {
  const WebDAVConfigDialog({super.key});

  @override
  State<WebDAVConfigDialog> createState() => _WebDAVConfigDialogState();
}

class _WebDAVConfigDialogState extends State<WebDAVConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _backupDirController = TextEditingController(text: '/findit_backups');
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isInitializing = true;
  _ConfigStatus _status = _ConfigStatus.none;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  Future<void> _loadExistingConfig() async {
    final provider = context.read<AppProvider>();
    try {
      if (provider.hasWebDAVConfig) {
        final creds = await provider.getWebDAVCredentials();
        if (!mounted || creds == null) return;
        _urlController.text = creds['url'] ?? '';
        _usernameController.text = creds['username'] ?? '';
        _passwordController.text = creds['password'] ?? '';
        if (creds['backup_dir'] != null) {
          _backupDirController.text = creds['backup_dir']!;
        }
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _backupDirController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WebDAV 配置'),
      content: IgnorePointer(
        ignoring: _isInitializing || _isLoading,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_statusMessage != null) ...[
                  _buildStatusMessage(),
                  const SizedBox(height: 16),
                ],
                _buildUrlField(),
                const SizedBox(height: 16),
                _buildUsernameField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 16),
                _buildBackupDirField(),
                const SizedBox(height: 8),
                _buildHelpText(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (context.watch<AppProvider>().hasWebDAVConfig)
          TextButton(
            onPressed: (_isLoading || _isInitializing)
                ? null
                : () => _clearConfig(),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除配置'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: (_isLoading || _isInitializing)
              ? null
              : _status == _ConfigStatus.success
                  ? () => Navigator.pop(context, true)
                  : () => _saveConfig(),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _status == _ConfigStatus.success ? '完成' : '保存并测试',
                ),
        ),
      ],
    );
  }

  Widget _buildUrlField() {
    return TextFormField(
      controller: _urlController,
      onChanged: (_) => _resetStatus(),
      decoration: const InputDecoration(
        labelText: 'WebDAV 服务器地址',
        hintText: 'https://dav.jianguoyun.com/dav',
        prefixIcon: Icon(Icons.cloud),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入 WebDAV 服务器地址';
        }
        if (!value.startsWith('http://') && !value.startsWith('https://')) {
          return '地址必须以 http:// 或 https:// 开头';
        }
        return null;
      },
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      onChanged: (_) => _resetStatus(),
      decoration: const InputDecoration(
        labelText: '用户名',
        prefixIcon: Icon(Icons.person_outline),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入用户名';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      onChanged: (_) => _resetStatus(),
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: '密码',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入密码';
        }
        return null;
      },
    );
  }

  Widget _buildBackupDirField() {
    return TextFormField(
      controller: _backupDirController,
      onChanged: (_) => _resetStatus(),
      decoration: const InputDecoration(
        labelText: '备份目录',
        hintText: '/findit_backups',
        prefixIcon: Icon(Icons.folder_outlined),
        helperText: '留空使用默认目录 /findit_backups',
      ),
      validator: (value) {
        final normalized = value?.trim() ?? '';
        if (normalized.contains('\\')) {
          return '目录请使用 / 分隔';
        }
        final segments = normalized.split('/');
        if (segments.any((segment) => segment == '.' || segment == '..')) {
          return '目录不能包含 . 或 ..';
        }
        return null;
      },
    );
  }

  Widget _buildStatusMessage() {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, foreground, background) = switch (_status) {
      _ConfigStatus.testing => (
          Icons.sync,
          colorScheme.primary,
          colorScheme.primaryContainer,
        ),
      _ConfigStatus.success => (
          Icons.check_circle_outline,
          Colors.green.shade800,
          Colors.green.shade50,
        ),
      _ConfigStatus.warning => (
          Icons.warning_amber,
          Colors.orange.shade900,
          Colors.orange.shade50,
        ),
      _ConfigStatus.error => (
          Icons.error_outline,
          colorScheme.error,
          colorScheme.errorContainer,
        ),
      _ConfigStatus.none => (
          Icons.info_outline,
          colorScheme.onSurface,
          colorScheme.surfaceContainerHighest,
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(color: foreground, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _resetStatus() {
    if (_status == _ConfigStatus.none || _isLoading) return;
    setState(() {
      _status = _ConfigStatus.none;
      _statusMessage = null;
    });
  }

  Widget _buildHelpText() {
    return Text(
      '常用 WebDAV 服务:\n'
      '• 坚果云：https://dav.jianguoyun.com/dav\n'
      '• Nextcloud: https://你的域名/remote.php/dav/files/用户名\n'
      '• 群晖 NAS: http://NAS 地址：端口号/webdav',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
        height: 1.5,
      ),
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _status = _ConfigStatus.testing;
      _statusMessage = '正在保存配置并测试连接...';
    });

    try {
      final provider = context.read<AppProvider>();
      final backupDir = _backupDirController.text.trim();
      final success = await provider.saveWebDAVConfig(
        url: _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        backupDir: backupDir.isEmpty ? null : backupDir,
      );

      if (success) {
        final testSuccess = await provider.testWebDAVConnection();
        if (mounted) {
          if (testSuccess) {
            setState(() {
              _status = _ConfigStatus.success;
              _statusMessage = 'WebDAV 配置已保存，连接测试通过。';
            });
          } else {
            await provider.clearWebDAVConfig();
            setState(() {
              _status = _ConfigStatus.warning;
              _statusMessage = '连接测试失败，配置未保存。请检查地址、用户名、密码和备份目录。';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _status = _ConfigStatus.error;
            _statusMessage = '配置保存失败，请检查输入后重试。';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _ConfigStatus.error;
          _statusMessage = '配置失败：$e';
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

  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除 WebDAV 配置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AppProvider>().clearWebDAVConfig();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

enum _ConfigStatus { none, testing, success, warning, error }
