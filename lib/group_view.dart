import 'package:drive_guide/group_tracking.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchInvitations();
    _listenToInvitationUpdates();
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
      await _firestore
          .collection('invitations')
          .doc(invitation.inviterId)
          .delete();
      // Update the UI
      _fetchInvitations();
    } else if (status == 'accepted') {
      // Show confirmation dialog
      bool confirm = await _showConfirmationDialog();
      if (confirm) {
        // Navigate to map page
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //       builder: (context) => GroupTrackingPage(
        //           currentUser: _auth.currentUser,
        //           friendUser: invitation.inviterId)),
        // );
      } else {
        // Do nothing if they choose 'No'
        print("Invitation acceptance cancelled.");
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
            child: ListView.builder(
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
          ),
        ],
      ),
    );
  }
}
