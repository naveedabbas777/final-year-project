import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:mockup_app/config/app_config.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/utils/retry_helper.dart';
import 'package:mockup_app/utils/error_presenter.dart';

import 'package:mockup_app/providers/auth_provider.dart';
import 'package:mockup_app/services/firebase_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

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
  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    // Use postFrameCallback to safely access Provider in initState
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = false;
    });

    try {
      // Use /api/users/me — always returns the full unredacted profile.
      // GET /api/users/:uid goes through canViewSensitiveFields which can
      // redact phone, email, address, lat/lon even for your own profile.
      final doc = await _svc.getUserMe();
      if (!mounted) return;
      setState(() {
        _data = doc;
        _loadError = doc == null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _loadError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayName() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    return (_data?['displayName'] ??
            _data?['name'] ??
            user?.displayName ??
            user?.email ??
            _t('User', 'صارف'))
        .toString();
  }

  String _userName() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final email = _emailAddress();
    if (email.isNotEmpty) {
      return email.split('@').first;
    }
    return (_data?['name'] ??
            _data?['displayName'] ??
            user?.displayName ??
            user?.uid ??
            _t('User', 'صارف'))
        .toString();
  }

  String _emailAddress() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    return (_data?['email'] ?? user?.email ?? '').toString();
  }

  String _phoneNumber() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    return (_data?['phoneNumber'] ?? _data?['phone'] ?? user?.phoneNumber ?? '')
        .toString();
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
    else if (created is String)
      dt = DateTime.tryParse(created);
    if (dt == null) return null;
    return DateFormat.yMMMMd().add_jm().format(dt);
  }

  String _accountType() {
    final role = (_data?['role'] ?? '').toString().trim();
    if (role.isNotEmpty) return role[0].toUpperCase() + role.substring(1);
    return _t('User', 'صارف');
  }

  String _profileInitial() {
    final name = _displayName().trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    final email = _emailAddress().trim();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return _t('U', 'ص');
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
    final uidToUpdate = user?.uid ?? (_data?['uid'] ?? _data?['id']);
    if (uidToUpdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('No editable user available', 'ترمیم کے لیے صارف دستیاب نہیں'))),
      );
      return;
    }

    final nameCtrl = TextEditingController(
      text: _data?['displayName'] ?? user?.displayName ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: _data?['phoneNumber'] ?? _data?['phone'] ?? user?.phoneNumber ?? '',
    );
    final districtCtrl = TextEditingController(
      text: (_data?['district'] ?? '').toString(),
    );
    final provinceCtrl = TextEditingController(
      text: (_data?['province'] ?? '').toString(),
    );
    final addressCtrl = TextEditingController(
      text: (_data?['address'] ?? '').toString(),
    );

    InputDecoration _field(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              _t('Edit Profile', 'پروفائل ترمیم کریں'),
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primaryMid,
                    decoration: _field(_t('Full Name', 'پورا نام'), Icons.person_outline),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primaryMid,
                    keyboardType: TextInputType.phone,
                    decoration: _field(_t('Phone Number', 'فون نمبر'), Icons.phone_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: districtCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primaryMid,
                    decoration: _field(_t('District', 'ضلع'), Icons.map_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: provinceCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primaryMid,
                    decoration: _field(
                      _t('Province', 'صوبہ'),
                      Icons.location_city_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primaryMid,
                    maxLines: 2,
                    decoration: _field(_t('Address', 'پتہ'), Icons.home_outlined),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(_t('Cancel', 'منسوخ')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  try {
                    await _svc.updateUserProfile(
                      uidToUpdate,
                      displayName:
                          nameCtrl.text.trim().isEmpty
                              ? null
                              : nameCtrl.text.trim(),
                      phoneNumber:
                          phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                      district:
                          districtCtrl.text.trim().isEmpty
                              ? null
                              : districtCtrl.text.trim(),
                      province:
                          provinceCtrl.text.trim().isEmpty
                              ? null
                              : provinceCtrl.text.trim(),
                      address:
                          addressCtrl.text.trim().isEmpty
                              ? null
                              : addressCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  } catch (e) {
                    if (ctx.mounted) Navigator.of(ctx).pop(false);
                  }
                },
                child: Text(_t('Save Changes', 'تبدیلیاں محفوظ کریں')),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _loadProfile();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('Profile updated successfully', 'پروفائل کامیابی سے اپڈیٹ ہو گیا')),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              _t('Sign Out', 'سائن آؤٹ'),
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: Text(_t('Are you sure you want to sign out of your account?', 'کیا آپ واقعی اپنے اکاؤنٹ سے سائن آؤٹ کرنا چاہتے ہیں؟')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(_t('Cancel', 'منسوخ')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(_t('Sign Out', 'سائن آؤٹ')),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signOut();
    // Reactive AuthProvider handles navigation — no imperative push needed.
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
        SnackBar(
          content: Text(
            '${_t('Image too large', 'تصویر بہت بڑی ہے')} (${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB). ${_t('Max 5 MB.', 'زیادہ سے زیادہ 5 MB۔')}',
          ),
        ),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final url = await RetryHelper.retry<String>(
        () => _uploadProfileImage(picked.path),
        maxAttempts: 3,
        onRetry: (attempt, delay) {
          if (mounted) {
            debugPrint('Retry upload attempt $attempt after $delay');
          }
        },
      );

      if (url.isNotEmpty) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final uidToUpdate = auth.user?.uid ?? (_data?['uid'] ?? _data?['id']);
        if (uidToUpdate != null) {
          await _svc.updateUserProfile(uidToUpdate, photoUrl: url);
          await _loadProfile();
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  url.contains('res.cloudinary.com')
                      ? _t('Profile photo uploaded to Cloudinary', 'پروفائل تصویر کلاؤڈینری پر اپلوڈ ہو گئی')
                      : _t('Profile photo uploaded locally', 'پروفائل تصویر لوکل اپلوڈ ہو گئی'),
                ),
              ),
            );
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_t('Upload failed', 'اپلوڈ ناکام'))));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ErrorPresenter.present(e))));
    } finally {
      if (!mounted) return;
      setState(() => _uploading = false);
    }
  }

  Future<String> _uploadProfileImage(String filePath) async {
    final user = fb.FirebaseAuth.instance.currentUser;
    String? idToken;
    if (user != null) idToken = await user.getIdToken();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/uploads/profile-image');
    final request = http.MultipartRequest('POST', uri);
    if (idToken != null) {
      request.headers['Authorization'] = 'Bearer $idToken';
    }
    request.files.add(await http.MultipartFile.fromPath('image', filePath));

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Profile image upload failed (${resp.statusCode})');
    }

    final body = json.decode(resp.body) as Map<String, dynamic>;
    final url = body['imageUrl'] as String? ?? '';
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final username = _userName();
    final email = _emailAddress().trim();
    final phone = _phoneNumber().trim();
    final memberSince = _formatCreatedAt();
    final accountType = _accountType();
    final location = _locationSummary();
    final district = (_data?['district'] ?? '').toString().trim();
    final province = (_data?['province'] ?? '').toString().trim();
    final photoUrl =
        _data?['photoUrl'] as String? ??
        Provider.of<AuthProvider>(context, listen: false).user?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('Profile', 'پروفائل'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 2,
      ),
      body:
          _loading
              ? const AsyncLoadingWidget()
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
                            backgroundImage:
                                photoUrl != null && photoUrl.isNotEmpty
                                    ? NetworkImage(photoUrl) as ImageProvider
                                    : null,
                            child:
                                photoUrl == null || photoUrl.isEmpty
                                    ? Text(
                                      _profileInitial(),
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
                              onTap:
                                  _uploading
                                      ? null
                                      : _pickAndUploadProfileImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  _uploading
                                      ? Icons.autorenew
                                      : Icons.camera_alt_outlined,
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
                    // Show a banner if backend fetch failed but Firebase Auth
                    // data is still available as a fallback.
                    if (_loadError)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _t('Could not load full profile from server. Showing cached data.', 'سرور سے مکمل پروفائل لوڈ نہ ہو سکا۔ کیش شدہ ڈیٹا دکھایا جا رہا ہے۔'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadProfile,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(48, 32),
                              ),
                              child: Text(
                                _t('Retry', 'دوبارہ کوشش'),
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Card(
                      color: Colors.green.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t('Account Summary', 'اکاؤنٹ خلاصہ'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        accountType,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      _t('Verified account', 'تصدیق شدہ اکاؤنٹ'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _ProfileFieldTile(
                              icon: Icons.person,
                              label: _t('Full name', 'پورا نام'),
                              value: name,
                            ),
                            _ProfileFieldTile(
                              icon: Icons.badge_outlined,
                              label: _t('Username', 'یوزرنیم'),
                              value: username,
                            ),
                            if (email.isNotEmpty)
                              _ProfileFieldTile(
                                icon: Icons.email_outlined,
                                label: _t('Email', 'ای میل'),
                                value: email,
                              ),
                            if (phone.isNotEmpty)
                              _ProfileFieldTile(
                                icon: Icons.phone_iphone,
                                label: _t('Contact', 'رابطہ'),
                                value: phone,
                              ),
                            if (location != null)
                              _ProfileFieldTile(
                                icon: Icons.location_on_outlined,
                                label: _t('Location', 'مقام'),
                                value: location,
                              ),
                            if (district.isNotEmpty)
                              _ProfileFieldTile(
                                icon: Icons.map_outlined,
                                label: _t('District', 'ضلع'),
                                value: district,
                              ),
                            if (province.isNotEmpty)
                              _ProfileFieldTile(
                                icon: Icons.location_city_outlined,
                                label: _t('Province', 'صوبہ'),
                                value: province,
                              ),
                            _ProfileFieldTile(
                              icon: Icons.date_range,
                              label: _t('Member since', 'رکنیت از'),
                              value: memberSince ?? _t('Not available', 'دستیاب نہیں'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: Text(_t('Edit profile', 'پروفائل ترمیم کریں')),
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
                        label: Text(_t('Sign out', 'سائن آؤٹ')),
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

class _ProfileFieldTile extends StatelessWidget {
  const _ProfileFieldTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
