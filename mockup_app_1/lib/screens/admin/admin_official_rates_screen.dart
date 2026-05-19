import 'package:flutter/material.dart';

import 'admin_rates_screen.dart';

class AdminOfficialRatesScreen extends StatelessWidget {
  const AdminOfficialRatesScreen({super.key});

  String _t(BuildContext context, String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Text(
            _t(
              context,
              'Official Rates Manager: add/edit product rates district-wise and upload CSV in bulk.',
              'سرکاری ریٹس مینیجر: فصل اور ضلع کے مطابق ریٹس شامل/ترمیم کریں اور CSV بلک اپ لوڈ کریں۔',
            ),
            style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600),
          ),
        ),
        const Expanded(child: AdminRatesScreen()),
      ],
    );
  }
}
