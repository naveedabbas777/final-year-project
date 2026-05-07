import 'package:flutter/material.dart';
import 'package:mockup_app/services/admin_api_service.dart';
import 'package:mockup_app/services/market_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class AdminListingsScreen extends StatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends State<AdminListingsScreen> {
  final _api = AdminApiService();
  Future<List<ListingDto>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _api.fetchListings(limit: 200));
  }

  Future<void> _changeStatus(ListingDto listing, String status) async {
    await _api.updateListingStatus(listingId: listing.id, status: status);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ListingDto>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AsyncLoadingWidget(message: 'Loading listings...');
        }
        if (snapshot.hasError) {
          return AsyncErrorWidget(
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final rows = snapshot.data ?? const <ListingDto>[];
        if (rows.isEmpty) {
          return const AsyncEmptyWidget(message: 'No listings found');
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final row = rows[index];
              return Card(
                child: ListTile(
                  isThreeLine: true,
                  title: Text('${row.cropName} • ${row.qualityGrade}'),
                  subtitle: Text(
                    '${row.district}\n${row.quantity.toStringAsFixed(0)} ${row.unit} • PKR ${row.askingPrice.toStringAsFixed(0)}',
                  ),
                  trailing: DropdownButton<String>(
                    value: row.status,
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('open')),
                      DropdownMenuItem(value: 'sold', child: Text('sold')),
                      DropdownMenuItem(value: 'closed', child: Text('closed')),
                    ],
                    onChanged: (value) async {
                      if (value == null || value == row.status) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await _changeStatus(row, value);
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Listing update failed: $e')),
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
