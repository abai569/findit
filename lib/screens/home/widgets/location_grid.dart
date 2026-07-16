import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../../search/search_screen.dart';

class LocationGrid extends StatelessWidget {
  const LocationGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final locations = provider.locations.take(6).toList();

        if (locations.isEmpty) {
          return _buildGridItem(
            context,
            label: '添加位置',
            color: Colors.grey,
            onTap: null,
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: locations.asMap().entries.map((entry) {
            final index = entry.key;
            final location = entry.value;
            final colors = [
              Colors.blue,
              Colors.green,
              Colors.orange,
              Colors.purple,
              Colors.teal,
              Colors.pink,
            ];
            final color = colors[index % colors.length];

            return _buildGridItem(
              context,
              label: location.name,
              color: color,
              onTap: () {
                provider.filterByLocation(location.id!);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchScreen(
                      initialLocationId: location.id,
                      initialLocationName: location.name,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGridItem(
    BuildContext context, {
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: (onTap != null ? color : Colors.grey).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: onTap != null ? color : Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ),
    );
  }
}
