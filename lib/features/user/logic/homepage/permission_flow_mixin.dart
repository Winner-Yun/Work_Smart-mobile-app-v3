part of '../homepage_logic.dart';

mixin _PermissionFlowMixin on _HomePageLogicState, _MapLocationMixin {
  Future<void> _runStartupPermissionFlow() async {
    if (_startupFlowStarted || !mounted) {
      return;
    }

    _startupFlowStarted = true;
    await LocalNotificationService.instance.initialize();

    final bool locationGranted = await _handleLocationPermissionStep();
    await _handleNotificationPermissionStep();

    if (mounted) {
      widget.onStartupFlowCompleted?.call();
    }

    if (!locationGranted && mounted) {
      setState(() => rangeStatusText = AppStrings.tr('perm_needed'));
    }
  }

  Future<bool> _handleLocationPermissionStep() async {
    if (kIsWeb) {
      return true;
    }

    bool hasRequestedOnce = false;
    while (mounted) {
      final LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        await initLocationTracking(skipPermissionRequest: true);
        return true;
      }

      if (!hasRequestedOnce && permission == LocationPermission.denied) {
        hasRequestedOnce = true;
        final LocationPermission requested =
            await Geolocator.requestPermission();
        if (requested == LocationPermission.always ||
            requested == LocationPermission.whileInUse) {
          await initLocationTracking(skipPermissionRequest: true);
          return true;
        }
      }

      final _PermissionResolutionAction
      action = await _showPermissionResolutionDialog(
        title: AppStrings.tr('location_permission_required_title'),
        message: AppStrings.tr('location_permission_required_message'),
        canRetry: permission != LocationPermission.deniedForever,
      );

      if (action == _PermissionResolutionAction.retry) {
        hasRequestedOnce = false;
        continue;
      }

      if (action == _PermissionResolutionAction.settings) {
        await openAppSettings();
        continue;
      }

      return false;
    }

    return false;
  }

  Future<void> _detectDeveloperModeOnHomepage() async {
    if (kIsWeb || _developerModeWarningShown || !mounted) {
      return;
    }

    bool fakeLocationDetected = false;
    bool developerModeDetected = false;

    try {
      fakeLocationDetected = await DetectFakeLocation().detectFakeLocation();
    } catch (_) {
      fakeLocationDetected = false;
    }

    try {
      developerModeDetected = await FlutterJailbreakDetection.developerMode;
    } catch (_) {
      developerModeDetected = false;
    }

    if (!fakeLocationDetected && !developerModeDetected) {
      return;
    }

    _developerModeWarningShown = true;
    if (!mounted) {
      return;
    }

    setState(() {
      isDeveloperModeDetected = true;
      isInRange = false;
      rangeStatusText = AppStrings.tr('mock_gps_label');
    });

    await _showDeveloperModeWarningAndExit(
      message: fakeLocationDetected
          ? AppStrings.tr('mock_gps_warning')
          : AppStrings.tr('developer_mode_alert_message'),
    );
  }

  Future<void> _handleNotificationPermissionStep() async {
    if (kIsWeb) {
      return;
    }

    await _requestPermissionWithResolution(
      permission: Permission.notification,
      title: AppStrings.tr('notification_permission_required_title'),
      message: AppStrings.tr('notification_permission_required_message'),
    );
  }

  Future<bool> _requestPermissionWithResolution({
    required Permission permission,
    required String title,
    required String message,
  }) async {
    bool hasRequestedOnce = false;

    while (mounted) {
      final PermissionStatus status = await permission.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      final bool canRetry =
          !status.isPermanentlyDenied &&
          !status.isRestricted &&
          !status.isLimited;

      if (!hasRequestedOnce && canRetry) {
        hasRequestedOnce = true;
        final PermissionStatus requestedStatus = await permission.request();
        if (requestedStatus.isGranted || requestedStatus.isLimited) {
          return true;
        }
      }

      final _PermissionResolutionAction action =
          await _showPermissionResolutionDialog(
            title: title,
            message: message,
            canRetry: canRetry,
          );

      if (action == _PermissionResolutionAction.retry) {
        hasRequestedOnce = false;
        continue;
      }

      if (action == _PermissionResolutionAction.settings) {
        await openAppSettings();
        continue;
      }

      return false;
    }

    return false;
  }

  Future<_PermissionResolutionAction> _showPermissionResolutionDialog({
    required String title,
    required String message,
    required bool canRetry,
  }) async {
    if (!mounted) {
      return _PermissionResolutionAction.notNow;
    }

    final _PermissionResolutionAction? action =
        await showDialog<_PermissionResolutionAction>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                if (canRetry)
                  TextButton(
                    onPressed: () => Navigator.of(
                      dialogContext,
                    ).pop(_PermissionResolutionAction.retry),
                    child: const Text('Retry'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_PermissionResolutionAction.settings),
                  child: const Text('Open Settings'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_PermissionResolutionAction.notNow),
                  child: const Text('Not Now'),
                ),
              ],
            );
          },
        );

    return action ?? _PermissionResolutionAction.notNow;
  }
}
