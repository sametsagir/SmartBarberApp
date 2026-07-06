import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';

class BookingScreen extends StatefulWidget {
  final String salonName;
  final Map<String, dynamic> service;
  final Map<String, dynamic> stylist;
  final String? rescheduleAppointmentId;

  const BookingScreen({
    super.key,
    required this.salonName,
    required this.service,
    required this.stylist,
    this.rescheduleAppointmentId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late List<DateTime> _dates;
  late DateTime _selectedDate;
  List<dynamic> _availableSlots = [];
  bool _isLoadingSlots = true;
  String? _selectedTimeSlot;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _dates = _generateDates();
    _selectedDate = _dates.first;
    _loadSlots();
  }

  List<DateTime> _generateDates() {
    final list = <DateTime>[];
    final today = DateTime.now();
    for (int i = 0; i < 14; i++) {
      list.add(today.add(Duration(days: i)));
    }
    return list;
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _getDayName(DateTime date) {
    const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return dayNames[date.weekday % 7];
  }

  Future<void> _loadSlots() async {
    setState(() {
      _isLoadingSlots = true;
      _selectedTimeSlot = null; // Reset selection on date change
    });
    
    final dateStr = _formatDate(_selectedDate);
    final result = await ApiService.getAvailableSlots(
      widget.stylist['id'],
      dateStr,
      widget.service['id'],
    );

    setState(() => _isLoadingSlots = false);

    if (result.success && result.data != null) {
      setState(() => _availableSlots = result.data!);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to load available hours.')),
        );
      }
    }
  }

  Future<void> _bookAppointment() async {
    if (_selectedTimeSlot == null) return;

    setState(() => _isBooking = true);
    final dateStr = _formatDate(_selectedDate);

    if (widget.rescheduleAppointmentId != null) {
      // Reschedule path
      final result = await ApiService.rescheduleAppointment(
        widget.rescheduleAppointmentId!,
        dateStr,
        _selectedTimeSlot!,
      );

      setState(() => _isBooking = false);

      if (mounted) {
        if (result.success) {
          _showRescheduleSuccessDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to update appointment.')),
          );
        }
      }
    } else {
      // Create new booking path
      final customerId = await ApiService.getUserId();
      if (customerId == null) {
        setState(() => _isBooking = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User session not found. Please log in again.')),
          );
        }
        return;
      }

      final result = await ApiService.createAppointment(
        customerId,
        widget.stylist['id'],
        widget.service['id'],
        dateStr,
        _selectedTimeSlot!,
      );

      setState(() => _isBooking = false);

      if (mounted) {
        if (result.success) {
          _showSuccessDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to book appointment.')),
          );
        }
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 72),
            const SizedBox(height: 24),
            const Text(
              'Booking Successful!',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.stylist['fullName']} - Your appointment at ${_selectedTimeSlot!} was successfully created.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Return back to main page (pop Dialog, pop BookingScreen, pop SalonDetailScreen)
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // pop BookingScreen
                Navigator.pop(context); // pop SalonDetailScreen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRescheduleSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 72),
            const SizedBox(height: 24),
            const Text(
              'Appointment Updated!',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.stylist['fullName']} - Your appointment has been successfully updated to ${_selectedTimeSlot!}.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context, true); // pop BookingScreen and return success
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      widget.rescheduleAppointmentId != null ? 'Update Appointment' : 'Select Date & Time',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              
              // Selected Info Summary
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.salonName,
                      style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.service['name'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Usta: ${widget.stylist['fullName']} (${widget.stylist['title']})',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 1. Date picker ribbon
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Select Date',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _dates.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final date = _dates[index];
                    final isSelected = _selectedDate.day == date.day &&
                        _selectedDate.month == date.month &&
                        _selectedDate.year == date.year;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDate = date);
                        _loadSlots();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF9C27B0)
                              : Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF9C27B0) : Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getDayName(date),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white54,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 2. Hour slot grid
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Select Time',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              
              Expanded(
                child: _isLoadingSlots
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                        ),
                      )
                    : _availableSlots.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.event_busy, size: 48, color: Colors.white38),
                                SizedBox(height: 12),
                                Text(
                                  'No available slots for this day.',
                                  style: TextStyle(color: Colors.white54, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 2.2,
                            ),
                            itemCount: _availableSlots.length,
                            itemBuilder: (context, index) {
                              final slot = _availableSlots[index] as String;
                              final isSelected = _selectedTimeSlot == slot;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedTimeSlot = slot),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF9C27B0).withOpacity(0.25)
                                        : Colors.white.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF9C27B0) : Colors.white.withOpacity(0.07),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      slot,
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFFE040FB) : Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              
              // Confirm Button
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton(
                  onPressed: (_selectedTimeSlot == null || _isBooking) ? null : _bookAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: Colors.white.withOpacity(0.03),
                    elevation: 4,
                  ),
                  child: _isBooking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.rescheduleAppointmentId != null ? 'UPDATE APPOINTMENT' : 'CONFIRM BOOKING',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
