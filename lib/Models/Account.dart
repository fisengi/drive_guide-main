import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  String? email;
  String? userId;
  GeoPoint? location;
  List<GroupMember>? groupWith;
  String? name;
  String? profilePicture;

  Account({
    this.email,
    this.userId,
    this.location,
    this.groupWith,
    this.name,
    this.profilePicture,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'userId': userId,
      'location': location,
      'groupWith':
          groupWith?.map((groupMember) => groupMember.toJson()).toList(),
      'name': name,
      'profilePicture': profilePicture,
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    var groupWithJson = json['groupWith'] as List<dynamic>?;
    List<GroupMember>? groupWithList;
    if (groupWithJson != null) {
      groupWithList = groupWithJson
          .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      groupWithList = null;
    }

    return Account(
      email: json['email'],
      userId: json['userId'],
      location: json['location'] ?? GeoPoint(0, 0),
      groupWith: groupWithList,
      name: json['name'],
      profilePicture: json['profilePicture'],
    );
  }

  @override
  String toString() {
    return 'Account{email: $email, userId: $userId, location: $location, groupWith: $groupWith, name: $name, profilePicture: $profilePicture}';
  }
}

class GroupMember {
  String? email;
  GeoPoint? location;
  String? name;
  String? userId;

  GroupMember({
    this.email,
    this.location,
    this.name,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'location': location,
      'name': name,
      'userId': userId,
    };
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      email: json['email'],
      location: json['location'],
      name: json['name'],
      userId: json['userId'],
    );
  }

  @override
  String toString() {
    return 'GroupMember{email: $email, location: $location, name: $name, userId: $userId}';
  }
}
