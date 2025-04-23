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
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}