import 'package:flutter/material.dart';

class ColorPickerSheet extends StatelessWidget {
  final Color? selectedColor;
  final Function(Color?) onSelect;

  const ColorPickerSheet({
    super.key, 
    required this.selectedColor, 
    required this.onSelect
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    final options = [
      {'name': 'Default', 'color': null},
      {'name': 'Blue', 'color': Colors.blue},
      {'name': 'Green', 'color': Colors.green},
      {'name': 'Orange', 'color': Colors.orange},
      {'name': 'Red', 'color': Colors.red},
      {'name': 'Pink', 'color': Colors.pink},
      {'name': 'Teal', 'color': Colors.teal},
      {'name': 'Lime', 'color': Colors.lime},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Color Scheme", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: options.length,
              itemBuilder: (ctx, i) {
                // FIXED: Typos 'finalitem' -> 'final item'
                final item = options[i];
                final color = item['color'] as Color?;
                final name = item['name'] as String;
                
                // FIXED: Use toARGB32() instead of deprecated .value
                final isSelected = (selectedColor?.toARGB32() == color?.toARGB32());
                final displayColor = color ?? cs.primary;

                return InkWell(
                  onTap: () {
                    onSelect(color);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected ? Border.all(color: displayColor, width: 2) : null,
                      // Note: Ensure you are using Flutter 3.27+ for withValues
                      boxShadow: isSelected ? [
                        BoxShadow(color: displayColor.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)
                      ] : [],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: displayColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: displayColor.withValues(alpha: 0.4), blurRadius: 4)],
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          name, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: isSelected ? displayColor : cs.onSurface
                          )
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}