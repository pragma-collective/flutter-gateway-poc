import 'package:cellfi_app/screens/sms_screen.dart';
import 'package:cellfi_app/screens/register_device.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/message.dart';
import 'routes/app_route.dart';



import 'package:cellfi_app/providers/device_registration_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // required before using async in main
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  Hive.registerAdapter(MessageAdapter());
  await Hive.openBox<Message>('messages');


  runApp(
    ChangeNotifierProvider(
      create: (_) => DeviceRegistrationProvider()..register(),
      child: const MyApp(),
    ),
  );
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
      initialRoute: AppRoutes.registerDevice,
      routes: {
        AppRoutes.registerDevice: (_) => const RegisterDeviceScreen(),
        AppRoutes.smsScreen: (_) => const SmsScreen(),
      },
    );
  }
}

