import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cellfi_app/core/services/periodic_worker_service.dart';

// Set to track processed FCM message IDs to avoid duplicates
final Set<String> _processedMessageIds = <String>{};

// This must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase
  await Firebase.initializeApp();

  debugPrint('Background message received: ${message.data}');

  final success = await FirebaseUtil._processMessageBackground(message, Telephony.instance);
  
  debugPrint("Background SMS processing ${success ? 'succeeded' : 'failed'}");

  // print('Background message received: ${message.data}');

  // // Check if we've already processed this message
  // final messageId = message.messageId ?? 'unknown';
  // if (_processedMessageIds.contains(messageId)) {
  //   print('⏭️ Already processed FCM message: $messageId, skipping');
  //   return;
  // }

  // // Mark as processed
  // _processedMessageIds.add(messageId);

  // // Store message for processing when app is active
  // final prefs = await SharedPreferences.getInstance();
  // final messagesJson = prefs.getStringList('pending_messages') ?? [];

  // // Simple storage of message data
  // final data = message.data;
  // final phoneNumber = data['phoneNumber'] ?? data['phone_number'] ?? data['PHONENUMBER'];
  // final messageContent = data['messageContent'] ?? data['message_content'] ?? data['MESSAGECONTENT'] ?? data['message'];

  // if (phoneNumber != null && messageContent != null) {
  //   messagesJson.add('$phoneNumber|||$messageContent');
  //   await prefs.setStringList('pending_messages', messagesJson);
  //   print('Message stored for later processing: $phoneNumber - $messageContent');
  // }

  // // We'll intentionally avoid triggering message processing here
  // // to prevent duplicate processing. Instead, we'll let the app
  // // handle processing when it resumes.
  // print('✅ Background message stored for later processing');
}

class FirebaseUtil {
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;
  static bool _isInitialized = false;

  // Timestamps to track when processing was last triggered
  static DateTime? _lastProcessingTime;
  static const Duration _minProcessingInterval = Duration(seconds: 5);

  // Initialize Firebase Messaging
  static Future<void> initialize(Telephony telephony) async {
    if (_isInitialized) return;

    print("Initializing Firebase Messaging...");

    // Initialize Firebase if not already initialized
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print("Firebase already initialized or error: $e");
    }

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Firebase Messaging permission status: ${settings.authorizationStatus}');

    // Get FCM token for debugging
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $token');

    // Process any pending messages stored while app was in background
    await _processPendingMessages(telephony);

    // Set up message listeners
    _setupMessageListeners(telephony);

