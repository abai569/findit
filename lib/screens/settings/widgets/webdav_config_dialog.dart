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
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  Future<void> _loadExistingConfig() async {
    final provider = context.read<AppProvider>();
    final creds = await provider.testWebDAVConnection().then((_) => null);
    
    if (provider.hasWebDAVConfig) {
      _urlController.text = '已配置';
      _usernameController.text = '已保存';
      _passwordController.text = '********';
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WebDAV 配置'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUrlField(),
              const SizedBox(height: 16),
              _buildUsernameField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 8),
              _buildHelpText(),
            ],
          ),
        ),
      ),
      actions: [
        if (context.watch<AppProvider>().hasWebDAVConfig)
          TextButton(
            onPressed: () => _clearConfig(),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除配置'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : () => _saveConfig(),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildUrlField() {
    return TextFormField(
      controller: _urlController,
      decoration: const InputDecoration(
        labelText: 'WebDAV 服务器地址',
        hintText: 'https://dav.jianguoyun.com/dav',
        prefixIcon: Icon(Icons.cloud),
      ),
      validator: (value) {
        if (context.read<AppProvider>().hasWebDAVConfig) {
          return null;
        }
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
      decoration: const InputDecoration(
        labelText: '用户名',
        prefixIcon: Icon(Icons.person_outline),
      ),
      validator: (value) {
        if (context.read<AppProvider>().hasWebDAVConfig) {
          return null;
        }
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
        if (context.read<AppProvider>().hasWebDAVConfig) {
          return null;
        }
        if (value == null || value.trim().isEmpty) {
          return '请输入密码';
        }
        return null;
      },
    );
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
    if (!context.read<AppProvider>().hasWebDAVConfig) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<AppProvider>();
      final success = await provider.saveWebDAVConfig(
        url: _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (success) {
        final testSuccess = await provider.testWebDAVConnection();
        if (mounted) {
          if (testSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('WebDAV 配置成功，连接测试通过'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('配置已保存，但连接测试失败，请检查网络或凭证'),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.pop(context);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('配置失败，请重试'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('配置失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已清除 WebDAV 配置'),
          ),
        );
      }
    }
  }
}
