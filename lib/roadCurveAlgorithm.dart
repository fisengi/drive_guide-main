library roadCurveAlgorithm;

import 'dart:math';
import 'package:drive_guide/simulationFunctions.dart';
import 'package:flutter_beep/flutter_beep.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'globals.dart';
import 'package:flutter/src/material/colors.dart' as forColors;

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

List<double> calculateTurnAngle(List<LatLng> polypoints,
    List<LatLng> redcircles, List<LatLng> orangecircles) {
  List<double> curves = [];

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
      redcircles.add(polypoints[i + 1]);
    } else if (turnAngle < 40 && turnAngle > 20) {
      orangecircles.add(polypoints[i + 1]);
    } else {}
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

  // for (int i = 0; i < returnCircles.length; i++) {
  //   print(
  //       "Circle ${i} => ${returnCircles[i].color}, ${returnCircles[i].circleSize}, ${returnCircles[i].coordination}");
  // }

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

Future<void> loadLatlngToCurves(
    List<LatLng> polylineCoordinates, List<double> curves) async {
  curveWithLatlng.clear();

  for (int i = 0; i < curves.length; i++) {
    curveWithLatlng.add(curveAndLatlng(curves[i], polylineCoordinates[i + 1]));
  }
}

void loadRouteSimulation(List<LatLng> coordinates) {
  simulationCoordinates.clear();

  for (int i = 0; i < coordinates.length - 1; i++) {
    simulationCoordinates
        .addAll(interpolatePoints(coordinates[i], coordinates[i + 1], 1));
  }

  for (int i = 0; i < simulationCoordinates.length - 1; i++) {
    if (simulationCoordinates[i] == simulationCoordinates[i + 1])
      simulationCoordinates.removeAt(i);
  }
}

void speedControl(LatLng coordinatOfCar, int speedOfCar) {
  double temp = Geolocator.distanceBetween(
    coordinatOfCar.latitude,
    coordinatOfCar.longitude,
    curveWithLatlng[curveIndex].coordination!.latitude,
    curveWithLatlng[curveIndex].coordination!.longitude,
  );

  if (temp > distanceToCurve && curveIndex < curveWithLatlng.length) {
    curveIndex++;
    distanceToCurve = double.infinity;
  } else {
    if (temp < distanceToCurve) {
      distanceToCurve = temp;
      if (distanceToCurve < 200) {
        checkSpeedAndCurve(speedOfCar);
      }
    }
  }
}

void checkSpeedAndCurve(int speedOfCar) {
  var curve = curveWithLatlng[curveIndex].curve!;
  if (speedOfCar < 80 && warningColor != forColors.Colors.green ||
      (curve < 10 && warningColor != forColors.Colors.green)) {
    warningColor = forColors.Colors.green;
  } else if (curve > 30 &&
      speedOfCar > 80 &&
      warningColor != forColors.Colors.yellow) {
    if (warningColor != forColors.Colors.yellow) {
      warningColor = forColors.Colors.yellow;
    }

    FlutterBeep.beep();

    print("MAX SPEED 100");
  } else if (curve > 20 &&
      speedOfCar > 90 &&
      warningColor != forColors.Colors.orange) {
    if (warningColor != forColors.Colors.orange) {
      warningColor = forColors.Colors.orange;
    }

    FlutterBeep.beep();
  } else if (curve > 10 && speedOfCar > 100) {
    if (warningColor != forColors.Colors.red) {
      warningColor = forColors.Colors.red;
    }
    FlutterBeep.beep();
  }
}
