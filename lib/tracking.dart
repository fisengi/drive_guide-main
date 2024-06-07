import 'dart:async';

import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:drive_guide/Models/Account.dart';
import 'package:drive_guide/login_page.dart';
import 'package:drive_guide/profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart' as gmaps;

import 'dart:math';

import 'package:flutter_beep/flutter_beep.dart';
//keep all member in the view, yavaşsa detaylı hızlıysa biraz daha detaysız göster. yakın curveleri tek circleda göster. curvelerin sıklığına göre derecesi değişiyor. curvelerde uyarı zamanı hıza göre değişecek
// hızların sağ üste ekle hız sınırı viraj keskinliği rakamsal olarak Sesli uyarı. Redis grup view. Group sesli konuşma. Chat view

import 'constant.dart';
import 'group_view.dart';

import 'package:flutter/src/material/colors.dart' as forColors;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart' as latLngalo;
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'roadCurveAlgorithm.dart';
import 'simulationFunctions.dart';
import 'globals.dart';

class TrackingPage extends StatefulWidget {
  final User user;

  const TrackingPage({Key? key, required this.user}) : super(key: key);

  @override
  State<TrackingPage> createState() => TrackingPageState();
}

class TrackingPageState extends State<TrackingPage> {
  final Completer<GoogleMapController> _controller = Completer();

  User? user = FirebaseAuth.instance.currentUser;
  Account? account;

  bool showPlacesList = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const LatLng sourceLocation = LatLng(41.113953, 29.013857);
  static const LatLng groupLocationfirst = LatLng(41.108150, 29.020767);
  LocationData? currentLocation;
  Location location = Location();
  LatLng? destination = null;
  final Set<Marker> _markers = {};
  Location _locationController = new Location();
  LatLng? _currentP = null;

  Timer? _locationUpdateTimer;
  Timer? _groupLocationUpdateTimer;

  void _fetchAccount() async {
    // print("FETCHING ACCOUNT");
    if (user != null) {
      try {
        // print(user!.uid);
        var snapshot = await _firestore
            .collection('Account')
            .where('userId', isEqualTo: user!.uid)
            .get();

        // Check if an account is found
        if (snapshot.docs.isNotEmpty) {
          var doc = snapshot.docs.first;

          var accountData = doc.data();

          print(accountData);
          setState(() {
            //burada accounta eşitlenmeli
            account = Account.fromJson(accountData);
            print("Account synced: $account");
          });
        } else {
          print("No account found for the user ID.");
          setState(() {
            account = null; // Ensure account is cleared if no data is found
            print("Account set to null");
          });
        }
      } catch (e) {
        print("Failed to fetch account: $e");
        setState(() {
          account = null;
          print("Account set to null due to error");
        });
      }
    }
  }

  void _updateLocation() async {
    if (user != null) {
      try {
        Position position = await _determinePosition();
        GeoPoint geoPoint = GeoPoint(position.latitude, position.longitude);
        print(
            "User's location: Latitude: ${geoPoint.latitude}, Longitude: ${geoPoint.longitude}");

        var snapshot = await _firestore
            .collection('Account')
            .where('userId', isEqualTo: user!.uid)
            .get();

        if (snapshot.docs.isNotEmpty) {
          var doc = snapshot.docs.first;
          await _firestore
              .collection('Account')
              .doc(doc.id)
              .update({'location': geoPoint});
          print("Location updated in Firestore");
        }
      } catch (e) {
        print("Failed to update location: $e");
      }
    }
  }

