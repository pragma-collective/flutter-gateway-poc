import 'package:another_telephony/telephony.dart';
import 'package:cellfi_app/core/services/api_service.dart';
import 'package:cellfi_app/utils/command_validator.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
void handleNewMessage(SmsMessage message) async { 
  SMSService().handleIncomingSms(message);
}

class SMSService {
  final ApiService _apiService = ApiService();
  
  void initializeListener() async {
    debugPrint("Start initializing SMS listener...");
    final telephony = Telephony.instance;
  
    // Request permissions
    final bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    
    if (permissionsGranted != null && permissionsGranted) {
      // Register the background handler
      telephony.listenIncomingSms(
        onNewMessage: handleNewMessage,  // Foreground handler
        onBackgroundMessage: handleNewMessage,  // Background handler
        listenInBackground: true  // Critical flag to enable background listening
      );
      
      debugPrint("🎧 SMS listener registered for background operation");
    } else {
      debugPrint("❌ SMS permissions not granted");
    }
  }

  Future<void> handleIncomingSms(SmsMessage message) async{
    // Logic to handle incoming SMS in the foreground
    final sender = message.address ?? 'Unknown';
    final body = message.body ?? '';

    debugPrint('New SMS from $sender: $body');

    final msgStartTime = DateTime.now();
    
    try {
      if (CommandValidator.isValidCommand(body)) {
        await _apiService.sendMessage(sender, body);

        final msgDuration = DateTime.now().difference(msgStartTime).inMilliseconds;

        debugPrint('Message sent: $body');
        debugPrint('Message duration: $msgDuration ms');

        return;
      }

      debugPrint('Invalid command: $body');
    } catch (e) {
      // @todo: store only failed messages?
      debugPrint('Error processing SMS: $e');
    }
  }
}