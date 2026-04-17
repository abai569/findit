import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/item_category.dart';
import '../add_item/add_item_screen.dart';

class SearchScreen extends StatefulWidget {
  final int? initialLocationId;
  final String? initialLocationName;

  const SearchScreen({
    super.key,
    this.initialLocationId,
    this.initialLocationName,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryId;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppProvider>().filterByLocation(widget.initialLocationId!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialLocationName ?? '搜索'),
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_list,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索物品名称...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              if (widget.initialLocationId != null) {
                                provider.filterByLocation(widget.initialLocationId!);
                              } else {
                                provider.loadAllData();
                              }
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    provider.searchItems(value);
                  },
                ),
              ),
              if (_showFilters) _buildFilterSection(provider),
              Expanded(
                child: provider.items.isEmpty
                    ? _buildEmptyState()
                    : _buildItemList(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('全部分类'),
            selected: _selectedCategoryId == null,
            onSelected: (selected) {
              setState(() {
                _selectedCategoryId = null;
              });
              if (widget.initialLocationId != null) {
                provider.filterByLocation(widget.initialLocationId!);
              } else {
                provider.loadAllData();
              }
            },
          ),
          ...provider.categories.map<ItemCategory>((category) {
            return FilterChip(
              label: Text('${category.icon} ${category.name}'),
              selected: _selectedCategoryId == category.id,
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryId = selected ? category.id : null;
                });
                provider.filterByCategory(category.id!);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '没有找到相关物品',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试其他关键词或添加新物品',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(AppProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: provider.items.length,
      itemBuilder: (context, index) {
        final item = provider.items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: item.imagePath != null && item.imagePath!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(item.imagePath!),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildImagePlaceholder();
                      },
                    ),
                  )
                : _buildImagePlaceholder(),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        provider.getLocationName(item.locationId),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddItemScreen(item: item),
                ),
              ).then((_) {
                provider.loadAllData();
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 24,
        color: Colors.grey[400],
      ),
    );
  }
}
