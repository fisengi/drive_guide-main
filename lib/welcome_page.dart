import 'package:drive_guide/tracking.dart';
import 'package:flutter/material.dart';
import 'User/login_page.dart';
import 'User/signup_page.dart';

class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[500], // Professional dark grey
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Column(
                children: <Widget>[
                  Hero(
                      tag: 'logo',
                      child: Container(
                        child: Image.asset('images/logo_dg.png'),
                        height: 240,
                      )),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Get started by logging in or signing up.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => LoginPage()));
                },
                child: Text('Login'),
                style: ElevatedButton.styleFrom(
                  primary: Colors.blueGrey[800],
                  onPrimary: Colors.white,
                  minimumSize: Size(double.infinity, 50), // full-width buttons
                ),
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => SignUpPage()));
                },
                child: Text('Sign Up'),
                style: ElevatedButton.styleFrom(
                  primary: Colors.grey[700],
                  onPrimary: Colors.white,
                  minimumSize: Size(double.infinity, 50), // full-width buttons
                ),
              ),
              // SizedBox(height: 12),
              // ElevatedButton(
              //   onPressed: () {
              //     Navigator.of(context).push(
              //         MaterialPageRoute(builder: (context) => TrackingPage(user: null)));
              //   },
              //   child: Text('Continue without signing in'),
              //   style: ElevatedButton.styleFrom(
              //     primary: Colors.grey[700],
              //     onPrimary: Colors.white,
              //     minimumSize: Size(double.infinity, 50), // full-width buttons
              //   ),
              // ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
