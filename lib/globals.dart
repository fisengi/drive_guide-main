import 'dart:async';

import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:drive_guide/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart' as gmaps;

import 'dart:math';
//keep all member in the view, yavaşsa detaylı hızlıysa biraz daha detaysız göster. yakın curveleri tek circleda göster. curvelerin sıklığına göre derecesi değişiyor. curvelerde uyarı zamanı hıza göre değişecek

import 'dart:math';

import 'package:location/location.dart';

import 'constant.dart';
import 'group_view.dart';

import 'package:flutter/src/material/colors.dart' as forColors;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart' as latLngalo;
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math.dart';

import 'roadCurveAlgorithm.dart';

double speedSliderValue = 60;
int lastRouteIndex = 0;
