import 'package:flutter/material.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/services/market_api_service.dart';
import 'chat_screen.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _service = MarketApiService();
  bool _loading = true;
  List<ConversationSummaryDto> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    try {
      final rows = await _service.fetchConversationSummaries(limit: 100);
      if (!mounted) return;
      setState(() {
        _conversations = rows;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteConversation(ConversationSummaryDto convo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation?'),
        content: const Text('This will remove the conversation from your side only.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteConversation(convo.threadId);
        if (!mounted) return;
        setState(() {
          _conversations.removeWhere((c) => c.threadId == convo.threadId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade50,
      body: _loading
          ? const Center(child: CompactLoadingIndicator())
          : _conversations.isEmpty
              ? const AsyncEmptyWidget(message: 'No messages yet.')
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _conversations.length,
                    itemBuilder: (context, idx) {
                      final convo = _conversations[idx];
                      final listingId = convo.listingId;
                      final productImageUrl = convo.productImageUrl.trim();
                      final previewText = convo.lastMessage.isNotEmpty
                          ? convo.lastMessage.length > 40
                              ? '${convo.lastMessage.substring(0, 40)}...'
                              : convo.lastMessage
                          : 'No message';

                      return Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  listingId: listingId,
                                  productName: convo.productName,
                                  productImageUrl: convo.productImageUrl,
                                ),
                              ),
                            );
                            // Refresh conversations after returning from chat
                            if (mounted) {
                              _loadConversations();
                            }
                          },
                          onLongPress: () => _deleteConversation(convo),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.green.shade100,
                                  backgroundImage: productImageUrl.isNotEmpty
                                      ? NetworkImage(productImageUrl)
                                      : null,
                                  child: productImageUrl.isEmpty
                                      ? Icon(
                                          Icons.shopping_bag,
                                          color: Colors.green.shade700,
                                          size: 24,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              convo.productName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTs(convo.lastTimestamp),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        previewText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: convo.unreadCount > 0
                                              ? Colors.black87
                                              : Colors.grey.shade600,
                                          fontWeight:
                                              convo.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (convo.unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${convo.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatTs(DateTime ts) {
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
