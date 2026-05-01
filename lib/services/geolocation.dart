import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Why the device wasn't able to provide a real position. Lets callers tell
/// "the user said no" apart from "we never got to ask" so the UI can surface
/// the right message (or open settings).
enum GeolocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class GeolocationResult {
  final Position? position;
  final GeolocationFailure? failure;

  const GeolocationResult._({this.position, this.failure});

  const GeolocationResult.success(Position p) : this._(position: p);
  const GeolocationResult.failed(GeolocationFailure f) : this._(failure: f);

  bool get ok => position != null;
}

/// Acquires the device's current position, requesting permission if needed.
///
/// Returns a [GeolocationResult] describing either the [Position] or why we
/// failed. Never throws — callers can rely on the result alone.
///
/// On a slow GPS lock the call falls back to the OS's last-known position so
/// the UI doesn't block forever; if even that is unavailable, the failure is
/// reported as [GeolocationFailure.timeout].
Future<GeolocationResult> acquireUserPosition({
  Duration timeout = const Duration(seconds: 15),
  LocationAccuracy accuracy = LocationAccuracy.high,
}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const GeolocationResult.failed(GeolocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const GeolocationResult.failed(
        GeolocationFailure.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.denied) {
      return const GeolocationResult.failed(GeolocationFailure.permissionDenied);
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: timeout,
      ),
    );
    return GeolocationResult.success(position);
  } on TimeoutException {
    final last = await _safeLastKnown();
    if (last != null) return GeolocationResult.success(last);
    return const GeolocationResult.failed(GeolocationFailure.timeout);
  } on LocationServiceDisabledException {
    return const GeolocationResult.failed(GeolocationFailure.serviceDisabled);
  } on PermissionDeniedException {
    return const GeolocationResult.failed(GeolocationFailure.permissionDenied);
  } catch (_) {
    final last = await _safeLastKnown();
    if (last != null) return GeolocationResult.success(last);
    return const GeolocationResult.failed(GeolocationFailure.unknown);
  }
}

Future<Position?> _safeLastKnown() async {
  try {
    return await Geolocator.getLastKnownPosition();
  } catch (_) {
    return null;
  }
}
