import 'package:flutter/material.dart';
import 'package:cellfi_app/providers/device_registration_provider.dart';
import 'package:cellfi_app/core/services/secure_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:cellfi_app/routes/app_route.dart';
import 'package:cellfi_app/widgets/api_base_url_selector.dart';

class RegisterDeviceScreen extends StatefulWidget {
  const RegisterDeviceScreen({Key? key}) : super(key: key);

  @override
  State<RegisterDeviceScreen> createState() => _RegisterDeviceScreenState();
}

class _RegisterDeviceScreenState extends State<RegisterDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneNumberController = TextEditingController();
  bool _isRegistering = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    try {
      final phoneNumber = await SecureStorageService.getPhoneNumber();
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        setState(() {
          _phoneNumberController.text = phoneNumber;
        });
      }
    } catch (e) {
      debugPrint("Error loading phone number: $e");
    }
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _showApiUrlDialog() {
    ApiBaseUrlDialog.show(context);
  }

  Future<void> _registerDevice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    try {
      // Save phone number to secure storage
      await SecureStorageService.savePhoneNumber(_phoneNumberController.text);

      // Register the device
      final provider = Provider.of<DeviceRegistrationProvider>(context, listen: false);
      await provider.register();

      if (provider.error != null) {
        setState(() {
          _errorMessage = provider.error;
          _isRegistering = false;
        });
        return;
      }

      // Navigate to SMS screen on success
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.smsScreen);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRegistering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Device'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showApiUrlDialog,
            tooltip: 'API Settings',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Welcome to CellFi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'Please enter your phone number to register this device.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  helperText: 'Enter your full phone number with country code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 10) {
                    return '📵 Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isRegistering ? null : _registerDevice,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isRegistering
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Registering...'),
                  ],
                )
                    : const Text('Register Device'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Registration Error',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}