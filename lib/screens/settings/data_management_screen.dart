import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item_category.dart';
import '../../models/location.dart';
import '../../providers/app_provider.dart';

class DataManagementScreen extends StatelessWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('位置和分类'),
          bottom: const TabBar(
            tabs: [Tab(text: '位置'), Tab(text: '分类')],
          ),
        ),
        body: const TabBarView(
          children: [_LocationTab(), _CategoryTab()],
        ),
      ),
    );
  }
}

class _LocationTab extends StatelessWidget {
  const _LocationTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) => _ManagementList(
        emptyText: '暂无位置',
        onAdd: () => _showLocationDialog(context),
        children: provider.locations
            .map(
              (location) => ListTile(
                title: Text(location.getFullPath(provider.locations)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '重命名',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showLocationDialog(context, location),
                    ),
                    IconButton(
                      tooltip: '删除',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirmed = await _confirmDelete(
                          context,
                          '删除位置',
                          '确定删除“${location.name}”吗？',
                        );
                        if (!confirmed) return;
                        try {
                          await provider.deleteLocation(location.id!);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _showLocationDialog(BuildContext context, [Location? location]) async {
    final controller = TextEditingController(text: location?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(location == null ? '新增位置' : '重命名位置'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(labelText: '位置名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (name == null || name.isEmpty || !context.mounted) return;
    final provider = context.read<AppProvider>();
    try {
      if (location == null) {
        await provider.addLocation(name);
      } else {
        await provider.updateLocation(location, name);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) => _ManagementList(
        emptyText: '暂无分类',
        onAdd: () => _showCategoryDialog(context),
        children: provider.categories
            .map(
              (category) => ListTile(
                leading: Text(category.icon, style: const TextStyle(fontSize: 24)),
                title: Text(category.name),
                subtitle: Text(category.color),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '编辑',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showCategoryDialog(context, category),
                    ),
                    IconButton(
                      tooltip: '删除',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirmed = await _confirmDelete(
                          context,
                          '删除分类',
                          '删除“${category.name}”后，关联物品将变为未分类。',
                        );
                        if (!confirmed) return;
                        try {
                          await provider.deleteCategory(category.id!);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _showCategoryDialog(
    BuildContext context, [ItemCategory? category]
  ) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final iconController = TextEditingController(text: category?.icon ?? '📦');
    final colorController = TextEditingController(text: category?.color ?? '#607D8B');
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? '新增分类' : '编辑分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, maxLength: 30, decoration: const InputDecoration(labelText: '名称')),
            TextField(controller: iconController, maxLength: 2, decoration: const InputDecoration(labelText: '图标')),
            TextField(controller: colorController, decoration: const InputDecoration(labelText: '颜色，例如 #607D8B')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, [
              nameController.text.trim(), iconController.text.trim(), colorController.text.trim()
            ]),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      iconController.dispose();
      colorController.dispose();
    });
    if (result == null || result[0].isEmpty || !context.mounted) return;
    final color = result[2].toUpperCase();
    if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(color)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('颜色格式应为 #RRGGBB，例如 #607D8B')),
      );
      return;
    }
    final provider = context.read<AppProvider>();
    try {
      if (category == null) {
        await provider.addCategory(
          name: result[0],
          icon: result[1].isEmpty ? '📦' : result[1],
          color: color,
        );
      } else {
        await provider.updateCategory(
          category,
          name: result[0],
          icon: result[1].isEmpty ? '📦' : result[1],
          color: color,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}

Future<bool> _confirmDelete(
  BuildContext context,
  String title,
  String message,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      ) ??
      false;
}

class _ManagementList extends StatelessWidget {
  final String emptyText;
  final VoidCallback onAdd;
  final List<Widget> children;

  const _ManagementList({required this.emptyText, required this.onAdd, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('新增')),
        ),
        const SizedBox(height: 12),
        if (children.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(emptyText)))
        else ...children,
      ],
    );
  }
}
