import 'package:flutter/material.dart';
import 'package:cellfi_app/providers/device_registration_provider.dart';
import 'package:cellfi_app/core/services/secure_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:cellfi_app/routes/app_route.dart';
import 'package:cellfi_app/widgets/api_base_url_selector.dart';
import 'package:cellfi_app/utils/isar_helper.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

class RegisterDeviceScreen extends StatefulWidget {
  const RegisterDeviceScreen({Key? key}) : super(key: key);

  @override
  State<RegisterDeviceScreen> createState() => _RegisterDeviceScreenState();
}

class _RegisterDeviceScreenState extends State<RegisterDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isRegistering = false;
  bool _isInitializing = false;
  String? _errorMessage;

  // For intl phone field
  PhoneNumber? _phoneNumber;
  String? _completePhoneNumber;
  bool _isPhoneNumberValid = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();

    // Pre-initialize Isar when the registration screen is shown
    // This prevents the database initialization delay after registration
    _preInitializeIsar();
  }

  Future<void> _preInitializeIsar() async {
    // Only do this if Isar isn't already ready
    if (!IsarHelper.isIsarReady()) {
      setState(() {
        _isInitializing = true;
      });

      try {
        await IsarHelper.initIsar();
        debugPrint("✅ Isar pre-initialized in registration screen");
      } catch (e) {
        debugPrint("⚠️ Non-critical error pre-initializing Isar: $e");
        // We don't want to block registration if Isar pre-init fails
      } finally {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    }
  }

  Future<void> _loadPhoneNumber() async {
    try {
      final savedPhoneNumber = await SecureStorageService.getPhoneNumber();
      if (savedPhoneNumber != null && savedPhoneNumber.isNotEmpty) {
        // Just set the saved number - the field will handle displaying it
        setState(() {
          _completePhoneNumber = savedPhoneNumber;
        });
        debugPrint("📱 Loaded saved phone number: $savedPhoneNumber");
      }
    } catch (e) {
      debugPrint("Error loading phone number: $e");
    }
  }

  void _showApiUrlDialog() {
    ApiBaseUrlDialog.show(context);
  }

  Future<void> _registerDevice() async {
    // Validate the form
    if (!_formKey.currentState!.validate() || !_isPhoneNumberValid || _phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    try {
      // Create the complete phone number with plus sign
      final completeNumber = '+${_phoneNumber!.countryCode}${_phoneNumber!.number}';

      // Save phone number to secure storage
      await SecureStorageService.savePhoneNumber(completeNumber);
      debugPrint("📱 Saving phone number: $completeNumber");

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

      // Add a small delay to ensure everything is ready
      await Future.delayed(const Duration(milliseconds: 300));

      // Navigate to SMS screen on success
      if (mounted) {
        // Check if Isar is ready before navigation
        if (!IsarHelper.isIsarReady()) {
          debugPrint("⚠️ Isar not ready after registration, initializing now");

          // Show a "preparing database" indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful. Preparing database...')),
          );

          try {
            await IsarHelper.initIsar();
            debugPrint("✅ Isar initialized before navigation");
          } catch (e) {
            debugPrint("⚠️ Non-critical error initializing Isar before navigation: $e");
            // Continue with navigation even if Isar init fails
            // The SMS screen will handle the initialization if needed
          }
        }

        // Now navigate
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

              // International Phone Field
              IntlPhoneField(
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  counterText: '', // Hide the counter
                ),
                initialCountryCode: 'PH', // Default to Philippines
                onChanged: (phone) {
                  setState(() {
                    _phoneNumber = phone;
                    _isPhoneNumberValid = true; // Basic validation happens in the field
                  });
                },
                onCountryChanged: (country) {
                  debugPrint('Country changed to: ${country.name}');
                },
                validator: (phone) {
                  if (phone == null || phone.number.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
                disableLengthCheck: false, // Enable length check based on country
                flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 8),
                showDropdownIcon: true,
                dropdownIconPosition: IconPosition.trailing,
                invalidNumberMessage: 'Invalid phone number',
              ),

              const SizedBox(height: 8),
              Text(
                '* Please include your country code',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isRegistering || _isInitializing || _phoneNumber == null) ? null : _registerDevice,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Registering...'),
                  ],
                )
                    : _isInitializing
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Preparing...'),
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