import 'package:flutter/material.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/services/assistant_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class FloatingAssistantWidget extends StatefulWidget {
  final Key? key;

  const FloatingAssistantWidget({this.key}) : super(key: key);

  @override
  State<FloatingAssistantWidget> createState() =>
      _FloatingAssistantWidgetState();
}

class _FloatingAssistantWidgetState extends State<FloatingAssistantWidget>
    with SingleTickerProviderStateMixin {
  final _assistantService = AssistantService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<AssistantMessage> _messages = [
    AssistantMessage(
      role: 'assistant',
      content:
          'Assalam-o-Alaikum! I am your expert farming advisor. I provide detailed guidance on crop cultivation, soil management, pest control, irrigation, fertilization, seasonal planning, harvesting techniques, and farming best practices. Ask me about any aspect of agricultural knowledge or farming activities. میں آپ کے زراعتی معاملات میں مدد کے لیے یہاں ہوں۔',
    ),
  ];

  bool _isExpanded = false;
  bool _sending = false;
  AssistantReplyMode _replyMode = AssistantReplyMode.auto;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _looksLikeUrdu(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  String _t(String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
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
        _sending = false;
      });
      _scrollToBottom();
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
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(AssistantMessage message) {
    final isUser = message.isUser;
    final isUrdu = _looksLikeUrdu(message.content);
    final bgColor = isUser ? Colors.green.shade600 : Colors.white;
    final textColor = isUser ? Colors.white : Colors.grey.shade900;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        constraints: BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      // Minimized FAB state
      return Positioned(
        right: 16,
        bottom: 80,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade700, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded chat state
    return Positioned(
      right: 12,
      bottom: 20,
      width: 320,
      height: 600,
      child: Material(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green.shade800, Colors.green.shade600],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Farming Assistant',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _t('English + Urdu', 'انگریزی + اردو'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleExpanded,
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(_messages[index]);
                  },
                ),
              ),
              // Input Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _controller,
                          enabled: !_sending,
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: _t('Ask...', 'سوال کریں...'),
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _sendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                _sending
                                    ? [
                                      Colors.grey.shade400,
                                      Colors.grey.shade300,
                                    ]
                                    : [
                                      Colors.green.shade700,
                                      Colors.green.shade600,
                                    ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child:
                              _sending
                                  ? CompactLoadingIndicator(
                                    color: Colors.white,
                                    size: 18,
                                  )
                                  : Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                        ),
                      ),
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
