import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class ApiConstants {
  static const String baseUrl = 'https://api.neptasolutions.co.uk';

  // Auth
  static const String register           = '$baseUrl/api/auth/register';
  static const String login              = '$baseUrl/api/auth/login';
  static const String logout             = '$baseUrl/api/auth/logout';
  static const String refresh            = '$baseUrl/api/auth/refresh';
  static const String me                 = '$baseUrl/api/auth/me';
  static const String verifyEmail        = '$baseUrl/api/auth/verify-email';
  static const String resendVerification = '$baseUrl/api/auth/resend-verification';
}


class _PrefKeys {
  static const String accessToken  = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userRole     = 'user_role';
  static const String userId       = 'user_id';
}


class AuthResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  const AuthResult({
    required this.success,
    this.message,
    this.data,
  });
}


class AuthService {
  
  AuthService._();
  static final AuthService instance = AuthService._();

 
  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<Map<String, String>> get _authHeaders async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Safely extract a field from several possible JSON paths
  String? _extract(Map<String, dynamic> body, List<String> keys) {
    for (final key in keys) {
      if (key.contains('.')) {
        final parts = key.split('.');
        dynamic node = body;
        for (final p in parts) {
          if (node is Map<String, dynamic>) {
            node = node[p];
          } else {
            node = null;
            break;
          }
        }
        if (node != null) return node.toString();
      } else if (body[key] != null) {
        return body[key].toString();
      }
    }
    return null;
  }

  String _errorMessage(Map<String, dynamic> body) =>
      _extract(body, ['message', 'error', 'detail', 'errors']) ??
      'Something went wrong. Please try again.';

 
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? role,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.accessToken, accessToken);
    if (refreshToken != null) {
      await prefs.setString(_PrefKeys.refreshToken, refreshToken);
    }
    if (role != null) await prefs.setString(_PrefKeys.userRole, role);
    if (userId != null) await prefs.setString(_PrefKeys.userId, userId);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_PrefKeys.accessToken);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_PrefKeys.refreshToken);
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_PrefKeys.userRole);
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_PrefKeys.accessToken);
    await prefs.remove(_PrefKeys.refreshToken);
    await prefs.remove(_PrefKeys.userRole);
    await prefs.remove(_PrefKeys.userId);
  }

  
 
  Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
    required String userType,
    // Driver-only fields (pass null for Buyer)
    String? licenseNumber,
    String? licensePlate,
    String? vehicleType,
  }) async {
    try {
      final body = <String, dynamic>{
        'firstName': firstName,
        'lastName':  lastName,
        'email':     email,
        'password':  password,
        'phone':     phone,
        'userType':  userType,
        if (licenseNumber != null) 'licenseNumber': licenseNumber,
        if (licensePlate  != null) 'licensePlate':  licensePlate,
        if (vehicleType   != null) 'vehicleType':   vehicleType,
      };

      final response = await http.post(
        Uri.parse(ApiConstants.register),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      final resBody = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false, message: _errorMessage(resBody));
    } catch (e) {
      return AuthResult(
          success: false, message: 'Network error. Check your connection.');
    }
  }

  
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      );

      final resBody = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Extract token — covers common API shapes
        final token = _extract(resBody, [
          'token',
          'access_token',
          'accessToken',
          'data.token',
          'data.access_token',
          'data.accessToken',
        ]);

        final refreshToken = _extract(resBody, [
          'refresh_token',
          'refreshToken',
          'data.refresh_token',
          'data.refreshToken',
        ]);

        final role = _extract(resBody, [
          'role',
          'userType',
          'user.role',
          'user.userType',
          'data.role',
          'data.userType',
        ]);

        final userId = _extract(resBody, [
          'id',
          'userId',
          'user.id',
          'data.id',
        ]);

        if (token != null) {
          await saveTokens(
            accessToken:  token,
            refreshToken: refreshToken,
            role:         role?.toLowerCase(),
            userId:       userId,
          );
        }

        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false, message: _errorMessage(resBody));
    } catch (e) {
      return AuthResult(
          success: false, message: 'Network error. Check your connection.');
    }
  }

  
  Future<AuthResult> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.me),
        headers: await _authHeaders,
      );

      final resBody = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Persist role from profile in case login didn't return it
        final role = _extract(resBody, [
          'role',
          'userType',
          'user.role',
          'user.userType',
          'data.role',
          'data.userType',
        ]);
        if (role != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_PrefKeys.userRole, role.toLowerCase());
        }
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false, message: _errorMessage(resBody));
    } catch (e) {
      return AuthResult(
          success: false, message: 'Network error. Check your connection.');
    }
  }

  // ── Logout ─────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse(ApiConstants.logout),
        headers: await _authHeaders,
      );
    } catch (_) {
      
    } finally {
      await clearTokens();
    }
  }


  Future<AuthResult> resendVerification({required String email}) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.resendVerification),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email}),
      );
      final resBody = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false, message: _errorMessage(resBody));
    } catch (e) {
      return AuthResult(
          success: false, message: 'Network error. Check your connection.');
    }
  }
}