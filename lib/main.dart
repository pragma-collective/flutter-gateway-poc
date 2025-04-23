import 'package:cellfi_app/screens/sms_screen.dart';
import 'package:cellfi_app/screens/register_device.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'routes/app_route.dart';
import 'utils/token_util.dart';
import 'package:cellfi_app/providers/device_registration_provider.dart';
import 'package:cellfi_app/providers/message_provider.dart';
import 'package:cellfi_app/utils/isar_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Isar only once
  await IsarHelper.initIsar();

  final apiToken = await TokenUtil.getApiToken();
  debugPrint(apiToken);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceRegistrationProvider()),
        // Initialize MessageProvider at app startup to ensure single initialization flow
        ChangeNotifierProvider(create: (_) => MessageProvider()..loadMessages()),
      ],
      child: const CellFiApp(),
    ),
  );
}

// Removed InitWrapper class as it's no longer needed
// MessageProvider is now initialized in the MultiProvider in main()

class CellFiApp extends StatelessWidget {
  const CellFiApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CellFi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder<String?>(
        future: TokenUtil.getApiToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final token = snapshot.data;
          return Consumer<MessageProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return (token != null && token.isNotEmpty)
                  ? const SmsScreen()
                  : const RegisterDeviceScreen();
            },
          );
        },
      ),
      routes: {
        AppRoutes.registerDevice: (_) => const RegisterDeviceScreen(),
        AppRoutes.smsScreen: (_) => const SmsScreen(),
      },
    );
  }
}