import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isRegistering;
  final String? fullName;
  final String? role;
  final String? debugCode;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.isRegistering = false,
    this.fullName,
    this.role,
    this.debugCode,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Timer fields
  int _secondsRemaining = 120;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    if (widget.debugCode != null) {
      _codeController.text = widget.debugCode!;
    }
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 120;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
          _timer?.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  String get _timerText {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final code = _codeController.text.trim();
    
    TaskResult<Map<String, dynamic>> result;
    if (widget.isRegistering) {
      result = await ApiService.register(
        widget.phoneNumber,
        code,
        widget.fullName ?? '',
        widget.role ?? 'Customer',
      );
    } else {
      result = await ApiService.verifyOtp(widget.phoneNumber, code);
    }

    setState(() => _isLoading = false);

    if (context.mounted) {
      if (result.success && result.data != null) {
        final data = result.data!;
        final token = data['token'];
        if (token != null) {
          await ApiService.saveToken(token, user: data['user']);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isRegistering ? 'Registration completed successfully!' : 'Login successful!')),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Verification failed.')),
        );
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    final result = await ApiService.sendOtp(widget.phoneNumber, isRegister: widget.isRegistering);
    setState(() => _isLoading = false);

    if (context.mounted) {
      if (result.success) {
        final debugCode = result.data?['debugCode'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(debugCode != null
                ? 'New verification code sent (Simulated: $debugCode)'
                : 'New verification code successfully sent!'),
          ),
        );
        if (debugCode != null) {
          _codeController.text = debugCode;
        }
        _startTimer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to resend code.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Beautiful formatted display of phone number for user context
    String displayPhone = widget.phoneNumber;
    if (widget.phoneNumber.length == 13 && widget.phoneNumber.startsWith('+90')) {
      final p = widget.phoneNumber;
      displayPhone = '+90 (${p.substring(3, 6)}) ${p.substring(6, 9)} ${p.substring(9, 11)} ${p.substring(11, 13)}';
    }

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
                            Icons.security,
                            size: 80,
                            color: Color(0xFF9C27B0),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Verify Code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter the 6-digit verification code sent to $displayPhone.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
                                TextFormField(
                                  controller: _codeController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 8,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLength: 6,
                                  decoration: InputDecoration(
                                    hintText: '000000',
                                    hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                                    counterText: '',
                                    filled: true,
                                    fillColor: Colors.black26,
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
                                      return 'Please enter the code.';
                                    }
                                    if (value.length != 6) {
                                      return 'Code must be 6 digits.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyOtp,
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
                                          'VERIFY CODE',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 24),
                                // Resend Timer UI
                                Center(
                                  child: _canResend
                                      ? TextButton(
                                          onPressed: _isLoading ? null : _resendOtp,
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(0xFFE040FB),
                                          ),
                                          child: const Text(
                                            'Resend Code',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'Resend code in ($_timerText)',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 14,
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
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }
}
