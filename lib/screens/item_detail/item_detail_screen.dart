import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item.dart';
import '../../providers/app_provider.dart';
import '../add_item/add_item_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final Item item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Item _item = widget.item;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('物品详情'),
        actions: [
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editItem(provider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _item.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (_item.imagePaths.isNotEmpty) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: _item.imagePaths.length,
                itemBuilder: (context, index) {
                  final image = File(_item.imagePaths[index]);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => _showImagePreview(image),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 48),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_item.imagePaths.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '共 ${_item.imagePaths.length} 张照片，左右滑动查看',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
          ],
          const SizedBox(height: 20),
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: '存放位置',
            value: provider.getLocationName(_item.locationId),
          ),
          _DetailRow(
            icon: Icons.category_outlined,
            label: '分类',
            value: provider.getCategoryName(_item.categoryId) ?? '未分类',
          ),
          _DetailRow(
            icon: Icons.notes_outlined,
            label: '备注',
            value: _item.notes?.trim().isNotEmpty == true ? _item.notes! : '无',
          ),
        ],
      ),
    );
  }

  Future<void> _editItem(AppProvider provider) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddItemScreen(item: _item)),
    );
    await provider.loadAllData();
    if (!mounted) return;
    final matches = provider.items.where((item) => item.id == _item.id);
    if (matches.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _item = matches.first);
  }

  void _showImagePreview(File image) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(image, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
