import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:drive_guide/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart' as gmaps;

import 'dart:math';

import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'constant.dart';
import 'group_view.dart';
import 'package:flutter/src/material/colors.dart' as forColors;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart' as latLngalo;
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter/src/material/colors.dart';

double findAngle(LatLng first, LatLng second, LatLng third) {
  // Calculate the sides of the triangle (distances between the points)
  var p = 0.017453292519943295; // Math.PI / 180
  var c_new = cos;
  var a_new = 0.5 -
      c_new((third.latitude - first.latitude) * p) / 2 +
      c_new(first.latitude * p) *
          c_new(third.latitude * p) *
          (1 - c_new((third.longitude - first.longitude) * p)) /
          2;
  var deneme = 12742 * asin(sqrt(a_new)) * 1000; // 2 * R; R = 6371 km

  double a = Geolocator.distanceBetween(
      second.latitude, second.longitude, third.latitude, third.longitude); // BC
  double b = Geolocator.distanceBetween(
      first.latitude, first.longitude, third.latitude, third.longitude); // AC
  double c = Geolocator.distanceBetween(
      first.latitude, first.longitude, second.latitude, second.longitude); // AB

  // Apply the spherical law of cosines to find the angle at A
  double angleA =
      acos(((deneme * deneme) + (c * c) - (a * a)) / (2 * deneme * c));
  print("Distance ${a} ${b} =? ${deneme} ${c} Angle ${angleA * (180.0 / pi)}");
  // Convert the angle from radians to degrees
  return angleA * (180.0 / pi);
}

class CalculationResult {
  List<double> curves;
  List<List<LatLng>> redPolylineCoordinates;
  List<List<LatLng>> bluePolylineCoordinates;

  CalculationResult(
      this.curves, this.redPolylineCoordinates, this.bluePolylineCoordinates);
}

calculateAngle(
  List<LatLng> polylinePoints,
  List<double> curves,
) {
  double curve = 0.0;
  List<List<LatLng>> bluePolylineCoordinates = [];
  List<List<LatLng>> redPolylineCoordinates = [];

  curves.clear();
  redPolylineCoordinates.clear();
  for (int i = 0; i < polylinePoints.length - 2; i++) {
    curve = findAngle(
        polylinePoints[i], polylinePoints[i + 1], polylinePoints[i + 2]);
    print("Curve ${i} ${curve}");
    curves.add(curve);
    if (curve >= 10) {
      redPolylineCoordinates.add([polylinePoints[i], polylinePoints[i + 1]]);
    } else {
      bluePolylineCoordinates.add([polylinePoints[i], polylinePoints[i + 1]]);
    }

    curve = 0.0;
  }
  return CalculationResult(
      curves, redPolylineCoordinates, bluePolylineCoordinates);
}

double calculatePolylineLength(List<LatLng> polylinePoints) {
  double totalDistance = 0.0;

  // Iterate through all polyline points
  for (int i = 0; i < polylinePoints.length - 1; i++) {
    // Current point
    final start = polylinePoints[i];
    // Next point
    final end = polylinePoints[i + 1];

    // Calculate the distance between the current point and the next point
    double distance = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    // print("Mesafe ${i} ${distance}");

    // Add the distance to the total distance
    totalDistance += distance;
  }

  return totalDistance; // Total distance in meters
}

class GroupTrackingPage extends StatefulWidget {
  final String currentUserID;
  final String invitedUserID;

  const GroupTrackingPage({
    Key? key,
    required this.currentUserID,
    required this.invitedUserID,
  }) : super(key: key);

  @override
  State<GroupTrackingPage> createState() => GroupTrackingPageState();
}

