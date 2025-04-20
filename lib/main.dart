import 'package:cellfi_app/pages/sms_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'model/message.dart';
import 'util.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // required before using async in main
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  Hive.registerAdapter(MessageAdapter());
  await Hive.openBox<Message>('messages');

  // ✅ Get and store FCM token
  await TokenUtil.getAndStoreFcmToken(); // 👈 add this here

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SmsHomePage(),
    );
  }
}

