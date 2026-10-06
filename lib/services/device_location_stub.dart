import 'package:latlong2/latlong.dart';

Future<LatLng> getCurrentDeviceLocation() {
  throw UnsupportedError('Device location is not available on this platform.');
}
