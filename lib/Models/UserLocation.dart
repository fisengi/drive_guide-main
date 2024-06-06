import 'package:cloud_firestore/cloud_firestore.dart';

class UserLocation {
  final String userId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  UserLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      userId: json['userId'],
      latitude: double.parse(json['latitude']),
      longitude: double.parse(json['longitude']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
