import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:mockup_app/services/alert_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertService>().loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8F1),
      appBar: AppBar(
        title: Text(loc.alertsTitle),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<AlertService>(
            builder: (_, service, __) {
              if (service.unreadCount == 0) return const SizedBox.shrink();
              return TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: service.isLoading ? null : service.markAllAsRead,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Mark all read'),
              );
            },
          ),
          Consumer<AlertService>(
            builder: (_, service, __) => IconButton(
              tooltip: 'Refresh',
              icon: service.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.refresh),
              onPressed: service.isLoading ? null : service.loadAlerts,
            ),
          ),
        ],
      ),
      body: Consumer<AlertService>(
        builder: (context, service, _) {
          final alerts = service.alerts;

          if (service.isLoading && alerts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 72,
                    color: Colors.green.shade200,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No weather alerts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alerts appear here when weather conditions\naffect your crops.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: Colors.green.shade700,
            onRefresh: service.loadAlerts,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _AlertCard(
                  alert: alert,
                  onTap: () => service.markAsRead(alert.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Individual alert card
// ──────────────────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});

  final AlertItem alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(alert.type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: alert.isRead ? Colors.white : palette.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alert.isRead
                ? Colors.transparent
                : palette.accent.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(alert.isRead ? 0.04 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(palette.icon, color: palette.accent, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: TextStyle(
                              fontWeight: alert.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ),
                        if (!alert.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: palette.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.yMMMd().add_jm().format(alert.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const Spacer(),
                        if (alert.isRead)
                          Text(
                            'Read',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          )
                        else
                          Text(
                            'Tap to dismiss',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.accent,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Visual palette per alert type
// ──────────────────────────────────────────────────────────────────────────────

class _Palette {
  const _Palette({
    required this.bg,
    required this.accent,
    required this.icon,
  });

  final Color bg;
  final Color accent;
  final IconData icon;
}

_Palette _palette(String type) {
  switch (type) {
    case 'rain':
      return const _Palette(
        bg: Color(0xFFE3F2FD),
        accent: Color(0xFF1565C0),
        icon: Icons.grain_rounded,
      );
    case 'heat':
      return const _Palette(
        bg: Color(0xFFFFF3E0),
        accent: Color(0xFFE65100),
        icon: Icons.wb_sunny_rounded,
      );
    case 'cold':
      return const _Palette(
        bg: Color(0xFFE0F7FA),
        accent: Color(0xFF00695C),
        icon: Icons.ac_unit_rounded,
      );
    case 'wind':
      return const _Palette(
        bg: Color(0xFFEDE7F6),
        accent: Color(0xFF4527A0),
        icon: Icons.air_rounded,
      );
    default:
      return const _Palette(
        bg: Color(0xFFF3F4F6),
        accent: Color(0xFF374151),
        icon: Icons.info_outline_rounded,
      );
  }
}
