import 'dart:async';
import 'dart:convert';
import 'package:drive_guide/Config/firebase_options.dart';
import 'package:drive_guide/User/login_page.dart';
import 'package:drive_guide/tracking.dart';
import 'package:drive_guide/welcome_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';

import 'package:dio/dio.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveGuide',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.data != null) {
              return TrackingPage(
                  user:
                      snapshot.data!); // User is logged in, go to tracking page
            }

            return WelcomePage(); // User is not logged in, show login page
          }
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(), // Loading state
            ),
          );
        },
      ),
    );
  }
}
