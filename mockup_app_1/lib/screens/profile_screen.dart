import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:mockup_app/config/app_config.dart';
import 'package:mockup_app/utils/retry_helper.dart';

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
  bool _uploading = false;

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

  Future<void> _pickAndUploadProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Validate size (max 5MB)
    final maxBytes = 5 * 1024 * 1024;
    final bytes = await picked.length();
    if (bytes > maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image too large (${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB). Max 5 MB.')),
      );
      return;
    }

    final cloudName = AppConfig.cloudinaryCloudName;
    final preset = AppConfig.cloudinaryUploadPreset;
    if (cloudName.isEmpty || preset.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloudinary not configured. Set CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET.')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final url = await RetryHelper.retry<String>(() => _uploadToCloudinary(picked.path, cloudName, preset),
          maxAttempts: 3, onRetry: (attempt, delay) {
        if (mounted) {
          debugPrint('Retry upload attempt $attempt after $delay');
        }
      });

      if (url.isNotEmpty) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final uidToUpdate = auth.user?.uid ?? (_data?['uid'] ?? _data?['id']);
        if (uidToUpdate != null) {
          await _svc.updateUserProfile(uidToUpdate, photoUrl: url);
          await _loadProfile();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: ${e.toString()}')));
    } finally {
      if (!mounted) return;
      setState(() => _uploading = false);
    }
  }

  Future<String> _uploadToCloudinary(String filePath, String cloudName, String uploadPreset) async {
    // Request signature from backend
    final user = fb.FirebaseAuth.instance.currentUser;
    String? idToken;
    if (user != null) idToken = await user.getIdToken();

    final signUri = Uri.parse('${AppConfig.apiBaseUrl}/api/uploads/cloudinary/sign');
    final signResp = await http.post(
      signUri,
      headers: {
        if (idToken != null) 'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({'folder': 'profiles'}),
    ).timeout(const Duration(seconds: 10));

    if (signResp.statusCode < 200 || signResp.statusCode >= 300) {
      throw Exception('Failed to obtain upload signature (${signResp.statusCode})');
    }

    final signBody = json.decode(signResp.body) as Map<String, dynamic>;
    final timestamp = signBody['timestamp']?.toString() ?? '';
    final signature = signBody['signature'] ?? '';
    final apiKey = signBody['apiKey'] ?? '';
    final cloud = signBody['cloudName'] ?? cloudName;

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['api_key'] = apiKey;
    request.fields['timestamp'] = timestamp;
    request.fields['signature'] = signature;
    request.fields['folder'] = 'profiles';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Cloudinary upload failed (${resp.statusCode})');
    }

    final body = json.decode(resp.body) as Map<String, dynamic>;
    final url = body['secure_url'] as String? ?? body['url'] as String? ?? '';
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final phone = _phoneNumber();
    final memberSince = _formatCreatedAt();
    final location = _locationSummary();
    final photoUrl = _data?['photoUrl'] as String? ?? Provider.of<AuthProvider>(context, listen: false).user?.photoURL;

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
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.green.shade700,
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl) as ImageProvider
                                : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: InkWell(
                              onTap: _uploading ? null : _pickAndUploadProfileImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  _uploading ? Icons.autorenew : Icons.camera_alt_outlined,
                                  size: 18,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ),
                        ],
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
