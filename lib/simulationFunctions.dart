import 'dart:async';
import 'dart:math';

import 'package:drive_guide/roadCurveAlgorithm.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';

import 'globals.dart';
import 'tracking.dart';

List<LatLng> interpolatePoints(
    LatLng start, LatLng end, double intervalMeters) {
  List<LatLng> points = [];
  // Calculate the distance between the start and end points
  double distance = Geolocator.distanceBetween(
      start.latitude, start.longitude, end.latitude, end.longitude);

  // Calculate the number of intervals
  int numPoints = (distance / intervalMeters).floor();

  // Add the initial point
  points.add(start);

  for (int i = 1; i <= numPoints; i++) {
    double fraction = (intervalMeters * i) / distance;

    // Calculate interpolated latitude and longitude
    double interpolatedLatitude =
        start.latitude + (end.latitude - start.latitude) * fraction;
    double interpolatedLongitude =
        start.longitude + (end.longitude - start.longitude) * fraction;

    // Add the new interpolated point to the list
    points.add(LatLng(interpolatedLatitude, interpolatedLongitude));
  }

  // Add the final point
  points.add(end);

  return points;
}

class SpeedSliderWidget extends StatefulWidget {
  final Function(double) onValueChanged;
  const SpeedSliderWidget({Key? key, required this.onValueChanged})
      : super(key: key);

  @override
  State<SpeedSliderWidget> createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<SpeedSliderWidget> {
  int divisons = 20;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: () {
              setState(() {
                speedSliderValue = (speedSliderValue - 10).clamp(0, 100);
                print(speedSliderValue);
              });
              widget.onValueChanged(speedSliderValue);
            },
          ),
          Expanded(
            child: Slider(
              value: speedSliderValue,
              min: 0,
              max: 140,
              divisions: 14,
              label: speedSliderValue.round().toString(),
              onChanged: (double value) {
                setState(() {
                  speedSliderValue = value;
                });
                widget.onValueChanged(speedSliderValue);
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              setState(() {
                speedSliderValue = (speedSliderValue + 10).clamp(0, 100);
              });
              widget.onValueChanged(speedSliderValue);
            },
          ),
        ],
      ),
    );
  }
}
