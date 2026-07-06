import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/services/api_service.dart';

class NearbyBarber {
  final String id;
  final String? dbSalonId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceMeter;
  final double? rating;
  final bool? isOpen;
  final String? phoneNumber;
  final String? imageUrl;
  
  // Enriched details
  final int reviewCount;
  final List<String> galleryUrls;
  final List<Map<String, String>> workingHours;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> reviews;

  NearbyBarber({
    required this.id,
    this.dbSalonId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceMeter,
    this.rating,
    this.isOpen,
    this.phoneNumber,
    this.imageUrl,
    required this.reviewCount,
    required this.galleryUrls,
    required this.workingHours,
    required this.services,
    required this.reviews,
  });
}

class NearbyBarbersResponse {
  final List<NearbyBarber> barbers;
  final String? nextPageToken;
  final bool hasMore;

  NearbyBarbersResponse({
    required this.barbers,
    this.nextPageToken,
    required this.hasMore,
  });
}

class NearbyService {
  // Premium barber photos from Unsplash for fallback
  static const List<String> _fallbackPhotos = [
    'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500',
    'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=500',
    'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=500',
    'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=500',
    'https://images.unsplash.com/photo-1605497746444-17dbd80a997a?w=500',
  ];

  static const List<String> _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://z.overpass-api.de/api/interpreter',
    'https://overpass.osm.ch/api/interpreter',
    'https://overpass.osm.ch/api/interpreter',
  ];

  // In-memory cache variables to optimize API usage
  static double? _cachedLat;
  static double? _cachedLng;
  static List<NearbyBarber> _cachedBarbers = [];
  static DateTime? _lastCacheTime;

  static String _getRandomPhoto(String seedId) {
    final int hash = seedId.hashCode.abs();
    return _fallbackPhotos[hash % _fallbackPhotos.length];
  }

  // --- Mock Generators ---
  static List<String> _generateGallery(String seedId) {
    final rand = Random(seedId.hashCode);
    final count = 3 + rand.nextInt(3); // 3 to 5 images
    final List<String> images = [];
    for (int i = 0; i < count; i++) {
      images.add(_fallbackPhotos[rand.nextInt(_fallbackPhotos.length)]);
    }
    return images;
  }

  static List<Map<String, String>> _generateWorkingHours(String seedId) {
    final rand = Random(seedId.hashCode + 1);
    final isWeekendOff = rand.nextBool();
    final openTime = 8 + rand.nextInt(3); // 8:00 - 10:00
    final closeTime = 19 + rand.nextInt(4); // 19:00 - 22:00
    final hoursStr = '${openTime.toString().padLeft(2, '0')}:00 - ${closeTime.toString().padLeft(2, '0')}:00';
    
    return [
      {'day': 'Pazartesi', 'hours': hoursStr},
      {'day': 'Salı', 'hours': hoursStr},
      {'day': 'Çarşamba', 'hours': hoursStr},
      {'day': 'Perşembe', 'hours': hoursStr},
      {'day': 'Cuma', 'hours': hoursStr},
      {'day': 'Cumartesi', 'hours': isWeekendOff ? '09:00 - 18:00' : hoursStr},
      {'day': 'Pazar', 'hours': isWeekendOff ? 'Kapalı' : '10:00 - 17:00'},
    ];
  }

  static List<Map<String, dynamic>> _generateServices(String seedId) {
    final rand = Random(seedId.hashCode + 2);
    final services = [
      {'name': 'Saç Kesimi', 'price': 200 + rand.nextInt(5) * 50},
      {'name': 'Sakal Tıraşı', 'price': 100 + rand.nextInt(4) * 30},
      {'name': 'Fön & Şekillendirme', 'price': 50 + rand.nextInt(3) * 20},
      {'name': 'Saç Yıkama', 'price': 40 + rand.nextInt(2) * 20},
      {'name': 'Cilt Bakımı & Maske', 'price': 150 + rand.nextInt(4) * 50},
      {'name': 'Saç Boyama', 'price': 400 + rand.nextInt(6) * 100},
      {'name': 'Çocuk Tıraşı', 'price': 150 + rand.nextInt(3) * 50},
    ];
    final count = 3 + rand.nextInt(4);
    services.shuffle(rand);
    return services.take(count).toList();
  }

  static List<Map<String, dynamic>> _generateReviews(String seedId) {
    final rand = Random(seedId.hashCode + 3);
    final reviewerNames = [
      'Alperen K.', 'Berkay S.', 'Caner M.', 'Deniz Y.', 'Emre T.', 
      'Fatih A.', 'Gökhan B.', 'Hakan D.', 'İbrahim K.', 'Kemal G.',
      'Murat Ö.', 'Oğuzhan Ç.', 'Serkan A.', 'Tolga B.', 'Yusuf E.'
    ];
    final comments = [
      'Temiz ve hızlı hizmet, ustalar güler yüzlü.',
      'Hayatımda aldığım en iyi sakal tıraşıydı, tavsiye ederim.',
      'Fiyatlar biraz yüksek ama işçilik gerçekten premium.',
      'Randevusuz gitmeyin çok sıra olabiliyor. Saç kesimi efsane.',
      'Klasik bir erkek kuaförü, saçımı istediğim gibi kesti.',
      'İçerisi çok temiz, hijyene önem veriyorlar. Usta Caner\'e teşekkürler.',
      'Bekleme alanında çay/kahve ikramı güzeldi, saç kesimi de başarılı.',
      'Fiyat performans dengesi harika. Çok memnun kaldım.',
      'Modern saç kesimlerini çok iyi uyguluyorlar, sürekli buradayım.'
    ];
    
    final count = 2 + rand.nextInt(4); // 2 to 5 reviews
    final List<Map<String, dynamic>> reviewsList = [];
    for (int i = 0; i < count; i++) {
      final name = reviewerNames[rand.nextInt(reviewerNames.length)];
      final rating = 4.0 + rand.nextDouble() * 1.0;
      final comment = comments[rand.nextInt(comments.length)];
      reviewsList.add({
        'name': name,
        'rating': rating,
        'comment': comment,
        'date': '${rand.nextInt(28) + 1} gün önce'
      });
    }
    return reviewsList;
  }

  /// Main entry point to fetch real barbers around coordinates.
  /// First checks if Google Places key is available, else falls back to OpenStreetMap Overpass.
  static Future<NearbyBarbersResponse> fetchNearbyBarbers({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
    bool forceRefresh = false,
    int page = 1,
    int pageSize = 10,
    String? nextPageToken,
    String? searchQuery,
    String? sortBy,
    bool? onlyOpen,
    String? requiredService,
  }) async {
    try {
      // Query the local database API for salons (ignoring the 3 km or radius limits)
      final result = await ApiService.getSalons(
        search: searchQuery,
        serviceName: requiredService,
        latitude: latitude,
        longitude: longitude,
        maxDistanceKm: null, // As requested: "en yakın 3 km olmasın en yakınındakiler gelsin"
        page: page,
        pageSize: pageSize,
      );

      if (result.success && result.data != null) {
        final List<dynamic> salonList = result.data!;
        final List<NearbyBarber> barbers = salonList.map((salon) {
          return NearbyBarber(
            id: salon['id'].toString(),
            dbSalonId: salon['id'].toString(),
            name: salon['name'] ?? 'Berber',
            address: salon['address'] ?? '',
            latitude: (salon['latitude'] as num).toDouble(),
            longitude: (salon['longitude'] as num).toDouble(),
            distanceMeter: (salon['distanceKm'] != null)
                ? (salon['distanceKm'] as num).toDouble() * 1000
                : 0.0,
            rating: (salon['rating'] as num?)?.toDouble() ?? 5.0,
            isOpen: salon['isOpen'] ?? false,
            phoneNumber: salon['phone'] ?? '',
            imageUrl: salon['imageUrl'],
            reviewCount: 15,
            galleryUrls: [salon['imageUrl'] ?? ''],
            workingHours: _generateWorkingHours(salon['id'].toString()),
            services: [],
            reviews: [],
          );
        }).toList();

        // Sort strictly by distance ascending
        barbers.sort((a, b) => a.distanceMeter.compareTo(b.distanceMeter));

        return NearbyBarbersResponse(
          barbers: barbers,
          nextPageToken: null,
          hasMore: barbers.length >= pageSize,
        );
      }
    } catch (e) {
      debugPrint('Error in fetchNearbyBarbers: $e');
    }

    return NearbyBarbersResponse(barbers: [], hasMore: false);
  }

  /// 1. Fetch from Google Places API (Requires billing & Key)
  static Future<NearbyBarbersResponse> _fetchFromGooglePlaces(
    double lat,
    double lng,
    double radiusInKm,
    String apiKey, {
    String? pageToken,
  }) async {
    final double radiusInMeters = radiusInKm * 1000;
    
    Uri url;
    if (pageToken != null && pageToken.isNotEmpty) {
      url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?pagetoken=$pageToken'
        '&key=$apiKey'
      );
      // Google places page token requires a tiny delay to activate
      await Future.delayed(const Duration(milliseconds: 1500));
    } else {
      url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng'
        '&radius=${radiusInMeters.toInt()}'
        '&type=hair_care'
        '&keyword=barber|berber|kuaför'
        '&key=$apiKey'
      );
    }

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Google Places HTTP Error: ${res.statusCode}');
    }

    final data = json.decode(res.body);
    if (data['status'] == 'REQUEST_DENIED' || data['status'] == 'INVALID_REQUEST') {
      throw Exception('Google Places API Status: ${data['status']} - ${data['error_message']}');
    }

    final results = data['results'] as List<dynamic>? ?? [];
    final List<NearbyBarber> list = [];
    final String? nextPageToken = data['next_page_token'];

    for (final place in results) {
      final String id = place['place_id'] ?? place['id'] ?? '';
      final String name = place['name'] ?? 'Berber';
      final String address = place['vicinity'] ?? place['formatted_address'] ?? 'Adres Belirtilmemiş';
      
      final geometry = place['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      if (location == null) continue;
      
      final double plat = (location['lat'] as num).toDouble();
      final double plng = (location['lng'] as num).toDouble();
      
      final double distMeter = Geolocator.distanceBetween(lat, lng, plat, plng);
      final double? rating = place['rating'] != null ? (place['rating'] as num).toDouble() : null;
      
      final openingHours = place['opening_hours'] as Map<String, dynamic>?;
      final bool? isOpen = openingHours?['open_now'];

      String? imageUrl;
      final photos = place['photos'] as List<dynamic>?;
      if (photos != null && photos.isNotEmpty) {
        final photoRef = photos.first['photo_reference'];
        if (photoRef != null) {
          imageUrl = 'https://maps.googleapis.com/maps/api/place/photo'
              '?maxwidth=400'
              '&photo_reference=$photoRef'
              '&key=$apiKey';
        }
      }
      imageUrl ??= _getRandomPhoto(id);

      final rand = Random(id.hashCode);
      final int reviewsCount = 10 + rand.nextInt(200);

      list.add(NearbyBarber(
        id: id,
        name: name,
        address: address,
        latitude: plat,
        longitude: plng,
        distanceMeter: distMeter,
        rating: rating ?? (4.0 + rand.nextDouble()),
        isOpen: isOpen,
        imageUrl: imageUrl,
        phoneNumber: null,
        reviewCount: reviewsCount,
        galleryUrls: _generateGallery(id),
        workingHours: _generateWorkingHours(id),
        services: _generateServices(id),
        reviews: _generateReviews(id),
      ));
    }

    list.sort((a, b) => a.distanceMeter.compareTo(b.distanceMeter));
    
    return NearbyBarbersResponse(
      barbers: list,
      nextPageToken: nextPageToken,
      hasMore: nextPageToken != null && nextPageToken.isNotEmpty,
    );
  }

  /// 2. Fetch from OpenStreetMap (Overpass API) - Completely Free, no API Key needed
  static Future<List<NearbyBarber>> _fetchFromOpenStreetMap(
    double lat,
    double lng,
    double radiusInKm,
  ) async {
    final double radiusInMeters = radiusInKm * 1000;
    
    final query = '''
    [out:json][timeout:15];
    (
      node["shop"="hairdresser"](around:$radiusInMeters,$lat,$lng);
      way["shop"="hairdresser"](around:$radiusInMeters,$lat,$lng);
      node["amenity"="barber"](around:$radiusInMeters,$lat,$lng);
      way["amenity"="barber"](around:$radiusInMeters,$lat,$lng);
    );
    out center;
    ''';

    final customUrl = dotenv.maybeGet('OVERPASS_API_URL')?.trim();
    final List<String> urlsToTry = [];
    if (customUrl != null && customUrl.isNotEmpty && customUrl != 'https://overpass-api.de/api/interpreter') {
      urlsToTry.add(customUrl);
    }
    urlsToTry.addAll(_overpassUrls);

    Exception? lastException;

    for (final url in urlsToTry) {
      try {
        debugPrint('OSM Overpass: Attempting request to $url...');
        final res = await http.post(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': '*/*',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'data': query},
        ).timeout(const Duration(seconds: 6));

        debugPrint('OSM Overpass: Received response code: ${res.statusCode} from $url');

        if (res.statusCode == 200) {
          final data = json.decode(utf8.decode(res.bodyBytes));
          final elements = data['elements'] as List<dynamic>? ?? [];
          final List<NearbyBarber> list = [];

          for (final element in elements) {
            final String id = '${element['type']}_${element['id']}';
            
            double? plat;
            double? plng;
            if (element['lat'] != null && element['lon'] != null) {
              plat = (element['lat'] as num).toDouble();
              plng = (element['lon'] as num).toDouble();
            } else if (element['center'] != null) {
              plat = (element['center']['lat'] as num).toDouble();
              plng = (element['center']['lon'] as num).toDouble();
            }
            
            if (plat == null || plng == null) continue;

            final tags = element['tags'] as Map<String, dynamic>? ?? {};
            String name = tags['name'] ?? 'Erkek Kuaförü / Berber';
            
            final List<String> addressParts = [];
            if (tags['addr:street'] != null) addressParts.add(tags['addr:street']);
            if (tags['addr:housenumber'] != null) addressParts.add(tags['addr:housenumber']);
            if (tags['addr:suburb'] != null) addressParts.add(tags['addr:suburb']);
            if (tags['addr:city'] != null) addressParts.add(tags['addr:city']);
            
            String address = addressParts.isNotEmpty 
                ? addressParts.join(', ') 
                : 'Adres Belirtilmemiş (Haritadan Konum Alınabilir)';
            
            final double distMeter = Geolocator.distanceBetween(lat, lng, plat, plng);
            final String? phone = tags['phone'] ?? tags['contact:phone'];
            
            bool? isOpen;
            if (tags['opening_hours'] != null) {
              isOpen = true; 
            }

            final rand = Random(id.hashCode);
            final int reviewsCount = 5 + rand.nextInt(75);

            list.add(NearbyBarber(
              id: id,
              name: name,
              address: address,
              latitude: plat,
              longitude: plng,
              distanceMeter: distMeter,
              rating: 4.0 + (rand.nextDouble() * 1.0),
              isOpen: isOpen,
              phoneNumber: phone,
              imageUrl: _getRandomPhoto(id),
              reviewCount: reviewsCount,
              galleryUrls: _generateGallery(id),
              workingHours: _generateWorkingHours(id),
              services: _generateServices(id),
              reviews: _generateReviews(id),
            ));
          }

          list.sort((a, b) => a.distanceMeter.compareTo(b.distanceMeter));
          return list;
        } else {
          lastException = Exception('OSM Overpass HTTP Error: ${res.statusCode} from $url');
          debugPrint('OSM Overpass URL $url returned HTTP ${res.statusCode}. Trying next server...');
        }
      } catch (e) {
        lastException = Exception('OSM Overpass Error: $e from $url');
        debugPrint('OSM Overpass URL $url failed with exception: $e. Trying next server...');
      }
    }

    throw lastException ?? Exception('All public OpenStreetMap Overpass servers failed to respond.');
  }

  /// Locally filters, sorts, and paginates a list of barbers.
  static List<NearbyBarber> getFilteredBarbers({
    required List<NearbyBarber> sourceList,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortBy, // 'distance', 'rating', 'reviews'
    double? maxDistanceKm,
    bool? onlyOpen,
    String? requiredService,
  }) {
    List<NearbyBarber> filtered = List.from(sourceList);

    // 1. Search Query Filter
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      filtered = filtered.where((b) {
        return b.name.toLowerCase().contains(q) || 
               b.address.toLowerCase().contains(q);
      }).toList();
    }

    // 2. Distance Filter
    if (maxDistanceKm != null) {
      final maxMeter = maxDistanceKm * 1000;
      filtered = filtered.where((b) => b.distanceMeter <= maxMeter).toList();
    }

    // 3. Open Now Filter
    if (onlyOpen == true) {
      filtered = filtered.where((b) => b.isOpen == true).toList();
    }

    // 4. Required Service Filter
    if (requiredService != null && requiredService.isNotEmpty) {
      filtered = filtered.where((b) {
        return b.services.any((s) => s['name'].toString().toLowerCase().contains(requiredService.toLowerCase()));
      }).toList();
    }

    // 5. Sorting
    if (sortBy == 'rating') {
      filtered.sort((a, b) => (b.rating ?? 0.0).compareTo(a.rating ?? 0.0));
    } else if (sortBy == 'reviews') {
      filtered.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    } else {
      // Default: distance
      filtered.sort((a, b) => a.distanceMeter.compareTo(b.distanceMeter));
    }

    // 6. Pagination
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= filtered.length) {
      return [];
    }
    final endIndex = min(startIndex + pageSize, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }
}
