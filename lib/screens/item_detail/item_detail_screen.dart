import 'dart:async';
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
  int _selectedImageIndex = 0;
  Timer? _savedMessageTimer;
  bool _showSavedMessage = false;

  @override
  void dispose() {
    _savedMessageTimer?.cancel();
    super.dispose();
  }

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
          if (_showSavedMessage) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green),
                  SizedBox(width: 8),
                  Text('修改已保存', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            _item.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (_item.imagePaths.isNotEmpty) ...[
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: InkWell(
                onTap: () => _showImagePreview(_selectedImageIndex),
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_item.imagePaths[_selectedImageIndex]),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _item.imagePaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = index == _selectedImageIndex;
                  return InkWell(
                    onTap: () => setState(() => _selectedImageIndex = index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(_item.imagePaths[index]),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
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
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_selectedImageIndex + 1} / ${_item.imagePaths.length}',
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
    final saved = await Navigator.push<bool>(
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
    setState(() {
      _item = matches.first;
      _showSavedMessage = saved == true;
      if (_selectedImageIndex >= _item.imagePaths.length) {
        _selectedImageIndex = _item.imagePaths.isEmpty
            ? 0
            : _item.imagePaths.length - 1;
      }
    });
    if (saved == true) {
      _savedMessageTimer?.cancel();
      _savedMessageTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showSavedMessage = false);
      });
    }
  }

  void _showImagePreview(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          imagePaths: _item.imagePaths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const _FullScreenGallery({
    required this.imagePaths,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.imagePaths.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) => InteractiveViewer(
          key: ValueKey(widget.imagePaths[index]),
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.file(
              File(widget.imagePaths[index]),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white,
                size: 56,
              ),
            ),
          ),
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
