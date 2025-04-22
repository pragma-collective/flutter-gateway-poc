import 'package:flutter/material.dart';
import 'package:cellfi_app/core/services/secure_storage_service.dart';

class PhoneNumberSelector extends StatefulWidget {
  final VoidCallback onSaved;

  const PhoneNumberSelector({super.key, required this.onSaved});

  @override
  State<PhoneNumberSelector> createState() => _PhoneNumberSelectorState();
}

class _PhoneNumberSelectorState extends State<PhoneNumberSelector> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  Future<void> _handleSave() async {
    final number = _controller.text.trim();

    if (number.isEmpty || number.length < 10) {
      setState(() => _error = '📵 Enter a valid phone number');
      return;
    }

    await SecureStorageService.savePhoneNumber(number);
    widget.onSaved();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Your Phone Number'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'e.g. 0917xxxxxxx',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _handleSave,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