class GroupTrackingPageState extends State<GroupTrackingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Completer<GoogleMapController> _controller = Completer();

  static const LatLng sourceLocation = LatLng(41.113953, 29.013857);

  LocationData? currentLocation;
  Location location = Location();

  LatLng? destination = null; //static const yok dododa

  List<LatLng> polylineCoordinates = [];
  List<List<LatLng>> redPolylineCoordinates = [];
  List<List<LatLng>> bluePolylineCoordinates = [];
  BitmapDescriptor? _customMarkerIcon;
  List<double> curves = [];

  Location _locationController = new Location();

  LatLng? _currentP = null;

  bool showPlacesList = false;

  TextEditingController searchController = TextEditingController();
  List<gmaps.Prediction> places = [];
  final gmaps.GoogleMapsPlaces _places =
      gmaps.GoogleMapsPlaces(apiKey: google_api_key);

  Map<MarkerId, Marker> _markers = {};
  int _currentPolylineIndex = 0;
  double _speed = 1.0; // Default speed

  double _speedInKmPerHour = 60.0; // Initial speed
  User? user = FirebaseAuth.instance.currentUser;

  Location _location = new Location();

  void _initLocationService() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _location.onLocationChanged.listen((LocationData currentLocation) {
      // Update your location data to Firestore
      _updateUserLocation(currentLocation);
    });
  }

  void _updateUserLocation(LocationData currentLocation) {
    var locationData = {
      'latitude': currentLocation.latitude.toString(),
      'longitude': currentLocation.longitude.toString(),
      'timestamp':
          FieldValue.serverTimestamp(), // Ensure time is synced with the server
    };

    _firestore
        .collection('locations')
        .doc(widget.currentUserID)
        .set(locationData, SetOptions(merge: true))
        .then((_) => print("Location updated in Firestore"))
        .catchError((error) => print("Failed to update location: $error"));
  }

  // Convert speed to meters per tick (assuming 1 tick per second for simplicity)
  double get _speedInMetersPerTick {
    return (_speedInKmPerHour * 1000) / 3600; // Convert km/h to m/s
  }

  void _adjustSpeed(bool increase) {
    setState(() {
      _speedInKmPerHour += (increase ? 10 : -10);
      _speedInKmPerHour =
          _speedInKmPerHour.clamp(10, 120); // Limit speed to a realistic range
    });
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    if (searchController.text.isNotEmpty) {
      _searchPlace(searchController.text);
      showPlacesList = true;
    } else {
      setState(() {
        places = [];
        showPlacesList = false;
      });
    }
  }

  // Interpolates points between two given points
  List<LatLng> interpolatePoints(LatLng start, LatLng end, double interval) {
    var distance = Geolocator.distanceBetween(
        start.latitude, start.longitude, end.latitude, end.longitude);
    var fraction = interval / distance;

    List<LatLng> segmentPoints = [];
    for (double step = 0; step < 1; step += fraction) {
      var lat = start.latitude + (end.latitude - start.latitude) * step;
      var lng = start.longitude + (end.longitude - start.longitude) * step;
      segmentPoints.add(LatLng(lat, lng));
    }
    return segmentPoints;
  }

  // Generates a smooth path by interpolating points between each pair of original path points
  List<LatLng> generateSmoothPath(
      List<LatLng> polylineCoordinates, double interval) {
    List<LatLng> smoothPath = [];
    for (int i = 0; i < polylineCoordinates.length - 1; i++) {
      var start = polylineCoordinates[i];
      var end = polylineCoordinates[i + 1];
      var segmentPoints = interpolatePoints(start, end, interval);
      smoothPath.addAll(segmentPoints);
    }
    smoothPath.add(polylineCoordinates.last);
    return smoothPath;
  }

  Widget _buildPlacesList() {
    if (!showPlacesList) {
      return SizedBox.shrink();
    }
    return places.isEmpty
        ? const Center(child: Text("No results"))
        : ListView.builder(
            shrinkWrap: true,
            itemCount: places.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(
                    places[index].description ?? "No description available"),
                onTap: () async {
                  final gmaps.PlacesDetailsResponse detail =
                      await _places.getDetailsByPlaceId(places[index].placeId!);
                  final lat = detail.result.geometry!.location.lat;
                  final lng = detail.result.geometry!.location.lng;

                  setState(() {
                    destination = LatLng(lat, lng);
                    showPlacesList = false;
                  });

                  final GoogleMapController controller =
                      await _controller.future;
                  controller.animateCamera(
                      CameraUpdate.newLatLngZoom(destination!, 15));

                  polylineCoordinates.clear();
                  if (currentLocation != null) {
                    _getPolyline(currentLocation!.latitude!,
                        currentLocation!.longitude!, lat, lng);
                  } else {
                    print("polyline çizemiyyor");
                  }
                },
              );
            },
          );
  }

  void _searchPlace(String input) async {
    final result = await _places.autocomplete(input,
        components: [gmaps.Component(gmaps.Component.country, "tr")]);
    if (result.isOkay) {
      setState(() {
        places = result.predictions;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    final _locationData = await location.getLocation();
    setState(() {
      currentLocation = _locationData;
    });
  }

  Future<void> getLocationUpdates() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await _locationController.serviceEnabled();
    if (_serviceEnabled) {
      _serviceEnabled = await _locationController.requestService();
    } else {
      return;
    }

    _permissionGranted = await _locationController.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _locationController.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationController.onLocationChanged
        .listen((LocationData currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        setState(() {
          _currentP =
              LatLng(currentLocation.latitude!, currentLocation.longitude!);
          _updateMapCameraPosition();
          print(_currentP);
          print("köksal");
        });
      }
    });
  }

  void _getPolyline(
      double startLat, double startLng, double destLat, double destLng) async {
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      google_api_key,
      PointLatLng(startLat, startLng),
      PointLatLng(destLat, destLng),
    );

    if (result.points.isNotEmpty) {
      polylineCoordinates.clear();
      result.points.forEach((PointLatLng point) =>
          polylineCoordinates.add(LatLng(point.latitude, point.longitude)));

      setState(() {});
    }
  }

  Future<void> _updateMarkerAndCameraPosition() async {
    final GoogleMapController controller = await _controller.future;
    if (_currentP != null) {
      controller.animateCamera(CameraUpdate.newLatLng(_currentP!));
      final marker = Marker(
        markerId: MarkerId("simulatedPosition"),
        position: _currentP!,
        icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
      );

      setState(() {
        _markers[MarkerId("simulatedPosition")] = marker;
      });
    }
  }

  Future<void> _updateMapCameraPosition() async {
    final GoogleMapController controller = await _controller.future;
    if (_currentP != null) {
      controller.animateCamera(CameraUpdate.newLatLng(_currentP!));

      final marker = Marker(
        markerId: MarkerId("currentSimulatedLocation"),
        position: _currentP!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );

      setState(() {
        // Add or update the marker in the map
        _markers[MarkerId("currentSimulatedLocation")] = marker;
      });
    }
  }

  void _resetMapToInitialState() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: sourceLocation, zoom: 15),
      ),
    );
  }

  // Method to build markers for the curves
  Set<Marker> _buildCurveMarkers() {
    Set<Marker> curveMarkers = {};
    if (polylineCoordinates.isNotEmpty) {
      for (int i = 0; i < polylineCoordinates.length; i++) {
        if (i >= 1 && i <= polylineCoordinates.length - 2) {
          curveMarkers.add(
            Marker(
              markerId: MarkerId("redpoly${i}"),
              position: polylineCoordinates[i],
              infoWindow: InfoWindow(
                title: "Curve ${i} ${curves[i - 1]}",
              ),
            ),
          );
        } else {
          curveMarkers.add(
            Marker(
              markerId: MarkerId("redpoly${i}"),
              position: polylineCoordinates[i],
              infoWindow: InfoWindow(title: "No Curve"),
            ),
          );
        }
      }
    }
    return curveMarkers;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMapAndLocation();
    });
    _listenForUserLocations();
    searchController.addListener(_onSearchChanged);
  }

  void _initMapAndLocation() {
    _getCurrentLocation();
    getLocationUpdates();
  }

  void _listenForUserLocations() {
    // Listen for current user location updates
    _firestore
        .collection('locations')
        .doc(widget.currentUserID)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          _updateLocationOnMap(
              snapshot.data() as Map<String, dynamic>, widget.currentUserID);
        }
      },
      onError: (e) => print("Error fetching location for current user: $e"),
    );

    // Listen for invited user location updates
    _firestore
        .collection('locations')
        .doc(widget.invitedUserID)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          _updateLocationOnMap(
              snapshot.data() as Map<String, dynamic>, widget.invitedUserID);
        }
      },
      onError: (e) => print("Error fetching location for invited user: $e"),
    );
  }

  void _updateLocationOnMap(Map<String, dynamic> locationData, String userId) {
    LatLng position = LatLng(
      double.parse(locationData['latitude']),
      double.parse(locationData['longitude']),
    );

    setState(() {
      _markers[MarkerId(userId)] = Marker(
        markerId: MarkerId(userId),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            userId == widget.currentUserID
                ? BitmapDescriptor.hueBlue
                : BitmapDescriptor.hueRed),
      );
    });

    if (_controller.isCompleted) {
      _controller.future.then((controller) => controller.animateCamera(
          CameraUpdate.newLatLngBounds(
              _calculateBounds(_markers.values), 100)));
    }
  }

  LatLngBounds _calculateBounds(Iterable<Marker> markers) {
    return LatLngBounds(
      southwest: LatLng(markers.map((m) => m.position.latitude).reduce(min),
          markers.map((m) => m.position.longitude).reduce(min)),
      northeast: LatLng(markers.map((m) => m.position.latitude).reduce(max),
          markers.map((m) => m.position.longitude).reduce(max)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _buildPlacesList();

    if (destination != null) {
      // double polylineLength = calculatePolylineLength(polylineCoordinates);
      // double maxCurvature = calculateTotalCurvature(polylineCoordinates,
      //     sourceLocation, destination!, redPolylineCoordinates);
      // print("Polyline Length: ${polylineLength.toStringAsFixed(2)} meters");
      // print("Curvature ${maxCurvature}");
      // double curveDeneme = findAngle(LatLng(41.11384, 29.0141),
      //     LatLng(41.11351, 29.01383), LatLng(41.11333, 29.01349));
      // print("Curve DOğru mu ${curveDeneme}");

      CalculationResult result = calculateAngle(polylineCoordinates, curves);
      curves = result.curves;
      redPolylineCoordinates = result.redPolylineCoordinates;
      bluePolylineCoordinates = result.bluePolylineCoordinates;
      print(
          "RED POLYLINES length = ${redPolylineCoordinates.length}${redPolylineCoordinates}");
    }
    return Scaffold(
      appBar: AppBar(
          title: Row(
        children: [
          Expanded(
              child: TextField(
            controller: searchController,
            decoration: InputDecoration(
                hintText: "Search for places...",
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      searchController.clear();
                      places.clear();
                      showPlacesList = false;
                    });
                  },
                )),
          )),
          IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: Icon(Icons.menu)),
        ],
      )),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? "User Name"),
              accountEmail: Text(user?.email ?? "user@example.com"),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  user?.email?.toUpperCase() ??
                      "U", // For simplicity, just the first letter of the name
                  style: TextStyle(fontSize: 40.0),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.group),
              title: Text('Group View'),
              onTap: () {
                // Navigate to the Group View page
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (context) => GroupView()));
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                // Handle the profile tap
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () {
                FirebaseAuth.instance.signOut().then((_) {
                  // This ensures that the navigation is pushed after the build is complete
                  Future.delayed(Duration.zero, () {
                    Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => LoginPage()));
                  });
                });
              },
            ),
          ],
        ),
      ),
      body: _currentP != null
          ? Center(
              child: Text("loading"),
            )
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition:
                        CameraPosition(target: LatLng(0, 0), zoom: 10),
                    myLocationEnabled: true,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                      _resetMapToInitialState();
                    },
                    polylines: {
                      if (redPolylineCoordinates.isNotEmpty)
                        for (int i = 0; i < redPolylineCoordinates.length; i++)
                          Polyline(
                            polylineId: PolylineId("red${i}"),
                            points: redPolylineCoordinates[i],
                            color: forColors.Colors.red,
                            width: 6,
                          ),
                      if (bluePolylineCoordinates.isNotEmpty)
                        for (int i = 0; i < bluePolylineCoordinates.length; i++)
                          Polyline(
                            polylineId: PolylineId("blue${i}"),
                            points: bluePolylineCoordinates[i],
                            color: forColors.Colors.blue,
                            width: 6,
                          ),
                      // Polyline(
                      //     polylineId: PolylineId("route"),
                      //     points: polylineCoordinates,
                      //     color: forColors.Colors.deepOrange,
                      //     width: 6)
                    },
                    markers: Set.of(_markers.values),
                  ),
                ),
                _buildPlacesList(),
              ],
            ),
    );
  }
}
