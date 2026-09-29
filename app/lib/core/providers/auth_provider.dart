import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/redeemed_coupon_service.dart';
import '../services/storage_service.dart';
import '../services/token_refresh_service.dart';

String phoneRegistrationEndpoint(bool isWholesaler) =>
    isWholesaler ? '/auth/register-phone/wholesaler' : '/auth/register-phone';

Map<String, dynamic> buildPhoneRegistrationPayload({
  required String name,
  required String phone,
  required String password,
  required bool isWholesaler,
  required bool termsAccepted,
  required bool privacyPolicyAccepted,
  required String termsVersion,
  required String privacyPolicyVersion,
  String? businessName,
}) => {
  'name': name,
  'phone': phone,
  'password': password,
  'termsAccepted': termsAccepted,
  'privacyPolicyAccepted': privacyPolicyAccepted,
  'termsVersion': termsVersion,
  'privacyPolicyVersion': privacyPolicyVersion,
  if (isWholesaler && businessName != null) 'businessName': businessName,
};

// Auth State
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);

    try {
      final token = await StorageService.getAccessToken();
      final userData = await StorageService.getUserData();

      debugPrint(
        '[Auth] Token: ${token != null ? 'exists' : 'null'}, UserData: ${userData != null ? 'exists' : 'null'}',
      );

      if (token != null && userData != null) {
        final cachedUser = UserModel.fromJson(userData);
        state = state.copyWith(user: cachedUser, isAuthenticated: false);
        final validation = await fetchCurrentUser();
        if (validation == false) return;

        state = state.copyWith(isAuthenticated: true, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, isAuthenticated: false);
      }
    } catch (e) {
      debugPrint('[Auth] _checkAuthStatus error: $e');
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  Future<bool> loginWithPhone({
    required String phone,
    required String password,
    required String expectedRole,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.post(
        '/auth/login-phone',
        data: {
          'phone': phone,
          'password': password,
          'expectedRole': expectedRole,
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final user = UserModel.fromJson(data['user']);

        await StorageService.saveTokens(
          data['accessToken'],
          data['refreshToken'],
        );
        await StorageService.saveUserData(data['user']);

        // ✓ NEW: Start proactive token refresh after successful login
        TokenRefreshService().startProactiveRefresh();

        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['message'] ?? 'Login failed',
        );
        return false;
      }
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] ?? 'Network error. Please try again.';
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      return false;
    }
  }

  Future<bool> registerWithPhone({
    required String name,
    required String phone,
    required String password,
    required bool isWholesaler,
    required bool termsAccepted,
    required bool privacyPolicyAccepted,
    required String termsVersion,
    required String privacyPolicyVersion,
    String? businessName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final endpoint = phoneRegistrationEndpoint(isWholesaler);
      final response = await _apiClient.post(
        endpoint,
        data: buildPhoneRegistrationPayload(
          name: name,
          phone: phone,
          password: password,
          isWholesaler: isWholesaler,
          termsAccepted: termsAccepted,
          privacyPolicyAccepted: privacyPolicyAccepted,
          termsVersion: termsVersion,
          privacyPolicyVersion: privacyPolicyVersion,
          businessName: businessName,
        ),
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final user = UserModel.fromJson(data['user']);

        await StorageService.saveTokens(
          data['accessToken'],
          data['refreshToken'],
        );
        await StorageService.saveUserData(data['user']);

        // ✓ NEW: Start proactive token refresh after successful registration
        TokenRefreshService().startProactiveRefresh();

        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['message'] ?? 'Registration failed',
        );
        return false;
      }
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] ?? 'Network error. Please try again.';
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      return false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? avatar,
    String? phone,
    String? address,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (avatar != null) data['avatar'] = avatar;
      if (phone != null) data['phone'] = phone;
      if (address != null) data['address'] = address;

      final response = await _apiClient.put('/auth/profile', data: data);

      if (response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data']);
        state = state.copyWith(user: user, isLoading: false);
        await StorageService.saveUserData(response.data['data']);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['message'] ?? 'Update failed',
        );
        return false;
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Network error';
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      return false;
    }
  }

  Future<String?> uploadProfileAvatar(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });
      final response = await _apiClient.post(
        '/auth/profile/avatar',
        data: formData,
      );

      if (response.data['success'] == true) {
        final userData = response.data['data']['user'];
        final user = UserModel.fromJson(userData);
        state = state.copyWith(user: user, isLoading: false);
        await StorageService.saveUserData(userData);
        return response.data['data']['avatarUrl']?.toString();
      }

      state = state.copyWith(
        isLoading: false,
        error: response.data['message'] ?? 'Avatar upload failed',
      );
      return null;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Avatar upload failed';
      state = state.copyWith(isLoading: false, error: message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAccountDeletionRequest() async {
    state = state.copyWith(error: null);
    try {
      final response = await _apiClient.get('/auth/account-deletion-request');
      if (response.data['success'] == true) {
        final data = response.data['data'];
        return data is Map<String, dynamic>
            ? data
            : data is Map
            ? Map<String, dynamic>.from(data)
            : null;
      }
      state = state.copyWith(
        error:
            response.data['message']?.toString() ??
            'Unable to load your deletion request.',
      );
    } on DioException catch (e) {
      state = state.copyWith(
        error:
            e.response?.data?['message']?.toString() ??
            'Unable to load your deletion request. Please try again.',
      );
    } catch (_) {
      state = state.copyWith(
        error: 'Unable to load your deletion request. Please try again.',
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> requestAccountDeletion() async {
    state = state.copyWith(error: null);
    try {
      final response = await _apiClient.post('/auth/account-deletion-request');
      if (response.data['success'] == true) {
        final data = response.data['data'];
        return data is Map<String, dynamic>
            ? data
            : data is Map
            ? Map<String, dynamic>.from(data)
            : null;
      }
      state = state.copyWith(
        error:
            response.data['message']?.toString() ??
            'Unable to submit your deletion request.',
      );
    } on DioException catch (e) {
      state = state.copyWith(
        error:
            e.response?.data?['message']?.toString() ??
            'Unable to submit your deletion request. Please try again.',
      );
    } catch (_) {
      state = state.copyWith(
        error: 'Unable to submit your deletion request. Please try again.',
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> cancelAccountDeletionRequest() async {
    state = state.copyWith(error: null);
    try {
      final response = await _apiClient.post(
        '/auth/account-deletion-request/cancel',
      );
      if (response.data['success'] == true) {
        final data = response.data['data'];
        return data is Map<String, dynamic>
            ? data
            : data is Map
            ? Map<String, dynamic>.from(data)
            : null;
      }
      state = state.copyWith(
        error:
            response.data['message']?.toString() ??
            'Unable to cancel your deletion request.',
      );
    } on DioException catch (e) {
      state = state.copyWith(
        error:
            e.response?.data?['message']?.toString() ??
            'Unable to cancel your deletion request. Please try again.',
      );
    } catch (_) {
      state = state.copyWith(
        error: 'Unable to cancel your deletion request. Please try again.',
      );
    }
    return null;
  }

  Future<void> _clearLocalSession() async {
    try {
      await StorageService.clearAll();
    } finally {
      // Clear redeemed coupons but preserve addresses so users don't have to re-enter them
      await RedeemedCouponService.clearLocalData();
      // Note: ShippingAddressService.clearLocalData() is NOT called here
      // This allows saved addresses to persist across login sessions
      state = AuthState();
    }
  }

  /// Attempts to refresh the access token using the refresh token
  /// Returns true if refresh was successful, false otherwise
  Future<bool> _attemptTokenRefresh() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken == null) {
        debugPrint('[Auth] No refresh token available');
        return false;
      }

      // Use a fresh Dio instance to avoid interceptor loop
      final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl));
      final response = await dio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final newAccessToken = response.data['data']['accessToken'];
        final newRefreshToken = response.data['data']['refreshToken'];

        if (newAccessToken != null && newRefreshToken != null) {
          await StorageService.saveTokens(newAccessToken, newRefreshToken);
          debugPrint('[Auth] Token refreshed successfully');
          return true;
        }
      }
      debugPrint('[Auth] Token refresh failed: Invalid response');
      return false;
    } on DioException catch (e) {
      debugPrint('[Auth] Token refresh DioException: ${e.message}');
      if (e.response?.statusCode == 401) {
        debugPrint('[Auth] Refresh token expired or revoked');
      }
      return false;
    } catch (e) {
      debugPrint('[Auth] Token refresh error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    // ✓ NEW: Stop proactive refresh on logout
    TokenRefreshService().stopProactiveRefresh();

    try {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken != null) {
        await _apiClient.post(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {}

    await _clearLocalSession();
  }

  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
    StorageService.saveUserData(user.toJson());
  }

  /// Fetches the current user from the backend
  /// Attempts to refresh token if 401 is received
  /// Only clears session if refresh also fails
  Future<bool?> fetchCurrentUser() async {
    try {
      final response = await _apiClient.get('/auth/me');
      if (response.data['success'] == true) {
        final user = UserModel.fromJson(
          response.data['data']['user'] ?? response.data['data'],
        );
        state = state.copyWith(user: user);
        await StorageService.saveUserData(
          response.data['data']['user'] ?? response.data['data'],
        );
        return true;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint(
          '[Auth] Got 401 in fetchCurrentUser, attempting token refresh...',
        );

        // ✓ NEW: Try to refresh token before clearing session
        final refreshed = await _attemptTokenRefresh();
        if (refreshed) {
          debugPrint('[Auth] Token refreshed, retrying fetchCurrentUser...');
          // Retry the request after successful refresh
          return await fetchCurrentUser();
        }

        // Only clear session if refresh failed
        debugPrint('[Auth] Token refresh failed, clearing session');
        await _clearLocalSession();
        return false;
      }
      debugPrint('[Auth] fetchCurrentUser error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[Auth] fetchCurrentUser error: $e');
      return null;
    }
    return null;
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
