import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/core/classes/detected_object.dart';

class ObjectDrawer extends ConsumerStatefulWidget {
  final bool isVisible;
  final DetectedObject? detectedObject;
  final VoidCallback onClose;
  final VoidCallback? onObjectConfirmed;
  final VoidCallback? onObjectDiscarded;

  const ObjectDrawer({
    super.key,
    required this.isVisible,
    required this.detectedObject,
    required this.onClose,
    this.onObjectConfirmed,
    this.onObjectDiscarded,
  });

  @override
  ConsumerState<ObjectDrawer> createState() => ObjectDrawerState();
}

class ObjectDrawerState extends ConsumerState<ObjectDrawer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right side
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(ObjectDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible && !_animationController.isAnimating) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Semi-transparent background overlay
        GestureDetector(
          onTap: widget.onClose,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: Colors.black.withOpacity(0.3),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        
        // Drawer content
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: 400,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(-5, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildContent()),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.detectedObject?.classIcon ?? Icons.location_on,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected Object',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.detectedObject?.detectionClass.toUpperCase() ?? 'UNKNOWN',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.detectedObject == null) {
      return const Center(
        child: Text(
          'No object selected',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final detectedObject = widget.detectedObject!;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInfoSection(detectedObject),
        ],
      ),
    );
  }

  Widget _buildInfoSection(DetectedObject detectedObject) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Object Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.tag,
            label: 'ID',
            value: detectedObject.id,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.category,
            label: 'Detection Class',
            value: detectedObject.detectionClass.toUpperCase(),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.priority_high,
            label: 'Priority',
            value: detectedObject.priorityText,
            valueColor: detectedObject.priorityColor,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.verified,
            label: 'Confidence',
            value: detectedObject.confidenceText,
            valueColor: detectedObject.confidenceColor,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.info,
            label: 'State',
            value: detectedObject.state.toUpperCase(),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.location_on,
            label: 'Position',
            value: '${detectedObject.position.latitude.toStringAsFixed(6)}, ${detectedObject.position.longitude.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.speed,
            label: 'Velocity',
            value: detectedObject.velocityText,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.speed,
            label: 'Speed',
            value: '${detectedObject.speed.toStringAsFixed(2)} m/s',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.access_time,
            label: 'Timestamp',
            value: '${detectedObject.timeStamp.hour.toString().padLeft(2, '0')}:${detectedObject.timeStamp.minute.toString().padLeft(2, '0')}:${detectedObject.timeStamp.second.toString().padLeft(2, '0')}',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.update,
            label: 'Last Updated',
            value: '${detectedObject.lastUpdated.hour.toString().padLeft(2, '0')}:${detectedObject.lastUpdated.minute.toString().padLeft(2, '0')}:${detectedObject.lastUpdated.second.toString().padLeft(2, '0')}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? Colors.grey[900],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (widget.detectedObject == null) {
      return const SizedBox.shrink();
    }

    final detectedObject = widget.detectedObject!;
    final isConfirmed = detectedObject.confidence >= 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.delete,
              label: 'Discard',
              color: Colors.red,
              onTap: isConfirmed || _isProcessing ? null : _discardObject,
              enabled: !isConfirmed && !_isProcessing,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionButton(
              icon: Icons.check_circle,
              label: isConfirmed ? 'Confirmed' : 'Confirm',
              color: Colors.green,
              onTap: isConfirmed || _isProcessing ? null : _confirmObject,
              enabled: !isConfirmed && !_isProcessing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : Colors.grey;

    return Material(
      color: effectiveColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing && onTap != null)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmObject() async {
    if (widget.detectedObject == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await ref.read(redisClientProvider.notifier)
          .confirmDetectedObject(widget.detectedObject!.id);

      if (success) {
        _showSnackBar('Object confirmed successfully', Colors.green);
        widget.onObjectConfirmed?.call();
      } else {
        _showSnackBar('Failed to confirm object', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error confirming object: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _discardObject() async {
    if (widget.detectedObject == null || _isProcessing) return;

    // Show confirmation dialog
    final confirmed = await _showDiscardConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await ref.read(redisClientProvider.notifier)
          .deleteDetectedObject(widget.detectedObject!.id);

      if (success) {
        _showSnackBar('Object discarded successfully', Colors.orange);
        widget.onObjectDiscarded?.call();
        widget.onClose();
      } else {
        _showSnackBar('Failed to discard object', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error discarding object: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _showDiscardConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              const Text('Confirm Discard'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to discard this detected object?'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Object: ${widget.detectedObject?.detectionClass.toUpperCase() ?? 'UNKNOWN'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('ID: ${widget.detectedObject?.id ?? 'N/A'}'),
                    Text('Confidence: ${widget.detectedObject?.confidenceText ?? 'N/A'}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}