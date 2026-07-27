import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/app_provider.dart';
import 'widgets/webdav_config_dialog.dart';
import 'widgets/backup_dialog.dart';
import 'widgets/restore_dialog.dart';
import 'data_management_screen.dart';
import 'widgets/family_sync_dialog.dart';
import '../../services/family_sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('数据管理'),
              _buildManagementCard(context, provider),
              const SizedBox(height: 24),
              _buildSectionHeader('统计信息'),
              _buildStatsCard(provider),
              const SizedBox(height: 24),
              _buildSectionHeader('关于'),
              _buildAboutCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildManagementCard(BuildContext context, AppProvider provider) {
    return Card(
      child: Column(
        children: [
          _buildGroupLabel('同步'),
          _buildFamilySyncTile(context, provider),
          const Divider(height: 1, indent: 56),
          _buildGroupLabel('备份'),
          _buildBackupTile(context, provider),
          const Divider(height: 1, indent: 56),
          _buildRestoreTile(context, provider),
          const Divider(height: 1, indent: 56),
          _buildWebDAVTile(context, provider),
          const Divider(height: 1),
          _buildGroupLabel('分类'),
          _buildCategoryTile(
            context,
            title: '位置分类',
            subtitle: '${provider.locations.length} 个位置',
            icon: Icons.location_on_outlined,
            initialIndex: 0,
          ),
          const Divider(height: 1, indent: 56),
          _buildCategoryTile(
            context,
            title: '物品分类',
            subtitle: '${provider.categories.length} 个分类',
            icon: Icons.category_outlined,
            initialIndex: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFamilySyncTile(BuildContext context, AppProvider provider) {
    final sync = provider.familySync;
    final status = !FamilySyncService.isConfigured
        ? '未配置云端'
        : sync.currentUser == null
            ? '未登录'
            : '已登录，可进行家庭同步';
    return ListTile(
      leading: Icon(
        Icons.family_restroom,
        color: sync.currentUser == null ? Colors.grey : Colors.green,
      ),
      title: const Text('家庭同步'),
      subtitle: Text(status),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await showDialog(
          context: context,
          builder: (_) => const FamilySyncDialog(),
        );
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildWebDAVTile(BuildContext context, AppProvider provider) {
    return ListTile(
      leading: Icon(
        Icons.settings_outlined,
        color: provider.hasWebDAVConfig ? Colors.green : Colors.grey,
      ),
      title: const Text('同步设置'),
      subtitle: Text(
        provider.hasWebDAVConfig ? 'WebDAV 已配置' : '配置 WebDAV 备份服务',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => const WebDAVConfigDialog(),
        );
      },
    );
  }

  Widget _buildBackupTile(BuildContext context, AppProvider provider) {
    return ListTile(
      leading: const Icon(Icons.backup_outlined),
      title: const Text('立即备份'),
      subtitle: const Text('备份数据到 WebDAV'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (!provider.hasWebDAVConfig) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请先配置 WebDAV'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        showDialog(
          context: context,
          builder: (context) => const BackupDialog(),
        );
      },
    );
  }

  Widget _buildRestoreTile(BuildContext context, AppProvider provider) {
    return ListTile(
      leading: const Icon(Icons.restore),
      title: const Text('恢复数据'),
      subtitle: const Text('从 WebDAV 恢复备份'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (!provider.hasWebDAVConfig) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请先配置 WebDAV'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        showDialog(
          context: context,
          builder: (context) => const RestoreDialog(),
        );
      },
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required int initialIndex,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DataManagementScreen(initialIndex: initialIndex),
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(AppProvider provider) {
    final itemCount = provider.items.length;
    final locationCount = provider.locations.length;
    final categoryCount = provider.categories.length;
    final backupCount = provider.backupHistory.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.inventory_2,
                  label: '物品数',
                  value: itemCount.toString(),
                  color: Colors.blue,
                ),
                _buildStatItem(
                  icon: Icons.location_on,
                  label: '位置数',
                  value: locationCount.toString(),
                  color: Colors.green,
                ),
                _buildStatItem(
                  icon: Icons.category,
                  label: '分类数',
                  value: categoryCount.toString(),
                  color: Colors.orange,
                ),
                _buildStatItem(
                  icon: Icons.backup,
                  label: '备份数',
                  value: backupCount.toString(),
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '物品管家',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) {
                final version = snapshot.hasError
                    ? '未知'
                    : snapshot.data?.version ?? '读取中';
                return Text(
                  '版本：$version',
                  style: TextStyle(color: Colors.grey[600]),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              '记录物品位置，快速查找\n支持 WebDAV 备份恢复',
              style: TextStyle(
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
