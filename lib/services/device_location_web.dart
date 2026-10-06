import 'dart:html' as html;

import 'package:latlong2/latlong.dart';

Future<LatLng> getCurrentDeviceLocation() async {
  final geolocation = html.window.navigator.geolocation;
  final position = await geolocation.getCurrentPosition();
  final coordinates = position.coords;
  final latitude = coordinates?.latitude;
  final longitude = coordinates?.longitude;
  if (latitude == null || longitude == null) {
    throw StateError('The browser did not return device coordinates.');
  }
  return LatLng(latitude.toDouble(), longitude.toDouble());
}
