import 'package:flutter/material.dart';
import 'package:cellfi_app/core/services/periodic_worker_service.dart';

class WorkerStatusIndicator extends StatefulWidget {
  final bool compact;

  const WorkerStatusIndicator({
    super.key,
    this.compact = true
  });

  @override
  State<WorkerStatusIndicator> createState() => _WorkerStatusIndicatorState();
}

class _WorkerStatusIndicatorState extends State<WorkerStatusIndicator> {
  WorkerStatus _currentStatus = WorkerStatus.initialized;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _setupListener();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setupListener() {
    PeriodicWorkerService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          _lastUpdated = DateTime.now();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactIndicator();
    } else {
      return _buildDetailedIndicator();
    }
  }

  Widget _buildCompactIndicator() {
    // Fix: Using shorter status text for compact view
    return Row(
      mainAxisSize: MainAxisSize.min, // Keep row as small as possible
      children: [
        _getStatusIcon(),
        const SizedBox(width: 8),
        // Wrap text in Flexible to allow it to shrink if needed
        Flexible(
          child: Text(
            _getShortStatusText(), // Use short text for compact view
            style: TextStyle(color: _getStatusColor()),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedIndicator() {
    return Card(
      color: _getStatusColor().withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getStatusIcon(large: true),
                const SizedBox(width: 16),
                // Wrap in Expanded to prevent overflow
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message Processor',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusText(),
                        style: TextStyle(color: _getStatusColor()),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_lastUpdated != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Last updated: ${_formatTime(_lastUpdated!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getStatusIcon({bool large = false}) {
    final double size = large ? 24.0 : 16.0;
    final double strokeWidth = large ? 3.0 : 2.0;

    switch (_currentStatus) {
      case WorkerStatus.initialized:
        return Icon(Icons.check_circle_outline, color: Colors.grey, size: size);
      case WorkerStatus.processing:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
        );
      case WorkerStatus.completed:
        return Icon(Icons.check_circle, color: Colors.green, size: size);
      case WorkerStatus.error:
        return Icon(Icons.error, color: Colors.red, size: size);
    }
  }

  // Shorter status text for compact view
  String _getShortStatusText() {
    switch (_currentStatus) {
      case WorkerStatus.initialized:
        return 'Ready';
      case WorkerStatus.processing:
        return 'Processing...';
      case WorkerStatus.completed:
        return 'Completed';
      case WorkerStatus.error:
        return 'Error';
    }
  }

  // Full status text for detailed view
  String _getStatusText() {
    switch (_currentStatus) {
      case WorkerStatus.initialized:
        return 'Ready to process messages';
      case WorkerStatus.processing:
        return 'Processing messages...';
      case WorkerStatus.completed:
        return 'Processing completed successfully';
      case WorkerStatus.error:
        return 'Error processing messages';
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case WorkerStatus.initialized:
        return Colors.grey;
      case WorkerStatus.processing:
        return Theme.of(context).primaryColor;
      case WorkerStatus.completed:
        return Colors.green;
      case WorkerStatus.error:
        return Colors.red;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'min' : 'mins'} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hr' : 'hrs'} ago';
    } else {
      return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}