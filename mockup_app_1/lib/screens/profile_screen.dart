import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mockup_app/providers/auth_provider.dart';
import 'package:mockup_app/services/firebase_service.dart';
import 'package:mockup_app/main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _svc = FirebaseService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    try {
      Map<String, dynamic>? doc;
      if (user != null) {
        doc = await _svc.getUserByUid(user.uid);
      } else {
        // fallback: try last logged-in phone (for password-only logins)
        final prefs = await SharedPreferences.getInstance();
        final lastPhone = prefs.getString('last_logged_in_phone');
        if (lastPhone != null && lastPhone.isNotEmpty) {
          doc = await _svc.getUserByPhone(lastPhone);
        }
      }
      if (mounted)
        setState(() {
          _data = doc;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _data = null;
        });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayName() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    return _data?['displayName'] ?? user?.displayName ?? 'User';
  }

  String _phoneNumber() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    return _data?['phoneNumber'] ?? user?.phoneNumber ?? '';
  }

  String? _formatCreatedAt() {
    final created = _data?['createdAt'];
    DateTime? dt;
    if (created == null) return null;
    if (created is DateTime)
      dt = created;
    else if (created is Timestamp)
      dt = created.toDate();
    else if (created is int)
      dt = DateTime.fromMillisecondsSinceEpoch(created);
    if (dt == null) return null;
    return DateFormat.yMMMMd().add_jm().format(dt);
  }

  String? _locationSummary() {
    final address = _data?['address'] as String?;
    final lat = (_data?['lat'] as num?)?.toDouble();
    final lon = (_data?['lon'] as num?)?.toDouble();

    if (address == null || address.isEmpty) return null;
    if (lat == null || lon == null) return address;
    return '$address (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})';
  }

  Future<void> _showEditDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    // determine uid to update
    final uidToUpdate = user?.uid ?? (_data?['uid'] ?? _data?['id']);
    if (uidToUpdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No editable user available')),
      );
      return;
    }

    final nameController = TextEditingController(
      text: _data?['displayName'] ?? user?.displayName ?? '',
    );
    final phoneController = TextEditingController(
      text: _data?['phoneNumber'] ?? user?.phoneNumber ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  final newPhone = phoneController.text.trim();
                  try {
                    await _svc.updateUserProfile(
                      uidToUpdate,
                      displayName: newName.isEmpty ? null : newName,
                      phoneNumber: newPhone.isEmpty ? null : newPhone,
                    );
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    Navigator.of(context).pop(false);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _loadProfile();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> _signOut() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreenWrapper()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final phone = _phoneNumber();
    final memberSince = _formatCreatedAt();
    final location = _locationSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.green.shade700,
        // Removed actions property to remove the edit icon
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.green.shade700,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 36,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      color: Colors.green.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: const Text('Full name'),
                            subtitle: Text(name),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.phone_iphone),
                            title: const Text('Phone'),
                            subtitle: Text(phone),
                          ),
                          if (location != null) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.location_on),
                              title: const Text('Location'),
                              subtitle: Text(location),
                            ),
                          ],
                          if (memberSince != null) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.date_range),
                              title: const Text('Joined'),
                              subtitle: Text(memberSince),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _showEditDialog,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _signOut,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
