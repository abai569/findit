import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _loadFamily();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作成功')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
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
        content: const Text('当前版本未配置 Supabase。构建时需要注入 SUPABASE_URL 和 SUPABASE_ANON_KEY。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ],
      );
    }

    final user = sync.currentUser;
    return AlertDialog(
      title: const Text('家庭同步'),
      content: SingleChildScrollView(
        child: _busy
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : user == null
                ? _buildAuthForm(provider)
                : _family == null
                    ? _buildFamilyForm(provider)
                    : _buildJoinedFamily(provider),
      ),
      actions: [
        if (user != null)
          TextButton(
            onPressed: () => _run(sync.signOut),
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
          decoration: const InputDecoration(labelText: '密码（至少 6 位）'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => _run(() => provider.familySync.signIn(
                      _emailController.text.trim(),
                      _passwordController.text,
                    )),
                child: const Text('登录'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _run(() => provider.familySync.signUp(
                      _emailController.text.trim(),
                      _passwordController.text,
                    )),
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
          onPressed: () => _run(() async {
            final code = await provider.familySync.createFamily(
              _familyNameController.text.trim(),
            );
            if (mounted) {
              await _showCode(code);
            }
          }),
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
          onPressed: () => _run(() => provider.familySync.joinFamily(
                _inviteController.text,
              )),
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
          _family?['name'] as String? ?? '家庭',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SelectableText('邀请码：${_family?['invite_code'] ?? ''}'),
        const SizedBox(height: 12),
        Text('成员：${members.length} 人'),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _run(provider.syncFamily),
            icon: const Icon(Icons.sync),
            label: const Text('立即同步'),
          ),
        ),
      ],
    );
  }

  Future<void> _showCode(String code) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('家庭创建成功'),
        content: SelectableText('邀请码：$code\n\n把邀请码发给家庭成员即可加入。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
        ],
      ),
    );
  }
}
