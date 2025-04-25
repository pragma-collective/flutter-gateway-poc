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

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  SmsScreenState createState() => SmsScreenState();
}

class SmsScreenState extends State<SmsScreen> with WidgetsBindingObserver {
  final Telephony telephony = Telephony.instance;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPhoneNumber();
    _setupSmsListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up Firebase listeners when the screen is disposed
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      debugPrint("🔁 App resumed — reopening Isar & triggering refresh");

      await IsarHelper.safeReopenIsar();

      if (mounted) {
        Provider.of<MessageProvider>(context, listen: false).refresh();
      }
    }
  }

  Future<void> _loadPhoneNumber() async {
    final number = await SecureStorageService.getPhoneNumber();
    setState(() => _phoneNumber = number);
  }

  Future<void> _handleSms(SmsMessage message) async {
    final newMsg = Message()
      ..sender = message.address ?? 'Unknown'
      ..body = message.body ?? ''
      ..receivedAt = DateTime.now()
      ..processed = false
      ..retryCount = 0;

    final isar = IsarHelper.getIsarInstance();
    await isar.writeTxn(() async {
      await isar.messages.put(newMsg);
    });

    // Notify provider to reload
    Provider.of<MessageProvider>(context, listen: false).refresh();
  }

  Future<void> _setupSmsListener() async {
    final sms = await Permission.sms.request();
    if (!sms.isGranted) return;

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await _handleSms(message);
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MessageProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('📨 Messages'),
            actions: [
              IconButton(
                icon: const Icon(Icons.api),
                tooltip: 'Set API Base URL',
                onPressed: () {
                  // Open modal dialog instead of navigating to a new page
                  ApiBaseUrlDialog.show(context);
                },
              ),
            ],
          ),
          body: StreamBuilder<List<Message>>(
            stream: provider.watchMessages(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_phoneNumber != null && _phoneNumber!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Registered number: $_phoneNumber',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await provider.refresh(); // optional for manual pull
                      },
                      child: messages.isEmpty
                          ? const Center(child: Text('No messages found.'))
                          : ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return ListTile(
                            title: Text(message.sender),
                            subtitle: Text(
                              message.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MessageDetailScreen(message: message),
                                ),
                              );
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
        );
      },
    );
  }
}