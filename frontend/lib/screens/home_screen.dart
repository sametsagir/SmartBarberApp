import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/salon_detail_screen.dart';
import 'package:frontend/screens/booking_screen.dart';
import 'package:frontend/screens/barber/barber_dashboard.dart';
import 'package:frontend/screens/barber/barber_services_screen.dart';
import 'package:frontend/screens/barber/barber_working_hours_screen.dart';
import 'package:frontend/screens/barber/barber_analytics_screen.dart';
import 'package:frontend/screens/barber/barber_salon_screen.dart';
import 'package:frontend/screens/salon_map_screen.dart';
import 'package:frontend/screens/favorites_screen.dart';
import 'package:frontend/screens/profile_settings_screen.dart';
import 'package:frontend/screens/nearby_barber_detail_screen.dart';
import 'package:frontend/services/nearby_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = "Dear Customer";
  String _userRole = "Customer";
  List<dynamic> _salons = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  // Location Selector State
  double? _selectedLat;
  double? _selectedLng;
  List<NearbyBarber> _topBarbers = [];
  bool _isLoadingTopBarbers = false;


  // Appointments Navigation & State
  int _currentIndex = 0;
  List<dynamic> _appointments = [];
  bool _isLoadingAppointments = false;
  String _selectedAppointmentTab = "Upcoming";
  bool _isSalonOwner = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSalons();
  }

  Future<void> _loadUserData() async {
    final name = await ApiService.getUserName();
    final role = await ApiService.getUserRole();
    if (!mounted) return;
    if (name != null && name.isNotEmpty) {
      setState(() => _userName = name);
    }
    if (role != null && role.isNotEmpty) {
      setState(() {
        _userRole = role;
        _currentIndex = 0; // safe reset
      });
      if (role == 'Customer') {
        _checkLocationAndPrompt();
      } else if (role == 'Barber') {
        final profileRes = await ApiService.getBarberProfile();
        if (mounted && profileRes.success && profileRes.data != null) {
          final isOwner = profileRes.data!['isOwner'] == true;
          setState(() {
            _isSalonOwner = isOwner;
          });
          if (isOwner) {
            // Check if they have zero services (new register)
            final servicesRes = await ApiService.getBarberServices();
            if (mounted && servicesRes.success && (servicesRes.data == null || servicesRes.data!.isEmpty)) {
              setState(() {
                _currentIndex = 1; // Force redirect to BarberServicesScreen
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showMandatoryServiceAlert();
              });
            }
          }
        }
      }
    }
  }

  void _showMandatoryServiceAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
            SizedBox(width: 10),
            Text('Adding Service is Mandatory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'To complete your shop registration and enable booking, you must add at least one service.\n\nPlease add a service using the "+" button in the bottom right.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('UNDERSTOOD, ADD SERVICE'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkLocationAndPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Always attempt to fetch the current GPS location on startup
    setState(() => _isLoadingTopBarbers = true);
    double? lat;
    double? lng;

    try {
      // Request permission first, regardless of whether GPS toggle is on/off
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          // Use 5-second timeout to prevent emulator from hanging indefinitely
          Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          lat = pos.latitude;
          lng = pos.longitude;

          await prefs.setDouble('selected_lat', lat);
          await prefs.setDouble('selected_lng', lng);
        } else {
          debugPrint('Location service is disabled.');
        }
      }
    } catch (e) {
      debugPrint('Auto GPS on startup failed: $e');
    }

    // Fallback: If GPS fetching failed, use the previously saved location in SharedPreferences, or fallback to Kadıköy
    if (lat == null || lng == null) {
      lat = prefs.getDouble('selected_lat') ?? 40.9901;
      lng = prefs.getDouble('selected_lng') ?? 29.0270;
      
      await prefs.setDouble('selected_lat', lat);
      await prefs.setDouble('selected_lng', lng);
    }

    if (!mounted) return;
    setState(() {
      _isLoadingTopBarbers = false;
      _selectedLat = lat;
      _selectedLng = lng;
    });
    _loadTopBarbers();
  }

  Future<void> _loadTopBarbers() async {
    if (_selectedLat == null || _selectedLng == null) return;
    if (!mounted) return;
    setState(() => _isLoadingTopBarbers = true);
    try {
      // Fetch salons sorted by distance from backend (maxDistanceKm is null to get all salons)
      final result = await ApiService.getSalons(
        latitude: _selectedLat!,
        longitude: _selectedLng!,
        maxDistanceKm: null,
        page: 1,
        pageSize: 40, // Fetch enough to cover the 39 district salons
      );

      if (result.success && result.data != null) {
        final List<dynamic> salonList = result.data!;
        final List<NearbyBarber> barbersList = salonList.map((salon) {
          return NearbyBarber(
            id: salon['id'].toString(),
            dbSalonId: salon['id'].toString(), // Custom property to route to SalonDetailScreen
            name: salon['name'] ?? 'Berber',
            address: salon['address'] ?? '',
            latitude: (salon['latitude'] as num).toDouble(),
            longitude: (salon['longitude'] as num).toDouble(),
            distanceMeter: (salon['distanceKm'] != null)
                ? (salon['distanceKm'] as num).toDouble() * 1000
                : 0.0,
            rating: (salon['rating'] as num?)?.toDouble() ?? 5.0,
            isOpen: salon['isOpen'] ?? false,
            imageUrl: salon['imageUrl'],
            reviewCount: 15,
            galleryUrls: [salon['imageUrl'] ?? ''],
            workingHours: [],
            services: [],
            reviews: [],
          );
        }).toList();

        // Sort strictly by distance ascending
        barbersList.sort((a, b) => a.distanceMeter.compareTo(b.distanceMeter));

        if (!mounted) return;
        setState(() {
          _topBarbers = barbersList.take(5).toList();
          _isLoadingTopBarbers = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _topBarbers = [];
          _isLoadingTopBarbers = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching top barbers: $e');
      if (!mounted) return;
      setState(() => _isLoadingTopBarbers = false);
    }
  }

  Future<void> _loadSalons({String? search}) async {
    setState(() => _isLoading = true);

    double? lat;
    double? lng;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          lat = position.latitude;
          lng = position.longitude;
        }
      }
    } catch (e) {
      debugPrint('Error fetching location for HomeScreen: $e');
    }

    final result = await ApiService.getSalons(
      search: search,
      latitude: lat,
      longitude: lng,
      pageSize: 20, // List up to 20 closest salons
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.data != null) {
      setState(() => _salons = result.data!);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to load salons.')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _loadSalons(search: query);
  }

  // Fetch customer appointments from API
  Future<void> _loadAppointments() async {
    setState(() => _isLoadingAppointments = true);
    final customerId = await ApiService.getUserId();
    if (customerId != null) {
      final result = await ApiService.getCustomerAppointments(customerId);
      if (!mounted) return;
      if (result.success && result.data != null) {
        setState(() => _appointments = result.data!);
      }
    }
    if (!mounted) return;
    setState(() => _isLoadingAppointments = false);
  }

  // Load simulator test appointments
  Future<void> _loadSimulationData() async {
    final customerId = await ApiService.getUserId();
    if (customerId == null) return;

    setState(() => _isLoadingAppointments = true);
    final result = await ApiService.createTestAppointments(customerId);
    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulation appointments successfully added to your account!')),
      );
      await _loadAppointments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'An error occurred.')),
      );
    }
    if (!mounted) return;
    setState(() => _isLoadingAppointments = false);
  }

  // Cancel Appointment
  Future<void> _cancelAppointment(String appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Appointment', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to cancel this appointment? This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CANCEL APPOINTMENT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isLoadingAppointments = true);
      final result = await ApiService.cancelAppointment(appointmentId);
      if (!mounted) return;
      setState(() => _isLoadingAppointments = false);

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your appointment has been successfully cancelled.')),
          );
          _loadAppointments();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Cancellation failed.')),
          );
        }
      }
    }
  }

  // Navigate to Slot Picker for Rescheduling
  void _rescheduleAppointment(Map<String, dynamic> app) async {
    final stylistId = app['stylistId'];
    final serviceId = app['serviceId'];

    final serviceMap = {
      'id': serviceId,
      'name': app['serviceName'],
      'price': app['servicePrice'],
      'durationInMinutes': app['serviceDurationInMinutes'] ?? 30,
    };

    final stylistMap = {
      'id': stylistId,
      'fullName': app['stylistName'],
      'title': app['stylistTitle'],
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          salonName: app['salonName'],
          service: serviceMap,
          stylist: stylistMap,
          rescheduleAppointmentId: app['id'],
        ),
      ),
    );

    if (result == true) {
      _loadAppointments();
    }
  }

  // Rate & Comment Dialog
  void _showRatingDialog(Map<String, dynamic> app) {
    int localStars = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                '${app['stylistName']} Rate',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${app['salonName']} - ${app['serviceName']} rate your experience for this service.',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    
                    // Star selector
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (idx) {
                          final starNum = idx + 1;
                          final isLit = starNum <= localStars;
                          return IconButton(
                            icon: Icon(
                              isLit ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 36,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                localStars = starNum;
                              });
                            },
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 18),
  
                    // Comment input textfield
                    TextField(
                      controller: commentController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: "Write a comment about the stylist's service quality...",
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                        filled: true,
                        fillColor: Colors.black26,
                        counterStyle: const TextStyle(color: Colors.white30),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final comment = commentController.text.trim();
                    final customerId = await ApiService.getUserId();
                    if (customerId == null) return;
  
                    final result = await ApiService.submitReview(
                      app['id'],
                      customerId,
                      localStars,
                      comment,
                    );
  
                    if (context.mounted) {
                      Navigator.pop(context); // close dialog
                      if (result.success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Your review has been successfully saved!')),
                        );
                        _loadAppointments();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message ?? 'An error occurred.')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SUBMIT REVIEW'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBarberLayout() {
    final List<Widget> barberScreens = [];
    final List<BottomNavigationBarItem> barberNavItems = [];

    barberScreens.add(const BarberDashboard());
    barberNavItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard, color: Color(0xFF9C27B0)),
      label: 'Appointments',
    ));

    if (_isSalonOwner) {
      barberScreens.add(const BarberServicesScreen());
      barberNavItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.content_cut_outlined),
        activeIcon: Icon(Icons.content_cut, color: Color(0xFF9C27B0)),
        label: 'Services',
      ));
    }

    barberScreens.add(const BarberWorkingHoursScreen());
    barberNavItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.access_time_outlined),
      activeIcon: Icon(Icons.access_time_filled, color: Color(0xFF9C27B0)),
      label: 'Hours',
    ));

    barberScreens.add(BarberAnalyticsScreen(isOwner: _isSalonOwner));
    barberNavItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.analytics_outlined),
      activeIcon: Icon(Icons.analytics, color: Color(0xFF9C27B0)),
      label: 'Analytics',
    ));

    if (_isSalonOwner) {
      barberScreens.add(const BarberSalonScreen());
      barberNavItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.store_outlined),
        activeIcon: Icon(Icons.store, color: Color(0xFF9C27B0)),
        label: 'My Salon',
      ));
    }

    // Safe bound check
    final activeIndex = _currentIndex >= barberScreens.length ? 0 : _currentIndex;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Header (Barber info + Logout)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, 💈',
                            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
                        onPressed: () async {
                          await ApiService.logout();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: barberScreens[activeIndex],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        ),
        child: BottomNavigationBar(
          currentIndex: activeIndex,
          onTap: (index) async {
            if (_userRole == 'Barber' && _isSalonOwner) {
              final servicesRes = await ApiService.getBarberServices();
              if (servicesRes.success && (servicesRes.data == null || servicesRes.data!.isEmpty)) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please add at least one service first. You cannot navigate to other pages without adding a service.')),
                  );
                }
                setState(() => _currentIndex = 1);
                return;
              }
            }
            setState(() => _currentIndex = index);
          },
          backgroundColor: const Color(0xFF0F0F1E),
          selectedItemColor: const Color(0xFF9C27B0),
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          type: BottomNavigationBarType.fixed,
          items: barberNavItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == 'Barber') {
      return _buildBarberLayout();
    }

    Widget bodyWidget;
    if (_currentIndex == 0) {
      bodyWidget = SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: _buildExploreView(),
        ),
      );
    } else if (_currentIndex == 1) {
      bodyWidget = const SalonMapScreen();
    } else if (_currentIndex == 2) {
      bodyWidget = const FavoritesScreen();
    } else {
      bodyWidget = SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: _buildAppointmentsView(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2F), Color(0xFF0F0F1E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: bodyWidget,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 0) {
              _checkLocationAndPrompt();
            }
            if (index == 3) {
              _loadAppointments();
            }
          },
          backgroundColor: const Color(0xFF0F0F1E),
          selectedItemColor: const Color(0xFF9C27B0),
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Appointments',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyBarberCard(NearbyBarber barber) {
    return GestureDetector(
      onTap: () {
        if (barber.dbSalonId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SalonDetailScreen(salonId: barber.dbSalonId!),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NearbyBarberDetailScreen(barber: barber),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Stack(
                children: [
                  Image.network(
                    barber.imageUrl ?? 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500',
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: Colors.grey[900],
                      child: const Icon(Icons.store, size: 36, color: Colors.white24),
                    ),
                  ),
                  if (barber.isOpen != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: barber.isOpen! ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          barber.isOpen! ? 'OPEN' : 'CLOSED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Details
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            barber.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              barber.rating?.toStringAsFixed(1) ?? '0.0',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white38, size: 13),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            barber.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, color: Color(0xFFE040FB), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '${(barber.distanceMeter / 1000).toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            color: Color(0xFFE040FB),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
  }

  // View 0: Explore / Salon Search List
  Widget _buildExploreView() {
    final isSearching = _searchController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Header (User info + Logout)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, 👋',
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                ],
              ),
            ),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white70, size: 22),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
                      );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
                    onPressed: () async {
                      await ApiService.logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Search Bar
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: Color(0xFF9C27B0)),
            hintText: 'Search salon or address...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (isSearching) ...[
          // SEARCHING MODE: Show vertical list of database search results
          const Text(
            'Search Results',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                    ),
                  )
                : _salons.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.search_off, size: 64, color: Colors.white38),
                            SizedBox(height: 16),
                            Text(
                              'No salon found matching your criteria.',
                              style: TextStyle(color: Colors.white60, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _salons.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final salon = _salons[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SalonDetailScreen(salonId: salon['id']),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.07)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Image.network(
                                      salon['imageUrl'] ?? 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500',
                                      height: 160,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 160,
                                        color: Colors.grey[900],
                                        child: const Icon(Icons.store, size: 48, color: Colors.white24),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  salon['name'],
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(Icons.star, color: Colors.amber, size: 18),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    salon['rating'].toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on, color: Colors.white38, size: 16),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  salon['address'],
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 14,
                                                  ),
                                                ),
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
                      ),
          ),
        ] else ...[
          // DEFAULT MODE: Show Premium "Best Salons Near You" with light map & horizontal cards
          // Action card for Nearby Real Barbers (kept as extra quick link)
          GestureDetector(
            onTap: () {
              setState(() {
                _currentIndex = 1; // Tab 1 is SalonMapScreen (Harita)
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFFE040FB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE040FB).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.map, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Registered Salons Map',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'View salons registered in the system on the map',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Best Salons Near You',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoadingTopBarbers
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                    ),
                  )
                : _topBarbers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.location_off, size: 64, color: Colors.white38),
                            SizedBox(height: 16),
                            Text(
                              'No active salon found within 3 km of your chosen location.',
                              style: TextStyle(color: Colors.white60, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _topBarbers.length,
                        itemBuilder: (context, index) {
                          return _buildNearbyBarberCard(_topBarbers[index]);
                        },
                      ),
          ),
        ],
      ],
    );
  }

  // View 1: Appointments Tab
  Widget _buildAppointmentsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Appointments',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track and manage your appointments',
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Custom Sliding Tab Selection
        Row(
          children: [
            _buildTabChip("Upcoming"),
            const SizedBox(width: 12),
            _buildTabChip("History"),
          ],
        ),
        const SizedBox(height: 16),

        // Appointments List
        Expanded(
          child: _isLoadingAppointments
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                  ),
                )
              : _appointments.isEmpty
                  ? _buildEmptyState()
                  : _buildAppointmentsList(),
        ),
      ],
    );
  }

  Widget _buildTabChip(String label) {
    final isSelected = _selectedAppointmentTab == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAppointmentTab = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9C27B0) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF9C27B0) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'You have no booked appointments.',
              style: TextStyle(color: Colors.white60, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSimulationData,
              icon: const Icon(Icons.flash_on),
              label: const Text('Load Simulation Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    final filtered = _appointments.where((a) {
      if (_selectedAppointmentTab == "Upcoming") {
        return a['isPast'] == false;
      } else {
        return a['isPast'] == true;
      }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note, size: 48, color: Colors.white12),
            const SizedBox(height: 12),
            Text(
              'No $_selectedAppointmentTab appointments found.',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final app = filtered[index];
        return _buildAppointmentCard(app);
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> app) {
    final isCancelled = app['status'] == "Cancelled";
    final isPast = app['isPast'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCancelled ? Colors.redAccent.withOpacity(0.15) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  app['salonName'] ?? 'Salon',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (isCancelled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'CANCELLED',
                    style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              else if (isPast)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'COMPLETED',
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3)),
                  ),
                  child: const Text(
                    'APPROVED',
                    style: TextStyle(color: Color(0xFFE040FB), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Service: ${app['serviceName']}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Stylist: ${app['stylistName']} (${app['stylistTitle']})',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Price: ${app['servicePrice']} TL',
            style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, fontSize: 14),
          ),
          
          const Divider(height: 24, color: Colors.white10),

          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white38, size: 16),
              const SizedBox(width: 6),
              Text(
                'Date: ${app['startTime']}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),

          if (!isCancelled) ...[
            const SizedBox(height: 16),
            if (!isPast) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: app['isRescheduleAllowed'] == true
                          ? () => _rescheduleAppointment(app)
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: app['isRescheduleAllowed'] == true
                              ? Colors.white.withOpacity(0.15)
                              : Colors.white.withOpacity(0.04),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Change Time',
                        style: TextStyle(
                          color: app['isRescheduleAllowed'] == true ? Colors.white : Colors.white24,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: app['isCancelAllowed'] == true
                          ? () => _cancelAppointment(app['id'])
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: app['isCancelAllowed'] == true
                              ? Colors.redAccent
                              : Colors.white.withOpacity(0.04),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: app['isCancelAllowed'] == true ? Colors.redAccent : Colors.white24,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (app['isCancelAllowed'] == false) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.info_outline, color: Colors.white38, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'No cancellations or changes allowed within the last 2 hours.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ] else ...[
              if (app['isRated'] == false)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showRatingDialog(app),
                    icon: const Icon(Icons.star_border, size: 18),
                    label: const Text('Rate & Comment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0).withOpacity(0.15),
                      foregroundColor: const Color(0xFFE040FB),
                      side: const BorderSide(color: Color(0xFF9C27B0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.015),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Your Rating: ',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          Row(
                            children: List.generate(5, (starIdx) {
                              return Icon(
                                starIdx < (app['rating'] ?? 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 14,
                              );
                            }),
                          ),
                        ],
                      ),
                      if (app['comment'] != null && app['comment'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '"${app['comment']}"',
                          style: const TextStyle(color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
