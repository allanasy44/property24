import 'dart:async';
import 'dart:js_interop';

import 'package:latlong2/latlong.dart';
import 'package:web/web.dart' as web;

Future<LatLng> getCurrentDeviceLocation() async {
  final position = Completer<LatLng>();
  web.window.navigator.geolocation.getCurrentPosition(
    ((web.GeolocationPosition result) {
      position.complete(
        LatLng(result.coords.latitude, result.coords.longitude),
      );
    }).toJS,
    ((web.GeolocationPositionError error) {
      position.completeError(StateError(error.message));
    }).toJS,
  );
  return position.future;
}
