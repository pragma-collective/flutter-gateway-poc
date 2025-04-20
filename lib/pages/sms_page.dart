import 'package:cellfi_app/pages/message_list_page.dart';
import 'package:cellfi_app/service/message_service.dart';
import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/message.dart';
import '../util.dart';

class SmsHomePage extends StatefulWidget {
  const SmsHomePage({super.key});

  @override
  SmsHomePageState createState() => SmsHomePageState();
}

class SmsHomePageState extends State<SmsHomePage> with WidgetsBindingObserver {
  String? latestSender;
  String? latestMessage;
  int totalMessages = 0;

  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _setupSmsListener();
    // _startMessageProcessing();
    _loadInitialMessage();
    _updateMessageCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      print("🔁 App resumed. Reopening Hive box to refresh view...");

      // ✅ Close and reopen the box to force a fresh read
      if (Hive.isBoxOpen('messages')) {
        await Hive.box<Message>('messages').close();
      }
      await Hive.openBox<Message>('messages');

      // ✅ Trigger rebuild
      setState(() {});
    }
  }

  Future<void> _startMessageProcessing() async {
    final processor = MessageService();
    await processor.processUnsentMessages();
  }

  Future<void> _updateMessageCount() async {
    final box = Hive.box<Message>('messages');
    setState(() {
      totalMessages = box.length;
    });
  }

  Future<void> _loadInitialMessage() async {
    final box = Hive.box<Message>('messages');
    if (box.isNotEmpty) {
      final latest = box.values.last;
      setState(() {
        latestSender = latest.sender;
        latestMessage = latest.body;
      });
    }
  }

  Future<void> _handleSms(SmsMessage message) async {
    await handleIncomingMessage(
      message.address ?? 'Unknown',
      message.body ?? '',
    );
    await _updateMessageCount();
  }

  Future<void> _setupSmsListener() async {
    final granted = await _requestPermissions();
    if (!granted) return;

    telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          setState(() {
            latestSender = message.address;
            latestMessage = message.body;
          });

          print("📩 [FG] From ${message.address}: ${message.body}");

          _handleSms(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true
    );
  }

  Future<bool> _requestPermissions() async {
    final sms = await Permission.sms.request();
    final phone = await Permission.phone.request();
    return sms.isGranted && phone.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMS Listener')),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Message>('messages').listenable(),
        builder: (context, Box<Message> box, _) {
          final latest = box.isNotEmpty ? box.values.last : null;
          final totalMessages = box.length;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: box.isEmpty
                  ? const Text(
                'Waiting for SMS...',
                style: TextStyle(fontSize: 18),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "📱 From: ${latest?.sender ?? '-'}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "💬 Message: ${latest?.body ?? '-'}",
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "📦 Total Messages: $totalMessages",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MessageListPage(),
                        ),
                      );
                    },
                    child: const Text('📄 View Saved Messages'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}