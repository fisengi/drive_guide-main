import 'package:drive_guide/tracking.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Models/Invitation.dart'; // Assuming Invitation.dart is in the Models directory

class GroupView extends StatefulWidget {
  @override
  _GroupViewState createState() => _GroupViewState();
}

class _GroupViewState extends State<GroupView> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _inviteeController = TextEditingController();

  List<Invitation> _invitations = [];
  List<Map<String, dynamic>> _groupMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchInvitations();
    _listenToInvitationUpdates();
    _fetchGroupMembers();
  }

  void _fetchInvitations() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        var snapshot = await _firestore
            .collection('invitations')
            .where('inviteeId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'pending')
            .get();

        var invitations = snapshot.docs
            .map((doc) => Invitation.fromJson(doc.data()))
            .toList();
        setState(() {
          _invitations = invitations;
        });
      } catch (e) {
        print("Failed to fetch invitations: $e");
      }
    }
  }

  void _sendInvitation() async {
    String inviteeId = _inviteeController.text.trim();
    User? currentUser = _auth.currentUser;

    if (currentUser != null && inviteeId.isNotEmpty) {
      try {
        await _firestore.collection('invitations').add({
          'inviterId': currentUser.uid,
          'inviteeId': inviteeId,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
        _inviteeController.clear();
        print("Invitation sent to $inviteeId");
      } catch (e) {
        print("Error sending invitation: $e");
      }
    } else {
      print("User not logged in or invitee ID is empty.");
    }
  }

  void _updateInvitationStatus(Invitation invitation, String status) async {
    if (status == 'declined') {
      // Delete the invitation from Firestore
      var snapshot = await _firestore
          .collection('invitations')
          .where('inviterId', isEqualTo: invitation.inviterId)
          .where('inviteeId', isEqualTo: invitation.inviteeId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      // Update the UI
      _fetchInvitations();
    } else if (status == 'accepted') {
      // Show confirmation dialog
      bool confirm = await _showConfirmationDialog();
      if (confirm) {
        await _addToGroup(invitation);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TrackingPage(user: _auth.currentUser!)));
      } else {
        // Do nothing if they choose 'No'
        print("Invitation acceptance cancelled.");
      }
    }
  }

  Future<void> _addToGroup(Invitation invitation) async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      var currentUserSnapshot = await _firestore
          .collection('Account')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      var inviterSnapshot = await _firestore
          .collection('Account')
          .where('userId', isEqualTo: invitation.inviterId)
          .get();

      if (currentUserSnapshot.docs.isNotEmpty &&
          inviterSnapshot.docs.isNotEmpty) {
        var currentUserDoc = currentUserSnapshot.docs.first;
        var inviterDoc = inviterSnapshot.docs.first;

        var currentUserLocation = currentUserDoc['location'];
        var inviterLocation = inviterDoc['location'];

        var currentUserGroupWith =
            currentUserDoc['groupWith'] as List<dynamic>? ?? [];
        var inviterGroupWith = inviterDoc['groupWith'] as List<dynamic>? ?? [];

        currentUserGroupWith.add({
          'userId': invitation.inviterId,
          'location': inviterLocation,
        });

        inviterGroupWith.add({
          'userId': currentUser.uid,
          'location': currentUserLocation,
        });

        await _firestore.collection('Account').doc(currentUserDoc.id).update({
          'groupWith': currentUserGroupWith,
        });

        await _firestore.collection('Account').doc(inviterDoc.id).update({
          'groupWith': inviterGroupWith,
        });
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Accept Invitation"),
          content: Text(
              "You are going to send your live location to that user, and you can see your friend's location. Are you sure?"),
          actions: <Widget>[
            TextButton(
              child: Text("No"),
              onPressed: () {
                Navigator.of(context)
                    .pop(false); // Closes the dialog and returns false
              },
            ),
            TextButton(
              child: Text("Yes"),
              onPressed: () {
                Navigator.of(context)
                    .pop(true); // Closes the dialog and returns true
              },
            ),
          ],
        );
      },
    );
  }

  void _fetchGroupMembers() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      var snapshot = await _firestore
          .collection('Account')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var userDoc = snapshot.docs.first;
        var groupWithList = userDoc['groupWith'] as List<dynamic>? ?? [];
        List<Map<String, dynamic>> groupMembers = [];

        for (var groupMember in groupWithList) {
          var memberSnapshot = await _firestore
              .collection('Account')
              .where('userId', isEqualTo: groupMember['userId'])
              .get();

          if (memberSnapshot.docs.isNotEmpty) {
            groupMembers.add(memberSnapshot.docs.first.data());
          }
        }

        setState(() {
          _groupMembers = groupMembers;
        });
      }
    }
  }

  void _listenToInvitationUpdates() {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _firestore
          .collection('invitations')
          .where('inviteeId', isEqualTo: currentUser.uid)
          .snapshots()
          .listen((snapshot) {
        var invitations = snapshot.docs
            .map((doc) => Invitation.fromJson(doc.data()))
            .toList();
        setState(() {
          _invitations = invitations;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Group View"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _inviteeController,
              decoration: InputDecoration(
                labelText: 'Enter User ID to invite',
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendInvitation,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _invitations.length,
                  itemBuilder: (context, index) {
                    Invitation invitation = _invitations[index];
                    return ListTile(
                      title: Text("Invitation from ${invitation.inviterId}"),
                      subtitle:
                          Text("Received on ${invitation.timestamp.toDate()}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check),
                            onPressed: () =>
                                _updateInvitationStatus(invitation, 'accepted'),
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () =>
                                _updateInvitationStatus(invitation, 'declined'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Divider(),
                Text('Current Group Members',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _groupMembers.length,
                  itemBuilder: (context, index) {
                    var member = _groupMembers[index];
                    return ListTile(
                      title: Text('Name: ${member['name']}'),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