    _isInitialized = true;
    print("Firebase Messaging initialized successfully");
  }

  // Clean up subscriptions
  static void dispose() {
    _foregroundSubscription?.cancel();
    _openedAppSubscription?.cancel();
    _isInitialized = false;
  }

  // Set up message listeners
  static void _setupMessageListeners(Telephony telephony) {
    // Cancel any existing subscriptions
    _foregroundSubscription?.cancel();
    _openedAppSubscription?.cancel();

    print("Setting up Firebase Messaging listeners...");

    // Handle foreground messages
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("FOREGROUND MESSAGE RECEIVED ======================");
      debugPrint("Message ID: ${message.messageId}");
      debugPrint("Message data: ${message.data}");

      final success = await FirebaseUtil._processMessageBackground(message, Telephony.instance);
      debugPrint("Foreground SMS processing ${success ? 'succeeded' : 'failed'}");
      return;

      // // Check if we've already processed this message
      // final messageId = message.messageId ?? 'unknown';
      // if (_processedMessageIds.contains(messageId)) {
      //   print('⏭️ Already processed FCM message: $messageId, skipping');
      //   return;
      // }

      // // Mark as processed
      // _processedMessageIds.add(messageId);

      // // Process the message
      // _processMessage(message, telephony);

      // // Trigger SMS processing, but with rate limiting
      // _triggerProcessingWithRateLimit();
    });

    // Handle when app is opened from notification
    // _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    //   print("APP OPENED FROM NOTIFICATION ======================");
    //   print("Message data: ${message.data}");

    //   // Check if we've already processed this message
    //   final messageId = message.messageId ?? 'unknown';
    //   if (_processedMessageIds.contains(messageId)) {
    //     print('⏭️ Already processed FCM message: $messageId, skipping');
    //     return;
    //   }

    //   // Mark as processed
    //   _processedMessageIds.add(messageId);

    //   // Process the message
    //   _processMessage(message, telephony);

    //   // Trigger SMS processing, but with rate limiting
    //   _triggerProcessingWithRateLimit();
    // });

    // Check for initial message (app opened from terminated state)
    // FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    //   if (message != null) {
    //     print("APP STARTED FROM TERMINATED STATE VIA NOTIFICATION ======================");
    //     print("Message data: ${message.data}");

    //     // Check if we've already processed this message
    //     final messageId = message.messageId ?? 'unknown';
    //     if (_processedMessageIds.contains(messageId)) {
    //       print('⏭️ Already processed FCM message: $messageId, skipping');
    //       return;
    //     }

    //     // Mark as processed
    //     _processedMessageIds.add(messageId);

    //     // Process the message
    //     _processMessage(message, telephony);

    //     // Trigger SMS processing, but with rate limiting
    //     _triggerProcessingWithRateLimit();
    //   }
    // });

    print("Firebase Messaging listeners setup complete");
  }

  // Trigger message processing with rate limiting
  static Future<void> _triggerProcessingWithRateLimit() async {
    final now = DateTime.now();

    // Check if we've processed recently
    if (_lastProcessingTime != null) {
      final timeSinceLastProcessing = now.difference(_lastProcessingTime!);

      if (timeSinceLastProcessing < _minProcessingInterval) {
        print('⏭️ Skipping message processing trigger - last triggered ${timeSinceLastProcessing.inSeconds} seconds ago');
        return;
      }
    }

    // Update last processing time
    _lastProcessingTime = now;

    // Trigger processing with a delay to avoid race conditions
    Future.delayed(const Duration(seconds: 1), () {
      PeriodicWorkerService.processMessagesNow();
    });
  }

  // Process FCM message
  static Future<bool> _processMessageBackground(RemoteMessage message, Telephony telephony) async {
    try {
      final data = message.data;
      final phoneNumber = data['phoneNumber'] ?? data['phone_number'] ?? data['PHONENUMBER'];
      final messageContent = data['messageContent'] ?? data['message_content'] ?? data['MESSAGECONTENT'] ?? data['message'];

      debugPrint("Extracted PhoneNumber: $phoneNumber");
      debugPrint("Extracted MessageContent: $messageContent");

      if (phoneNumber != null && messageContent != null) {
        debugPrint("Sending SMS via telephony...");
        final success = await _sendSmsBackground(telephony, phoneNumber, messageContent);
        return success;
      } else {
        debugPrint("Cannot send SMS - missing phone number or message content");
        return false;
      }
    } catch (e) {
      debugPrint("Error processing message: $e");
      return false;
    }
  }

  static Future<bool> _sendSmsBackground(Telephony telephony, String phoneNumber, String messageContent, {int attempt = 1, int maxRetries = 3}) async {
    try {
      final completer = Completer<bool>();
      bool receivedCallback = false;
      
      // Set a timeout for SMS delivery confirmation (1 minute)
      Timer deliveryTimeout = Timer(const Duration(minutes: 1), () {
        if (!completer.isCompleted) {
          debugPrint("⏱️ SMS status timeout for $phoneNumber (attempt $attempt)");
          completer.complete(false);
        }
      });
      
      await telephony.sendSms(
        to: phoneNumber,
        message: messageContent,
        statusListener: (SendStatus status) {
          receivedCallback = true;
          if (status == SendStatus.DELIVERED) {
            debugPrint("✅ SMS delivered successfully to $phoneNumber");
            if (!completer.isCompleted) {
              deliveryTimeout.cancel();
              completer.complete(true);
            }
          } else if (status == SendStatus.SENT) {
            debugPrint("📤 SMS sent to $phoneNumber (awaiting delivery confirmation)");
            // Don't complete yet, wait for DELIVERED
          }
        },  
      );
      
      // If we don't receive any status callback within 10 seconds, assume it was just sent
      Timer(const Duration(seconds: 10), () {
        if (!receivedCallback && !completer.isCompleted) {
          debugPrint("ℹ️ No status received for SMS to $phoneNumber, assuming sent");
          completer.complete(true);
        }
      });
      
      return await completer.future;
    } catch (e) {
      debugPrint("❌ Error sending SMS (attempt $attempt): $e");
      
      // Retry logic with Fibonacci delay pattern
      if (attempt < maxRetries) {
        // Calculate Fibonacci delay: 1 min, 2 min, 3 min
        final int delayMinutes = attempt + (attempt > 1 ? attempt - 1 : 0);
        debugPrint("🔄 Will retry in $delayMinutes minutes (attempt ${attempt+1}/$maxRetries)");
        
        await Future.delayed(Duration(minutes: delayMinutes));
        return _sendSmsBackground(
          telephony, 
          phoneNumber, 
          messageContent,
          attempt: attempt + 1,
          maxRetries: maxRetries
        );
      }

      debugPrint("⛔ Max retries reached for SMS to $phoneNumber");
      return false;
    }
  }

  // Process FCM message
  static void _processMessage(RemoteMessage message, Telephony telephony) {
    try {
      final data = message.data;
      final phoneNumber = data['phoneNumber'] ?? data['phone_number'] ?? data['PHONENUMBER'];
      final messageContent = data['messageContent'] ?? data['message_content'] ?? data['MESSAGECONTENT'] ?? data['message'];

      print("Extracted PhoneNumber: $phoneNumber");
      print("Extracted MessageContent: $messageContent");

      if (phoneNumber != null && messageContent != null) {
        print("Sending SMS via telephony...");
        _sendSms(telephony, phoneNumber, messageContent);
      } else {
        print("Cannot send SMS - missing phone number or message content");
      }
    } catch (e) {
      print("Error processing message: $e");
    }
  }

  // Process any pending messages stored while app was in background
  static Future<void> _processPendingMessages(Telephony telephony) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessages = prefs.getStringList('pending_messages') ?? [];

      if (pendingMessages.isNotEmpty) {
        print("Processing ${pendingMessages.length} pending messages");

        for (final encodedMessage in pendingMessages) {
          final parts = encodedMessage.split('|||');
          if (parts.length == 2) {
            final phoneNumber = parts[0];
            final messageContent = parts[1];
            await _sendSms(telephony, phoneNumber, messageContent);
          }
        }

        // Clear pending messages
        await prefs.setStringList('pending_messages', []);
      }
    } catch (e) {
      print("Error processing pending messages: $e");
    }
  }

  // Send SMS
  static Future<void> _sendSms(Telephony telephony, String phoneNumber, String messageContent) async {
    try {
      await telephony.sendSms(
        to: phoneNumber,
        message: messageContent,
      );
    } catch (e) {
      debugPrint("Error sending SMS: $e");
    }
  }

  // Clean up the processed message IDs cache to prevent memory leaks
  // Call this periodically to keep the cache size manageable
  static void cleanupProcessedMessageIds({int maxSize = 100}) {
    if (_processedMessageIds.length > maxSize) {
      print('Cleaning up processed message IDs cache (size: ${_processedMessageIds.length})');

      // Convert to list, sort by most recent (if possible), and keep only the most recent ones
      // Since we don't track timestamps, we'll just keep the most recent ones based on set order
      final idsToKeep = _processedMessageIds.toList().reversed.take(maxSize ~/ 2).toSet();
      _processedMessageIds.clear();
      _processedMessageIds.addAll(idsToKeep);

      print('Processed message IDs cache cleaned (new size: ${_processedMessageIds.length})');
    }
  }
}