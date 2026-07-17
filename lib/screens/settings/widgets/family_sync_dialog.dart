import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../../providers/app_provider.dart';
import '../../../services/family_sync_service.dart';

class FamilySyncDialog extends StatefulWidget {
  const FamilySyncDialog({super.key});

  @override
  State<FamilySyncDialog> createState() => _FamilySyncDialogState();
}

class _FamilySyncDialogState extends State<FamilySyncDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _familyNameController = TextEditingController(text: '我的家庭');
  final _inviteController = TextEditingController();
  Map<String, dynamic>? _family;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _familyNameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _loadFamily() async {
    final provider = context.read<AppProvider>();
    if (provider.familySync.currentUser == null) return;
    try {
      final family = await provider.familySync.getFamily();
      if (mounted) setState(() => _family = family);
    } catch (_) {}
  }

  Future<void> _run(
    Future<void> Function() action, {
    String successMessage = '操作成功',
  }) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      await _loadFamily();
      if (mounted) {
        setState(() {
          _message = successMessage;
          _messageIsError = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _cleanError(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final sync = provider.familySync;
    if (!FamilySyncService.isConfigured) {
      return AlertDialog(
        title: const Text('家庭同步'),
        content: const Text('当前版本未配置 PocketBase。构建时需要注入 POCKETBASE_URL。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ],
      );
    }

    final user = sync.currentUser;
    return AlertDialog(
      title: const Text('家庭同步'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_message != null) ...[
              _buildMessage(),
              const SizedBox(height: 12),
            ],
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            IgnorePointer(
              ignoring: _busy,
              child: Opacity(
                opacity: _busy ? 0.6 : 1,
                child: user == null
                    ? _buildAuthForm(provider)
                    : _family == null
                        ? _buildFamilyForm(provider)
                        : _buildJoinedFamily(provider),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (user != null)
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(sync.signOut, successMessage: '已退出账号'),
            child: const Text('退出账号'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    );
  }

  Widget _buildAuthForm(AppProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: '邮箱'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: '密码（至少 8 位）'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => _run(
                  () async {
                    await provider.familySync.signIn(
                      _emailController.text.trim(),
                      _passwordController.text,
                    );
                    await provider.loadAllData();
                  },
                  successMessage: '登录成功',
                ),
                child: const Text('登录'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _run(
                  () => provider.familySync.signUp(
                    _emailController.text.trim(),
                    _passwordController.text,
                  ),
                  successMessage: '注册成功，请登录',
                ),
                child: const Text('注册'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFamilyForm(AppProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('创建新家庭，或输入成员发来的邀请码。'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _familyNameController,
          decoration: const InputDecoration(labelText: '家庭名称'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _run(
            () async {
              await provider.familySync.createFamily(
                _familyNameController.text.trim(),
              );
            },
            successMessage: '家庭创建成功',
          ),
          icon: const Icon(Icons.home_work_outlined),
          label: const Text('创建家庭'),
        ),
        const Divider(height: 28),
        TextField(
          controller: _inviteController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: '邀请码'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _run(
            () async {
              await provider.familySync.joinFamily(_inviteController.text);
              await provider.loadAllData();
            },
            successMessage: '已加入家庭',
          ),
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('加入家庭'),
        ),
      ],
    );
  }

  Widget _buildJoinedFamily(AppProvider provider) {
    final members = (_family?['members'] as List? ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '家庭名称：${_family?['name'] as String? ?? '家庭'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildInviteCode(_family?['invite_code'] as String? ?? ''),
        const SizedBox(height: 12),
        Text('成员：${members.length} 人'),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _run(
              provider.syncFamily,
              successMessage: '同步完成',
            ),
            icon: const Icon(Icons.sync),
            label: const Text('立即同步'),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCode(String code) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '邀请码：$code',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: '复制邀请码',
            onPressed: () => _copyInviteCode(code),
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage() {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _messageIsError ? colorScheme.error : Colors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _messageIsError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(_message!, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  Future<void> _copyInviteCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() {
      _message = '邀请码已复制';
      _messageIsError = false;
    });
  }

  String _cleanError(Object error) {
    final message = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (message.contains('ClientException')) return '云端操作失败，请检查网络后重试';
    return message.isEmpty ? '操作失败，请稍后重试' : message;
  }
}
