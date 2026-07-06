import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';

class BarberAnalyticsScreen extends StatefulWidget {
  final bool isOwner;
  const BarberAnalyticsScreen({super.key, this.isOwner = false});

  @override
  State<BarberAnalyticsScreen> createState() => _BarberAnalyticsScreenState();
}

class _BarberAnalyticsScreenState extends State<BarberAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _analyticsData;
  String _selectedPeriod = "daily"; // "daily" or "monthly"

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getBarberAnalytics();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _analyticsData = result.data!;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to load analytics data.')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
        ),
      );
    }

    if (_analyticsData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'Failed to load analytics data.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalytics,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C27B0)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final data = _analyticsData!;
    final totalSalonRevenue = data['totalSalonRevenue'] ?? 0;
    final totalSalonBookings = data['totalSalonBookings'] ?? 0;
    final personalRevenue = data['personalRevenue'] ?? 0;
    final personalBookings = data['personalBookings'] ?? 0;
    final salonName = data['salonName'] ?? 'Salon';

    final List<dynamic> dailyEarnings = data['dailyEarnings'] ?? [];
    final List<dynamic> monthlyEarnings = data['monthlyEarnings'] ?? [];
    final List<dynamic> stylistStats = data['stylistStats'] ?? [];
    final List<dynamic> serviceStats = data['serviceStats'] ?? [];

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: const Color(0xFF9C27B0),
      backgroundColor: const Color(0xFF1E1E2F),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenue & Analytics Report',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    salonName,
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadAnalytics,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Overview Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35, // Taller cells to prevent overflow (especially with scaled fonts)
            children: [
              if (widget.isOwner) ...[
                _buildStatCard(
                  'Total Salon Revenue',
                  '${totalSalonRevenue.toStringAsFixed(0)} TL',
                  Icons.payments,
                  const Color(0xFF4CAF50),
                ),
                _buildStatCard(
                  'Salon Appointments',
                  '$totalSalonBookings',
                  Icons.calendar_today,
                  const Color(0xFF00BCD4),
                ),
              ],
              _buildStatCard(
                'Personal Earnings',
                '${personalRevenue.toStringAsFixed(0)} TL',
                Icons.account_balance_wallet,
                const Color(0xFF9C27B0),
              ),
              _buildStatCard(
                'Personal Appointments',
                '$personalBookings',
                Icons.person_pin,
                const Color(0xFFFF9800),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Revenue Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Revenue Chart',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        _buildPeriodTab('daily', 'Daily'),
                        const SizedBox(width: 8),
                        _buildPeriodTab('monthly', 'Monthly'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _selectedPeriod == 'daily'
                    ? BarChartWidget(
                        data: dailyEarnings,
                        labelKey: 'dayName',
                        valueKey: 'revenue',
                        subLabelKey: 'dayMonth',
                      )
                    : BarChartWidget(
                        data: monthlyEarnings,
                        labelKey: 'monthName',
                        valueKey: 'revenue',
                      ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Stylist Performance List (En Çok Tercih Edilen)
          if (widget.isOwner) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Most Preferred Stylists',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  stylistStats.isEmpty
                      ? const Center(
                          child: Text(
                            'No stylist performance data found.',
                            style: TextStyle(color: Colors.white30, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: stylistStats.length,
                          itemBuilder: (context, index) {
                            final st = stylistStats[index];
                            final count = st['bookingCount'] ?? 0;
                            final revenue = st['revenue'] ?? 0;
                            final name = st['fullName'] ?? '';

                            // Calculate percentage compared to total salon bookings
                            final double pct = totalSalonBookings > 0 ? (count / totalSalonBookings) : 0.0;
                            
                            // Initials for avatar
                            String initials = "";
                            final names = name.split(' ');
                            if (names.isNotEmpty) {
                              initials += names[0][0];
                              if (names.length > 1 && names[1].isNotEmpty) {
                                initials += names[1][0];
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF9C27B0).withOpacity(0.2),
                                    child: Text(
                                      initials.toUpperCase(),
                                      style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            Text(
                                              '${revenue.toStringAsFixed(0)} TL',
                                              style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$count Bookings (${(pct * 100).toStringAsFixed(0)}%)',
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: pct,
                                            backgroundColor: Colors.white.withOpacity(0.05),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 4. Popular Services List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Service Preference Distribution',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                serviceStats.isEmpty
                    ? const Center(
                        child: Text(
                          'No service stats data found.',
                          style: TextStyle(color: Colors.white30, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: serviceStats.length,
                        separatorBuilder: (context, index) => const Divider(height: 20, color: Colors.white10),
                        itemBuilder: (context, index) {
                          final svc = serviceStats[index];
                          final count = svc['bookingCount'] ?? 0;
                          final revenue = svc['revenue'] ?? 0;
                          final name = svc['name'] ?? '';

                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE040FB).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.content_cut,
                                  color: Color(0xFFE040FB),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$count Kez Tercih Edildi',
                                      style: const TextStyle(color: Colors.white30, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${revenue.toStringAsFixed(0)} TL',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // reduced vertical padding slightly
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1, // prevent wrap which causes overflow
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: iconColor, size: 16),
            ],
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), // slightly reduced font size from 18 to 16
            maxLines: 1, // prevent wrap
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9C27B0) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF9C27B0) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class BarChartWidget extends StatelessWidget {
  final List<dynamic> data;
  final String labelKey;
  final String valueKey;
  final String? subLabelKey;
  final double height;

  const BarChartWidget({
    super.key,
    required this.data,
    required this.labelKey,
    required this.valueKey,
    this.subLabelKey,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No data available.', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );
    }

    double maxValue = data.map((item) => (item[valueKey] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) maxValue = 1.0;

    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((item) {
          final val = (item[valueKey] as num).toDouble();
          final label = item[labelKey].toString();
          final subLabel = subLabelKey != null ? item[subLabelKey].toString() : null;
          final ratio = val / maxValue;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Revenue value
                Text(
                  val > 0 ? '${val.toInt()}' : '0',
                  style: const TextStyle(color: Color(0xFFE040FB), fontSize: 9, fontWeight: FontWeight.bold),
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
                // Bar indicator (Expanded + FractionallySizedBox to prevent layout overflow)
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: ratio,
                    alignment: Alignment.bottomCenter,
                    child: Tooltip(
                      message: '$label: ${val.toInt()} TL',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9C27B0), Color(0xFFE040FB)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9C27B0).withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Main Label
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Sub label (e.g. 19.06)
                if (subLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: const TextStyle(color: Colors.white30, fontSize: 8),
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
