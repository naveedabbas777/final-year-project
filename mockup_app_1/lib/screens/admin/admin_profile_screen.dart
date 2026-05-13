import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/providers/auth_provider.dart';
import 'package:mockup_app/services/firebase_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final FirebaseService _svc = FirebaseService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final doc = await _svc.getUserMe();
      if (!mounted) return;
      setState(() => _data = doc);
    } catch (e) {
      if (!mounted) return;
      setState(() => _data = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatCreatedAt() {
    final created = _data?['createdAt'];
    DateTime? dt;
    if (created == null) return _t('Unknown', 'نامعلوم');
    if (created is DateTime) dt = created;
    else if (created is int) dt = DateTime.fromMillisecondsSinceEpoch(created);
    else if (created is String) dt = DateTime.tryParse(created);
    if (dt == null) return _t('Unknown', 'نامعلوم');
    return DateFormat.yMMMMd().add_jm().format(dt);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Sign out', 'سائن آؤٹ'), style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(_t('Are you sure you want to sign out?', 'کیا آپ واقعی سائن آؤٹ کرنا چاہتے ہیں؟'), style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_t('Cancel', 'منسوخ'), style: const TextStyle(color: AppColors.textPrimary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_t('Sign out', 'سائن آؤٹ')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = (_data?['firebaseUid'] ?? _data?['uid'] ?? _data?['id'] ?? '').toString();
    final name = (_data?['displayName'] ?? _data?['name'] ?? '').toString();
    final email = (_data?['email'] ?? '').toString();
    final role = (_data?['role'] ?? '').toString();
    final phone = (_data?['phoneNumber'] ?? _data?['phone'] ?? '').toString();
    final district = (_data?['district'] ?? '').toString();
    final province = (_data?['province'] ?? '').toString();
    final photoUrl = (_data?['photoUrl'] ?? '').toString();
    final lastSeen = (_data?['lastSeen'] ?? '').toString();
    final isOnline = _data?['isOnline'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Admin Profile', 'ایڈمن پروفائل')),
        backgroundColor: AppColors.primaryMid,
        foregroundColor: AppColors.white,
      ),
      body: _loading
          ? const AsyncLoadingWidget()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primary,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) as ImageProvider : null,
                      child: photoUrl.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'A', style: const TextStyle(fontSize: 28, color: AppColors.white)) : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          _row('UID', uid),
                          _row('Name', name),
                          _row('Email', email),
                          _row('Role', role),
                          _row('Phone', phone),
                          _row('District', district),
                          _row('Province', province),
                          _row('Created', _formatCreatedAt()),
                          _row('Online', isOnline ? _t('Yes', 'ہاں') : _t('No', 'نہیں')),
                          if (lastSeen.isNotEmpty) _row('Last seen', lastSeen),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: Text(_t('Sign out', 'سائن آؤٹ')),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                      onPressed: _signOut,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Expanded(child: Text(value.isNotEmpty ? value : '-', textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
