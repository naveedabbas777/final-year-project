import 'package:flutter/material.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/models/help_guide_model.dart';

class ComprehensiveHelpDialog extends StatefulWidget {
  const ComprehensiveHelpDialog({Key? key}) : super(key: key);

  @override
  State<ComprehensiveHelpDialog> createState() =>
      _ComprehensiveHelpDialogState();
}

class _ComprehensiveHelpDialogState extends State<ComprehensiveHelpDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _screenNames = [
    'dashboard',
    'forecast',
    'alerts',
    'market',
    'settings',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _screenNames.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

  IconData _getIconFromType(IconType type) {
    switch (type) {
      case IconType.lightbulb:
        return Icons.lightbulb_outline;
      case IconType.info:
        return Icons.info_outline;
      case IconType.help:
        return Icons.help_outline;
      case IconType.settings:
        return Icons.settings_outlined;
      case IconType.location:
        return Icons.location_on_outlined;
      case IconType.weather:
        return Icons.cloud_queue_outlined;
      case IconType.alert:
        return Icons.notifications_outlined;
      case IconType.market:
        return Icons.storefront_outlined;
      case IconType.crop:
        return Icons.agriculture_outlined;
    }
  }

  Color _getScreenColor(String screenName) {
    switch (screenName) {
      case 'dashboard':
        return Colors.green;
      case 'forecast':
        return Colors.blue;
      case 'alerts':
        return Colors.orange;
      case 'market':
        return Colors.purple;
      case 'settings':
        return Colors.teal;
      default:
        return Colors.green;
    }
  }

  IconData _getScreenIcon(String screenName) {
    switch (screenName) {
      case 'dashboard':
        return Icons.home_outlined;
      case 'forecast':
        return Icons.calendar_today_outlined;
      case 'alerts':
        return Icons.notifications_outlined;
      case 'market':
        return Icons.storefront_outlined;
      case 'settings':
        return Icons.settings_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _getScreenTitle(String screenName) {
    final guide = appHelpGuides[screenName];
    return _t(guide?.titleEn ?? '', guide?.titleUr ?? '');
  }

  Widget _buildScreenHelpTab(String screenName) {
    final guide = appHelpGuides[screenName];
    if (guide == null) return const SizedBox.shrink();

    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final description = isUrdu ? guide.descriptionUr : guide.descriptionEn;
    final color = _getScreenColor(screenName);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment:
            isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Screen description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUrdu) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getScreenIcon(screenName), color: color),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                if (isUrdu) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getScreenIcon(screenName), color: color),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tips section title
          Text(
            _t('Tips & Features:', 'نکات اور خصوصیات:'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Tips list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: guide.tips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tip = guide.tips[index];
              final tipTitle = isUrdu ? tip.titleUr : tip.titleEn;
              final tipDesc = isUrdu ? tip.descriptionUr : tip.descriptionEn;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment:
                      isUrdu
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!isUrdu) ...[
                          Icon(
                            _getIconFromType(tip.icon),
                            size: 18,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            tipTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ),
                        if (isUrdu) ...[
                          const SizedBox(width: 8),
                          Icon(
                            _getIconFromType(tip.icon),
                            size: 18,
                            color: color,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tipDesc,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';

    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: double.maxFinite,
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade700, Colors.green.shade600],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              isUrdu
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('Digital Kissan Guide', 'ڈیجیٹل کسان گائیڈ'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _t(
                                'Learn how to use each screen',
                                'ہر سکرین کو استعمال کرنا سیکھیں',
                              ),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.6),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    tabs:
                        _screenNames.map((screenName) {
                          return Tab(
                            child: Row(
                              children: [
                                Icon(_getScreenIcon(screenName), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  _getScreenTitle(screenName),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children:
                    _screenNames
                        .map((screenName) => _buildScreenHelpTab(screenName))
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
