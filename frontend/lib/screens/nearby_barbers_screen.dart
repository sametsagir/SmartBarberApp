import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/services/nearby_service.dart';
import 'package:frontend/screens/nearby_barber_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NearbyBarbersScreen extends StatefulWidget {
  const NearbyBarbersScreen({super.key});

  @override
  State<NearbyBarbersScreen> createState() => _NearbyBarbersScreenState();
}

class _NearbyBarbersScreenState extends State<NearbyBarbersScreen> {
  // Barber Lists
  List<NearbyBarber> _displayedBarbers = [];
  NearbyBarber? _selectedBarber;

  // Pagination State
  int _currentPage = 1;
  final int _pageSize = 12; // 10-15 results per page
  bool _hasMore = true;
  bool _isLoading = false;
  bool _permissionDenied = false;
  String? _googleNextPageToken;

  // Location State
  Position? _currentPosition;
  bool _mapCenterMoved = false;
  LatLng? _movedCenter;

  // UI Modes
  bool _isMapMode = true;

  // Controllers
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.85);
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Filters State
  String _sortBy = 'distance'; // 'distance', 'rating', 'reviews'
  double _radiusFilter = 10.0;  // Radius filter (1km - 10km)
  bool _onlyOpenFilter = false;
  String? _serviceFilter;       // E.g. 'Haircut', 'Beard Shave'

  final List<String> _availableServices = [
    'Haircut',
    'Beard Shave',
    'Blow Dry & Styling',
    'Skin Care & Mask',
    'Hair Coloring',
  ];

  // Manual location simulation options in case GPS is denied
  final List<Map<String, dynamic>> _manualLocations = [
    {'name': 'Kadikoy, Istanbul', 'lat': 40.9901, 'lng': 29.0270},
    {'name': 'Besiktas, Istanbul', 'lat': 41.0428, 'lng': 29.0075},
    {'name': 'Sisli, Istanbul', 'lat': 41.0602, 'lng': 28.9877},
    {'name': 'Uskudar, Istanbul', 'lat': 41.0267, 'lng': 29.0162},
    {'name': 'Fatih, Istanbul', 'lat': 41.0186, 'lng': 28.9436},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _checkLocationPermissionAndLoad();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore && !_isMapMode) {
        _loadNextPage();
      }
    }
  }

  /// Initial entry: Requests GPS permission and retrieves location
  Future<void> _checkLocationPermissionAndLoad() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
      _mapCenterMoved = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        setState(() {
          _permissionDenied = true;
          _isLoading = false;
        });
        _showSnackBar('Location services are disabled. Please enable GPS.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          setState(() {
            _permissionDenied = true;
            _isLoading = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _permissionDenied = true;
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      setState(() {
        _currentPosition = position;
      });

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      await prefs.setDouble('selected_lat', position.latitude);
      await prefs.setDouble('selected_lng', position.longitude);
      await prefs.setString('selected_loc_name', 'Current Location (GPS)');

      await _loadBarbers(position.latitude, position.longitude);

    } catch (e) {
      debugPrint('Error getting location: $e');
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
        _isLoading = false;
      });
    }
  }

  /// Loads real barbers using nearby service and populates cached list
  Future<void> _loadBarbers(double lat, double lng, {bool forceRefresh = false}) async {
    debugPrint('[_loadBarbers] Loading page 1 for coordinates: $lat, $lng');
    setState(() {
      _currentPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
      _currentPage = 1;
      _googleNextPageToken = null;
      _displayedBarbers = [];
      _hasMore = true;
      _mapCenterMoved = false;
    });
    await _fetchPage(page: 1, append: false, forceRefresh: forceRefresh);
  }

  /// Dynamic API-optimized page-by-page loading
  Future<void> _fetchPage({required int page, required bool append, bool forceRefresh = false}) async {
    if (_currentPosition == null) return;
    
    setState(() => _isLoading = true);

    try {
      final response = await NearbyService.fetchNearbyBarbers(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusInKm: _radiusFilter,
        forceRefresh: forceRefresh,
        page: page,
        pageSize: _pageSize,
        nextPageToken: _googleNextPageToken,
        searchQuery: _searchController.text,
        sortBy: _sortBy,
        onlyOpen: _onlyOpenFilter,
        requiredService: _serviceFilter,
      );

      if (!mounted) return;
      setState(() {
        _googleNextPageToken = response.nextPageToken;
        _hasMore = response.hasMore;
        
        if (append) {
          _displayedBarbers.addAll(response.barbers);
        } else {
          _displayedBarbers = response.barbers;
        }
        
        _isLoading = false;
        
        if (!append && _displayedBarbers.isNotEmpty) {
          _selectedBarber = _displayedBarbers.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMapMode) {
              _mapController.move(LatLng(_displayedBarbers.first.latitude, _displayedBarbers.first.longitude), 16.0);
            }
          });
        }
      });
    } catch (e, stack) {
      debugPrint('[_fetchPage] Error fetching page: $e\n$stack');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error loading location data: $e');
    }
  }

  void _loadNextPage() {
    if (_isLoading || !_hasMore) return;
    _currentPage++;
    _fetchPage(page: _currentPage, append: true);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _currentPage = 1;
      _googleNextPageToken = null;
      _hasMore = true;
    });
    _fetchPage(page: 1, append: false);
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

  /// Show manual location selection dialog
  void _showManualLocationSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Manual Location Selection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _manualLocations.map((loc) {
            return ListTile(
              leading: const Icon(Icons.location_city, color: Color(0xFFE040FB)),
              title: Text(loc['name'], style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('selected_lat', loc['lat']);
                await prefs.setDouble('selected_lng', loc['lng']);
                await prefs.setString('selected_loc_name', loc['name']);

                setState(() {
                  _permissionDenied = false;
                  _currentPosition = Position(
                    latitude: loc['lat'],
                    longitude: loc['lng'],
                    timestamp: DateTime.now(),
                    accuracy: 0.0,
                    altitude: 0.0,
                    heading: 0.0,
                    speed: 0.0,
                    speedAccuracy: 0.0,
                    altitudeAccuracy: 0.0,
                    headingAccuracy: 0.0,
                  );
                });
                _loadBarbers(loc['lat'], loc['lng']);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E2F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Filter & Sort',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  
                  // Sorting options
                  const Text('Sort By', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFilterChip(
                        label: 'Mesafe',
                        selected: _sortBy == 'distance',
                        onTap: () => setSheetState(() => _sortBy = 'distance'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Puan',
                        selected: _sortBy == 'rating',
                        onTap: () => setSheetState(() => _sortBy = 'rating'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Review Count',
                        selected: _sortBy == 'reviews',
                        onTap: () => setSheetState(() => _sortBy = 'reviews'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Distance radius filter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Search Radius', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${_radiusFilter.toStringAsFixed(0)} km', style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _radiusFilter,
                    min: 1.0,
                    max: 10.0,
                    divisions: 9,
                    activeColor: const Color(0xFFE040FB),
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setSheetState(() => _radiusFilter = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Open now switch
                  SwitchListTile(
                    title: const Text('Open Only', style: TextStyle(color: Colors.white, fontSize: 14)),
                    value: _onlyOpenFilter,
                    activeColor: const Color(0xFFE040FB),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setSheetState(() => _onlyOpenFilter = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Service selection
                  const Text('Sunulan Hizmet', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All',
                          selected: _serviceFilter == null,
                          onTap: () => setSheetState(() => _serviceFilter = null),
                        ),
                        ..._availableServices.map((service) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: _buildFilterChip(
                              label: service,
                              selected: _serviceFilter == service,
                              onTap: () => setSheetState(() => _serviceFilter = service),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Apply button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentPage = 1;
                        _googleNextPageToken = null;
                        _hasMore = true;
                      });
                      _fetchPage(page: 1, append: false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Filtreleri Uygula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({required String label, required bool selected, required VoidCallback onTap}) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFE040FB),
      backgroundColor: Colors.white.withOpacity(0.05),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFFE040FB) : Colors.white.withOpacity(0.08),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2F),
        elevation: 0,
        title: const Text(
          'Barbers Near Me',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(_isMapMode ? Icons.list : Icons.map, color: Colors.white70),
            tooltip: _isMapMode ? 'List View' : 'Map View',
            onPressed: () {
              setState(() {
                _isMapMode = !_isMapMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white70),
            tooltip: 'Konumumu Bul',
            onPressed: _checkLocationPermissionAndLoad,
          ),
          IconButton(
            icon: const Icon(Icons.location_city, color: Colors.white70),
            tooltip: 'Select Region Manually',
            onPressed: _showManualLocationSelector,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Row
          _buildSearchAndFilterRow(),
          
          Expanded(
            child: _isLoading && _displayedBarbers.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                    ),
                  )
                : _permissionDenied
                    ? _buildPermissionDeniedView()
                    : _isMapMode
                        ? _buildMapView()
                        : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1E1E2F),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF9C27B0), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Berber veya cadde ara...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: const Icon(Icons.clear, color: Colors.white38, size: 18),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showFilterPanel,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_sortBy != 'distance' || _radiusFilter != 10.0 || _onlyOpenFilter || _serviceFilter != null)
                      ? const Color(0xFFE040FB)
                      : Colors.white.withOpacity(0.08),
                  width: (_sortBy != 'distance' || _radiusFilter != 10.0 || _onlyOpenFilter || _serviceFilter != null) ? 1.5 : 1.0,
                ),
              ),
              child: Icon(
                Icons.tune,
                color: (_sortBy != 'distance' || _radiusFilter != 10.0 || _onlyOpenFilter || _serviceFilter != null)
                    ? const Color(0xFFE040FB)
                    : Colors.white70,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.location_off, size: 80, color: Colors.redAccent),
            const SizedBox(height: 24),
            const Text(
              'Location Permission Required',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'We need access to your GPS location to list real salons around you. For your security, your location data is not shared.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _checkLocationPermissionAndLoad,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Renew GPS Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showManualLocationSelector,
              icon: const Icon(Icons.map),
              label: const Text('Select Region Manually', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF9C27B0)),
                foregroundColor: const Color(0xFFE040FB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    if (_displayedBarbers.isEmpty) {
      return _buildNoBarbersView();
    }

    final List<Marker> markers = [];

    // User Position Marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
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
      );
    }

    // Barber Markers
    for (int i = 0; i < _displayedBarbers.length; i++) {
      final b = _displayedBarbers[i];
      final isSelected = _selectedBarber?.id == b.id;
      markers.add(
        Marker(
          point: LatLng(b.latitude, b.longitude),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedBarber = b;
              });
              _mapController.move(LatLng(b.latitude, b.longitude), 16.5);
              _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
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
                    Icons.content_cut,
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
        ),
      );
    }

    return Stack(
      children: [
        // 1. Map Layer
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition != null 
                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                : LatLng(_centerLat(), _centerLng()),
            initialZoom: 15.5,
            minZoom: 5.0,
            maxZoom: 19.5,
            onPositionChanged: (pos, hasGesture) {
              if (hasGesture) {
                final double dist = Geolocator.distanceBetween(
                  _currentPosition?.latitude ?? _centerLat(),
                  _currentPosition?.longitude ?? _centerLng(),
                  pos.center.latitude,
                  pos.center.longitude,
                );
                if (dist > 1500) { // map moved > 1.5 km
                  setState(() {
                    _mapCenterMoved = true;
                    _movedCenter = pos.center;
                  });
                }
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.frontend',
            ),
            MarkerLayer(markers: markers),
          ],
        ),

        // 2. Search this area button
        if (_mapCenterMoved && _movedCenter != null)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  _loadBarbers(_movedCenter!.latitude, _movedCenter!.longitude);
                },
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search in this Region', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E2F).withOpacity(0.95),
                  foregroundColor: const Color(0xFFE040FB),
                  shadowColor: Colors.black45,
                  elevation: 8,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF9C27B0), width: 1.0),
                  ),
                ),
              ),
            ),
          ),

        // 3. Carousel Cards
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _displayedBarbers.length,
            onPageChanged: (index) {
              final barber = _displayedBarbers[index];
              setState(() {
                _selectedBarber = barber;
              });
              _mapController.move(LatLng(barber.latitude, barber.longitude), 14.5);
            },
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final barber = _displayedBarbers[index];
              final isSelected = _selectedBarber?.id == barber.id;
              
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NearbyBarberDetailScreen(barber: barber),
                    ),
                  );
                },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.6,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2F).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE040FB).withOpacity(0.4) : Colors.white.withOpacity(0.08),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            barber.imageUrl ?? 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500',
                            width: 85,
                            height: 85,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              width: 85,
                              height: 85,
                              color: Colors.grey[900],
                              child: const Icon(Icons.store, color: Colors.white24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                barber.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                barber.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    barber.rating?.toStringAsFixed(1) ?? '4.5',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${barber.reviewCount})',
                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.navigation_outlined, color: Colors.blueAccent, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    barber.distanceMeter >= 1000 
                                        ? '${(barber.distanceMeter / 1000).toStringAsFixed(1)} km'
                                        : '${barber.distanceMeter.toInt()} m',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _launchNavigation(barber.latitude, barber.longitude),
                                      icon: const Icon(Icons.directions, size: 14),
                                      label: const Text('DIRECTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF9C27B0),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  if (barber.phoneNumber != null && barber.phoneNumber!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.phone, color: Colors.greenAccent),
                                      onPressed: () => _makeCall(barber.phoneNumber!),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.05),
                                        padding: const EdgeInsets.all(8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(color: Colors.white.withOpacity(0.08)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildListView() {
    if (_displayedBarbers.isEmpty) {
      return _buildNoBarbersView();
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _displayedBarbers.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _displayedBarbers.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
              ),
            ),
          );
        }

        final b = _displayedBarbers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NearbyBarberDetailScreen(barber: b),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      b.imageUrl ?? 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[900],
                        child: const Icon(Icons.store, color: Colors.white24, size: 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                b.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            if (b.isOpen != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: b.isOpen! ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  b.isOpen! ? 'Open' : 'Closed',
                                  style: TextStyle(
                                    color: b.isOpen! ? Colors.green : Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              b.rating?.toStringAsFixed(1) ?? '4.5',
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${b.reviewCount} yorum)',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            const Spacer(),
                            const Icon(Icons.navigation_outlined, color: Colors.blueAccent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              b.distanceMeter >= 1000 
                                  ? '${(b.distanceMeter / 1000).toStringAsFixed(1)} km'
                                  : '${b.distanceMeter.toInt()} m',
                              style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoBarbersView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 72, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No Search Results Found',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'No nearby barber salon was found matching your criteria. Please try resetting your filters or moving to another area on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _sortBy = 'distance';
                  _radiusFilter = 10.0;
                  _onlyOpenFilter = false;
                  _serviceFilter = null;
                  _currentPage = 1;
                  _googleNextPageToken = null;
                  _hasMore = true;
                });
                _fetchPage(page: 1, append: false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.08),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }

  double _centerLat() => _displayedBarbers.isNotEmpty ? _displayedBarbers.first.latitude : 40.9901;
  double _centerLng() => _displayedBarbers.isNotEmpty ? _displayedBarbers.first.longitude : 29.0270;
}
