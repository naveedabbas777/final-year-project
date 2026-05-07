import 'package:flutter/material.dart';
import 'package:mockup_app/services/admin_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _api = AdminApiService();
  Future<List<AdminUserDto>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _api.fetchUsers(limit: 150));
  }

  Future<void> _changeRole(AdminUserDto user, String role) async {
    await _api.updateUserRole(userId: user.firebaseUid, role: role);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminUserDto>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AsyncLoadingWidget(message: 'Loading users...');
        }
        if (snapshot.hasError) {
          return AsyncErrorWidget(
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final users = snapshot.data ?? const <AdminUserDto>[];
        if (users.isEmpty) {
          return const AsyncEmptyWidget(message: 'No users found');
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final user = users[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user.isAdmin
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                    child: Icon(
                      user.isAdmin ? Icons.shield : Icons.person,
                      color: user.isAdmin
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                  title: Text(user.name.isEmpty ? user.firebaseUid : user.name),
                  subtitle: Text(
                    '${user.role} • ${user.district.isEmpty ? 'No district' : user.district}',
                  ),
                  trailing: DropdownButton<String>(
                    value: user.role,
                    items: const [
                      DropdownMenuItem(value: 'farmer', child: Text('farmer')),
                      DropdownMenuItem(value: 'buyer', child: Text('buyer')),
                      DropdownMenuItem(value: 'admin', child: Text('admin')),
                    ],
                    onChanged: (value) async {
                      if (value == null || value == user.role) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await _changeRole(user, value);
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Role update failed: $e')),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
