import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';


/// 🔁 Background handler
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  print("📩 [BG] From ${message.address}: ${message.body}");
  // You can forward this to an API here if needed
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // required before using async in main
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
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
      home: SmsHomePage(),
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

  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _setupSmsListener();
  }


  Future<void> _setupSmsListener() async {
    final granted = await _requestPermissions();
    if (!granted) return;

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        setState(() {
          latestSender = message.address;
          latestMessage = message.body;
        });
        print("📩 [FG] From ${message.address}: ${message.body}");
      },
      onBackgroundMessage: backgroundMessageHandler,
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
      appBar: AppBar(title: Text('SMS Listener')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: latestMessage == null
              ? Text('Waiting for SMS...', style: TextStyle(fontSize: 18))
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("📱 From: $latestSender", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("💬 Message: $latestMessage", style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}