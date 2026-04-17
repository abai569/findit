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
  int? _selectedLocationId;
  int? _selectedCategoryId;
  File? _imageFile;
  final _imageService = ImageService();

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _selectedLocationId = widget.item!.locationId;
      _selectedCategoryId = widget.item!.categoryId;
      if (widget.item!.imagePath != null && widget.item!.imagePath!.isNotEmpty) {
        _imageFile = File(widget.item!.imagePath!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    return Center(
      child: GestureDetector(
        onTap: _showImageSourceDialog,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: _imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _imageFile!,
                    fit: BoxFit.cover,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击拍照或选择图片',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
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
          return DropdownMenuItem(
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
            if (_imageFile != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除图片', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imageFile = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      File? image;
      if (source == ImageSource.camera) {
        image = await _imageService.pickImage();
      } else {
        image = await _imageService.pickImageFromGallery();
      }

      if (image != null) {
        final compressed = await _imageService.compressImage(image);
        setState(() {
          _imageFile = compressed ?? image;
        });
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
          imagePath: _imageFile?.path,
        );
        await provider.updateItem(updatedItem);
      } else {
        await provider.addItem(
          name: _nameController.text.trim(),
          locationId: _selectedLocationId!,
          categoryId: _selectedCategoryId,
          imagePath: _imageFile?.path,
        );
      }

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
