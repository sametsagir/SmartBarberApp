import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/salon_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _favoriteSalons = [];
  List<dynamic> _favoriteStylists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final salonsRes = await ApiService.getFavoriteSalons();
    final stylistsRes = await ApiService.getFavoriteStylists();

    if (mounted) {
      setState(() {
        if (salonsRes.success && salonsRes.data != null) {
          _favoriteSalons = salonsRes.data!;
        }
        if (stylistsRes.success && stylistsRes.data != null) {
          _favoriteStylists = stylistsRes.data!;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _removeSalon(String id) async {
    final res = await ApiService.toggleFavoriteSalon(id);
    if (res.success) {
      setState(() {
        _favoriteSalons.removeWhere((item) => item['id'] == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salon removed from favorites.')),
        );
      }
    }
  }

  Future<void> _removeStylist(String id) async {
    final res = await ApiService.toggleFavoriteStylist(id);
    if (res.success) {
      setState(() {
        _favoriteStylists.removeWhere((item) => item['id'] == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stylist removed from favorites.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2F),
        title: const Text(
          'Favorilerim',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF9C27B0),
          labelColor: const Color(0xFFE040FB),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.store), text: 'Salonlar'),
            Tab(icon: Icon(Icons.person), text: 'Ustalar'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSalonsList(),
                _buildStylistsList(),
              ],
            ),
    );
  }

  Widget _buildSalonsList() {
    if (_favoriteSalons.isEmpty) {
      return const Center(
        child: Text(
          'You have no favorite salons yet.',
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favoriteSalons.length,
      itemBuilder: (context, index) {
        final salon = _favoriteSalons[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                salon['imageUrl'] ?? 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[900],
                  child: const Icon(Icons.store, color: Colors.white30),
                ),
              ),
            ),
            title: Text(
              salon['name'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  salon['address'],
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      salon['rating'].toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.redAccent),
              onPressed: () => _removeSalon(salon['id']),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SalonDetailScreen(salonId: salon['id']),
                ),
              ).then((_) => _loadFavorites());
            },
          ),
        );
      },
    );
  }

  Widget _buildStylistsList() {
    if (_favoriteStylists.isEmpty) {
      return const Center(
        child: Text(
          'You have no favorite stylists yet.',
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favoriteStylists.length,
      itemBuilder: (context, index) {
        final stylist = _favoriteStylists[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF9C27B0).withOpacity(0.2),
              child: const Icon(Icons.person, color: Colors.white70, size: 28),
            ),
            title: Text(
              stylist['fullName'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${stylist['title']} | ${stylist['salonName']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      stylist['rating'].toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.redAccent),
              onPressed: () => _removeStylist(stylist['id']),
            ),
          ),
        );
      },
    );
  }
}
