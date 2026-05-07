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
  bool _sending = false;
  Future<List<AdminUserDto>>? _farmersFuture;
  Future<List<AdminNotificationLogDto>>? _historyFuture;
  final Set<String> _selectedFarmerIds = <String>{};
  String? _singleFarmerId;
  String _historyMode = 'all_modes';
  DateTime? _historyFrom;
  DateTime? _historyTo;

  @override
  void initState() {
    super.initState();
    _farmersFuture = _api.fetchUsers(limit: 200, role: 'farmer');
    _reloadHistory();
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
        const SnackBar(content: Text('Title and message are required')),
      );
      return;
    }

    List<String> targets = const [];
    if (_mode == 'single') {
      if (_singleFarmerId == null || _singleFarmerId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose one farmer')),
        );
        return;
      }
      targets = [_singleFarmerId!];
    } else if (_mode == 'some') {
      if (_selectedFarmerIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one farmer')),
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
        title: title,
        body: body,
        targetUserIds: targets,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Sent to ${result['recipients'] ?? 0} farmers, pushes: ${result['pushSent'] ?? 0}',
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
      messenger.showSnackBar(SnackBar(content: Text('Send failed: $e')));
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
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.send), text: 'Compose'),
              Tab(icon: Icon(Icons.history), text: 'History'),
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
                const Text(
                  'Send Farmer Notifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: const InputDecoration(
                    labelText: 'Target Mode',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All farmers')),
                    DropdownMenuItem(value: 'some', child: Text('Selected farmers')),
                    DropdownMenuItem(value: 'single', child: Text('Single farmer')),
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
                  decoration: const InputDecoration(
                    labelText: 'Notification Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bodyController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notification Message',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_mode != 'all')
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
                          'Could not load farmers: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        );
                      }
                      final farmers = snapshot.data ?? const <AdminUserDto>[];
                      if (farmers.isEmpty) {
                        return const Text('No farmers found');
                      }

                      if (_mode == 'single') {
                        return DropdownButtonFormField<String>(
                          initialValue: _singleFarmerId,
                          decoration: const InputDecoration(
                            labelText: 'Choose Farmer',
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
                                    ? 'No district'
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
                    label: Text(_sending ? 'Sending...' : 'Send Notification'),
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
          return const AsyncLoadingWidget(message: 'Loading history...');
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
              const Expanded(
                child: AsyncEmptyWidget(message: 'No notification history yet'),
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
                          '${row.createdAt ?? 'Unknown time'}\nmode: ${row.mode} • recipients: ${row.recipients} • pushes: ${row.pushSent}',
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
      if (value == null) return 'Any';
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
                decoration: const InputDecoration(
                  labelText: 'Mode Filter',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'all_modes', child: Text('All modes')),
                  DropdownMenuItem(value: 'all', child: Text('All farmers')),
                  DropdownMenuItem(value: 'some', child: Text('Selected farmers')),
                  DropdownMenuItem(value: 'single', child: Text('Single farmer')),
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
                      child: Text('From: ${formatDate(_historyFrom)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => pickDate(isFrom: false),
                      child: Text('To: ${formatDate(_historyTo)}'),
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
                      label: const Text('Apply'),
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
                      label: const Text('Reset'),
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
                Text('Sent at: ${row.createdAt ?? 'Unknown'}'),
                const SizedBox(height: 8),
                Text('Mode: ${row.mode}'),
                Text('Recipients: ${row.recipients}'),
                Text('Push sent: ${row.pushSent}'),
                Text('Alerts created: ${row.alertCreated}'),
                const SizedBox(height: 12),
                const Text(
                  'Message',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(row.body),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
