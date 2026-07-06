import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/booking_screen.dart';

class SalonDetailScreen extends StatefulWidget {
  final String salonId;

  const SalonDetailScreen({super.key, required this.salonId});

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen> {
  Map<String, dynamic>? _salonData;
  bool _isLoading = true;
  bool _isFavorite = false;
  List<dynamic> _favoriteStylists = [];

  // Selected Service and Stylist
  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _selectedStylist;

  @override
  void initState() {
    super.initState();
    _loadSalonDetails();
  }

  Future<void> _loadSalonDetails() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getSalonDetails(widget.salonId);
    
    final favRes = await ApiService.getFavoriteSalons();
    final favStylistsRes = await ApiService.getFavoriteStylists();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _salonData = result.data!;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to load salon details.')),
          );
        }
        if (favRes.success && favRes.data != null) {
          _isFavorite = favRes.data!.any((item) => item['id'] == widget.salonId);
        }
        if (favStylistsRes.success && favStylistsRes.data != null) {
          _favoriteStylists = favStylistsRes.data!;
        }
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final res = await ApiService.toggleFavoriteSalon(widget.salonId);
    if (res.success && res.data != null) {
      setState(() => _isFavorite = res.data!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFavorite ? 'Salon added to favorites.' : 'Salon removed from favorites.'),
          ),
        );
      }
    }
  }

  Future<void> _toggleFavoriteStylist(String stylistId) async {
    final res = await ApiService.toggleFavoriteStylist(stylistId);
    if (res.success && res.data != null) {
      final isFav = res.data!;
      setState(() {
        if (isFav) {
          _favoriteStylists.add({'id': stylistId});
        } else {
          _favoriteStylists.removeWhere((item) => item['id'] == stylistId);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFav ? 'Stylist added to favorites.' : 'Stylist removed from favorites.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1E),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
          ),
        ),
      );
    }

    if (_salonData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1E),
        appBar: AppBar(title: const Text('Salon Detay')),
        body: const Center(
          child: Text('Failed to load salon.', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final salon = _salonData!['salon'];
    final services = _salonData!['services'] as List<dynamic>;
    final rawStylists = _salonData!['stylists'] as List<dynamic>;
    final List<dynamic> reviews = _salonData!['reviews'] ?? [];

    final stylists = _selectedService == null
        ? rawStylists
        : rawStylists.where((s) {
            final List<dynamic> svcIds = s['serviceIds'] ?? [];
            return svcIds.map((id) => id.toString()).contains(_selectedService!['id'].toString());
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: Stack(
        children: [
          // Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Cover Image AppBar
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: const Color(0xFF1E1E2F),
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.redAccent : Colors.white,
                      ),
                      onPressed: _toggleFavorite,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    salon['imageUrl'] ?? 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.store, size: 64, color: Colors.white24),
                    ),
                  ),
                ),
              ),
              
              // Salon Details Body
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Salon Name & Rating
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                salon['name'],
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 22),
                                const SizedBox(width: 4),
                                Text(
                                  salon['rating'].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Address
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white38, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                salon['address'],
                                style: const TextStyle(color: Colors.white60, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 40, color: Colors.white12),
                        
                        // 1. Services Section
                        const Text(
                          '1. Select Service',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: services.length,
                          itemBuilder: (context, index) {
                            final service = services[index];
                            final isSelected = _selectedService?['id'] == service['id'];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedService = service;
                                  // Reset selected stylist if they don't support the newly selected service
                                  if (_selectedStylist != null) {
                                    final List<dynamic> svcIds = _selectedStylist!['serviceIds'] ?? [];
                                    if (!svcIds.map((id) => id.toString()).contains(service['id'].toString())) {
                                      _selectedStylist = null;
                                    }
                                  }
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF9C27B0).withOpacity(0.15)
                                      : Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF9C27B0)
                                        : Colors.white.withOpacity(0.07),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            service['name'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time, color: Colors.white38, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${service['durationInMinutes']} min',
                                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '${service['price'].toString().replaceAll('.00', '')} TL',
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFFE040FB) : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 40, color: Colors.white12),

                        // 2. Stylists Section
                        const Text(
                          '2. Select Stylist',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: stylists.length,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final stylist = stylists[index];
                              final isSelected = _selectedStylist?['id'] == stylist['id'];
                              final isBusy = stylist['isBusy'] ?? false;
                              final isStylistFav = _favoriteStylists.any((item) => item['id'] == stylist['id']);
                              return GestureDetector(
                                onTap: () => setState(() => _selectedStylist = stylist),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 140,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF9C27B0).withOpacity(0.15)
                                        : Colors.white.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF9C27B0)
                                          : Colors.white.withOpacity(0.07),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Status Badge and Favorite button side by side
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isBusy
                                                  ? Colors.redAccent.withOpacity(0.15)
                                                  : Colors.greenAccent.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isBusy ? Colors.redAccent : Colors.greenAccent,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              isBusy ? 'BUSY' : 'AVAILABLE',
                                              style: TextStyle(
                                                color: isBusy ? Colors.redAccent : Colors.greenAccent,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => _toggleFavoriteStylist(stylist['id']),
                                            child: Icon(
                                              isStylistFav ? Icons.favorite : Icons.favorite_border,
                                              color: isStylistFav ? Colors.redAccent : Colors.white54,
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        stylist['fullName'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        stylist['title'],
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 13),
                                          const SizedBox(width: 2),
                                          Text(
                                            stylist['rating'].toString(),
                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const Divider(height: 40, color: Colors.white12),

                        // 3. Customer Reviews Section
                        const Text(
                          'Customer Reviews',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (reviews.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Text(
                              'No reviews have been written for this salon yet.',
                              style: TextStyle(color: Colors.white38, fontSize: 14),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reviews.length,
                            itemBuilder: (context, index) {
                              final r = reviews[index];
                              final rating = (r['rating'] as num).toDouble();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          r['customerName'] ?? 'Customer',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          r['createdAt'] ?? '',
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Row(
                                          children: List.generate(5, (starIdx) {
                                            return Icon(
                                              starIdx < rating ? Icons.star : Icons.star_border,
                                              color: Colors.amber,
                                              size: 13,
                                            );
                                          }),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF9C27B0).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${r['serviceName']} - ${r['stylistName']}',
                                            style: const TextStyle(color: Color(0xFFE040FB), fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (r['comment'] != null && r['comment'].toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '"${r['comment']}"',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),

                        // Safe spacer for button overlap
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
          
          // Sticky Bottom Booking Button
          if (_selectedService != null && _selectedStylist != null)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingScreen(
                        salonName: salon['name'],
                        service: _selectedService!,
                        stylist: _selectedStylist!,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                ),
                child: const Text(
                  'SELECT APPOINTMENT TIME',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
