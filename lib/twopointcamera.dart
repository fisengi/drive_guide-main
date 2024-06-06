import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapUtils {
  // Function to calculate the midpoint
  static LatLng calculateMidpoint(LatLng point1, LatLng point2) {
    double latitudeMid = (point1.latitude + point2.latitude) / 2;
    double longitudeMid = (point1.longitude + point2.longitude) / 2;
    return LatLng(latitudeMid, longitudeMid);
  }

  // Function to estimate zoom level based on the distance
  static double calculateZoom(LatLng point1, LatLng point2) {
    double earthRadius = 6371000; // in meters
    double lat1 = point1.latitude * pi / 180;
    double lat2 = point2.latitude * pi / 180;
    double lon1 = point1.longitude * pi / 180;
    double lon2 = point2.longitude * pi / 180;

    double dLon = lon2 - lon1;
    double dLat = lat2 - lat1;

    double a =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    // Simplistic way to calculate zoom
    double zoom = 20;
    return zoom;
  }

  // Function to animate the camera
  static Future<void> animateCameraToMidpoint(
      GoogleMapController controller, LatLng point1, LatLng point2) async {
    LatLng midpoint = calculateMidpoint(point1, point2);
    double zoom = calculateZoom(point1, point2);
    await controller?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: midpoint,
        bearing: 270.0,
        tilt: 30.0,
        zoom: 19.0,
      ),
    ));
  }
}