  void _updateGroupLocations() async {
    if (widget.user != null) {
      var currentUserSnapshot = await _firestore
          .collection('Account')
          .where('userId', isEqualTo: widget.user.uid)
          .get();

      if (currentUserSnapshot.docs.isNotEmpty) {
        var currentUserDoc = currentUserSnapshot.docs.first;

        List<dynamic> groupWithList = currentUserDoc['groupWith'];

        Set<Marker> groupMarkers = {};
        groupMarkers.add(Marker(
          markerId: MarkerId('currentUser'),
          position: LatLng(currentUserDoc['location'].latitude,
              currentUserDoc['location'].longitude),
          icon: groupMemberIcon,
        ));

        for (var groupMember in groupWithList) {
          var groupMemberSnapshot = await _firestore
              .collection('Account')
              .where('userId', isEqualTo: groupMember['userId'])
              .get();

          if (groupMemberSnapshot.docs.isNotEmpty) {
            var groupMemberDoc = groupMemberSnapshot.docs.first;
            var groupMemberLocation = groupMemberDoc['location'];

            groupMarkers.add(Marker(
              markerId: MarkerId(groupMember['userId']),
              position: LatLng(
                  groupMemberLocation.latitude, groupMemberLocation.longitude),
              icon: groupMemberIcon,
            ));
          }
        }

        setState(() {
          _markers.clear();
          _markers.addAll(groupMarkers);
        });

        if (groupViewMode) {
          // Update the camera view to show all markers
          final GoogleMapController controller = await _controller.future;
          LatLngBounds bounds = _createBoundsForMarkers(groupMarkers);
          CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 50);
          controller.animateCamera(cameraUpdate);
        }
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _updateLocation();
    });
  }

  void _startGroupLocationUpdates() {
    _groupLocationUpdateTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _updateGroupLocations();
    });
  }

  void addCustomIcon() {
    BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(), "images/DriveGuide.png")
        .then((icon) {
      setState(() {
        carIcon = icon;
      });
    });
  }

  void _initCarMarker() {
    addCustomIcon();
    carMarker = Marker(
      markerId: MarkerId("car"),
      position: sourceLocation,
      icon: carIcon,
    );
  }

  void _initGroupView(BuildContext context) async {
    try {
      // Fetch both user's locations from Firestore
      User? currentUser = widget.user;
      if (currentUser != null) {
        var currentUserSnapshot = await _firestore
            .collection('Account')
            .where('userId', isEqualTo: currentUser.uid)
            .get();

        if (currentUserSnapshot.docs.isNotEmpty) {
          var currentUserDoc = currentUserSnapshot.docs.first;

          List<dynamic> groupWithList = currentUserDoc['groupWith'];

          Set<Marker> groupMarkers = {};
          groupMarkers.add(Marker(
            markerId: MarkerId('currentUser'),
            position: LatLng(currentUserDoc['location'].latitude,
                currentUserDoc['location'].longitude),
            icon: groupMemberIcon, //değiştir burayı
          ));

          for (var groupMember in groupWithList) {
            groupMarkers.add(Marker(
              markerId: MarkerId(groupMember['userId']),
              position: LatLng(groupMember['location'].latitude,
                  groupMember['location'].longitude),
              icon: groupMemberIcon,
            ));
          }

          setState(() {
            _markers.addAll(groupMarkers);
            groupViewMode = true;
          });

          // Update the camera view to show all markers
          final GoogleMapController controller = await _controller.future;
          LatLngBounds bounds = _createBoundsForMarkers(groupMarkers);
          CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 50);
          controller.animateCamera(cameraUpdate);
        }
      }
    } catch (e) {
      print("Failed to initialize group view: $e");
    }
  }

  LatLngBounds _createBoundsForMarkers(Set<Marker> markers) {
    double southWestLat = markers.first.position.latitude;
    double southWestLng = markers.first.position.longitude;
    double northEastLat = markers.first.position.latitude;
    double northEastLng = markers.first.position.longitude;

    markers.forEach((marker) {
      if (marker.position.latitude < southWestLat) {
        southWestLat = marker.position.latitude;
      }
      if (marker.position.longitude < southWestLng) {
        southWestLng = marker.position.longitude;
      }
      if (marker.position.latitude > northEastLat) {
        northEastLat = marker.position.latitude;
      }
      if (marker.position.longitude > northEastLng) {
        northEastLng = marker.position.longitude;
      }
    });

    return LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
  }

  void stopSimulation() async {
    timer?.cancel(); // Stop the timer that updates the car's position
    print("Simulation stopped");

    // Remove the car marker
    setState(() {
      carMarker = null;
      simulationMode = false;
      polylineCoordinates.clear();
    });

    // Optionally reset the camera to a default position or zoom out
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target:
            sourceLocation, // Adjust this as needed to your "home" or default view
        zoom: 15, // Default zoom level after stopping the simulation
        tilt: 0,
        bearing: 0,
      ),
    ));

    // Reset simulation mode if applicable
  }

  void pauseSimulation() {
    timer?.cancel();
    setState(() {
      isStopped = true;
    });
    print("Simulation paused");
  }

  Future<void> startSimulation() async {
    _initCarMarker();

    final GoogleMapController controller = await _controller.future;
    await controller?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: sourceLocation,
        bearing:
            270.0, //calculate bearing, interpolated points, köksalla konuş bunu
        tilt: 30.0,
        zoom: 19.0,
      ),
    ));

    await Future.delayed(const Duration(seconds: 5));
    lastRouteIndex = 0;
    distanceToCurve = double.infinity;
    curveIndex = 0;
    // Resetting and starting the simulation with the initial speed.
    startOrRestartTimer(lastRouteIndex, distanceToCurve, curveIndex);
  }

  void startOrRestartTimer(
      int startIndex, double distanceToCurve, int curveIndexx) {
    timer?.cancel(); // Cancel any existing timer.
    // Reset the route index.

    // Calculate the time interval based on the current speed slider value.
    int timeForSpeed = 150 - speedSliderValue.round();
    print("Timer interval set to: $timeForSpeed milliseconds");

    // Start a new timer with the newly calculated interval.
    timer = Timer.periodic(Duration(milliseconds: timeForSpeed), (Timer t) {
      if (startIndex < simulationCoordinates.length &&
          simulationMode == true &&
          isStopped == false) {
        if (curveWithLatlng.isNotEmpty) {
          speedControl(
              simulationCoordinates[startIndex], speedSliderValue.round());
        }

        updatePosition(simulationCoordinates[startIndex]);
        lastRouteIndex = startIndex; // Update the last position of routeIndex
        startIndex++;
      } else {
        t.cancel();
        print("Reached destination");
      }
    });
  }

