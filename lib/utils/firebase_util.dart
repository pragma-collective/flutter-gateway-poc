import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase
  await Firebase.initializeApp();

  print('Background message received: ${message.data}');

  // Store message for processing when app is active
  final prefs = await SharedPreferences.getInstance();
  final messagesJson = prefs.getStringList('pending_messages') ?? [];

  // Simple storage of message data
  final data = message.data;
  final phoneNumber = data['phoneNumber'] ?? data['phone_number'] ?? data['PHONENUMBER'];
  final messageContent = data['messageContent'] ?? data['message_content'] ?? data['MESSAGECONTENT'] ?? data['message'];

  if (phoneNumber != null && messageContent != null) {
    messagesJson.add('$phoneNumber|||$messageContent');
    await prefs.setStringList('pending_messages', messagesJson);
    print('Message stored for later processing: $phoneNumber - $messageContent');
  }
}

class FirebaseUtil {
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;
  static bool _isInitialized = false;

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
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("FOREGROUND MESSAGE RECEIVED ======================");
      print("Message ID: ${message.messageId}");
      print("Message data: ${message.data}");
      _processMessage(message, telephony);
    });

    // Handle when app is opened from notification
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("APP OPENED FROM NOTIFICATION ======================");
      print("Message data: ${message.data}");
      _processMessage(message, telephony);
    });

    // Check for initial message (app opened from terminated state)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print("APP STARTED FROM TERMINATED STATE VIA NOTIFICATION ======================");
        print("Message data: ${message.data}");
        _processMessage(message, telephony);
      }
    });

    print("Firebase Messaging listeners setup complete");
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
      print("SMS sent successfully to $phoneNumber");
    } catch (e) {
      print("Error sending SMS: $e");
    }
  }
}