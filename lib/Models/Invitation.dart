import 'package:cloud_firestore/cloud_firestore.dart';

class Invitation {
  String inviterId; // ID of the user who sends the invitation
  String inviteeId; // ID of the user who receives the invitation
  String inviterName; // Add name fields
  String inviteeName;
  String status; // Status of the invitation (pending, accepted, declined)
  Timestamp timestamp; // Firebase compatible timestamp

  Invitation({
    required this.inviterId,
    required this.inviteeId,
    required this.inviterName,
    required this.inviteeName,
    this.status = 'pending', // Default status is 'pending'
    required this.timestamp,
  });

  // Converts Invitation object to JSON format for Firebase
  Map<String, dynamic> toJson() => {
        'inviterId': inviterId,
        'inviteeId': inviteeId,
        'inviterName': inviterName,
        'inviteeName': inviteeName,
        'status': status,
        'timestamp': timestamp,
      };

  // Factory method to create an Invitation from a JSON object
  factory Invitation.fromJson(Map<String, dynamic> json) => Invitation(
        inviterId: json['inviterId'],
        inviteeId: json['inviteeId'],
        inviterName: json['inviterName'] ?? '', // Handle potential nulls
        inviteeName: json['inviteeName'] ?? '',
        status: json['status'],
        timestamp: json['timestamp'] as Timestamp,
      );
}
