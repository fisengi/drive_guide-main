import 'dart:async';
import 'package:flutter/src/material/colors.dart' as forColors;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Services/roadCurveAlgorithm.dart';

//SIMULATION VARIABLES
double speedSliderValue = 60;
int lastRouteIndex = 0;
bool simulationMode = false;
bool isStopped = false;
int simulationSpeed = 60;
List<LatLng> simulationCoordinates = [];

//GROUP VARIABLES
bool groupViewMode = false;
String groupView = 'closed';
BitmapDescriptor carIcon = BitmapDescriptor.defaultMarker;
BitmapDescriptor groupMemberIcon = BitmapDescriptor.defaultMarker;
Marker? carMarker;
Marker? groupMember;
List<LatLng> groupPolyLineCoordinates = [];

//SPEED WARNING
double distanceToCurve = double.infinity;
int curveIndex = 0;
Color warningColor = forColors.Colors.green;
Timer? timer;
List<curveAndLatlng> curveWithLatlng = [];
List<double> curves = [];
List<LatLng> redcircles = [];
List<LatLng> orangecircles = [];
List<ZoomOutTurnAngle> allCircles = [];
List<LatLng> polylineCoordinates = [];

class kullanici {
  int? speed;
  LatLng? coordination;
}

class curveAndLatlng {
  double? curve;
  LatLng? coordination;

  curveAndLatlng(double curv, LatLng polylineCoordinat) {
    curve = curv;
    coordination = polylineCoordinat;
  }
}
