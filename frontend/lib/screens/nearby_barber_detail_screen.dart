import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/services/nearby_service.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/salon_detail_screen.dart';
import 'package:geolocator/geolocator.dart';

class NearbyBarberDetailScreen extends StatefulWidget {
  final NearbyBarber barber;

  const NearbyBarberDetailScreen({super.key, required this.barber});

  @override
  State<NearbyBarberDetailScreen> createState() => _NearbyBarberDetailScreenState();
}

class _NearbyBarberDetailScreenState extends State<NearbyBarberDetailScreen> {
  String? _matchedSalonId;
  bool _isCheckingMatch = true;
  late String _activeImageUrl;

  @override
  void initState() {
    super.initState();
    _activeImageUrl = widget.barber.imageUrl ?? 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800';
    _checkLocalDbMatch();
  }

  /// Checks if this real-world barber matches any salon in the local database
  Future<void> _checkLocalDbMatch() async {
    try {
      final result = await ApiService.getSalons();
      if (result.success && result.data != null) {
        final localSalons = result.data!;
        for (final salon in localSalons) {
          final salonName = salon['name'].toString().toLowerCase().trim();
          final barberName = widget.barber.name.toLowerCase().trim();
          
          final double distance = Geolocator.distanceBetween(
            (salon['latitude'] as num).toDouble(),
            (salon['longitude'] as num).toDouble(),
            widget.barber.latitude,
            widget.barber.longitude,
          );
          
          // Match criteria: extremely close coordinates (< 150m) or containing name
          if (distance < 150 || salonName.contains(barberName) || barberName.contains(salonName)) {
            if (mounted) {
              setState(() {
                _matchedSalonId = salon['id'].toString();
                _isCheckingMatch = false;
              });
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking local DB match: $e');
    }
    if (mounted) {
      setState(() {
        _isCheckingMatch = false;
      });
    }
  }

  /// Launch Google Maps navigation
  Future<void> _launchNavigation(double destLat, double destLng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not open map navigation app.');
      }
    } catch (e) {
      _showSnackBar('Could not start navigation: $e');
    }
  }

  /// Launch phone call
  Future<void> _makeCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnackBar('Could not start phone call.');
      }
    } catch (e) {
      _showSnackBar('Hata: $e');
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF9C27B0),
      ),
    );
  }

  void _handleOnlineBooking() {
    if (_matchedSalonId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SalonDetailScreen(salonId: _matchedSalonId!),
        ),
      );
    } else {
      // Show info dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFE040FB)),
              SizedBox(width: 12),
              Text('Online Booking is Not Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            '"${widget.barber.name}" is not yet a member of our online booking system. You can call the business directly to make a reservation.',
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('KAPAT', style: TextStyle(color: Colors.white38)),
            ),
            if (widget.barber.phoneNumber != null && widget.barber.phoneNumber!.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _makeCall(widget.barber.phoneNumber!);
                },
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('ARA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Dynamic App Bar with Image
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: const Color(0xFF1E1E2F),
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _activeImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: const Color(0xFF1E1E2F),
                          child: const Icon(Icons.store, size: 80, color: Colors.white24),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                              const Color(0xFF0F0F1E),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Content
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title & Rating
                        _buildHeaderSection(),
                        const SizedBox(height: 12),
                        
                        // Distance & Opening state
                        _buildMetaSection(),
                        const SizedBox(height: 24),
                        
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 16),
                        
                        // Image Gallery
                        _buildGallerySection(),
                        const SizedBox(height: 24),

                        // Working Hours
                        _buildWorkingHoursSection(),
                        const SizedBox(height: 24),

                        // Services list
                        _buildServicesSection(),
                        const SizedBox(height: 24),

                        // Reviews list
                        _buildReviewsSection(),
                        const SizedBox(height: 100), // padding for floating bottom button
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),

          // Bottom Booking & Direction Action Bar
          _buildFloatingBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            widget.barber.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.barber.rating?.toStringAsFixed(1) ?? '4.5',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaSection() {
    return Row(
      children: [
        const Icon(Icons.navigation_outlined, color: Colors.blueAccent, size: 16),
        const SizedBox(width: 6),
        Text(
          widget.barber.distanceMeter >= 1000
              ? '${(widget.barber.distanceMeter / 1000).toStringAsFixed(1)} km away'
              : '${widget.barber.distanceMeter.toInt()} meters away',
          style: const TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        if (widget.barber.isOpen != null) ...[
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.barber.isOpen! ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.barber.isOpen! ? 'OPEN' : 'CLOSED',
              style: TextStyle(
                color: widget.barber.isOpen! ? Colors.green : Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo Gallery',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.barber.galleryUrls.length,
            itemBuilder: (context, index) {
              final imgUrl = widget.barber.galleryUrls[index];
              final isCurrent = _activeImageUrl == imgUrl;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _activeImageUrl = imgUrl;
                  });
                },
                child: Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? const Color(0xFFE040FB) : Colors.white10,
                      width: isCurrent ? 2.0 : 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkingHoursSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time, color: Color(0xFFE040FB), size: 20),
              SizedBox(width: 10),
              Text(
                'Working Hours',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.barber.workingHours.map((wh) {
            final isToday = _isDayToday(wh['day']!);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    wh['day']!,
                    style: TextStyle(
                      color: isToday ? Colors.white : Colors.white54,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    wh['hours']!,
                    style: TextStyle(
                      color: isToday ? const Color(0xFFE040FB) : Colors.white70,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  bool _isDayToday(String dayName) {
    final now = DateTime.now();
    final weekday = now.weekday;
    switch (weekday) {
      case 1: return dayName == 'Pazartesi';
      case 2: return dayName == 'Tuesday';
      case 3: return dayName == 'Wednesday';
      case 4: return dayName == 'Thursday';
      case 5: return dayName == 'Cuma';
      case 6: return dayName == 'Cumartesi';
      case 7: return dayName == 'Pazar';
    }
    return false;
  }

  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hizmetler ve Fiyatlar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        ...widget.barber.services.map((service) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  service['name'],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                ),
                Text(
                  '${service['price']} TL',
                  style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Customer Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              '${widget.barber.reviewCount} Yorum',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...widget.barber.reviews.map((rev) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      rev['name'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      rev['date'],
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Row(
                      children: List.generate(5, (idx) {
                        return Icon(
                          Icons.star,
                          size: 14,
                          color: idx < (rev['rating'] as double).round() ? Colors.amber : Colors.white12,
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (rev['rating'] as double).toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '"${rev['comment']}"',
                  style: const TextStyle(color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFloatingBottomActions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2F).withOpacity(0.95),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        ),
        child: Row(
          children: [
            // Directions Button
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: IconButton(
                icon: const Icon(Icons.directions, color: Colors.blueAccent),
                padding: const EdgeInsets.all(16),
                onPressed: () => _launchNavigation(widget.barber.latitude, widget.barber.longitude),
                tooltip: 'Yol Tarifi Al',
              ),
            ),
            const SizedBox(width: 12),
            
            // Booking Button
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: _isCheckingMatch
                      ? null
                      : LinearGradient(
                          colors: _matchedSalonId != null
                              ? [const Color(0xFF9C27B0), const Color(0xFFE040FB)]
                              : [Colors.white12, Colors.white10],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _matchedSalonId != null
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE040FB).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: _isCheckingMatch ? null : _handleOnlineBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isCheckingMatch
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        )
                      : Text(
                          _matchedSalonId != null ? 'BOOK ONLINE' : 'CONTACT BUSINESS',
                          style: TextStyle(
                            color: _matchedSalonId != null ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
