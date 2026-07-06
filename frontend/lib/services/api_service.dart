import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const _secureStorage = FlutterSecureStorage();
  // Auto-detect backend URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5123/api';
    }
    try {
      if (Platform.isAndroid) {
        // Android Emulator uses 10.0.2.2 to access host machine's localhost
        return 'http://10.0.2.2:5123/api';
      }
    } catch (_) {
      // Platform check fails on web sometimes, fallback to localhost
    }
    return 'http://localhost:5123/api';
  }

  // Request OTP code
  static Future<TaskResult<Map<String, dynamic>>> sendOtp(String phoneNumber, {bool isRegister = false}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'isRegister': isRegister,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return TaskResult(success: true, data: Map<String, dynamic>.from(body));
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'An error occurred.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Failed to connect to server: $e');
    }
  }

  // Verify OTP code
  static Future<TaskResult<Map<String, dynamic>>> verifyOtp(String phoneNumber, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber, 'code': code}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Invalid or expired code.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Failed to connect to server: $e');
    }
  }

  // Complete Registration
  static Future<TaskResult<Map<String, dynamic>>> register(String phoneNumber, String code, String fullName, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'code': code,
          'fullName': fullName,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to create registration.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Failed to connect to server: $e');
    }
  }

  // Fetch Salon List with filters
  static Future<TaskResult<List<dynamic>>> getSalons({
    String? search,
    String? serviceName,
    double? latitude,
    double? longitude,
    double? maxDistanceKm,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      var queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (serviceName != null && serviceName.isNotEmpty) queryParams['serviceName'] = serviceName;
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (maxDistanceKm != null) queryParams['maxDistanceKm'] = maxDistanceKm.toString();
      queryParams['page'] = page.toString();
      queryParams['pageSize'] = pageSize.toString();

      final uri = Uri.parse('$baseUrl/salons').replace(queryParameters: queryParams);
      
      final token = await getToken();
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = _safeJsonDecode(response.body);
        final mapped = body.map((s) {
          if (s is Map) {
            s['imageUrl'] = formatImageUrl(s['imageUrl']);
          }
          return s;
        }).toList();
        return TaskResult(success: true, data: mapped);
      } else {
        return TaskResult(success: false, message: 'Salonlar listelenemedi.');
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Fetch Salon Details
  static Future<TaskResult<Map<String, dynamic>>> getSalonDetails(String salonId) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/salons/$salonId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['salon'] != null) {
          body['salon']['imageUrl'] = formatImageUrl(body['salon']['imageUrl']);
        }
        return TaskResult(success: true, data: body);
      } else {
        return TaskResult(success: false, message: 'Salon detayları getirilemedi.');
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Fetch Available Slots for Stylist on Date
  static Future<TaskResult<List<dynamic>>> getAvailableSlots(String stylistId, String date, String serviceId) async {
    try {
      final token = await getToken();
      final uri = Uri.parse('$baseUrl/booking/available-slots').replace(queryParameters: {
        'stylistId': stylistId,
        'date': date,
        'serviceId': serviceId,
      });

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Müsait saatler getirilemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Create Appointment
  static Future<TaskResult<Map<String, dynamic>>> createAppointment(
      String customerId, String stylistId, String serviceId, String date, String timeSlot) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/booking/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'customerId': customerId,
          'stylistId': stylistId,
          'serviceId': serviceId,
          'appointmentDate': date,
          'timeSlot': timeSlot,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Randevu oluşturulamadı.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Get Customer Appointments
  static Future<TaskResult<List<dynamic>>> getCustomerAppointments(String customerId) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/booking/customer/$customerId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load appointments.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Cancel Appointment
  static Future<TaskResult<Map<String, dynamic>>> cancelAppointment(String appointmentId) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/booking/cancel/$appointmentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to cancel appointment.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Confirm Appointment
  static Future<TaskResult<Map<String, dynamic>>> confirmAppointment(String appointmentId) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/booking/confirm/$appointmentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = _safeJsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = _safeJsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Randevu onaylanamadı.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Reject Appointment
  static Future<TaskResult<Map<String, dynamic>>> rejectAppointment(String appointmentId) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/booking/reject/$appointmentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = _safeJsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = _safeJsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Randevu reddedilemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Reschedule Appointment
  static Future<TaskResult<Map<String, dynamic>>> rescheduleAppointment(String appointmentId, String date, String timeSlot) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/booking/reschedule'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'appointmentId': appointmentId,
          'newDate': date,
          'newTimeSlot': timeSlot,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Randevu güncellenemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Submit Review
  static Future<TaskResult<Map<String, dynamic>>> submitReview(String appointmentId, String customerId, int rating, String comment) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/booking/review'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'appointmentId': appointmentId,
          'customerId': customerId,
          'rating': rating,
          'comment': comment,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Değerlendirme kaydedilemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Create Test Appointments
  static Future<TaskResult<Map<String, dynamic>>> createTestAppointments(String customerId) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/booking/create-test-appointments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'customerId': customerId,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load simulation data.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Get Barber Profile details and working hours
  static Future<TaskResult<Map<String, dynamic>>> getBarberProfile() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/barber/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load barber profile.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Update Barber Working Hours
  static Future<TaskResult<Map<String, dynamic>>> updateBarberWorkingHours(List<dynamic> workingHours) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/barber/working-hours'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(workingHours),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Çalışma saatleri güncellenemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Get Barber Salon Services
  static Future<TaskResult<List<dynamic>>> getBarberServices() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/barber/services'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load services.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Add Barber Salon Service
  static Future<TaskResult<Map<String, dynamic>>> addBarberService(String name, int duration, double price) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/barber/services'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'durationInMinutes': duration,
          'price': price,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Hizmet eklenemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Update Barber Salon Service
  static Future<TaskResult<Map<String, dynamic>>> updateBarberService(String serviceId, String name, int duration, double price) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/barber/services/$serviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'durationInMinutes': duration,
          'price': price,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Hizmet güncellenemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Delete Barber Salon Service
  static Future<TaskResult<Map<String, dynamic>>> deleteBarberService(String serviceId) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/barber/services/$serviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Hizmet silinemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Get Barber Appointments list
  static Future<TaskResult<List<dynamic>>> getBarberAppointments({String? startDate, String? endDate}) async {
    try {
      final token = await getToken();
      var queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final uri = Uri.parse('$baseUrl/barber/appointments').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load appointments.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Get Barber Analytics and Earnings Report
  static Future<TaskResult<Map<String, dynamic>>> getBarberAnalytics() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/barber/analytics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = _safeJsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = _safeJsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load analytics data.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Get user settings (Reminder Minutes and Wallet balance)
  static Future<TaskResult<Map<String, dynamic>>> getUserSettings() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/user/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = _safeJsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = _safeJsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load user settings.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Update user settings (Reminder minutes preference)
  static Future<TaskResult<bool>> updateUserSettings(int reminderMinutes) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/user/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reminderMinutesBefore': reminderMinutes}),
      );

      if (response.statusCode == 200) {
        return TaskResult(success: true, data: true);
      } else {
        final error = _safeJsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Ayarlar güncellenemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }


  // Toggle favorite salon
  static Future<TaskResult<bool>> toggleFavoriteSalon(String salonId) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/user/favorites/salon/toggle/$salonId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = _safeJsonDecode(response.body);
        final isFavorite = body['isFavorite'] as bool;
        return TaskResult(success: true, data: isFavorite);
      } else {
        return TaskResult(success: false, message: 'Favorite salon operation failed.');
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Toggle favorite stylist
  static Future<TaskResult<bool>> toggleFavoriteStylist(String stylistId) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/user/favorites/stylist/toggle/$stylistId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = _safeJsonDecode(response.body);
        final isFavorite = body['isFavorite'] as bool;
        return TaskResult(success: true, data: isFavorite);
      } else {
        return TaskResult(success: false, message: 'Favorite stylist operation failed.');
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Get favorite salons
  static Future<TaskResult<List<dynamic>>> getFavoriteSalons() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/user/favorites/salons'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = _safeJsonDecode(response.body);
        final mapped = body.map((s) {
          if (s is Map) {
            s['imageUrl'] = formatImageUrl(s['imageUrl']);
          }
          return s;
        }).toList();
        return TaskResult(success: true, data: mapped);
      } else {
        return TaskResult(success: false, message: 'Failed to load favorite salons.');
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Get favorite stylists
  static Future<TaskResult<List<dynamic>>> getFavoriteStylists() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/user/favorites/stylists'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = _safeJsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        return TaskResult(success: false, message: 'Failed to load favorite stylists.');
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Session Management
  static Future<void> saveToken(String token, {Map<String, dynamic>? user}) async {
    await _secureStorage.write(key: 'jwt_token', value: token);
    final prefs = await SharedPreferences.getInstance();
    if (user != null) {
      await prefs.setString('user_id', user['id'] ?? '');
      await prefs.setString('user_name', user['fullName'] ?? '');
      await prefs.setString('user_role', user['role'] ?? '');
    }
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      String payload = parts[1];
      int normalizedLength = payload.length % 4;
      if (normalizedLength > 0) {
        payload += '=' * (4 - normalizedLength);
      }
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      
      final decoded = utf8.decode(base64Url.decode(payload));
      final Map<String, dynamic> map = jsonDecode(decoded);
      if (map.containsKey('exp')) {
        final exp = map['exp'] as int;
        final expDateTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
        return DateTime.now().toUtc().isAfter(expDateTime);
      }
    } catch (e) {
      return true; // Expired if parse fails
    }
    return true;
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  // Get Barber Salon details
  static Future<TaskResult<Map<String, dynamic>>> getBarberSalon() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/barber/salon'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        body['imageUrl'] = formatImageUrl(body['imageUrl']);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load salon details.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  static Future<TaskResult<String>> reverseGeocode(double latitude, double longitude) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/barber/reverse-geocode?latitude=$latitude&longitude=$longitude'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return TaskResult(success: true, data: body['address']);
      } else {
        return TaskResult(success: false, message: 'Adres çözümlenemedi.');
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Update Barber Salon details
  static Future<TaskResult<Map<String, dynamic>>> updateBarberSalon({
    required String name,
    required double latitude,
    required double longitude,
    required String phone,
    String? imageUrl,
    String? address,
  }) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/barber/salon'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'phone': phone,
          'imageUrl': imageUrl,
          'address': address,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Salon bilgileri güncellenemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  static Future<void> logout() async {
    await _secureStorage.delete(key: 'jwt_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_role');
  }

  static String formatImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=500'; // Default photo
    }
    if (url.startsWith('/')) {
      final hostUrl = baseUrl.replaceAll('/api', '');
      return '$hostUrl$url';
    }
    return url;
  }

  // Upload Salon Cover Image
  static Future<TaskResult<String>> uploadSalonImage(Uint8List imageBytes, String filename) async {
    try {
      final token = await getToken();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/barber/upload'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: filename,
        ),
      );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return TaskResult(success: true, data: body['url']);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to upload image.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Server error: $e');
    }
  }

  // Get all employees for the salon (owner only)
  static Future<TaskResult<List<dynamic>>> getEmployees() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/barber/employees'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load staff list.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Connection error: $e');
    }
  }

  // Add a new employee (owner only)
  static Future<TaskResult<bool>> addEmployee(String fullName, String phoneNumber, String title) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/barber/employees'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fullName': fullName,
          'phoneNumber': phoneNumber,
          'title': title,
        }),
      );
      if (response.statusCode == 200) {
        return TaskResult(success: true, data: true);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Çalışan eklenemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Connection error: $e');
    }
  }

  // Delete an employee (owner only)
  static Future<TaskResult<bool>> deleteEmployee(String id) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/barber/employees/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return TaskResult(success: true, data: true);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Çalışan silinemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Connection error: $e');
    }
  }

  // Get working hours of an employee
  static Future<TaskResult<List<dynamic>>> getEmployeeWorkingHours(String stylistId) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/barber/employees/$stylistId/working-hours'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load working hours.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Connection error: $e');
    }
  }

  // Update working hours of an employee
  static Future<TaskResult<bool>> updateEmployeeWorkingHours(String stylistId, List<Map<String, dynamic>> workingHours) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/barber/employees/$stylistId/working-hours'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(workingHours),
      );
      if (response.statusCode == 200) {
        return TaskResult(success: true, data: true);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Mesai saatleri güncellenemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Connection error: $e');
    }
  }

  // Get assigned services for employee
  static Future<TaskResult<List<dynamic>>> getEmployeeServices(String stylistId) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/barber/employees/$stylistId/services'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load service authorizations.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Connection error: $e');
    }
  }

  // Update assigned services for employee
  static Future<TaskResult<bool>> updateEmployeeServices(String stylistId, List<String> serviceIds) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/barber/employees/$stylistId/services'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(serviceIds),
      );
      if (response.statusCode == 200) {
        return TaskResult(success: true, data: true);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Hizmet yetkileri güncellenemedi.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Connection error: $e');
    }
  }

  // Get all salon appointments for side-by-side grid
  static Future<TaskResult<List<dynamic>>> getSalonAppointments(String date) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/barber/salon-appointments?date=$date'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load salon appointments.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Connection error: $e');
    }
  }

  // Create manual walk-in appointment
  static Future<TaskResult<bool>> createWalkInAppointment({
    required String stylistId,
    required String serviceId,
    required String startTime,
    required String guestName,
    String? guestPhone,
  }) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/barber/walk-in'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'stylistId': stylistId,
          'serviceId': serviceId,
          'startTime': startTime,
          'guestName': guestName,
          'guestPhone': guestPhone ?? '',
        }),
      );
      if (response.statusCode == 200) {
        return TaskResult(success: true, data: true);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Manuel randevu oluşturulamadı.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Connection error: $e');
    }
  }

  // Get all reviews for the salon
  static Future<TaskResult<List<dynamic>>> getSalonReviews() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/barber/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return TaskResult(success: true, data: body);
      } else {
        final error = jsonDecode(response.body);
        return TaskResult(success: false, message: _getErrorMessage(error, 'Failed to load reviews.'));
      }
    } catch (e) {
      return TaskResult(success: false, message: 'Connection error: $e');
    }
  }

  static dynamic _safeJsonDecode(String body) {
    try {
      if (body.isEmpty) return {};
      return jsonDecode(body);
    } catch (_) {
      return {};
    }
  }

  static String _getErrorMessage(dynamic error, String defaultMsg) {
    try {
      if (error is Map) {
        return error['message'] ?? error['Message'] ?? defaultMsg;
      }
    } catch (_) {}
    return defaultMsg;
  }
}

class TaskResult<T> {
  final bool success;
  final T? data;
  final String? message;

  TaskResult({required this.success, this.data, this.message});
}
