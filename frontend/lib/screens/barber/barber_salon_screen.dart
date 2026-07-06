import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/services/api_service.dart';

class BarberSalonScreen extends StatefulWidget {
  const BarberSalonScreen({super.key});

  @override
  State<BarberSalonScreen> createState() => _BarberSalonScreenState();
}

class _BarberSalonScreenState extends State<BarberSalonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imageController = TextEditingController();
  final MapController _mapController = MapController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  double? _selectedLat;
  double? _selectedLng;
  bool _isGpsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSalonDetails();
    _imageController.addListener(_onImageChanged);
  }

  void _onImageChanged() {
    setState(() {});
  }

  Future<void> _loadSalonDetails() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getBarberSalon();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          final salon = result.data!;
          _nameController.text = salon['name'] ?? '';
          _addressController.text = salon['address'] ?? '';
          _phoneController.text = salon['phone'] ?? '';
          _imageController.text = salon['imageUrl'] ?? '';
          _selectedLat = (salon['latitude'] as num?)?.toDouble();
          _selectedLng = (salon['longitude'] as num?)?.toDouble();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to load salon details.')),
          );
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGpsLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable GPS.')),
          );
        }
        setState(() => _isGpsLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          setState(() => _isGpsLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission has been permanently denied.')),
          );
        }
        setState(() => _isGpsLoading = false);
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _selectedLat = pos.latitude;
        _selectedLng = pos.longitude;
      });

      // Call API to reverse geocode and get the real street address
      final geoResult = await ApiService.reverseGeocode(pos.latitude, pos.longitude);

      setState(() {
        if (geoResult.success && geoResult.data != null) {
          _addressController.text = geoResult.data!;
        } else {
          _addressController.text = "GPS Konumu (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})";
        }
        _isGpsLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(LatLng(pos.latitude, pos.longitude), 17.5);
        } catch (e) {
          debugPrint('MapController not attached yet: $e');
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS location and address successfully detected!')),
        );
      }
    } catch (e) {
      setState(() => _isGpsLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  Future<void> _saveSalonDetails() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLat == null || _selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please get GPS location first to automatically determine your shop address.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final result = await ApiService.updateBarberSalon(
      name: _nameController.text.trim(),
      latitude: _selectedLat!,
      longitude: _selectedLng!,
      phone: _phoneController.text.trim(),
      imageUrl: _imageController.text.trim().isEmpty ? null : _imageController.text.trim(),
      address: _addressController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salon details successfully updated!')),
        );
        _loadSalonDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'An error occurred.')),
        );
      }
    }
  }

  InputDecoration _buildInputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF9C27B0)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await file.readAsBytes();
      final result = await ApiService.uploadSalonImage(bytes, file.name);

      setState(() => _isUploadingImage = false);

      if (result.success && result.data != null) {
        setState(() {
          _imageController.text = result.data!;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cover image successfully uploaded!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to upload image.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error occurred: $e')),
        );
      }
    }
  }

  Widget _buildImagePreview() {
    final rawUrl = _imageController.text.trim();
    final url = ApiService.formatImageUrl(rawUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shop Cover Image',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isUploadingImage ? null : _pickAndUploadImage,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    url,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 48),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.black.withOpacity(0.45),
                    ),
                    child: Center(
                      child: _isUploadingImage
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE040FB)),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Select Cover Image from Files',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMap() {
    if (_selectedLat == null || _selectedLng == null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, color: Colors.white30, size: 40),
              SizedBox(height: 8),
              Text(
                'Map view will load once location is set',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final latLng = LatLng(_selectedLat!, _selectedLng!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shop Map Location',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: latLng,
                    initialZoom: 17.5,
                    minZoom: 10.0,
                    maxZoom: 19.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.example.frontend',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: latLng,
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE040FB).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFFE040FB),
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      _buildZoomButton(
                        icon: Icons.add,
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          if (currentZoom < 19.5) {
                            _mapController.move(_mapController.camera.center, currentZoom + 0.5);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildZoomButton(
                        icon: Icons.remove,
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          if (currentZoom > 10.0) {
                            _mapController.move(_mapController.camera.center, currentZoom - 0.5);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZoomButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F).withOpacity(0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 16),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    );
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Salon Bilgilerim',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Keep your shop details updated so customers can easily locate and reach you.',
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 20),

              // Salon Name Field
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Salon Name', Icons.store),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Salon name cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Address Field (Read-only)
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                readOnly: true,
                style: const TextStyle(color: Colors.white70),
                decoration: _buildInputDecoration('Adres Bilgisi (GPS ile otomatik belirlenir)', Icons.location_on).copyWith(
                  suffixIcon: _isGpsLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.gps_fixed, color: Color(0xFFE040FB)),
                          onPressed: _getCurrentLocation,
                          tooltip: 'Konumumu GPS\'ten Al',
                        ),
                ),
              ),
              
              const SizedBox(height: 12),
              _buildMiniMap(),
              const SizedBox(height: 16),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Phone Number', Icons.phone),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Image Selection Preview
              _buildImagePreview(),
              const SizedBox(height: 28),

              // Save Button
              if (_isSaving)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _saveSalonDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'UPDATE DETAILS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _imageController.removeListener(_onImageChanged);
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _imageController.dispose();
    super.dispose();
  }
}
