import 'package:flutter/material.dart';

import '../services/market_api_service.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _service = MarketApiService();

  bool _loading = false;
  String? _error;
  List<OfferDto> _myOffers = const [];
  List<OfferDto> _incoming = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.fetchMyOffers(),
        _service.fetchIncomingOffers(),
      ]);
      if (!mounted) return;
      setState(() {
        _myOffers = results[0];
        _incoming = results[1];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _accept(OfferDto offer) async {
    try {
      await _service.acceptOffer(offer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer accepted and order created')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reject(OfferDto offer) async {
    try {
      await _service.rejectOffer(offer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offer rejected')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancel(OfferDto offer) async {
    try {
      await _service.cancelOffer(offer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offer cancelled')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildOfferCard(OfferDto offer, {bool incoming = false}) {
    final listing = offer.listing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listing != null
                  ? '${listing.cropName} (${listing.district})'
                  : 'Listing ${offer.listingId}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('Offer price: PKR ${offer.offerPrice.toStringAsFixed(0)}'),
            Text('Quantity: ${offer.quantity.toStringAsFixed(0)}'),
            Text('Status: ${offer.status}'),
            const SizedBox(height: 8),
            if (incoming && offer.status == 'pending')
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _accept(offer),
                    child: const Text('Accept'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _reject(offer),
                    child: const Text('Reject'),
                  ),
                ],
              )
            else if (!incoming && offer.status == 'pending')
              OutlinedButton(
                onPressed: () => _cancel(offer),
                child: const Text('Cancel Offer'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'My Offers'), Tab(text: 'Incoming Offers')],
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
              : TabBarView(
                controller: _tab,
                children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    child:
                        _myOffers.isEmpty
                            ? ListView(
                              children: const [
                                SizedBox(height: 140),
                                Center(child: Text('No offers placed yet.')),
                              ],
                            )
                            : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _myOffers.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder:
                                  (_, i) => _buildOfferCard(_myOffers[i]),
                            ),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child:
                        _incoming.isEmpty
                            ? ListView(
                              children: const [
                                SizedBox(height: 140),
                                Center(child: Text('No incoming offers.')),
                              ],
                            )
                            : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _incoming.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder:
                                  (_, i) => _buildOfferCard(
                                    _incoming[i],
                                    incoming: true,
                                  ),
                            ),
                  ),
                ],
              ),
    );
  }
}
