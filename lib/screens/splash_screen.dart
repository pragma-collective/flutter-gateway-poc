import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_registration_provider.dart';
import 'error_screen.dart';
import 'sms_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() async {
    final provider = Provider.of<DeviceRegistrationProvider>(context, listen: false);
    await provider.register();

    if (!mounted) return;

    if (provider.error != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ErrorScreen(message: provider.error!)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SmsScreen()), // 👈 Show SMS page
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}