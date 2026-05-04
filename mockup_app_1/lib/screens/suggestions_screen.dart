import 'package:flutter/material.dart';
import 'package:mockup_app/l10n/app_localizations.dart';

class SuggestionsScreen extends StatelessWidget {
  const SuggestionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final suggestions = [
      (
        title: loc.irrigateFields,
        reason: loc.irrigateFieldsReason,
        icon: Icons.water_drop,
      ),
      (
        title: loc.delayFertilizer,
        reason: loc.delayFertilizerReason,
        icon: Icons.grass,
      ),
      (
        title: loc.harvestEarly,
        reason: loc.harvestEarlyReason,
        icon: Icons.agriculture,
      ),
      (
        title: loc.checkSoilMoisture,
        reason: loc.checkSoilMoistureReason,
        icon: Icons.analytics,
      ),
      (
        title: loc.avoidPesticide,
        reason: loc.avoidPesticideReason,
        icon: Icons.bug_report,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.suggestionsTitle),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.green.shade50,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.separated(
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = suggestions[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(item.icon, color: Colors.green.shade800),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.keyboard_arrow_down),
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.reason,
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