// when speedSliderValue changes.
  void onSpeedSliderValueChanged(double value) {
    startOrRestartTimer(lastRouteIndex + 1, distanceToCurve,
        curveIndex); // Restart the timer with new interval.
  }

  void updatePosition(LatLng newPosition) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(newPosition));
    setState(() {
      carMarker = Marker(
        markerId: MarkerId("car"),
        position: newPosition,
        icon: carIcon,
      );
    });
  }

  void _initSimulation(BuildContext context) async {
    Navigator.pop(context);
    _initCarMarker();
    setState(() {
      simulationMode = true; // Toggle simulation mode
    });
  }

  void _groupCarMarker() {
    addCustomIconGroup();
    groupMember = Marker(
      markerId: MarkerId("groupMember"),
      position: groupLocationfirst,
      icon: groupMemberIcon,
    );
  }

  void addCustomIconGroup() {
    BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(), "images/Group_Member.png")
        .then((icon) {
      setState(() {
        groupMemberIcon = icon;
      });
    });
  }

  TextEditingController searchController = TextEditingController();
  List<gmaps.Prediction> places = [];
  final gmaps.GoogleMapsPlaces _places =
      gmaps.GoogleMapsPlaces(apiKey: google_api_key);

  bool isSearching = false;

  @override
  void dispose() {
    timer?.cancel();
    _locationUpdateTimer?.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      if (searchController.text.isNotEmpty) {
        _searchPlace(searchController.text);
        showPlacesList = true;
        isSearching = true; // We are now searching
      } else {
        places = [];
        showPlacesList = false;
        isSearching = false; // Search has been cleared
      }
    });
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
                  places[index].description ?? "No description available",
                  style: TextStyle(color: forColors.Colors.white),
                ),
                onTap: () async {
                  final gmaps.PlacesDetailsResponse detail =
                      await _places.getDetailsByPlaceId(places[index].placeId!);
                  final lat = detail.result.geometry!.location.lat;
                  final lng = detail.result.geometry!.location.lng;

                  setState(() {
                    destination = LatLng(lat, lng);
                    showPlacesList = false;
                    isSearching = false;
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
                    print("Can Not Draw Polyline");
                  }
                },
              );
            },
          );
  }

  Widget buildSpeedWarner() {
    return Container(
      width: 100, // Set the width of the SizedBox
      height: 100,
      color: forColors.Colors.red, // Set the height of the SizedBox
      child: Center(
        // Display the number
        child: Text(
          '$speedSliderValue',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: forColors.Colors.black),
        ),
      ),
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
          print(_currentP);
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

  void groupViewOpened() async {
    final GoogleMapController controller = await _controller.future;
    animateCameraToMidpoint(controller, groupMember!.position, sourceLocation);
  }

  static LatLng calculateMidpoint(LatLng point1, LatLng point2) {
    double latitudeMid = (point1.latitude + point2.latitude) / 2;
    double longitudeMid = (point1.longitude + point2.longitude) / 2;
    return LatLng(latitudeMid, longitudeMid);
  }

  // Function to estimate zoom level based on the distance
  static double calculateZoom(LatLng point1, LatLng point2) {
    double distance = Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );

    print("Distance => $distance");

    // Simplistic way to calculate zoom
    double zoom = max(0, 20 - log(distance + 1) / log(3.20));
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
        zoom: zoom,
      ),
    ));
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    getLocationUpdates();
    // _startLocationUpdates();
    // _startGroupLocationUpdates();
    searchController.addListener(_onSearchChanged);

    _initCarMarker();
    _groupCarMarker();

    _fetchAccount();
    _updateLocation();
  }

  @override
  Widget build(BuildContext context) {
    _buildPlacesList();
    buildSpeedWarner();

    if (destination != null) {
      curves =
          calculateTurnAngle(polylineCoordinates, redcircles, orangecircles);

      loadLatlngToCurves(polylineCoordinates, curves);

      allCircles = calculateTurnAngleZoomOut(polylineCoordinates);
    }

    Set<Circle> circlesss = {
      for (var angle in allCircles)
        if (angle.color == 'red')
          Circle(
            circleId: CircleId(angle.coordination.toString()),
            center: angle.coordination,
            radius: 15 * angle.circleSize.toDouble(),
            fillColor: forColors.Colors.red.withOpacity(0.5),
            strokeWidth: 1,
            strokeColor: forColors.Colors.red,
          )
        else
          Circle(
            circleId: CircleId(angle.coordination.toString()),
            center: angle.coordination,
            radius: 10 * angle.circleSize.toDouble(),
            fillColor: forColors.Colors.orange.withOpacity(0.5),
            strokeWidth: 1,
            strokeColor: forColors.Colors.orange,
          )

      // allCircles = calculateTurnAngleZoomOut(polylineCoordinates);
    };
    return Scaffold(
      appBar: simulationMode && destination != null
          ? AppBar(
              title: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: warningColor,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Text(
                  '$speedSliderValue',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: forColors.Colors.white),
                ),
              ),
            ))
          : AppBar(
              actions: [
                  Switch(
                    value: groupViewMode,
                    onChanged: (value) {
                      setState(() {
                        groupViewMode = value;
                      });
                      if (groupViewMode) {
                        _initGroupView(context);
                      } else {
                        setState(() {
                          _markers.clear();
                        });
                      }
                    },
                  )
                ],
              title: Row(
                children: [
                  Expanded(
                      child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                        hintText: "Search for places...",
                        border: InputBorder.none,
                        suffixIcon: Icon(Icons.search)),
                  )),
                ],
              )),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(account?.name ?? "User Name"),
              accountEmail: Text(account?.email ?? "user@example.com"),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  user?.email?.toUpperCase() ?? "U",
                  style: TextStyle(fontSize: 40.0),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.group),
              title: Text("${account?.userId}"),
              onTap: () {
                groupViewMode = true;
                _initGroupView(context);
              }
              // Navigate to the Group View page
              // Navigator.of(context)
              //     .push(MaterialPageRoute(builder: (context) => GroupView()));
              ,
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                // Handle the profile tap
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ProfilePage()));
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Invitations'),
              onTap: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (context) => GroupView()));
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Simulation'),
              onTap: () => _initSimulation(context),
            ),
          ],
        ),
      ),
      body: _currentP == null
          ? Center(
              child: Text("loading"),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: sourceLocation, zoom: 15),
                  myLocationEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  circles: circlesss,
                  polylines: {
                    if (polylineCoordinates.isNotEmpty)
                      Polyline(
                        polylineId: PolylineId("polyline"),
                        points: polylineCoordinates,
                        color: forColors.Colors.blue,
                        width: 6,
                      ),
                  },
                  markers: {
                    if (simulationMode == true) carMarker!,
                    if (groupViewMode == true) ..._markers,
                    Marker(
                        markerId: MarkerId("source"),
                        position: sourceLocation,
                        icon: carIcon),
                    if (destination != null)
                      Marker(
                        markerId: MarkerId("destination"),
                        position: LatLng(
                            destination!.latitude, destination!.longitude),
                      ),
                  },
                ),
                if (isSearching) ...[
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Container(
                      color: forColors.Colors.black.withOpacity(0.5),
                    ),
                  ),
                  Container(
                    child: Column(
                      children: [
                        _buildPlacesList(),
                      ],
                    ),
                  ),
                ],
                if (groupViewMode == true)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Offstage(
                      offstage: isSearching,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
                        decoration: BoxDecoration(
                            color: forColors.Colors.white,
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(10))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _buildActionButton(
                                context, Icons.camera_indoor, 'Open group view',
                                () {
                              if (groupView == "closed") {
                                groupViewOpened();
                              } else {}
                            }),
                            _buildActionButton(context, Icons.camera_outdoor,
                                'Close group view', () {}),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (simulationMode == true)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Offstage(
                      offstage: isSearching,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
                        decoration: BoxDecoration(
                            color: forColors.Colors.white,
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(10))),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SpeedSliderWidget(
                              onValueChanged: onSpeedSliderValueChanged,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: <Widget>[
                                _buildActionButton(context, Icons.play_arrow,
                                    'Start Simulation', () {
                                  if (destination != null) {
                                    loadRouteSimulation(polylineCoordinates);
                                    startSimulation();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'To start simulation you need to select a destination'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }),
                                _buildActionButton(
                                    context, Icons.pause, 'Pause Simulation',
                                    () {
                                  pauseSimulation(); // You'll need to implement this
                                }),
                                _buildActionButton(
                                    context, Icons.stop, 'Stop Simulation', () {
                                  stopSimulation(); // You'll need to implement this
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
              ],
            ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String tooltip,
      VoidCallback onPressed) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      child: Icon(icon),
      backgroundColor: forColors.Colors.deepPurple,
      foregroundColor: forColors.Colors.white,
      heroTag: null,
    );
  }
}
