import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class CurrentLocationException implements Exception {
  final String message;

  const CurrentLocationException(this.message);

  @override
  String toString() => message;
}

class CurrentLocationService {
  final Geocoding _geocoding;

  CurrentLocationService({Geocoding? geocoding})
    : _geocoding = geocoding ?? Geocoding();

  Future<String> getCurrentAddress() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const CurrentLocationException(
        'Turn on Location or GPS, then try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const CurrentLocationException(
        'Location permission was denied. You can still enter the address manually.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const CurrentLocationException(
        'Location permission is blocked. Enable it in Android Settings, then try again.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        throw const CurrentLocationException(
          'A readable address was not found. Please enter it manually.',
        );
      }

      final address = _formatPlacemark(placemarks.first);
      if (address.length < 10) {
        throw const CurrentLocationException(
          'The detected address is incomplete. Please enter it manually.',
        );
      }
      return address.length <= 300 ? address : address.substring(0, 300);
    } on TimeoutException {
      throw const CurrentLocationException(
        'Location took too long. Move near a window or check GPS, then try again.',
      );
    } on LocationServiceDisabledException {
      throw const CurrentLocationException(
        'Turn on Location or GPS, then try again.',
      );
    } on CurrentLocationException {
      rethrow;
    } catch (_) {
      throw const CurrentLocationException(
        'Could not determine your address. Check your connection or enter it manually.',
      );
    }
  }

  String _formatPlacemark(Placemark placemark) {
    final street = [
      placemark.subThoroughfare,
      placemark.thoroughfare,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');

    final parts = <String?>[
      street.isEmpty ? placemark.street : street,
      placemark.subLocality,
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.administrativeArea,
      placemark.postalCode,
      placemark.country,
    ];
    final seen = <String>{};
    return parts
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where((part) => seen.add(part.toLowerCase()))
        .join(', ');
  }
}
