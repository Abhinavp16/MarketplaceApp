import 'package:flutter/material.dart';
import 'token_refresh_service.dart';
import 'storage_service.dart';

/// Service to handle app lifecycle events (resume, pause, detach)
/// Automatically refreshes tokens when the app resumes to prevent session expiration
class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  
  bool _isDisposed = false;
  DateTime? _lastResumeTime;

  factory AppLifecycleService() {
    return _instance;
  }

  AppLifecycleService._internal();

  /// Initialize the app lifecycle observer
  void initialize() {
    if (!_isDisposed) {
      WidgetsBinding.instance.addObserver(this);
      debugPrint('[AppLifecycle] Initialized');
    }
  }

  /// Dispose the app lifecycle observer
  void dispose() {
    if (!_isDisposed) {
      WidgetsBinding.instance.removeObserver(this);
      _isDisposed = true;
      debugPrint('[AppLifecycle] Disposed');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[AppLifecycle] State changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResume();
        break;
      case AppLifecycleState.paused:
        _handleAppPause();
        break;
      case AppLifecycleState.detached:
        _handleAppDetach();
        break;
      case AppLifecycleState.hidden:
        debugPrint('[AppLifecycle] App hidden');
        break;
      case AppLifecycleState.inactive:
        debugPrint('[AppLifecycle] App inactive');
        break;
    }
  }

  /// Called when app resumes from background
  /// Refreshes token if the app was paused for a significant time
  Future<void> _handleAppResume() async {
    debugPrint('[AppLifecycle] App resumed');
    
    try {
      final token = await StorageService.getAccessToken();
      if (token == null) {
        debugPrint('[AppLifecycle] No token found on resume');
        return;
      }

      // Check if app was paused for more than 5 minutes
      if (_lastResumeTime != null) {
        final timeSincePause = DateTime.now().difference(_lastResumeTime!);
        debugPrint('[AppLifecycle] Time since pause: ${timeSincePause.inMinutes} minutes');
        
        if (timeSincePause.inMinutes > 5) {
          debugPrint('[AppLifecycle] App paused for > 5 minutes, refreshing token...');
          await TokenRefreshService().refreshToken();
        }
      }
      
      _lastResumeTime = null;
    } catch (e) {
      debugPrint('[AppLifecycle] Error handling resume: $e');
    }
  }

  /// Called when app is paused (backgrounded)
  void _handleAppPause() {
    debugPrint('[AppLifecycle] App paused');
    _lastResumeTime = DateTime.now();
  }

  /// Called when app is detached (closing)
  void _handleAppDetach() {
    debugPrint('[AppLifecycle] App detaching');
    TokenRefreshService().stopProactiveRefresh();
  }
}
