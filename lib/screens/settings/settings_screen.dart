import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/app_provider.dart';
import 'widgets/webdav_config_dialog.dart';
import 'widgets/backup_dialog.dart';
import 'widgets/restore_dialog.dart';
import 'data_management_screen.dart';

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
              _buildSectionHeader('数据备份'),
              _buildWebDAVCard(context, provider),
              const SizedBox(height: 8),
              _buildBackupCard(context, provider),
              const SizedBox(height: 8),
              _buildRestoreCard(context, provider),
              const SizedBox(height: 24),
              _buildSectionHeader('数据管理'),
              _buildDataManagementCard(context),
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

  Widget _buildWebDAVCard(BuildContext context, AppProvider provider) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: provider.hasWebDAVConfig
              ? Colors.green[100]
              : Colors.grey[200],
          child: Icon(
            Icons.cloud,
            color: provider.hasWebDAVConfig ? Colors.green : Colors.grey,
          ),
        ),
        title: const Text('WebDAV 设置'),
        subtitle: Text(
          provider.hasWebDAVConfig ? '已配置' : '未配置',
          style: TextStyle(
            color: provider.hasWebDAVConfig ? Colors.green : Colors.grey,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => const WebDAVConfigDialog(),
          );
        },
      ),
    );
  }

  Widget _buildBackupCard(BuildContext context, AppProvider provider) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: const Icon(
            Icons.backup,
            color: Colors.blue,
          ),
        ),
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
      ),
    );
  }

  Widget _buildRestoreCard(BuildContext context, AppProvider provider) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange[100],
          child: const Icon(
            Icons.restore,
            color: Colors.orange,
          ),
        ),
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
      ),
    );
  }

  Widget _buildDataManagementCard(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.tune)),
        title: const Text('位置和分类管理'),
        subtitle: const Text('自定义位置和分类'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DataManagementScreen()),
          );
        },
      ),
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
                final buildNumber = snapshot.data?.buildNumber;
                return Text(
                  '版本：$version${buildNumber == null || buildNumber.isEmpty ? '' : '+$buildNumber'}',
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
