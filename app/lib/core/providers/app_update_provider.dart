import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/mandatory_update_dialog.dart';
import '../models/app_update_config.dart';
import '../navigation/app_navigator_key.dart';
import '../services/app_update_service.dart';
import 'auth_provider.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(ref.watch(apiClientProvider));
});

final appUpdateControllerProvider = Provider<AppUpdateController>((ref) {
  return AppUpdateController(ref.watch(appUpdateServiceProvider));
});

class AppUpdateController {
  AppUpdateController(this._service);

  static const Duration resumeCheckInterval = Duration(minutes: 15);

  final AppUpdateGateway _service;
  Future<AppUpdateCheckResult>? _inFlightCheck;
  DateTime? _lastCheckAt;
  AppUpdateRequirement? _activeRequirement;
  bool _dialogVisible = false;
  bool _closingAfterDisable = false;
  bool _initialCheckCompleted = false;

  bool get initialCheckCompleted => _initialCheckCompleted;

  Future<bool> checkAndShow(
    BuildContext context, {
    bool isInitialCheck = false,
  }) async {
    if (!isInitialCheck && !_initialCheckCompleted) return false;

    final now = DateTime.now();
    if (!isInitialCheck &&
        _activeRequirement == null &&
        _lastCheckAt != null &&
        now.difference(_lastCheckAt!) < resumeCheckInterval) {
      return false;
    }

    _lastCheckAt = now;
    final check = _inFlightCheck ??= _service.checkForMandatoryUpdate();
    AppUpdateCheckResult result;
    try {
      result = await check;
    } finally {
      if (identical(_inFlightCheck, check)) _inFlightCheck = null;
      if (isInitialCheck) _initialCheckCompleted = true;
    }

    if (!result.succeeded) {
      return _activeRequirement != null;
    }

    final requirement = result.requirement;
    if (requirement == null) {
      _activeRequirement = null;
      _dismissDialogAfterDisable();
      return false;
    }

    _activeRequirement = requirement;
    if (!context.mounted) return true;
    _showRequirement(context, requirement);
    return true;
  }

  void _showRequirement(
    BuildContext context,
    AppUpdateRequirement requirement,
  ) {
    if (_dialogVisible) return;

    _dialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => MandatoryUpdateDialog(
          requirement: requirement,
          onUpdate: () => _service.openStore(requirement.storeUri),
        ),
      ).whenComplete(() {
        _dialogVisible = false;
        if (_closingAfterDisable) {
          _closingAfterDisable = false;
          return;
        }

        if (_activeRequirement == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final activeRequirement = _activeRequirement;
          final rootContext = appNavigatorKey.currentContext;
          if (rootContext != null && activeRequirement != null) {
            _showRequirement(rootContext, activeRequirement);
          }
        });
      }),
    );
  }

  void _dismissDialogAfterDisable() {
    if (!_dialogVisible) return;
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return;
    _closingAfterDisable = true;
    navigator.pop();
  }
}
