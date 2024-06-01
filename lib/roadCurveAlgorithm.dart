library roadCurveAlgorithm;

import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

double degreesToRadians(degrees) {
  return degrees * pi / 180;
}

double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
  var deltaLon = degreesToRadians(lon2 - lon1);
  var phi1 = degreesToRadians(lat1);
  var phi2 = degreesToRadians(lat2);

  var x = sin(deltaLon) * cos(phi2);
  var y = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLon);

  var bearing = atan2(x, y);
  bearing = radiansToDegrees(bearing);
  return (bearing + 360) % 360;
}

double radiansToDegrees(double radians) {
  return radians * 180 / pi;
}

List<double> calculateTurnAngle(
    List<LatLng> polypoints,
    List<List<LatLng>> redPolyline,
    List<List<LatLng>> orangePolyline,
    List<List<LatLng>> bluePolyline,
    List<LatLng> redcircles,
    List<LatLng> orangecircles) {
  List<double> curves = [];
  redPolyline.clear();
  orangePolyline.clear();
  bluePolyline.clear();
  redcircles.clear();
  orangecircles.clear();

  for (int i = 0; i < polypoints.length - 2; i++) {
    double initialBearing = calculateBearing(
        polypoints[i].latitude,
        polypoints[i].longitude,
        polypoints[i + 1].latitude,
        polypoints[i + 1].longitude);
    double finalBearing = calculateBearing(
        polypoints[i + 1].latitude,
        polypoints[i + 1].longitude,
        polypoints[i + 2].latitude,
        polypoints[i + 2].longitude);

    double turnAngle = finalBearing - initialBearing;

    if (turnAngle < 0) {
      turnAngle = turnAngle.abs();
      if (turnAngle > 180) {
        turnAngle -= 360;
        if (turnAngle < 0) {
          turnAngle = turnAngle.abs();
        }
      }
    } else if (turnAngle > 180) {
      turnAngle -= 360;
      if (turnAngle < 0) {
        turnAngle = turnAngle.abs();
      }
    }
    if (turnAngle > 40) {
      redPolyline.add([polypoints[i], polypoints[i + 1]]);
      redcircles.add(polypoints[i + 1]);
    } else if (turnAngle < 40 && turnAngle > 20) {
      orangePolyline.add([polypoints[i], polypoints[i + 1]]);
      orangecircles.add(polypoints[i + 1]);
    } else {
      bluePolyline.add([polypoints[i], polypoints[i + 1]]);
    }
    curves.add(turnAngle);
  }

  return curves;
}

class ZoomOutTurnAngle {
  int circleSize;
  LatLng coordination;
  String color;

  ZoomOutTurnAngle(this.circleSize, this.coordination, this.color);

  // void incCircleSize() {
  //   this.circleSize++;
  // }
}

List<ZoomOutTurnAngle> calculateTurnAngleZoomOut(
  List<LatLng> polypoints,
) {
  List<ZoomOutTurnAngle> allCircles = [];

  for (int i = 0; i < polypoints.length - 2; i++) {
    double initialBearing = calculateBearing(
        polypoints[i].latitude,
        polypoints[i].longitude,
        polypoints[i + 1].latitude,
        polypoints[i + 1].longitude);
    double finalBearing = calculateBearing(
        polypoints[i + 1].latitude,
        polypoints[i + 1].longitude,
        polypoints[i + 2].latitude,
        polypoints[i + 2].longitude);

    double turnAngle = finalBearing - initialBearing;

    if (turnAngle < 0) {
      turnAngle = turnAngle.abs();
      if (turnAngle > 180) {
        turnAngle -= 360;
        if (turnAngle < 0) {
          turnAngle = turnAngle.abs();
        }
      }
    } else if (turnAngle > 180) {
      turnAngle -= 360;
      if (turnAngle < 0) {
        turnAngle = turnAngle.abs();
      }
    }
    if (turnAngle > 40) {
      allCircles.add(ZoomOutTurnAngle(1, polypoints[i + 1], "red"));
    } else if (turnAngle < 40 && turnAngle > 20) {
      allCircles.add(ZoomOutTurnAngle(1, polypoints[i + 1], "orange"));
    } else {}
  }
  List<ZoomOutTurnAngle> returnCircles = checkForDistanceInCircles(allCircles);

  for (int i = 0; i < returnCircles.length; i++) {
    print(
        "Circle ${i} => ${returnCircles[i].color}, ${returnCircles[i].circleSize}, ${returnCircles[i].coordination}");
  }

  return returnCircles;
}

