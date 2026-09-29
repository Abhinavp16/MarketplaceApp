import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'api_client.dart';
import 'storage_service.dart';

/// Service to handle token refresh with proactive refresh timer
/// Refreshes tokens before they expire to prevent auto-logout
class TokenRefreshService {
  static final TokenRefreshService _instance = TokenRefreshService._internal();
  
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  
  // Refresh token 1 hour before expiration (11 hours for 12-hour tokens)
  static const Duration _refreshBeforeExpiry = Duration(hours: 1);
  // Default refresh interval (check every 30 minutes if token needs refresh)
  static const Duration _defaultRefreshInterval = Duration(minutes: 30);

  factory TokenRefreshService() {
    return _instance;
  }

  TokenRefreshService._internal();

  /// Starts the proactive token refresh mechanism
  /// Should be called after successful login
  void startProactiveRefresh() {
    debugPrint('[TokenRefresh] Starting proactive refresh mechanism');
    _stopRefreshTimer(); // Stop any existing timer
    _refreshTimer = Timer.periodic(_defaultRefreshInterval, (_) async {
      await _proactiveRefresh();
    });
  }

  /// Stops the proactive token refresh mechanism
  /// Should be called on logout
  void stopProactiveRefresh() {
    debugPrint('[TokenRefresh] Stopping proactive refresh mechanism');
    _stopRefreshTimer();
  }

  void _stopRefreshTimer() {
    if (_refreshTimer != null) {
      _refreshTimer!.cancel();
      _refreshTimer = null;
    }
  }

  /// Performs proactive token refresh if needed
  Future<void> _proactiveRefresh() async {
    if (_isRefreshing) return;
    
    try {
      final accessToken = await StorageService.getAccessToken();
      if (accessToken == null) return;

      // Check if token is expiring soon
      if (_isTokenExpiringSoon(accessToken)) {
        debugPrint('[TokenRefresh] Token expiring soon, refreshing...');
        await refreshToken();
      }
    } catch (e) {
      debugPrint('[TokenRefresh] Error in proactive refresh: $e');
    }
  }

  /// Checks if a JWT token is expiring within the refresh window
  bool _isTokenExpiringSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // Decode the payload (JWT payload is base64url encoded)
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = payload['exp'];
      
      if (exp == null) return false;
      
      final expiryTime = DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
      final now = DateTime.now();
      final timeUntilExpiry = expiryTime.difference(now);
      
      debugPrint('[TokenRefresh] Token expires in: ${timeUntilExpiry.inMinutes} minutes');
      return timeUntilExpiry < _refreshBeforeExpiry;
    } catch (e) {
      debugPrint('[TokenRefresh] Error checking token expiry: $e');
      return false;
    }
  }

  /// Manually refresh the access token
  /// Returns true if successful, false otherwise
  Future<bool> refreshToken() async {
    if (_isRefreshing) {
      debugPrint('[TokenRefresh] Refresh already in progress, skipping');
      return false;
    }

    _isRefreshing = true;
    try {
      final refreshTokenValue = await StorageService.getRefreshToken();
      if (refreshTokenValue == null) {
        debugPrint('[TokenRefresh] No refresh token available');
        return false;
      }

      // Use a fresh Dio instance to avoid interceptor loops
      final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl));
      final response = await dio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshTokenValue},
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final newAccessToken = response.data['data']['accessToken'];
        final newRefreshToken = response.data['data']['refreshToken'];
        
        if (newAccessToken != null && newRefreshToken != null) {
          await StorageService.saveTokens(newAccessToken, newRefreshToken);
          debugPrint('[TokenRefresh] Token refreshed successfully');
          return true;
        }
      }
      
      debugPrint('[TokenRefresh] Token refresh failed: Invalid response');
      return false;
    } on DioException catch (e) {
      debugPrint('[TokenRefresh] Token refresh DioException: ${e.message}');
      if (e.response?.statusCode == 401) {
        debugPrint('[TokenRefresh] Refresh token expired or revoked');
      }
      return false;
    } catch (e) {
      debugPrint('[TokenRefresh] Token refresh error: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Disposes the service (cleanup)
  void dispose() {
    _stopRefreshTimer();
  }
}
