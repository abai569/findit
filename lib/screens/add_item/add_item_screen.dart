import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/app_provider.dart';
import '../../models/item.dart';
import '../../services/image_service.dart';

class AddItemScreen extends StatefulWidget {
  final Item? item;

  const AddItemScreen({super.key, this.item});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  int? _selectedLocationId;
  int? _selectedCategoryId;
  final List<File> _imageFiles = [];
  final Set<String> _pendingImagePaths = {};
  final _imageService = ImageService();

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _notesController.text = widget.item!.notes ?? '';
      _selectedLocationId = widget.item!.locationId;
      _selectedCategoryId = widget.item!.categoryId;
      _imageFiles.addAll(widget.item!.imagePaths.map(File.new));
    }
  }

  @override
  void dispose() {
    for (final path in _pendingImagePaths) {
      unawaited(_deleteImage(path));
    }
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑物品' : '添加物品'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteItem,
              color: Colors.red,
            ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.locations.isEmpty) {
            return const Center(
              child: Text('请先添加位置'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageSection(),
                  const SizedBox(height: 24),
                  _buildNameField(),
                  const SizedBox(height: 16),
                  _buildLocationPicker(provider),
                  const SizedBox(height: 16),
                  _buildCategoryPicker(provider),
                  const SizedBox(height: 16),
                  _buildNotesField(),
                  const SizedBox(height: 32),
                  _buildSaveButton(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '照片（可多选）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            IconButton.filledTonal(
              onPressed: _showImageSourceDialog,
              tooltip: '添加照片',
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_imageFiles.isEmpty)
          InkWell(
            onTap: _showImageSourceDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '拍照或从相册选择多张图片',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _imageFiles.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _imageFiles[index],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filled(
                        onPressed: () {
                          final removedImage = _imageFiles.removeAt(index);
                          if (_pendingImagePaths.remove(removedImage.path)) {
                            unawaited(_deleteImage(removedImage.path));
                          }
                          setState(() {});
                        },
                        tooltip: '删除照片',
                        iconSize: 18,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      minLines: 3,
      maxLines: 6,
      decoration: const InputDecoration(
        labelText: '备注（可选）',
        hintText: '记录物品特征、使用说明等',
        prefixIcon: Icon(Icons.notes_outlined),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: '物品名称',
        hintText: '例如：身份证、护照、备用钥匙',
        prefixIcon: Icon(Icons.label_outline),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入物品名称';
        }
        return null;
      },
    );
  }

  Widget _buildLocationPicker(AppProvider provider) {
    return DropdownButtonFormField<int>(
      value: _selectedLocationId,
      decoration: const InputDecoration(
        labelText: '存放位置',
        prefixIcon: Icon(Icons.location_on_outlined),
      ),
      items: provider.locations.map((location) {
        final fullPath = location.getFullPath(provider.locations);
        return DropdownMenuItem(
          value: location.id,
          child: Text(fullPath),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedLocationId = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return '请选择存放位置';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryPicker(AppProvider provider) {
    return DropdownButtonFormField<int>(
      value: _selectedCategoryId,
      decoration: const InputDecoration(
        labelText: '分类（可选）',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('未分类'),
        ),
        ...provider.categories.map((category) {
          return DropdownMenuItem<int>(
            value: category.id,
            child: Text('${category.icon} ${category.name}'),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCategoryId = value;
        });
      },
    );
  }

  Widget _buildSaveButton(AppProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: () => _saveItem(provider),
        icon: const Icon(Icons.save),
        label: Text(isEditing ? '保存修改' : '添加物品'),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final image = await _imageService.pickImage();
        if (image == null) return;
        final compressed = await _imageService.compressImage(image);
        final savedImage = compressed ?? image;
        if (mounted) {
          _pendingImagePaths.add(savedImage.path);
          setState(() => _imageFiles.add(savedImage));
        } else {
          await _imageService.deleteImage(savedImage.path);
        }
      } else {
        final images = await _imageService.pickImagesFromGallery();
        for (final image in images) {
          final compressed = await _imageService.compressImage(image) ?? image;
          if (mounted) {
            _pendingImagePaths.add(compressed.path);
            setState(() => _imageFiles.add(compressed));
          } else {
            await _deleteImage(compressed.path);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败：$e')),
        );
      }
    }
  }

  Future<void> _saveItem(AppProvider provider) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择存放位置')),
      );
      return;
    }

    try {
      if (isEditing) {
        final updatedItem = widget.item!.copyWith(
          name: _nameController.text.trim(),
          locationId: _selectedLocationId!,
          categoryId: _selectedCategoryId,
          clearCategory: _selectedCategoryId == null,
          imagePaths: _imageFiles.map((image) => image.path).toList(),
          notes: _notesController.text.trim(),
        );
        await provider.updateItem(updatedItem);
      } else {
        await provider.addItem(
          name: _nameController.text.trim(),
          locationId: _selectedLocationId!,
          categoryId: _selectedCategoryId,
          imagePaths: _imageFiles.map((image) => image.path).toList(),
          notes: _notesController.text.trim(),
        );
      }

      _pendingImagePaths.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? '修改成功' : '添加成功'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    }
  }

  Future<void> _deleteImage(String path) async {
    try {
      await _imageService.deleteImage(path);
    } catch (e) {
      debugPrint('删除图片失败：$e');
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个物品吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AppProvider>().deleteItem(widget.item!.id!);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
