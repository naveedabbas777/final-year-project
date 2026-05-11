import 'package:flutter/material.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

import '../services/assistant_service.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _assistantService = AssistantService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<AssistantMessage> _messages = [
    AssistantMessage(
      role: 'assistant',
      content:
          'Assalam-o-Alaikum! I am your farming assistant. Ask your question below and I will help in English or Urdu. میں آپ کی مدد کے لیے یہاں ہوں۔',
    ),
  ];

  bool _sending = false;
  AssistantReplyMode _replyMode = AssistantReplyMode.auto;

  String _t(String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _looksLikeUrdu(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final priorHistory = List<AssistantMessage>.from(_messages);
    setState(() {
      _sending = true;
      _messages.add(AssistantMessage(role: 'user', content: text));
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final reply = await _assistantService.sendMessage(
        message: text,
        history: priorHistory,
        mode: _replyMode,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(
          AssistantMessage(role: 'assistant', content: reply.reply),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AssistantMessage(
            role: 'assistant',
            content: _t(
              'I could not reach the AI service right now. Please try again.',
              'میں ابھی AI سروس تک نہیں پہنچ سکا۔ براہ کرم دوبارہ کوشش کریں۔',
            ),
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildMessageBubble(AssistantMessage message) {
    final isUser = message.isUser;
    final bubbleColor = isUser ? Colors.green.shade700 : Colors.white;
    final textColor = isUser ? Colors.white : AppColors.textPrimary;
    final isUrdu = _looksLikeUrdu(message.content);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: isUser ? null : Border.all(color: AppColors.primaryBorder),
        ),
        child: Directionality(
          textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
          child: Text(
            message.content,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Assistant',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              _t('English + Urdu', 'انگریزی + اردو'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade800, Colors.green.shade600],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_sending && index == _messages.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: const CompactLoadingIndicator(size: 18),
                      ),
                    );
                  }
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        style: const TextStyle(color: Colors.black),
                        cursorColor: Colors.black,
                        decoration: InputDecoration(
                          hintText: _t('Type here...', 'یہاں لکھیں...'),
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: _sending ? null : _sendMessage,
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
