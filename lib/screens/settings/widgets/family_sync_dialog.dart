import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../../services/family_sync_service.dart';

class FamilySyncScreen extends StatefulWidget {
  const FamilySyncScreen({super.key});

  @override
  State<FamilySyncScreen> createState() => _FamilySyncScreenState();
}

class _FamilySyncScreenState extends State<FamilySyncScreen> {
  Map<String, dynamic>? _family;
  bool _loading = true;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _refreshFamily();
  }

  Future<void> _refreshFamily() async {
    if (mounted) setState(() => _loading = true);
    final sync = context.read<AppProvider>().familySync;
    try {
      final family = sync.currentUser == null ? null : await sync.getFamily();
      if (mounted) setState(() => _family = family);
    } catch (error) {
      if (mounted) _setMessage(_cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      await _refreshFamily();
      if (mounted) _setMessage(successMessage);
    } catch (error) {
      if (mounted) _setMessage(_cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sync = provider.familySync;
    final user = sync.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('家庭同步')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!FamilySyncService.isConfigured)
            _buildMessageCard(
              '当前版本未配置 PocketBase，无法使用家庭同步。',
              isError: true,
            )
          else ...[
            if (_message != null) ...[
              _buildMessageCard(_message!, isError: _messageIsError),
              const SizedBox(height: 12),
            ],
            if (_busy || _loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            IgnorePointer(
              ignoring: _busy || _loading,
              child: Opacity(
                opacity: _busy || _loading ? 0.6 : 1,
                child: user == null
                    ? _buildSignedOutOptions(provider)
                    : _family == null
                        ? _buildNoFamilyOptions(provider)
                        : _buildJoinedOptions(provider),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignedOutOptions(AppProvider provider) {
    return _buildOptionsCard([
      ListTile(
        leading: const Icon(Icons.login),
        title: const Text('登录账号'),
        subtitle: const Text('登录已有家庭同步账号'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showAuthDialog(provider, register: false),
      ),
      ListTile(
        leading: const Icon(Icons.person_add_outlined),
        title: const Text('注册账号'),
        subtitle: const Text('创建新的家庭同步账号'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showAuthDialog(provider, register: true),
      ),
    ]);
  }

  Widget _buildNoFamilyOptions(AppProvider provider) {
    final email = provider.familySync.currentUser?.getStringValue('email') ?? '';
    return _buildOptionsCard([
      ListTile(
        leading: const Icon(Icons.home_work_outlined),
        title: const Text('创建家庭'),
        subtitle: const Text('创建一个新的共享家庭'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showCreateFamilyDialog(provider),
      ),
      ListTile(
        leading: const Icon(Icons.group_add_outlined),
        title: const Text('加入家庭'),
        subtitle: const Text('使用邀请码加入已有家庭'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showJoinFamilyDialog(provider),
      ),
      ListTile(
        leading: const Icon(Icons.manage_accounts_outlined),
        title: const Text('账号信息'),
        subtitle: Text(email),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showAccountDialog(provider),
      ),
    ]);
  }

  Widget _buildJoinedOptions(AppProvider provider) {
    final members = _family?['members'] as List? ?? const [];
    final inviteCode = _family?['invite_code'] as String? ?? '';
    return _buildOptionsCard([
      ListTile(
        leading: const Icon(Icons.home_outlined),
        title: const Text('家庭信息'),
        subtitle: Text(_family?['name'] as String? ?? '家庭'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _showFamilyInfo,
      ),
      ListTile(
        leading: const Icon(Icons.key_outlined),
        title: const Text('邀请码'),
        subtitle: Text(inviteCode),
        trailing: const Icon(Icons.copy_outlined),
        onTap: () => _copyInviteCode(inviteCode),
      ),
      ListTile(
        leading: const Icon(Icons.groups_outlined),
        title: const Text('家庭成员'),
        subtitle: Text('${members.length} 人'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showMembers(members),
      ),
      ListTile(
        leading: const Icon(Icons.sync),
        title: const Text('立即同步'),
        subtitle: const Text('同步位置、分类、物品和照片'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _run(
          provider.syncFamily,
          successMessage: '家庭数据同步完成',
        ),
      ),
      ListTile(
        leading: const Icon(Icons.manage_accounts_outlined),
        title: const Text('账号管理'),
        subtitle: Text(
          provider.familySync.currentUser?.getStringValue('email') ?? '',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showAccountDialog(provider),
      ),
    ]);
  }

  Widget _buildOptionsCard(List<Widget> tiles) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            tiles[index],
            if (index < tiles.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageCard(String message, {required bool isError}) {
    final color = isError ? Theme.of(context).colorScheme.error : Colors.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  Future<void> _showAuthDialog(
    AppProvider provider, {
    required bool register,
  }) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(register ? '注册账号' : '登录账号'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '邮箱'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码（至少 8 位）'),
            ),
            if (register) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(register ? '注册' : '登录'),
          ),
        ],
      ),
    );
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmation = confirmController.text;
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    if (submitted != true) return;
    if (!mounted) return;
    if (register && password != confirmation) {
      _setMessage('两次输入的密码不一致', isError: true);
      return;
    }
    await _run(
      () async {
        if (register) {
          await provider.familySync.signUp(email, password);
        } else {
          await provider.familySync.signIn(email, password);
          await provider.loadAllData();
        }
      },
      successMessage: register ? '注册成功，请登录' : '登录成功',
    );
  }

  Future<void> _showCreateFamilyDialog(AppProvider provider) async {
    final controller = TextEditingController(text: '我的家庭');
    final submitted = await _showInputDialog(
      title: '创建家庭',
      label: '家庭名称',
      controller: controller,
      confirmText: '创建',
    );
    final name = controller.text.trim();
    controller.dispose();
    if (!submitted) return;
    if (!mounted) return;
    await _run(
      () async {
        await provider.familySync.createFamily(name);
        await provider.loadAllData();
      },
      successMessage: '家庭创建成功',
    );
  }

  Future<void> _showJoinFamilyDialog(AppProvider provider) async {
    final controller = TextEditingController();
    final submitted = await _showInputDialog(
      title: '加入家庭',
      label: '邀请码',
      controller: controller,
      confirmText: '加入',
      capitalization: TextCapitalization.characters,
    );
    final code = controller.text.trim();
    controller.dispose();
    if (!submitted) return;
    if (!mounted) return;
    await _run(
      () async {
        await provider.familySync.joinFamily(code);
        await provider.loadAllData();
      },
      successMessage: '已加入家庭',
    );
  }

  Future<bool> _showInputDialog({
    required String title,
    required String label,
    required TextEditingController controller,
    required String confirmText,
    TextCapitalization capitalization = TextCapitalization.none,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              textCapitalization: capitalization,
              decoration: InputDecoration(labelText: label),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showAccountDialog(AppProvider provider) async {
    final email = provider.familySync.currentUser?.getStringValue('email') ?? '';
    final signOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('账号信息'),
        content: Text('邮箱：$email'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (signOut == true && mounted) {
      await _run(
        () async {
          await provider.familySync.signOut();
          await provider.loadAllData();
        },
        successMessage: '已退出账号',
      );
    }
  }

  Future<void> _showFamilyInfo() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('家庭信息'),
        content: Text('家庭名称：${_family?['name'] as String? ?? '家庭'}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMembers(List members) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('家庭成员'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final member = Map<String, dynamic>.from(members[index] as Map);
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(member['role'] as String? ?? 'member'),
                subtitle: Text(member['user'] as String? ?? ''),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyInviteCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _setMessage('邀请码已复制');
  }

  String _cleanError(Object error) {
    final message = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (message.contains('ClientException')) return '云端操作失败，请检查网络后重试';
    return message.isEmpty ? '操作失败，请稍后重试' : message;
  }
}
