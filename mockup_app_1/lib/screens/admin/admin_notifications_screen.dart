import 'package:flutter/material.dart';
import 'package:mockup_app/services/admin_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _api = AdminApiService();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _mode = 'all';
  String _audience = 'farmers';
  bool _sending = false;
  Future<List<AdminUserDto>>? _farmersFuture;
  Future<List<AdminNotificationLogDto>>? _historyFuture;
  final Set<String> _selectedFarmerIds = <String>{};
  String? _singleFarmerId;
  String _historyMode = 'all_modes';
  DateTime? _historyFrom;
  DateTime? _historyTo;

  String _t(BuildContext context, String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  void initState() {
    super.initState();
    _farmersFuture = _loadAudienceUsers();
    _reloadHistory();
  }

  Future<List<AdminUserDto>> _loadAudienceUsers() {
    if (_audience == 'admins') {
      return _api.fetchUsers(limit: 200, role: 'admin');
    }
    return _api.fetchUsers(limit: 200, role: 'farmer');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(context, 'Title and message are required', 'عنوان اور پیغام ضروری ہیں'),
          ),
        ),
      );
      return;
    }

    List<String> targets = const [];
    if (_mode == 'single') {
      if (_singleFarmerId == null || _singleFarmerId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(context, 'Please choose one user', 'براہ کرم ایک صارف منتخب کریں'))),
        );
        return;
      }
      targets = [_singleFarmerId!];
    } else if (_mode == 'some') {
      if (_selectedFarmerIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(context, 'Please select at least one user', 'براہ کرم کم از کم ایک صارف منتخب کریں'),
            ),
          ),
        );
        return;
      }
      targets = _selectedFarmerIds.toList();
    }

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _api.sendNotificationToFarmers(
        mode: _mode,
        audience: _audience,
        title: title,
        body: body,
        targetUserIds: targets,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _t(
              context,
              'Sent to ${result['recipients'] ?? 0} users, pushes: ${result['pushSent'] ?? 0}',
              '${result['recipients'] ?? 0} صارفین کو بھیجا گیا، پشز: ${result['pushSent'] ?? 0}',
            ),
          ),
        ),
      );
      _titleController.clear();
      _bodyController.clear();
      _selectedFarmerIds.clear();
      _singleFarmerId = null;
      _reloadHistory();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_t(context, 'Send failed: $e', 'بھیجنے میں ناکامی: $e'))),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.send), text: _t(context, 'Compose', 'تحریر')),
              Tab(icon: const Icon(Icons.history), text: _t(context, 'History', 'ہسٹری')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_buildComposeTab(), _buildHistoryTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(context, 'Send Farmer Notifications', 'کسانوں کو اطلاعات بھیجیں'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  decoration: InputDecoration(
                    labelText: _t(context, 'Audience', 'ہدف سامعین'),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'farmers', child: Text(_t(context, 'Farmers', 'کسان'))),
                    DropdownMenuItem(value: 'admins', child: Text(_t(context, 'Admins', 'ایڈمنز'))),
                    DropdownMenuItem(value: 'all_users', child: Text(_t(context, 'All users', 'تمام صارفین'))),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _audience = value;
                      if (_audience == 'all_users') {
                        _mode = 'all';
                      }
                      _selectedFarmerIds.clear();
                      _singleFarmerId = null;
                      _farmersFuture = _loadAudienceUsers();
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: InputDecoration(
                    labelText: _t(context, 'Target Mode', 'ٹارگٹ موڈ'),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'all', child: Text(_t(context, 'All in selected audience', 'منتخب سامعین میں سب'))),
                    if (_audience != 'all_users')
                      DropdownMenuItem(value: 'some', child: Text(_t(context, 'Selected users', 'منتخب صارفین'))),
                    if (_audience != 'all_users')
                      DropdownMenuItem(value: 'single', child: Text(_t(context, 'Single user', 'ایک صارف'))),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _mode = value;
                      _selectedFarmerIds.clear();
                      _singleFarmerId = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: _t(context, 'Notification Title', 'اطلاع کا عنوان'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bodyController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _t(context, 'Notification Message', 'اطلاع کا پیغام'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_mode != 'all' && _audience != 'all_users')
                  FutureBuilder<List<AdminUserDto>>(
                    future: _farmersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        );
                      }
                      if (snapshot.hasError) {
                        return Text(
                          '${_t(context, 'Could not load farmers', 'کسان لوڈ نہیں ہو سکے')}: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        );
                      }
                      final farmers = snapshot.data ?? const <AdminUserDto>[];
                      if (farmers.isEmpty) {
                        return Text(_t(context, 'No users found for selected audience', 'منتخب سامعین کے لیے کوئی صارف نہیں ملا'));
                      }

                      if (_mode == 'single') {
                        return DropdownButtonFormField<String>(
                          initialValue: _singleFarmerId,
                          decoration: InputDecoration(
                            labelText: _t(context, 'Choose User', 'صارف منتخب کریں'),
                            border: OutlineInputBorder(),
                          ),
                          items: farmers
                              .map(
                                (farmer) => DropdownMenuItem(
                                  value: farmer.firebaseUid,
                                  child: Text(
                                farmer.name.isEmpty
                                        ? farmer.firebaseUid
                                        : '${farmer.name} (${farmer.district})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _singleFarmerId = value),
                        );
                      }

                      return SizedBox(
                        height: 220,
                        child: ListView.builder(
                          itemCount: farmers.length,
                          itemBuilder: (_, index) {
                            final farmer = farmers[index];
                            final uid = farmer.firebaseUid;
                            return CheckboxListTile(
                              dense: true,
                              value: _selectedFarmerIds.contains(uid),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedFarmerIds.add(uid);
                                  } else {
                                    _selectedFarmerIds.remove(uid);
                                  }
                                });
                              },
                              title: Text(
                                farmer.name.isEmpty ? uid : farmer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                farmer.district.isEmpty
                                    ? _t(context, 'No district', 'ضلع نہیں')
                                    : farmer.district,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    label: Text(
                      _sending
                          ? _t(context, 'Sending...', 'بھیجا جا رہا ہے...')
                          : _t(context, 'Send Notification', 'اطلاع بھیجیں'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    Future<void> pickDate({required bool isFrom}) async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: isFrom
            ? (_historyFrom ?? DateTime.now())
            : (_historyTo ?? DateTime.now()),
      );
      if (picked == null) return;
      setState(() {
        if (isFrom) {
          _historyFrom = DateTime(picked.year, picked.month, picked.day);
        } else {
          _historyTo = DateTime(
            picked.year,
            picked.month,
            picked.day,
            23,
            59,
            59,
          );
        }
      });
    }

    return FutureBuilder<List<AdminNotificationLogDto>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AsyncLoadingWidget(
            message: _t(context, 'Loading history...', 'ہسٹری لوڈ ہو رہی ہے...'),
          );
        }
        if (snapshot.hasError) {
          return AsyncErrorWidget(
            error: snapshot.error.toString(),
            onRetry: () => setState(
              () => _historyFuture = _api.fetchNotificationHistory(limit: 100),
            ),
          );
        }
        final rows = snapshot.data ?? const <AdminNotificationLogDto>[];
        if (rows.isEmpty) {
          return Column(
            children: [
              _buildHistoryFilters(pickDate),
              Expanded(
                child: AsyncEmptyWidget(
                  message: _t(
                    context,
                    'No notification history yet',
                    'ابھی تک کوئی اطلاع ہسٹری نہیں',
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildHistoryFilters(pickDate),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _reloadHistory(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    return Card(
                      child: ListTile(
                        isThreeLine: true,
                        leading: const Icon(Icons.notifications_active),
                        title: Text(row.title),
                        subtitle: Text(
                          '${row.createdAt ?? _t(context, 'Unknown time', 'نامعلوم وقت')}\n${_t(context, 'mode', 'موڈ')}: ${row.mode} • ${_t(context, 'audience', 'سامعین')}: ${row.audience.isEmpty ? _t(context, 'farmers', 'کسان') : row.audience} • ${_t(context, 'recipients', 'وصول کنندگان')}: ${row.recipients} • ${_t(context, 'pushes', 'پشز')}: ${row.pushSent}',
                        ),
                        onTap: () => _showHistoryDetailDialog(row),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryFilters(
    Future<void> Function({required bool isFrom}) pickDate,
  ) {
    String formatDate(DateTime? value) {
      if (value == null) return _t(context, 'Any', 'کوئی بھی');
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _historyMode,
                decoration: InputDecoration(
                  labelText: _t(context, 'Mode Filter', 'موڈ فلٹر'),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(value: 'all_modes', child: Text(_t(context, 'All modes', 'تمام موڈز'))),
                  DropdownMenuItem(value: 'all', child: Text(_t(context, 'All farmers', 'تمام کسان'))),
                  DropdownMenuItem(value: 'some', child: Text(_t(context, 'Selected farmers', 'منتخب کسان'))),
                  DropdownMenuItem(value: 'single', child: Text(_t(context, 'Single farmer', 'ایک کسان'))),
                ],
                onChanged: (value) =>
                    setState(() => _historyMode = value ?? 'all_modes'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => pickDate(isFrom: true),
                      child: Text('${_t(context, 'From', 'سے')}: ${formatDate(_historyFrom)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => pickDate(isFrom: false),
                      child: Text('${_t(context, 'To', 'تک')}: ${formatDate(_historyTo)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _reloadHistory,
                      icon: const Icon(Icons.filter_alt),
                      label: Text(_t(context, 'Apply', 'لاگو کریں')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _historyMode = 'all_modes';
                          _historyFrom = null;
                          _historyTo = null;
                        });
                        _reloadHistory();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(_t(context, 'Reset', 'ری سیٹ')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reloadHistory() {
    final mode = _historyMode == 'all_modes' ? null : _historyMode;
    setState(() {
      _historyFuture = _api.fetchNotificationHistory(
        limit: 100,
        mode: mode,
        from: _historyFrom,
        to: _historyTo,
      );
    });
  }

  void _showHistoryDetailDialog(AdminNotificationLogDto row) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(row.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_t(context, 'Sent at', 'بھیجا گیا وقت')}: ${row.createdAt ?? _t(context, 'Unknown', 'نامعلوم')}'),
                const SizedBox(height: 8),
                Text('${_t(context, 'Mode', 'موڈ')}: ${row.mode}'),
                Text('${_t(context, 'Recipients', 'وصول کنندگان')}: ${row.recipients}'),
                Text('${_t(context, 'Push sent', 'پش بھیجے گئے')}: ${row.pushSent}'),
                Text('${_t(context, 'Alerts created', 'بنائے گئے الرٹس')}: ${row.alertCreated}'),
                const SizedBox(height: 12),
                Text(
                  _t(context, 'Message', 'پیغام'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(row.body),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t(context, 'Close', 'بند کریں')),
            ),
          ],
        );
      },
    );
  }
}
