import 'package:augur/ui/utils/app_colors.dart';
import 'package:flutter/material.dart';

class HeightSelectionDrawer extends StatelessWidget {
  final int waypointIndex;
  final double currentHeight;
  final ValueChanged<double> onHeightChanged;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  const HeightSelectionDrawer({
    super.key,
    required this.waypointIndex,
    required this.currentHeight,
    required this.onHeightChanged,
    required this.onClose,
    required this.onDelete,
  });

  void _adjustHeight(double adjustment) {
    final newHeight = (currentHeight + adjustment).clamp(5.0, 100.0);
    onHeightChanged(newHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 10,
      child: Container(
        width: 220,
        height: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 10,
              offset: const Offset(-2, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Waypoint ${waypointIndex + 1} Info',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Altitude Section
                    const Text(
                      'ALTITUDE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Current height display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${currentHeight.toInt()}m',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Height adjustment buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // -5 button
                        ElevatedButton(
                          onPressed: currentHeight > 10.0
                              ? () => _adjustHeight(-5.0)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[400],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(50, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('-5',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),

                        // -1 button
                        ElevatedButton(
                          onPressed: currentHeight > 5.0
                              ? () => _adjustHeight(-1.0)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[300],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(50, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('-1',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),

                        // +1 button
                        ElevatedButton(
                          onPressed: currentHeight < 100.0
                              ? () => _adjustHeight(1.0)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[300],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(50, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('+1',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),

                        // +5 button
                        ElevatedButton(
                          onPressed: currentHeight < 95.0
                              ? () => _adjustHeight(5.0)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[400],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(50, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('+5',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Quick presets
                    const Text(
                      'QUICK PRESETS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [10.0, 25.0, 50.0, 80.0].map((height) {
                        final isSelected = currentHeight == height;
                        return ElevatedButton(
                          onPressed: () => onHeightChanged(height),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected
                                ? const Color(0xFF4CAF50)
                                : Colors.grey[200],
                            foregroundColor:
                                isSelected ? Colors.white : Colors.black54,
                            minimumSize: const Size(60, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(
                            '${height.toInt()}m',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const Spacer(),

                    // Delete button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                        ),
                        child: const Text(
                          'Delete Waypoint',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
