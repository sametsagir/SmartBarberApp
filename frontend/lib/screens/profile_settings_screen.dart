import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  int _selectedMinutes = 60;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _reminderOptions = [
    {'label': '30 Minutes Before', 'value': 30},
    {'label': '1 Hour Before', 'value': 60},
    {'label': '2 Hours Before', 'value': 120},
    {'label': '12 Hours Before', 'value': 720},
    {'label': '1 Day (24 Hours) Before', 'value': 1440},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getUserSettings();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _selectedMinutes = res.data!['reminderMinutesBefore'] ?? 60;
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final res = await ApiService.updateUserSettings(_selectedMinutes);
    setState(() => _isSaving = false);

    if (mounted) {
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder setting successfully updated.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Update failed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2F),
        title: const Text('Profile Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  // Title / Icon
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFF1E1E2F),
                    child: Icon(Icons.settings, size: 40, color: Color(0xFFE040FB)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Appointment Reminder Setting',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Choose how long before appointments SMS and stylist notifications should be triggered.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  // Dropdown Selection Container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMinutes,
                        dropdownColor: const Color(0xFF1E1E2F),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE040FB)),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        isExpanded: true,
                        items: _reminderOptions.map((opt) {
                          return DropdownMenuItem<int>(
                            value: opt['value'],
                            child: Text(opt['label']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMinutes = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_isSaving)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 6,
                      ),
                      child: const Text(
                        'AYARLARI KAYDET',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
    );
  }
}
