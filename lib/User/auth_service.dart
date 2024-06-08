import 'package:drive_guide/tracking.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  Future<void> signInWithGoogle(
      BuildContext context, Function(bool) setLoading) async {
    setLoading(true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
        if (userCredential.user != null) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) => TrackingPage(
                    user: userCredential.user!,
                  )));
        } else {
          print("Login failed: User not found in Firebase Auth.");
        }
      } else {
        print("Login aborted by the user.");
      }
    } catch (e) {
      print("Error signing in with Google: $e");
    }
    setLoading(false);
  }
}
