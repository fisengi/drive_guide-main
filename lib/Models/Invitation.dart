import 'package:cloud_firestore/cloud_firestore.dart';

class Invitation {
  final String inviterId;
  final String inviteeId;
  final String status;
  final Timestamp timestamp;

  Invitation({
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    required this.timestamp,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      inviterId: json['inviterId'],
      inviteeId: json['inviteeId'],
      status: json['status'],
      timestamp: json['timestamp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inviterId': inviterId,
      'inviteeId': inviteeId,
      'status': status,
      'timestamp': timestamp,
    };
  }
}
