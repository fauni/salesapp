import 'package:geolocator/geolocator.dart';

/// A GPS fix — latitude/longitude in decimal degrees.
typedef LatLng = (double lat, double lng);

/// Best-effort GPS fix for SAP's U_SL_Ubicacion (set at order-submit time).
/// Returns null on ANY failure — permission denied, location services off,
/// timeout, or any other geolocator error. Location is optional information,
/// never a requirement to create an order (confirmed product decision).
Future<LatLng?> getCurrentLocationOrNull() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return (pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}
