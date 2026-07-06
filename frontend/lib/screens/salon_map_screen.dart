import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/salon_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalonMapScreen extends StatefulWidget {
  const SalonMapScreen({super.key});

  @override
  State<SalonMapScreen> createState() => _SalonMapScreenState();
}

class _SalonMapScreenState extends State<SalonMapScreen> {
  List<dynamic> _salons = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedSalon;
  final MapController _mapController = MapController();

  // Active user coordinate (defaults to Kadıköy if not found in preferences)
  double _currentLat = 40.9901;
  double _currentLng = 29.0270;

  @override
  void initState() {
    super.initState();
    _loadLocationAndSalons();
  }

  Future<void> _loadLocationAndSalons() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('selected_lat');
    final lng = prefs.getDouble('selected_lng');

    if (lat != null && lng != null) {
      _currentLat = lat;
      _currentLng = lng;
    }

    await _loadSalons();

    // Move map to the current position after load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(LatLng(_currentLat, _currentLng), 15.5);
      } catch (e) {
        debugPrint('Could not move map: $e');
      }
    });
  }

  Future<void> _loadSalons() async {
    // Fetch salons with coordinates to calculate proximity
    final res = await ApiService.getSalons(
      latitude: _currentLat,
      longitude: _currentLng,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _salons = res.data!;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2F),
        elevation: 0,
        title: const Text(
          'Salon Map',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadLocationAndSalons,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
              ),
            )
          : Stack(
              children: [
                // Real OpenStreetMap Dark-theme Map via flutter_map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_currentLat, _currentLng),
                    initialZoom: 15.5,
                    minZoom: 5.0,
                    maxZoom: 19.5,
                    onTap: (_, __) {
                      setState(() => _selectedSalon = null);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.example.frontend',
                    ),
                    
                    // User current simulated location marker & Salon markers
                    MarkerLayer(
                      markers: [
                        // User Current Location (Center)
                        Marker(
                          point: LatLng(_currentLat, _currentLng),
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.25),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Salon Pins
                        ..._salons.map((salon) {
                          final double lat = (salon['latitude'] as num).toDouble();
                          final double lng = (salon['longitude'] as num).toDouble();
                          final isSelected = _selectedSalon?['id'] == salon['id'];

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedSalon = salon);
                                _mapController.move(LatLng(lat, lng), 14.5);
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFE040FB) : const Color(0xFF9C27B0),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.store,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: isSelected ? const Color(0xFFE040FB) : const Color(0xFF9C27B0),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),

                // Interactive Bottom Card Overlay
                if (_selectedSalon != null)
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: _buildSalonDetailCard(_selectedSalon!),
                  ),
              ],
            ),
    );
  }

  Widget _buildSalonDetailCard(Map<String, dynamic> salon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F).withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              salon['imageUrl'] ?? 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[900],
                child: const Icon(Icons.store, color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  salon['name'],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      salon['rating'].toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.navigation, color: Colors.blueAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      salon['distanceKm'] != null ? '${salon['distanceKm']} km' : 'Calculating Distance...',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SalonDetailScreen(salonId: salon['id']),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('VIEW DETAILS & BOOK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
