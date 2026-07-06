import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Local state for role selection: "Customer" or "Barber"
  String _selectedRole = "Customer";

  Future<void> _startRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Format to standard E.164: +905051234567
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final phoneNumber = '+90$rawPhone';
    final fullName = _nameController.text.trim();

    // Call sendOtp with isRegister: true
    final result = await ApiService.sendOtp(phoneNumber, isRegister: true);

    setState(() => _isLoading = false);

    if (context.mounted) {
      if (result.success) {
        final debugCode = result.data?['debugCode'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(debugCode != null
                ? 'Registration verification code sent (Simulated: $debugCode)'
                : 'Registration verification code sent!'),
          ),
        );
        
        // Navigate to OTP screen in registration mode, passing entered registration values
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              phoneNumber: phoneNumber,
              isRegistering: true,
              fullName: fullName,
              role: _selectedRole,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                     padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.person_add_alt_1,
                            size: 64,
                            color: Color(0xFF9C27B0),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Create New Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Fill in your information to start the registration process.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 32),
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
                                // Phone Field
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    PhoneRegFormatter(),
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
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(width: 4),
                                      ],
                                    ),
                                    hintText: '(555) 123 45 67',
                                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
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
                                      return 'Please enter the 10-digit number.';
                                    }
                                    if (!digits.startsWith('5')) {
                                      return 'Number must start with 5.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // Name Field
                                TextFormField(
                                  controller: _nameController,
                                  keyboardType: TextInputType.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.person, color: Color(0xFF9C27B0)),
                                    hintText: 'Full Name',
                                    hintStyle: const TextStyle(color: Colors.white38),
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
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your name.';
                                    }
                                    if (value.trim().split(' ').length < 2) {
                                      return 'Please enter both your first and last name.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                
                                // Role Picker Title
                                const Text(
                                  'Purpose of Use',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Customer Card Option
                                GestureDetector(
                                  onTap: () => setState(() => _selectedRole = "Customer"),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _selectedRole == "Customer"
                                          ? const Color(0xFF9C27B0).withOpacity(0.15)
                                          : Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _selectedRole == "Customer"
                                            ? const Color(0xFF9C27B0)
                                            : Colors.white.withOpacity(0.1),
                                        width: _selectedRole == "Customer" ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 32,
                                          color: _selectedRole == "Customer" ? const Color(0xFFE040FB) : Colors.white60,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: const [
                                              Text(
                                                'I am a Customer',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'I want to search for barbers and book appointments easily.',
                                                style: TextStyle(color: Colors.white60, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Barber Card Option
                                GestureDetector(
                                  onTap: () => setState(() => _selectedRole = "Barber"),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _selectedRole == "Barber"
                                          ? const Color(0xFF9C27B0).withOpacity(0.15)
                                          : Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _selectedRole == "Barber"
                                            ? const Color(0xFF9C27B0)
                                            : Colors.white.withOpacity(0.1),
                                        width: _selectedRole == "Barber" ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.content_cut,
                                          size: 32,
                                          color: _selectedRole == "Barber" ? const Color(0xFFE040FB) : Colors.white60,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: const [
                                              Text(
                                                'I am a Barber / Salon Owner',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'I want to manage my booking calendar and salon working hours.',
                                                style: TextStyle(color: Colors.white60, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                // Register Button
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _startRegistration,
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
                                          'START REGISTRATION & SEND CODE',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.1,
                                          ),
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}

class PhoneRegFormatter extends TextInputFormatter {
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
      newText = newText.substring(0, newText.length - 10 == 0 ? 10 : newText.length); // Keep up to 10
      newText = newText.substring(0, newText.length > 10 ? 10 : newText.length);
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
