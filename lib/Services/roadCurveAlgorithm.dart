library roadCurveAlgorithm;

import 'dart:math';
import 'package:drive_guide/Services/simulationFunctions.dart';
import 'package:flutter_beep/flutter_beep.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../Config/globals.dart';
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

List<curveAndLatlng> calculateTurnAngle(List<LatLng> polypoints) {
  // List<double> curves = [];
  curveWithLatlng.clear();
  allCircles.clear();

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

    // double turnAngle_2 = (finalBearing - initialBearing + 540) % 360 - 180;

    // // Depending on the turn angle, add circles with different colors
    // if (turnAngle_2 > 40) {
    //   allCircles.add(ZoomOutTurnAngle(1, polypoints[i + 1], "red"));
    // } else if (turnAngle_2 > 20) {
    //   allCircles.add(ZoomOutTurnAngle(1, polypoints[i + 1], "orange"));
    // }

    // curveWithLatlng.add(curveAndLatlng(turnAngle_2, polypoints[i + 1]));

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
      allCircles.add(ZoomOutTurnAngle(2, polypoints[i + 1], "red"));
    } else if (turnAngle < 40 && turnAngle > 20) {
      allCircles.add(ZoomOutTurnAngle(1, polypoints[i + 1], "orange"));
    }
    // curves.add(turnAngle);
    curveWithLatlng.add(curveAndLatlng(turnAngle, polylineCoordinates[i + 1]));
  }

  checkForDistanceInCircles();
  return curveWithLatlng;
}

class ZoomOutTurnAngle {
  int circleSize;
  LatLng coordination;
  String color;

  ZoomOutTurnAngle(this.circleSize, this.coordination, this.color);
}

void checkForDistanceInCircles() {
  double distance;
  List<ZoomOutTurnAngle> tobeDeleted = [];
  List<ZoomOutTurnAngle> tobeAdded = [];

  for (int i = 0; i < allCircles.length - 1; i++) {
    List<ZoomOutTurnAngle> tempCircles = [];
    distance = Geolocator.distanceBetween(
      allCircles[i].coordination.latitude,
      allCircles[i].coordination.longitude,
      allCircles[i + 1].coordination.latitude,
      allCircles[i + 1].coordination.longitude,
    );
    if (distance < 100) {
      tempCircles.add(allCircles[i]);
      tempCircles.add(allCircles[i + 1]);
      for (int j = i + 1; j < allCircles.length - 1; j++) {
        if (distance +
                Geolocator.distanceBetween(
                  allCircles[j].coordination.latitude,
                  allCircles[j].coordination.longitude,
                  allCircles[j + 1].coordination.latitude,
                  allCircles[j + 1].coordination.longitude,
                ) <
            100) {
          tempCircles.add(allCircles[j + 1]);
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
    allCircles.removeWhere((element) => element == tobeDeleted[l]);
  }
  allCircles.addAll(tobeAdded);
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

      if (speedOfCar > 120) {
        if (distanceToCurve < 400) {
          checkSpeedAndCurve(speedOfCar);
        }
      } else if (speedOfCar > 100) {
        if (distanceToCurve < 200) {
          checkSpeedAndCurve(speedOfCar);
        }
      } else if (speedOfCar > 80) {
        if (distanceToCurve < 150) {
          checkSpeedAndCurve(speedOfCar);
        }
      } else if (speedOfCar > 60) {
        if (distanceToCurve < 100) {
          checkSpeedAndCurve(speedOfCar);
        }
      } else {
        if (distanceToCurve < 70) {
          checkSpeedAndCurve(speedOfCar);
        }
      }
    }
  }
}

double maxSpeedForCurve(double curveAngle) {
  // Calculate maximum speed
  double radius = 500.0 / curveAngle;
  double maxSpeed = sqrt(0.7 * 9.81 * radius);

  // Convert max speed from m/s to km/h
  return maxSpeed * 3.6; // 1 m/s = 3.6 km/h
}

void checkSpeedAndCurve(int speedOfCar) {
  var curve = curveWithLatlng[curveIndex].curve!;
  double calculatedMaxSpeed = maxSpeedForCurve(curve);

  print("Calculated speed=> ${calculatedMaxSpeed} + Curve Angle =>${curve}");

  if (calculatedMaxSpeed > 140) {
    maxSpeed = 140;
  } else if (calculatedMaxSpeed < 40) {
    maxSpeed = 40;
  } else {
    maxSpeed = (calculatedMaxSpeed ~/ 10) * 10;
  }

  if (calculatedMaxSpeed - speedOfCar > 0 &&
      warningColor != forColors.Colors.green) {
    warningColor = forColors.Colors.green;
  } else if (calculatedMaxSpeed - speedOfCar < 0 &&
      calculatedMaxSpeed - speedOfCar > -20 &&
      warningColor != forColors.Colors.orange) {
    if (warningColor != forColors.Colors.orange) {
      warningColor = forColors.Colors.orange;
    }

    FlutterBeep.beep();
  } else if (calculatedMaxSpeed - speedOfCar < 0 &&
      calculatedMaxSpeed - speedOfCar < -20) {
    if (warningColor != forColors.Colors.red) {
      warningColor = forColors.Colors.red;
    }
    FlutterBeep.beep();
  }
}
