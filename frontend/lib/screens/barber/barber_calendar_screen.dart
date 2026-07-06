import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/api_service.dart';

class BarberCalendarScreen extends StatefulWidget {
  const BarberCalendarScreen({super.key});

  @override
  State<BarberCalendarScreen> createState() => _BarberCalendarScreenState();
}

class _BarberCalendarScreenState extends State<BarberCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _employees = [];
  List<dynamic> _appointments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    final employeesRes = await ApiService.getEmployees();
    final appointmentsRes = await ApiService.getSalonAppointments(dateStr);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (employeesRes.success && employeesRes.data != null) {
          _employees = employeesRes.data!;
        }
        if (appointmentsRes.success && appointmentsRes.data != null) {
          _appointments = appointmentsRes.data!;
        } else {
          _appointments = [];
        }
      });
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9C27B0),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2F),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  void _showWalkInDialog(dynamic stylist) async {
    setState(() => _isLoading = true);
    final servicesRes = await ApiService.getBarberServices();
    setState(() => _isLoading = false);

    if (!servicesRes.success || servicesRes.data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load salon services.')),
        );
      }
      return;
    }

    final List<dynamic> services = servicesRes.data!;
    if (services.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must add a service to the shop first before adding a walk-in booking.')),
        );
      }
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedServiceId = services.first['id'].toString();
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Walk-in Booking: ${stylist['fullName']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Customer Name', Icons.person),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter customer name' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.phone,
                        decoration: _buildInputDecoration('Phone Number (Optional)', Icons.phone),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        dropdownColor: const Color(0xFF1E1E2F),
                        style: const TextStyle(color: Colors.white),
                        value: selectedServiceId,
                        decoration: _buildInputDecoration('Select Service', Icons.content_cut),
                        items: services.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'].toString(),
                            child: Text('${s['name']} (${s['price']} TL)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedServiceId = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFF9C27B0),
                                    onPrimary: Colors.white,
                                    surface: Color(0xFF1E1E2F),
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setSheetState(() => selectedTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Color(0xFF9C27B0)),
                              const SizedBox(width: 12),
                              Text(
                                'Appointment Time: ${selectedTime.format(context)}',
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                              ),
                              const Spacer(),
                              const Icon(Icons.edit, color: Colors.white38, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  setSheetState(() => isSaving = true);
                                  
                                  final dateFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate);
                                  final hourStr = selectedTime.hour.toString().padLeft(2, '0');
                                  final minStr = selectedTime.minute.toString().padLeft(2, '0');
                                  final startStr = '$dateFormatted $hourStr:$minStr';

                                  final res = await ApiService.createWalkInAppointment(
                                    stylistId: stylist['id'].toString(),
                                    serviceId: selectedServiceId!,
                                    startTime: startStr,
                                    guestName: nameController.text.trim(),
                                    guestPhone: phoneController.text.trim(),
                                  );

                                  setSheetState(() => isSaving = false);
                                  
                                  if (mounted) {
                                    if (res.success) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Walk-in appointment successfully created!')),
                                      );
                                      _loadData();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(res.message ?? 'Booking conflict or error occurred.')),
                                      );
                                    }
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C27B0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF9C27B0)),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateTitle = DateFormat('dd MMMM yyyy, EEEE', 'en_US').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Agenda'),
        backgroundColor: const Color(0xFF1E1E2F),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2F), Color(0xFF0F0F1E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Date selector banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black.withOpacity(0.15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
                    onPressed: () => _changeDate(-1),
                  ),
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Color(0xFFE040FB), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            dateTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white70),
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
            ),
            
            // Scheduling Grid
            Expanded(
              child: _isLoading && _employees.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                      ),
                    )
                  : _employees.isEmpty
                      ? const Center(
                          child: Text(
                            'To view the agenda, please add staff from Staff Management first.',
                            style: TextStyle(color: Colors.white38),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: const Color(0xFF9C27B0),
                          backgroundColor: const Color(0xFF1E1E2F),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _employees.length,
                            itemBuilder: (context, empIdx) {
                              final stylist = _employees[empIdx];
                              final stylistIdStr = stylist['id'].toString();
                              
                              // Filter appointments for this stylist
                              final stylistApps = _appointments.where((a) => a['stylistId'].toString() == stylistIdStr).toList();
                              
                              return _buildStylistColumn(stylist, stylistApps);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStylistColumn(dynamic stylist, List<dynamic> apps) {
    return Container(
      width: 290,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header (Stylist Name)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF9C27B0).withOpacity(0.15),
                  child: Text(
                    stylist['fullName'].isNotEmpty ? stylist['fullName'][0].toUpperCase() : 'B',
                    style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  stylist['fullName'],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  stylist['title'],
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Appointments list inside stylist column
          Expanded(
            child: apps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.event_available, size: 36, color: Colors.white12),
                        SizedBox(height: 8),
                        Text('No appointments today', style: TextStyle(color: Colors.white24, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: apps.length,
                    itemBuilder: (context, idx) {
                      final app = apps[idx];
                      final startStr = app['startTime'] as String;
                      final endStr = app['endTime'] as String;
                      final startTimeFormatted = startStr.substring(startStr.length - 5);
                      final endTimeFormatted = endStr.substring(endStr.length - 5);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, color: Color(0xFFE040FB), size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$startTimeFormatted - $endTimeFormatted',
                                      style: const TextStyle(color: Color(0xFFE040FB), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${app['servicePrice']} TL',
                                    style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              app['customerName'] ?? '',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              app['serviceName'] ?? '',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (app['customerPhone'] != null && app['customerPhone'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone, color: Colors.white24, size: 11),
                                  const SizedBox(width: 4),
                                  Text(
                                    app['customerPhone'],
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          // Add Walk-in booking at bottom
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showWalkInDialog(stylist),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Walk-in Appointment', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.04),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
