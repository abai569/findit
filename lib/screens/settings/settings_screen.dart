import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/family_sync_service.dart';
import '../home/widgets/home_ad_banner.dart';
import 'data_management_screen.dart';
import 'widgets/backup_dialog.dart';
import 'widgets/family_sync_dialog.dart';
import 'widgets/restore_dialog.dart';
import 'widgets/webdav_config_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HomeAdBanner(placement: 'settings_top'),
            const SizedBox(height: 16),
            _buildStatsCard(provider),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('管理中心'),
                subtitle: const Text('备份与分类管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManagementCenterScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.family_restroom),
                title: const Text('家庭同步'),
                subtitle: Text(
                  !FamilySyncService.isConfigured
                      ? '未配置云端'
                      : provider.familySync.currentUser == null
                          ? '未登录'
                          : '已登录',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FamilySyncScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                subtitle: const Text('版本与应用信息'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManagementCenterScreen extends StatelessWidget {
  const ManagementCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理中心')),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.category_outlined),
                      title: const Text('物品分类'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategoryManagementScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('位置分类'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LocationManagementScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.backup_outlined),
                      title: const Text('立即备份'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _requireWebDAV(
                        context,
                        provider,
                        () => showDialog(
                          context: context,
                          builder: (_) => const BackupDialog(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('恢复数据'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _requireWebDAV(
                        context,
                        provider,
                        () => showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const RestoreDialog(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('同步设置'),
                      subtitle: Text(
                        provider.hasWebDAVConfig ? 'WebDAV 已配置' : 'WebDAV 未配置',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => const WebDAVConfigDialog(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requireWebDAV(
    BuildContext context,
    AppProvider provider,
    VoidCallback action,
  ) async {
    if (provider.hasWebDAVConfig) {
      action();
      return;
    }
    final openConfig = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cloud_off_outlined),
        title: const Text('尚未配置 WebDAV'),
        content: const Text('请先完成 WebDAV 配置，再使用备份或恢复功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('去配置'),
          ),
        ],
      ),
    );
    if (openConfig == true && context.mounted) {
      final configured = await showDialog<bool>(
        context: context,
        builder: (_) => const WebDAVConfigDialog(),
      );
      if (configured == true && context.mounted) {
        action();
      }
    }
  }
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '物品管家',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) => Text(
                      '版本：${snapshot.data?.version ?? (snapshot.hasError ? '未知' : '读取中')}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('记录物品位置，快速查找\n支持家庭同步与 WebDAV 备份恢复'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildStatsCard(AppProvider provider) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            Icons.inventory_2,
            '物品',
            provider.items.length,
            const Color(0xFF2878B5),
          ),
          _StatItem(
            Icons.location_on,
            '位置',
            provider.locations.length,
            const Color(0xFF2E8B57),
          ),
          _StatItem(
            Icons.category,
            '分类',
            provider.categories.length,
            const Color(0xFFD97706),
          ),
          _StatItem(
            Icons.backup,
            '备份',
            provider.backupHistory.length,
            const Color(0xFF168A8A),
          ),
        ],
      ),
    ),
  );
}

class _StatItem extends StatelessWidget {
  const _StatItem(this.icon, this.label, this.value, this.color);

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}