List<ZoomOutTurnAngle> checkForDistanceInCircles(
    List<ZoomOutTurnAngle> circles) {
  double distance;
  List<ZoomOutTurnAngle> tobeDeleted = [];
  List<ZoomOutTurnAngle> tobeAdded = [];

  for (int i = 0; i < circles.length - 1; i++) {
    List<ZoomOutTurnAngle> tempCircles = [];
    distance = Geolocator.distanceBetween(
      circles[i].coordination.latitude,
      circles[i].coordination.longitude,
      circles[i + 1].coordination.latitude,
      circles[i + 1].coordination.longitude,
    );
    if (distance < 200) {
      tempCircles.add(circles[i]);
      tempCircles.add(circles[i + 1]);
      for (int j = i + 1; j < circles.length - 1; j++) {
        if (distance +
                Geolocator.distanceBetween(
                  circles[j].coordination.latitude,
                  circles[j].coordination.longitude,
                  circles[j + 1].coordination.latitude,
                  circles[j + 1].coordination.longitude,
                ) <
            200) {
          tempCircles.add(circles[j + 1]);
          i = j + 1;
        } else {
          i = j;
          break;
        }
      }
      int midIndex = tempCircles.length ~/ 2;
      tempCircles[midIndex].circleSize = tempCircles.length;
      if (tempCircles.first.color == 'red') {
        tempCircles[midIndex].color = 'red';
      }
      if (tempCircles.first.color == 'orange') {
        tempCircles[midIndex].color = 'orange';
      }

      tobeDeleted.addAll(tempCircles);
      tobeAdded.add(tempCircles[midIndex]);
    }
  }
  for (int l = 0; l < tobeDeleted.length; l++) {
    circles.removeWhere((element) => element == tobeDeleted[l]);
  }
  circles.addAll(tobeAdded);

  return circles;
}

double calculateHaversineDistance(lat1, lon1, lat2, lon2) {
  var R = 6371e3; // meters
  var phi1 = degreesToRadians(lat1);
  var phi2 = degreesToRadians(lat2);
  var deltaPhi = degreesToRadians(lat2 - lat1);
  var deltaLambda = degreesToRadians(lon2 - lon1);

  var a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
      cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
  var c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c;
}

void findRadius(List<LatLng> markers) {
  var sumLat = 0.0;
  var sumLon = 0.0;

  for (var marker in markers) {
    sumLat += marker.latitude;
    sumLon += marker.longitude;
  }

  var centroidLat = sumLat / markers.length;
  var centroidLon = sumLon / markers.length;

  double maxDistance = 0;
  for (var marker in markers) {
    double distance = calculateHaversineDistance(
      centroidLat,
      centroidLon,
      marker.latitude,
      marker.longitude,
    );
    if (distance > maxDistance) {
      maxDistance = distance;
    }
  }

  // print("Inner radius is: $maxDistance meters");
}

double calculatePolylineLength(List<LatLng> polylinePoints) {
  double totalDistance = 0.0;

  for (int i = 0; i < polylinePoints.length - 1; i++) {
    final start = polylinePoints[i];

    final end = polylinePoints[i + 1];

    // Calculate the distance between the current point and the next point
    double distance = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    totalDistance += distance;
  }

  return totalDistance;
}
