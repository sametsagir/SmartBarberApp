import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';

class BarberWorkingHoursScreen extends StatefulWidget {
  final String? stylistId;
  final String? stylistName;
  const BarberWorkingHoursScreen({super.key, this.stylistId, this.stylistName});

  @override
  State<BarberWorkingHoursScreen> createState() => _BarberWorkingHoursScreenState();
}

class _BarberWorkingHoursScreenState extends State<BarberWorkingHoursScreen> {
  List<dynamic> _workingHours = [];
  bool _isLoading = false;

  final List<String> _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Fridayrtesi'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileAndHours();
  }

  Future<void> _loadProfileAndHours() async {
    setState(() => _isLoading = true);
    
    TaskResult<dynamic> result;
    if (widget.stylistId != null) {
      result = await ApiService.getEmployeeWorkingHours(widget.stylistId!);
    } else {
      result = await ApiService.getBarberProfile();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          List<dynamic> hours = [];
          if (widget.stylistId != null) {
            hours = result.data as List<dynamic>;
          } else {
            hours = result.data!['workingHours'] ?? [];
          }
          // Sort days to start with Monday (1) to Sunday (0)
          // 1, 2, 3, 4, 5, 6, 0
          hours.sort((a, b) {
            int aVal = a['dayOfWeek'] == 0 ? 7 : a['dayOfWeek'];
            int bVal = b['dayOfWeek'] == 0 ? 7 : b['dayOfWeek'];
            return aVal.compareTo(bVal);
          });
          // Make mutable copies of maps
          _workingHours = hours.map((h) => Map<String, dynamic>.from(h)).toList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to load working hours.')),
          );
        }
      });
    }
  }

  Future<void> _selectTime(int index, String fieldKey) async {
    final currentVal = _workingHours[index][fieldKey] as String?;
    TimeOfDay initialTime = const TimeOfDay(hour: 9, minute: 0);

    if (currentVal != null && currentVal.isNotEmpty) {
      final parts = currentVal.split(':');
      if (parts.length >= 2) {
        initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9C27B0),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2F),
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE040FB),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      final newTime = '$hourStr:$minuteStr';

      setState(() {
        _workingHours[index][fieldKey] = newTime;
      });
    }
  }

  Future<void> _saveWorkingHours() async {
    // Validate times before sending
    for (int i = 0; i < _workingHours.length; i++) {
      final day = _workingHours[i];
      if (day['isActive'] == true) {
        final start = _parseTime(day['startTime']);
        final end = _parseTime(day['endTime']);
        
        if (start.hour > end.hour || (start.hour == end.hour && start.minute >= end.minute)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_dayNames[day['dayOfWeek']]} start time cannot be after end time.')),
          );
          return;
        }

        final lunchStartStr = day['lunchStartTime'] as String?;
        final lunchEndStr = day['lunchEndTime'] as String?;

        if (lunchStartStr != null && lunchEndStr != null) {
          final lStart = _parseTime(lunchStartStr);
          final lEnd = _parseTime(lunchEndStr);

          if (lStart.hour > lEnd.hour || (lStart.hour == lEnd.hour && lStart.minute >= lEnd.minute)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${_dayNames[day['dayOfWeek']]} lunch break start time cannot be after end time.')),
            );
            return;
          }
        }
      }
    }

    setState(() => _isLoading = true);
    // Prep list structure to send
    final requestBody = _workingHours.map((h) {
      return {
        'dayOfWeek': h['dayOfWeek'],
        'startTime': h['startTime'],
        'endTime': h['endTime'],
        'lunchStartTime': h['lunchStartTime'],
        'lunchEndTime': h['lunchEndTime'],
        'isActive': h['isActive'],
      };
    }).toList();

    final TaskResult<dynamic> result;
    if (widget.stylistId != null) {
      result = await ApiService.updateEmployeeWorkingHours(widget.stylistId!, requestBody.cast<Map<String, dynamic>>());
    } else {
      result = await ApiService.updateBarberWorkingHours(requestBody);
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Working hours successfully saved!')),
        );
        _loadProfileAndHours();
        if (widget.stylistId != null) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Error occurred while saving.')),
        );
      }
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Shift Hours',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Schedule weekly shift hours, lunch breaks, and off days here.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: _isLoading && _workingHours.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                  ),
                )
              : ListView.builder(
                  itemCount: _workingHours.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final day = _workingHours[index];
                    final dayIndex = day['dayOfWeek'] as int;
                    final dayName = _dayNames[dayIndex];
                    final isActive = day['isActive'] as bool;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(isActive ? 0.03 : 0.01),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isActive ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.02),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dayName,
                                style: TextStyle(
                                  color: isActive ? Colors.white : Colors.white30,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    isActive ? 'Working' : 'Off / Closed',
                                    style: TextStyle(
                                      color: isActive ? const Color(0xFFE040FB) : Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: isActive,
                                    activeColor: const Color(0xFF9C27B0),
                                    onChanged: (val) {
                                      setState(() {
                                        _workingHours[index]['isActive'] = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (isActive) ...[
                            const Divider(color: Colors.white10, height: 16),
                            // Shift hours selection
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Working Hours', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                Row(
                                  children: [
                                    _buildTimeButton(day['startTime'], () => _selectTime(index, 'startTime')),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text('-', style: TextStyle(color: Colors.white38)),
                                    ),
                                    _buildTimeButton(day['endTime'], () => _selectTime(index, 'endTime')),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Lunch break hours selection
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Lunch Break', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                Row(
                                  children: [
                                    _buildTimeButton(
                                      day['lunchStartTime'] ?? '12:00',
                                      () => _selectTime(index, 'lunchStartTime'),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text('-', style: TextStyle(color: Colors.white38)),
                                    ),
                                    _buildTimeButton(
                                      day['lunchEndTime'] ?? '13:00',
                                      () => _selectTime(index, 'lunchEndTime'),
                                    ),
                                  ],
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

        // Save Button at bottom
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveWorkingHours,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );

    if (widget.stylistId != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.stylistName ?? 'Employee'} Shift Hours'),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: mainContent,
          ),
        ),
      );
    }

    return mainContent;
  }

  Widget _buildTimeButton(String time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          time,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }
}
