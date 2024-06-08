import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../Models/Account.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Account? account;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? accountDocId;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _fetchAccount();
  }

  void _fetchAccount() async {
    if (user != null) {
      try {
        var snapshot = await _firestore
            .collection('Account')
            .where('userId', isEqualTo: user!.uid)
            .get();

        if (snapshot.docs.isNotEmpty) {
          var doc = snapshot.docs.first;
          var accountData = doc.data();
          setState(() {
            accountDocId = doc.id;
            account = Account.fromJson(accountData!);
            _nameController.text = account?.name ?? "";
          });
        } else {
          setState(() {
            account = null;
          });
        }
      } catch (e) {
        setState(() {
          account = null;
        });
      }
    }
  }

  void _updateName() async {
    if (user != null && accountDocId != null) {
      try {
        await _firestore
            .collection('Account')
            .doc(accountDocId)
            .update({'name': _nameController.text});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Name updated successfully')),
        );
        _fetchAccount();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile != null && accountDocId != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${user!.uid}.jpg');
        await storageRef.putFile(_imageFile!);
        final downloadURL = await storageRef.getDownloadURL();
        await _firestore.collection('Account').doc(accountDocId).update({
          'profilePicture': downloadURL,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile picture updated successfully')),
        );
        _fetchAccount();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile Page'),
      ),
      body: account != null ? _buildProfileDetails() : _buildNoAccountMessage(),
    );
  }

  Widget _buildProfileDetails() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: account?.profilePicture != null
                      ? NetworkImage(account!.profilePicture!)
                      : AssetImage('images/default_profilepicture.png')
                          as ImageProvider,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickImage,
                    child: Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: Theme.of(context).primaryColor,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => _updateName(),
            ),
            const SizedBox(height: 5),
            Text(
              account!.email ?? "No email available",
              style: Theme.of(context).textTheme.bodyText2,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('User ID: ${account!.userId ?? ""}'),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: () {
                    if (account!.userId != null) {
                      Clipboard.setData(ClipboardData(text: account!.userId!));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('User ID copied to clipboard'),
                      ));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _updateName,
                style: ElevatedButton.styleFrom(
                  primary: Theme.of(context).primaryColor,
                  shape: StadiumBorder(),
                ),
                child:
                    Text('Update Name', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 30),
            Divider(),
            const SizedBox(height: 10),
            Text(
              'Recent Grouped With:',
              style: Theme.of(context).textTheme.headline6,
            ),
            const SizedBox(height: 10),
            ..._buildGroupWithList(),
            const SizedBox(height: 10),
            Divider(),
            const SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                // Navigate to settings page
              },
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text('Information'),
              onTap: () {
                // Navigate to information page
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                // Handle logout
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupWithList() {
    if (account!.groupWith != null && account!.groupWith!.isNotEmpty) {
      return account!.groupWith!.map((groupMember) {
        return ListTile(
          leading: Icon(Icons.person),
          title: Text(groupMember.name ?? 'Unnamed'),
          subtitle: Text(groupMember.email ?? ''),
        );
      }).toList();
    } else {
      return [Text('No group members found.')];
    }
  }

  Widget _buildNoAccountMessage() {
    return Center(
      child: Text('No account details available.'),
    );
  }
}
