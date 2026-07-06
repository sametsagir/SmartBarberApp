import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:frontend/screens/barber/barber_calendar_screen.dart';
import 'package:frontend/screens/barber/barber_employees_screen.dart';
import 'package:frontend/screens/barber/barber_reviews_screen.dart';

class BarberDashboard extends StatefulWidget {
  const BarberDashboard({super.key});

  @override
  State<BarberDashboard> createState() => _BarberDashboardState();
}

class _BarberDashboardState extends State<BarberDashboard> {
  String _activeTab = 'Daily'; // 'Günlük', 'Haftalık', 'Aylık'
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _appointments = [];
  bool _isLoading = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _checkOwnerStatus();
  }

  Future<void> _checkOwnerStatus() async {
    final result = await ApiService.getBarberProfile();
    if (mounted && result.success && result.data != null) {
      setState(() {
        _isOwner = result.data!['isOwner'] == true;
      });
    }
  }

  // Calculate start/end dates based on _activeTab and _selectedDate
  void _loadAppointments() async {
    setState(() => _isLoading = true);

    String? startDateStr;
    String? endDateStr;

    if (_activeTab == 'Daily') {
      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      startDateStr = start.toIso8601String();
      endDateStr = end.toIso8601String();
    } else if (_activeTab == 'Weekly') {
      // Find Monday of the selected week
      int currentWeekday = _selectedDate.weekday; // Mon=1, Sun=7
      final monday = _selectedDate.subtract(Duration(days: currentWeekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      final start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
      final end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
      startDateStr = start.toIso8601String();
      endDateStr = end.toIso8601String();
    } else if (_activeTab == 'Monthly') {
      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      final start = DateTime(firstDay.year, firstDay.month, firstDay.day, 0, 0, 0);
      final end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);
      startDateStr = start.toIso8601String();
      endDateStr = end.toIso8601String();
    }

    final result = await ApiService.getBarberAppointments(
      startDate: startDateStr,
      endDate: endDateStr,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _appointments = result.data!;
        } else {
          _appointments = [];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to load appointments.')),
          );
        }
      });
    }
  }

  void _changeDateRange(int delta) {
    setState(() {
      if (_activeTab == 'Daily') {
        _selectedDate = _selectedDate.add(Duration(days: delta));
      } else if (_activeTab == 'Weekly') {
        _selectedDate = _selectedDate.add(Duration(days: delta * 7));
      } else if (_activeTab == 'Monthly') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
      }
    });
    _loadAppointments();
  }

  String _getDateRangeTitle() {
    if (_activeTab == 'Daily') {
      return DateFormat('dd MMMM yyyy', 'en_US').format(_selectedDate);
    } else if (_activeTab == 'Weekly') {
      int currentWeekday = _selectedDate.weekday;
      final monday = _selectedDate.subtract(Duration(days: currentWeekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final startStr = DateFormat('dd MMM', 'en_US').format(monday);
      final endStr = DateFormat('dd MMM yyyy', 'en_US').format(sunday);
      return '$startStr - $endStr';
    } else {
      return DateFormat('MMMM yyyy', 'en_US').format(_selectedDate);
    }
  }

  void _handleConfirm(String appointmentId) async {
    setState(() => _isLoading = true);
    final result = await ApiService.confirmAppointment(appointmentId);
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? 'Appointment confirmed.' : (result.message ?? 'An error occurred.')),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      if (result.success) {
        _loadAppointments();
      }
    }
  }

  void _handleReject(String appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        title: const Text('Decline Appointment', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to decline this appointment?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final result = await ApiService.rejectAppointment(appointmentId);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? 'Appointment declined successfully.' : (result.message ?? 'An error occurred.')),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
        if (result.success) {
          _loadAppointments();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Title
        const Text(
          'Appointment Panel',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (_isOwner) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'Agenda',
                  subtitle: 'Overview',
                  icon: Icons.calendar_month,
                  color: const Color(0xFF9C27B0),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BarberCalendarScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'Staff',
                  subtitle: 'Staff Management',
                  icon: Icons.people_outline,
                  color: const Color(0xFFE040FB),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BarberEmployeesScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'Reviews',
                  subtitle: 'Customer Feedback',
                  icon: Icons.chat_bubble_outline,
                  color: Colors.cyan,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BarberReviewsScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),

        // Tabs Selector (Günlük, Haftalık, Aylık)
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: ['Daily', 'Weekly', 'Monthly'].map((tab) {
              final isSelected = _activeTab == tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeTab = tab;
                    });
                    _loadAppointments();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF9C27B0) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Date Switcher Widget
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: () => _changeDateRange(-1),
              ),
              Text(
                _getDateRangeTitle(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                onPressed: () => _changeDateRange(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Appointments Timeline / List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _loadAppointments();
            },
            color: const Color(0xFF9C27B0),
            backgroundColor: const Color(0xFF1E1E2F),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                    ),
                  )
                : _appointments.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                          const Center(
                            child: Icon(Icons.calendar_today_outlined, size: 64, color: Colors.white24),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'No appointments found for this date range.',
                              style: TextStyle(color: Colors.white38, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _appointments.length,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final app = _appointments[index];
                          final isCancelled = app['status'] == 'Cancelled';
                          final isPending = app['status'] == 'Pending';
                          final startDateTime = DateTime.parse(app['startTime']);
                          final endDateTime = DateTime.parse(app['endTime']);
                          final timeStr = '${DateFormat('HH:mm').format(startDateTime)} - ${DateFormat('HH:mm').format(endDateTime)}';
                          final dateStr = DateFormat('dd MMM yyyy', 'en_US').format(startDateTime);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isCancelled
                                  ? Colors.redAccent.withOpacity(0.03)
                                  : (isPending
                                      ? Colors.orangeAccent.withOpacity(0.02)
                                      : Colors.white.withOpacity(0.03)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCancelled
                                    ? Colors.redAccent.withOpacity(0.2)
                                    : (isPending
                                        ? Colors.orangeAccent.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.06)),
                              ),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Left Colored Accent Line
                                  Container(
                                    width: 5,
                                    decoration: BoxDecoration(
                                      color: isCancelled
                                          ? Colors.redAccent
                                          : (isPending
                                              ? Colors.orangeAccent
                                              : const Color(0xFF9C27B0)),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        bottomLeft: Radius.circular(16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Appointment Main Info
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Customer Name Initials Avatar + Name
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor: isCancelled
                                                          ? Colors.redAccent.withOpacity(0.2)
                                                          : (isPending
                                                              ? Colors.orangeAccent.withOpacity(0.2)
                                                              : const Color(0xFF9C27B0).withOpacity(0.2)),
                                                      child: Text(
                                                        app['customerName'].isNotEmpty
                                                            ? app['customerName'][0].toUpperCase()
                                                            : 'M',
                                                        style: TextStyle(
                                                          color: isCancelled
                                                              ? Colors.redAccent
                                                              : (isPending
                                                                  ? Colors.orangeAccent
                                                                  : const Color(0xFFE040FB)),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        app['customerName'],
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Price Tag
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF9C27B0).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${app['servicePrice']} TL',
                                                  style: const TextStyle(
                                                    color: Color(0xFFE040FB),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          // Service details
                                          Text(
                                            app['serviceName'],
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          // Time, Date & Duration info
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time, color: Colors.white38, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                timeStr,
                                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                              ),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.calendar_today_outlined, color: Colors.white38, size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                dateStr,
                                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                              ),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.timer_outlined, color: Colors.white38, size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${app['serviceDuration']} min',
                                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          if (app['customerPhone'] != null && app['customerPhone'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.phone, color: Colors.white38, size: 12),
                                                const SizedBox(width: 4),
                                                Text(
                                                  app['customerPhone'],
                                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (isPending) ...[
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                TextButton(
                                                  onPressed: () => _handleReject(app['id'].toString()),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.redAccent,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  child: const Row(
                                                    children: [
                                                      Icon(Icons.close, size: 14),
                                                      SizedBox(width: 4),
                                                      Text('Decline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  onPressed: () => _handleConfirm(app['id'].toString()),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF9C27B0),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    children: [
                                                      Icon(Icons.check, size: 14),
                                                      SizedBox(width: 4),
                                                      Text('Confirm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Status Badge or Cancelled indicator on right
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Center(
                                      child: isCancelled
                                          ? const Icon(Icons.cancel, color: Colors.redAccent, size: 20)
                                          : (isPending
                                              ? const Icon(Icons.hourglass_empty, color: Colors.orangeAccent, size: 20)
                                              : const Icon(Icons.check_circle, color: Color(0xFF9C27B0), size: 20)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white30, fontSize: 9),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
