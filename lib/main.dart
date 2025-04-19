import 'package:cellfi_app/pages/message_list_page.dart';
import 'package:cellfi_app/service/message_service.dart';
import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'model/message.dart';
import 'util.dart';

/// 🔁 Background handler
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  print("📩 [BG] From ${message.address}: ${message.body}");

  // Required before using Hive in isolate
  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  Hive.registerAdapter(MessageAdapter());
  await Hive.openBox<Message>('messages');

  await handleIncomingMessage(
    message.address ?? 'Unknown',
    message.body ?? '',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // required before using async in main
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  Hive.registerAdapter(MessageAdapter());
  await Hive.openBox<Message>('messages');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CellFi',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SmsHomePage(),
    );
  }
}

class SmsHomePage extends StatefulWidget {
  const SmsHomePage({super.key});

  @override
  SmsHomePageState createState() => SmsHomePageState(); // ✅ public type
}

class SmsHomePageState extends State<SmsHomePage> {
  String? latestSender;
  String? latestMessage;
  int totalMessages = 0;

  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _setupSmsListener();
    _startMessageProcessing();
    _loadInitialMessage();
    _updateMessageCount();
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
    await _updateMessageCount(); // still useful here
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