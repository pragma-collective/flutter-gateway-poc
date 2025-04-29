import 'dart:async';

import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:cellfi_app/models/message.dart';
import 'package:cellfi_app/utils/isar_helper.dart';
import 'package:cellfi_app/utils/message_util.dart';
import 'package:cellfi_app/core/services/secure_storage_service.dart';
import 'package:cellfi_app/screens/message_detail_screen.dart';
import 'package:cellfi_app/providers/message_provider.dart';
import 'package:cellfi_app/widgets/api_base_url_selector.dart';
import 'package:cellfi_app/widgets/message_processor_widget.dart';
import 'package:cellfi_app/core/services/message_service.dart';
import 'package:cellfi_app/core/services/periodic_worker_service.dart';
import 'package:cellfi_app/utils/command_validator.dart';
import 'package:cellfi_app/widgets/worker_status_indicator.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  SmsScreenState createState() => SmsScreenState();
}

class SmsScreenState extends State<SmsScreen> with WidgetsBindingObserver {
  final Telephony telephony = Telephony.instance;
  String? _phoneNumber;
  bool _showProcessingDetails = false;
  bool _isarReady = false;
  bool _smsListenerActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPhoneNumber();

    // First ensure Isar is ready, then setup SMS listener
    _ensureIsarAndSetup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // We don't need to unregister the SMS listener since it's managed by the telephony plugin
    super.dispose();
  }

  Future<void> _ensureIsarAndSetup() async {
    try {
      // Wait for Isar to be initialized
      await IsarHelper.initialized;

      // Mark Isar as ready
      setState(() {
        _isarReady = true;
      });

      // Setup SMS listener now that Isar is ready
      _setupSmsListener();

      // Trigger message processing with a slight delay
      Future.delayed(const Duration(milliseconds: 800), _triggerMessageProcessing);
    } catch (e) {
      debugPrint("💥 Error ensuring Isar is ready: $e");
      // Try again after a short delay
      Future.delayed(const Duration(seconds: 1), _ensureIsarAndSetup);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      debugPrint("🔁 App resumed in SMS screen");

      // We need to synchronize carefully here
      setState(() {
        _isarReady = false; // Mark Isar as not ready during reopening
        _smsListenerActive = false; // Mark SMS listener as inactive
      });

      // First wait for Isar to be safely reopened
      try {
        await IsarHelper.safeReopenIsar();

        if (mounted) {
          setState(() {
            _isarReady = true; // Mark Isar as ready again
          });

          // Refresh messages
          Provider.of<MessageProvider>(context, listen: false).refresh();

          // Re-setup the SMS listener
          _setupSmsListener();

          // Trigger processing with a delay to ensure everything is ready
          Future.delayed(const Duration(milliseconds: 800), _triggerMessageProcessing);
        }
      } catch (e) {
        debugPrint("💥 Error during app resume in SMS screen: $e");

        // Try to recover by re-ensuring Isar setup
        Future.delayed(const Duration(seconds: 1), _ensureIsarAndSetup);
      }
    } else if (state == AppLifecycleState.paused) {
      debugPrint("⏸️ App paused in SMS screen");

      setState(() {
        _isarReady = false;
        _smsListenerActive = false;
      });
    }
  }

  Future<void> _loadPhoneNumber() async {
    final number = await SecureStorageService.getPhoneNumber();
    if (mounted) {
      setState(() => _phoneNumber = number);
    }
  }

  // Callback function for the SMS listener
  Future<void> _onSmsReceived(SmsMessage message) async {
    try {
      final sender = message.address ?? 'Unknown';
      final body = message.body ?? '';

      debugPrint("📲 New SMS received: $sender");

      // Handle the SMS safely
      await handleIncomingMessage(sender, body);

      // Notify provider to reload
      if (mounted) {
        Provider.of<MessageProvider>(context, listen: false).refresh();
      }
    } catch (e) {
      debugPrint("💥 Error handling incoming SMS in screen: $e");
    }
  }

  Future<void> _setupSmsListener() async {
    try {
      // Check if already active
      if (_smsListenerActive) {
        debugPrint("⚠️ SMS listener already active, skipping setup");
        return;
      }

      final sms = await Permission.sms.request();
      if (!sms.isGranted) {
        debugPrint("⚠️ SMS permission not granted");
        return;
      }

      // Set up SMS listener using the correct telephony API
      telephony.listenIncomingSms(
        onNewMessage: _onSmsReceived,
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true,
      );

      setState(() {
        _smsListenerActive = true;
      });

      debugPrint("📲 SMS listener setup complete");
    } catch (e) {
      debugPrint("💥 Error setting up SMS listener: $e");
      setState(() {
        _smsListenerActive = false;
      });
    }
  }

  Future<void> _triggerMessageProcessing() async {
    try {
      if (!_isarReady) {
        debugPrint("⚠️ Isar not ready, delaying message processing");
        Future.delayed(const Duration(seconds: 1), _triggerMessageProcessing);
        return;
      }

      await PeriodicWorkerService.processMessagesNow();
    } catch (e) {
      debugPrint("💥 Error triggering message processing: $e");
    }
  }

  Future<void> _toggleProcessingDetails() async {
    setState(() {
      _showProcessingDetails = !_showProcessingDetails;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MessageProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('📨 Messages'),
                if (!_smsListenerActive) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.sms_failed,
                    color: Colors.orange,
                    size: 16,
                  ),
                ],
              ],
            ),
            actions: [
              if (_isarReady) // Only show processing button if Isar is ready
                IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Process Messages Now',
                  onPressed: _triggerMessageProcessing,
                ),
              IconButton(
                icon: const Icon(Icons.api),
                tooltip: 'Set API Base URL',
                onPressed: () {
                  ApiBaseUrlDialog.show(context);
                },
              ),
            ],
          ),
          body: !_isarReady
              ? _buildIsarLoadingState()
              : StreamBuilder<List<Message>>(
            stream: provider.watchMessages(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data ?? [];
              final unprocessedCount = messages
                  .where((m) => !m.processed && CommandValidator.isValidCommand(m.body))
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SMS listener status (if not active)
                  if (!_smsListenerActive)
                    Container(
                      width: double.infinity,
                      color: Colors.orange.shade100,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'SMS listener not active. Tap to retry',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _setupSmsListener,
                            child: const Text('RETRY'),
                          ),
                        ],
                      ),
                    ),

                  // Status indicator
                  GestureDetector(
                    onTap: _toggleProcessingDetails,
                    child: Container(
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Wrap indicator in Expanded to prevent overflow
                          const Expanded(
                            child: WorkerStatusIndicator(compact: true),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min, // Keep this row as small as possible
                            children: [
                              if (unprocessedCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$unprocessedCount pending',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Icon(
                                _showProcessingDetails ? Icons.expand_less : Icons.expand_more,
                                size: 16,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Detailed status (if expanded)
                  if (_showProcessingDetails)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const WorkerStatusIndicator(compact: false),
                          if (unprocessedCount > 0) ...[
                            const SizedBox(height: 16),
                            _buildPendingMessagesCard(unprocessedCount),
                          ],
                        ],
                      ),
                    ),

                  // Phone number display
                  if (_phoneNumber != null && _phoneNumber!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          // Wrap in Expanded to prevent overflow
                          Expanded(
                            child: Text(
                              'Registered: $_phoneNumber',
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Message list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await provider.refresh();
                        if (_isarReady) {
                          await _triggerMessageProcessing();
                        }
                      },
                      child: messages.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                        itemCount: messages.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return ListTile(
                            leading: _buildMessageStatusIcon(message),
                            title: Text(
                              message.sender,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatDateTime(message.receivedAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MessageDetailScreen(message: message),
                                ),
                              ).then((_) {
                                if (_isarReady) {
                                  _triggerMessageProcessing();
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton: _isarReady ? FloatingActionButton(
            onPressed: _triggerMessageProcessing,
            tooltip: 'Process Messages',
            child: const Icon(Icons.send),
          ) : null, // Hide FAB if Isar is not ready
        );
      },
    );
  }

  Widget _buildIsarLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing database...'),
          SizedBox(height: 8),
          Text(
            'Please wait while the app is preparing',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
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
            Icons.message,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Messages will appear here when received',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingMessagesCard(int count) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.pending, color: Colors.orange.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Messages',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('$count message${count == 1 ? '' : 's'} waiting to be sent'),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isarReady ? _triggerMessageProcessing : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageStatusIcon(Message message) {
    if (message.processed) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else if (message.retryCount > 0) {
      return Badge(
        label: Text(message.retryCount.toString()),
        child: const Icon(Icons.error_outline, color: Colors.orange),
      );
    } else if (CommandValidator.isValidCommand(message.body)) {
      return const Icon(Icons.pending, color: Colors.blue);
    } else {
      return const Icon(Icons.sms, color: Colors.grey);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}