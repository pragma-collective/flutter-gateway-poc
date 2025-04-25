import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:cellfi_app/core/services/secure_storage_service.dart';
import 'package:cellfi_app/providers/device_registration_provider.dart';
import 'package:cellfi_app/utils/api_base_url_util.dart';
import 'package:cellfi_app/widgets/api_base_url_selector.dart';
import 'sms_screen.dart';

class RegisterDeviceScreen extends StatefulWidget {
  const RegisterDeviceScreen({super.key});

  @override
  State<RegisterDeviceScreen> createState() => _RegisterDeviceScreenState();
}

class _RegisterDeviceScreenState extends State<RegisterDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _fullPhoneNumber;
  bool _loading = false;
  String? _currentBaseUrl;
  final _apiConfig = ApiUrlConfig();

  @override
  void initState() {
    super.initState();
    _loadCurrentBaseUrl();
  }

  Future<void> _loadCurrentBaseUrl() async {
    final url = await _apiConfig.getBaseUrl();
    if (mounted) {
      setState(() {
        _currentBaseUrl = url;
      });
    }
  }

  Future<void> _showApiBaseUrlDialog() async {
    await ApiBaseUrlDialog.show(context);
    // Reload the current base URL after dialog is closed
    _loadCurrentBaseUrl();

    // Update the provider with the new URL
    if (mounted) {
      try {
        final provider = context.read<DeviceRegistrationProvider>();
        final newBaseUrl = await _apiConfig.getBaseUrl();

        if (newBaseUrl.isNotEmpty) {
          // Update the provider with the new URL
          provider.updateConfig(
            baseUrl: newBaseUrl,
            // You can add more config parameters here if needed
          );

          // Optionally log the update for debugging
          debugPrint('Updated provider base URL to: $newBaseUrl');

          // Show success confirmation to user
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API configuration updated successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Handle case where baseUrl is empty
          debugPrint('Warning: Retrieved base URL is empty');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update API configuration: Empty URL'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        // Handle any errors during the update process
        debugPrint('Error updating provider config: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update API configuration: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_fullPhoneNumber == null || _fullPhoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is required')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await SecureStorageService.savePhoneNumber(_fullPhoneNumber!);
      final provider = context.read<DeviceRegistrationProvider>();
      await provider.register();

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SmsScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Device")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display the current base URL and button to change it
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'API URL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showApiBaseUrlDialog,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Change'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _currentBaseUrl ?? 'Not set',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: _currentBaseUrl != null
                              ? Colors.black87
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              IntlPhoneField(
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                initialCountryCode: 'PH',
                onSaved: (phone) => _fullPhoneNumber = phone?.completeNumber,
                validator: (phone) {
                  if (phone == null || phone.completeNumber.isEmpty) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _submit,
                child: const Text('Register Device'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}