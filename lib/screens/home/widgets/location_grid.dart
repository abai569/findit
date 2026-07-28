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
        final locations = provider.locations;

        if (locations.isEmpty) {
          return _buildGridItem(
            context,
            label: '添加位置',
            color: Colors.grey,
            onTap: null,
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final spacing = 8.0;
            final itemCount = 4;
            final itemWidth = (constraints.maxWidth - spacing * (itemCount - 1)) / itemCount;
            return Wrap(
              spacing: spacing,
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

                return SizedBox(
                  width: itemWidth,
                  child: _buildGridItem(
                    context,
                    label: location.name,
                    color: color,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchScreen(
                            initialLocationId: location.id,
                            initialLocationName: location.name,
                            autofocus: false,
                          ),
                        ),
                      ).then((_) => provider.loadAllData());
                    },
                  ),
                );
              }).toList(),
            );
          },
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
  return GestureDetector(
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (onTap != null ? color : Colors.grey).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
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
