import 'package:cellfi_app/core/services/periodic_worker_service.dart';
import 'package:cellfi_app/core/services/message_service.dart';
import 'package:cellfi_app/screens/sms_screen.dart';
import 'package:cellfi_app/screens/register_device.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:another_telephony/telephony.dart';
import 'firebase_options.dart';
import 'routes/app_route.dart';
import 'utils/token_util.dart';
import 'package:cellfi_app/providers/device_registration_provider.dart';
import 'package:cellfi_app/providers/message_provider.dart';
import 'package:cellfi_app/utils/isar_helper.dart';
import 'package:cellfi_app/utils/firebase_util.dart';

// Flag to track app initialization state
bool _isInitializing = false;
bool _isInitialized = false;
const int MAX_INIT_RETRIES = 3;

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set a flag to track initialization state
  _isInitializing = true;

  // Wrap in a try-catch to handle initialization errors
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Isar database with retries
    await _initializeIsarWithRetry();

    // Initialize Telephony instance
    final telephony = Telephony.instance;

    // Initialize Firebase Messaging utility
    await FirebaseUtil.initialize(telephony);

    // Initialize periodic worker service (runs every 15 minutes)
    await PeriodicWorkerService.initialize(interval: const Duration(minutes: 1));

    // Check API token
    final apiToken = await TokenUtil.getApiToken();
    debugPrint("API Token: $apiToken");

    // Mark initialization as complete
    _isInitializing = false;
    _isInitialized = true;

    // Run the app
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DeviceRegistrationProvider()),
          // Initialize MessageProvider at app startup
          ChangeNotifierProvider(create: (_) => MessageProvider()..loadMessages()),
          // Add the enhanced MessageService provider
          ChangeNotifierProvider(create: (_) => MessageService()),
        ],
        child: const CellFiApp(),
      ),
    );
  } catch (e) {
    // Log the error and run a minimal error app
    debugPrint("💥 Critical error during app initialization: $e");

    // Reset flags
    _isInitializing = false;
    _isInitialized = false;

    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Restart the app
                  main();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

// Helper method to initialize Isar with retries
Future<void> _initializeIsarWithRetry() async {
  int retries = 0;
  bool success = false;

  while (!success && retries < MAX_INIT_RETRIES) {
    try {
      debugPrint("🔄 Attempting to initialize Isar (attempt ${retries + 1}/${MAX_INIT_RETRIES})");

      // If it's a retry, completely close Isar first
      if (retries > 0) {
        try {
          await IsarHelper.closeIsar();
          await Future.delayed(const Duration(milliseconds: 500)); // Brief pause
        } catch (e) {
          debugPrint("⚠️ Error closing Isar before retry: $e");
        }
      }

      // Initialize Isar
      await IsarHelper.initIsar();

      // If we get here without an exception, it was successful
      success = true;
      debugPrint("✅ Isar initialization successful on attempt ${retries + 1}");
    } catch (e) {
      retries++;
      debugPrint("❌ Isar initialization failed (attempt $retries): $e");

      if (retries < MAX_INIT_RETRIES) {
        // Wait a bit before retrying
        await Future.delayed(const Duration(seconds: 1));
      } else {
        debugPrint("🚨 All Isar initialization attempts failed");
        rethrow;
      }
    }
  }
}

class CellFiApp extends StatefulWidget {
  const CellFiApp({super.key});

  @override
  State<CellFiApp> createState() => _CellFiAppState();
}

class _CellFiAppState extends State<CellFiApp> with WidgetsBindingObserver {
  bool _isResuming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up resources when app is terminated
    PeriodicWorkerService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // Process messages when app is resumed
    if (state == AppLifecycleState.resumed) {
      // Set a flag to prevent multiple resumes from happening at once
      if (_isResuming) {
        debugPrint("⚠️ App resume already in progress, skipping this one");
        return;
      }

      _isResuming = true;

      debugPrint("🔁 App resumed in main.dart");

      // Add a slight delay to ensure everything is ready
      await Future.delayed(const Duration(milliseconds: 200));

      try {
        // Carefully reopen Isar if needed
        if (!IsarHelper.isIsarReady()) {
          debugPrint("🔄 Isar not ready, reopening on resume");
          await IsarHelper.safeReopenIsar();
        } else {
          debugPrint("✅ Isar already open and ready on resume");
        }

        // Small additional delay after reopening
        await Future.delayed(const Duration(milliseconds: 300));

        // Process any pending messages with a slight delay
        // to ensure Isar is fully initialized
        Future.delayed(
            const Duration(milliseconds: 800),
                () => PeriodicWorkerService.processMessagesNow()
        );
      } catch (e) {
        debugPrint("💥 Error during app resume: $e");

        // Try to recover by re-initializing
        if (!_isInitializing && !_isInitialized) {
          debugPrint("🔄 Trying to re-initialize app after failed resume");
          try {
            await _initializeIsarWithRetry();
          } catch (initError) {
            debugPrint("💥 Failed to re-initialize Isar: $initError");
          }
        }
      } finally {
        _isResuming = false;
      }
    } else if (state == AppLifecycleState.paused) {
      debugPrint("⏸️ App paused in main.dart");
    }
  }

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
          // Show loading screen while getting token
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If there was an error, show error screen
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text('Error loading API token'),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Force reload
                        setState(() {});
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final token = snapshot.data;

          // If no token is found, immediately go to registration screen
          if (token == null || token.isEmpty) {
            debugPrint("🔑 No API token found, going to registration screen");
            return const RegisterDeviceScreen();
          }

          // If token exists, check with the server using the DeviceRegistrationProvider
          return Consumer<DeviceRegistrationProvider>(
            builder: (context, deviceProvider, _) {
              // Trigger the checkDevice method when this Consumer is built
              // but only once to avoid infinite loops
              if (deviceProvider.isLoading) {
                debugPrint("🔄 Checking device registration status...");
                // This will happen on the first build only because we're checking isLoading
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  deviceProvider.checkDevice();
                });
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Verifying device registration..."),
                      ],
                    ),
                  ),
                );
              }

              // If there's an error or the device check failed, go to registration
              if (deviceProvider.error != null || !deviceProvider.isDeviceRegistered) {
                debugPrint("❌ Device not registered: ${deviceProvider.error}");
                return const RegisterDeviceScreen();
              }

              debugPrint("✅ Device registration verified, loading messages");

              // Verify Isar is ready before loading messages
              if (!IsarHelper.isIsarReady()) {
                debugPrint("⚠️ Isar not ready before loading SMS screen, initializing now");
                return FutureBuilder<void>(
                  future: IsarHelper.initIsar(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text("Preparing database..."),
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Scaffold(
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              const Text('Database initialization error'),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  // Try again
                                  setState(() {});
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // If everything is OK, proceed to the SMS screen
                    return const SmsScreen();
                  },
                );
              }

              // If everything is OK, proceed to the SMS screen through the MessageProvider
              return Consumer<MessageProvider>(
                builder: (context, messageProvider, _) {
                  if (messageProvider.isLoading) {
                    return const Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Loading messages..."),
                          ],
                        ),
                      ),
                    );
                  }

                  return const SmsScreen();
                },
              );
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