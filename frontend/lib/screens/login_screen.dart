import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/otp_screen.dart';
import 'package:frontend/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    // Format to standard E.164: +905051234567
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final phoneNumber = '+90$rawPhone';
    
    final result = await ApiService.sendOtp(phoneNumber);

    setState(() => _isLoading = false);

    if (context.mounted) {
      if (result.success) {
        final debugCode = result.data?['debugCode'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(debugCode != null
                ? 'Verification code sent (Simulated: $debugCode)'
                : 'Verification code sent!'),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              phoneNumber: phoneNumber,
              debugCode: debugCode,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'An error occurred.')),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2F), Color(0xFF0F0F1E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon
                    const Icon(
                      Icons.content_cut,
                      size: 80,
                      color: Color(0xFF9C27B0),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    const Text(
                      'SmartBarberApp',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The best stylists, the easiest booking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Login or Sign Up',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Verify by entering your phone number',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Phone Field with Mask
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              PhoneInputFormatter(),
                            ],
                            decoration: InputDecoration(
                              prefixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(width: 16),
                                  Icon(Icons.phone, color: Color(0xFF9C27B0)),
                                  SizedBox(width: 8),
                                  Text(
                                    '+90 ',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 4),
                                ],
                              ),
                              hintText: '(555) 123 45 67',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 18),
                              filled: true,
                              fillColor: Colors.black26,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.redAccent),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                  return 'Phone number cannot be empty.';
                              }
                              final digits = value.replaceAll(RegExp(r'\D'), '');
                              if (digits.length != 10) {
                                  return 'Please enter the full 10-digit number.';
                              }
                              if (!digits.startsWith('5')) {
                                  return 'Number must start with 5.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          // Submit Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _sendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9C27B0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 24),
                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'or',
                                  style: TextStyle(color: Colors.white38, fontSize: 14),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Google Login Button
                          ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.05),
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.15)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.person_add_outlined, size: 20),
                                SizedBox(width: 12),
                                Text(
                                  'CREATE ACCOUNT',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}

// Custom Phone Number Mask Formatter: (5XX) XXX XX XX
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var oldText = oldValue.text.replaceAll(RegExp(r'\D'), '');
    var newText = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Eğer kullanıcı boşluk veya parantez gibi bir format karakterini silerse
    // ham sayı uzunluğu değişmez ama metin kısalır. Bu durumda sondaki rakamı da sil.
    if (newValue.text.length < oldValue.text.length && oldText.length == newText.length) {
      if (newText.isNotEmpty) {
        newText = newText.substring(0, newText.length - 1);
      }
    }

    if (newText.length > 10) {
      newText = newText.substring(0, 10);
    }
    
    var buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      if (i == 0) buffer.write('(');
      buffer.write(newText[i]);
      if (i == 2) buffer.write(') ');
      if (i == 5) buffer.write(' ');
      if (i == 7) buffer.write(' ');
    }
    
    var formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
