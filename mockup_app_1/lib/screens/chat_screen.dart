import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

import '../config/app_config.dart';
import '../services/market_api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.listingId,
    this.toUid,
    this.productName,
    this.productImageUrl,
  });

  final String listingId;
  final String? toUid;
  final String? productName;
  final String? productImageUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = MarketApiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessageDto>[];
  bool _loadedInitialMessages = false;
  StreamSubscription<String>? _sseSub;
  HttpClient? _httpClient;
  String? _myUid;
  bool _connecting = true;
  bool _sending = false;
  bool _messagesLoadFailed = false;
  bool _loadingMoreMessages = false;
  bool _hasMoreMessages = true;
  int _messageLimit = 50;
  final Set<String> _typingUids = <String>{};
  Timer? _typingDebounce;
  bool _isTypingSent = false;
  bool _sellerIsOnline = false;
  DateTime? _sellerLastSeen;
  UserProfileDto? _peerProfile;
  bool _loadingPeer = false;
  bool _threadReady = false;
  String? _threadError;

  String get _peerName {
    final profileName = _peerProfile?.primaryName.trim() ?? '';
    if (profileName.isNotEmpty) return profileName;

    final email = _peerProfile?.email.trim() ?? '';
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }

    if (widget.toUid == null || widget.toUid!.trim().isEmpty) {
      return 'Listing Chat';
    }

    return 'Chat';
  }

  String get _chatTitle {
    final product = widget.productName?.trim() ?? '';
    if (product.isNotEmpty) return product;
    return _peerName;
  }

  String get _presenceText {
    if (_sellerIsOnline) return 'Online now';
    final presence = _formatPresence();
    if (presence.isNotEmpty) return presence;
    return _loadingPeer ? 'Loading profile...' : '';
  }

  String get _peerPhotoUrl {
    return _peerProfile?.photoUrl ?? '';
  }

  String _formatTs(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is Map && raw['seconds'] is num) {
      final dt =
          DateTime.fromMillisecondsSinceEpoch(
            ((raw['seconds'] as num).toInt()) * 1000,
            isUtc: true,
          ).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return raw.toString();
  }

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final thread = await _service.ensureListingThread(widget.listingId);
      if (!mounted) return;
      setState(() {
        _threadReady = true;
        _threadError = null;
        if ((widget.productName ?? '').trim().isEmpty && thread.productName.trim().isNotEmpty) {
          // The screen title falls back to the thread's product name via the widget getter.
        }
      });
      if (widget.toUid != null) {
        _loadPeerProfile();
        _fetchPresence();
      }
      // Fire-and-forget presence update; don't let network/token failures crash the UI
      _service.setPresence(isOnline: true).catchError((e) {
        if (kDebugMode) debugPrint('[Chat] setPresence failed: $e');
      });
      await _loadInitialMessages();
      await _connectRealtime();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _threadError = e.toString();
        _threadReady = false;
        _connecting = false;
      });
    }
  }

  @override
  void dispose() {
    if (_isTypingSent) {
      _service
          .setTyping(listingId: widget.listingId, isTyping: false)
          .catchError((_) {});
    }
    _service.setPresence(isOnline: false).catchError((_) {});
    _typingDebounce?.cancel();
    _sseSub?.cancel();
    _httpClient?.close(force: true);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  String _base() {
    return AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
  }

  Future<void> _connectRealtime() async {
    if (!_threadReady) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _connecting = false);
        return;
      }

      // Try to obtain token with a few short retries to avoid transient network failures
      String? token;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          token = await user.getIdToken();
          break;
        } catch (e) {
          if (kDebugMode)
            debugPrint('[Chat] getIdToken attempt ${attempt + 1} failed: $e');
          await Future.delayed(Duration(milliseconds: 300 * (1 << attempt)));
        }
      }

      if (token == null) {
        // give up for now and reconnect later
        if (!mounted) return;
        setState(() => _connecting = false);
        _reconnectLater();
        return;
      }

      final uri = Uri.parse(
        '${_base()}/api/messages/stream/listing/${widget.listingId}?limit=$_messageLimit',
      );

      _httpClient?.close(force: true);
      _httpClient = HttpClient();
      final req = await _httpClient!.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');

      HttpClientResponse res;
      try {
        res = await req.close();
      } catch (e) {
        if (kDebugMode) debugPrint('[Chat] SSE request failed: $e');
        _reconnectLater();
        return;
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (!mounted) return;
        setState(() => _connecting = false);
        if (!_loadedInitialMessages) {
          await _loadInitialMessages();
        }
        return;
      }

      if (!mounted) return;
      setState(() => _connecting = false);

      _sseSub?.cancel();
      _sseSub = res
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleSseLine,
            onError: (_) {
              _reconnectLater();
            },
            onDone: _reconnectLater,
            cancelOnError: true,
          );
    } catch (e) {
      if (kDebugMode)
        debugPrint('[Chat] _connectRealtime unexpected error: $e');
      _reconnectLater();
    }
  }

  Future<void> _loadInitialMessages() async {
    if (!_threadReady) return;
    try {
      final rows = await _service.fetchMessagesForListingWithCache(
        widget.listingId,
        limit: _messageLimit,
      );
      if (!mounted) return;
      setState(() {
        _loadedInitialMessages = true;
        _messagesLoadFailed = false;
        _hasMoreMessages = rows.length >= _messageLimit;
        if (rows.isNotEmpty) {
          _messages
            ..clear()
            ..addAll(rows);
        }
        _connecting = false;
      });
      if (rows.isNotEmpty) {
        await _service.cacheMessagesForListing(widget.listingId, rows);
        await _markReadIfNeeded(rows);
        _scrollToBottom();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedInitialMessages = true;
        _connecting = false;
        _messagesLoadFailed = true;
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (!_threadReady) return;
    if (_loadingMoreMessages || !_hasMoreMessages || _messages.isEmpty) return;
    final cursor = _messages.first.timestamp;
    setState(() => _loadingMoreMessages = true);
    try {
      final rows = await _service.fetchMessagesForListing(
        widget.listingId,
        limit: _messageLimit,
        before: cursor,
      );
      if (!mounted || rows.isEmpty) {
        if (mounted) setState(() => _hasMoreMessages = false);
        return;
      }
      setState(() {
        _messages..insertAll(
          0,
          rows.where((row) => !_messages.any((msg) => msg.id == row.id)),
        );
        _hasMoreMessages = rows.length >= _messageLimit;
      });
      await _service.cacheMessagesForListing(widget.listingId, _messages);
    } finally {
      if (mounted) setState(() => _loadingMoreMessages = false);
    }
  }

  String _pendingEvent = 'message';

  void _scrollToBottom() {
    Future.microtask(() {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSseLine(String line) {
    if (line.startsWith('event:')) {
      _pendingEvent = line.substring(6).trim();
      return;
    }
    if (!line.startsWith('data:')) return;

    final jsonText = line.substring(5).trim();
    if (jsonText.isEmpty) return;

    final decoded = jsonDecode(jsonText);
    if (_pendingEvent == 'snapshot' && decoded is List) {
      final rows =
          decoded
              .whereType<Map>()
              .map((e) => ChatMessageDto.fromJson(Map<String, dynamic>.from(e)))
              .toList();
      if (!mounted) return;
      setState(() {
        final merged = <String, ChatMessageDto>{
          for (final message in _messages) message.id: message,
          for (final message in rows) message.id: message,
        };
        final sorted =
            merged.values.toList()
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _messages
          ..clear()
          ..addAll(sorted);
      });
      _service.cacheMessagesForListing(widget.listingId, _messages);
      _markReadIfNeeded(rows);
      _scrollToBottom();
      return;
    }

    if (_pendingEvent == 'typing' && decoded is Map) {
      final uids = _toStringList(decoded['uids']);
      if (!mounted) return;
      setState(() {
        _typingUids
          ..clear()
          ..addAll(uids.where((uid) => uid != (_myUid ?? '')));
      });
    }
  }

  Future<void> _markReadIfNeeded(List<ChatMessageDto> rows) async {
    final hasUnread = rows.any((m) {
      return m.toUid == (_myUid ?? '') && !m.readBy.contains(_myUid ?? '');
    });

    if (!hasUnread) return;
    try {
      await _service.markListingMessagesRead(widget.listingId);
    } catch (_) {}
  }

  void _onInputChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (hasText && !_isTypingSent) {
      _isTypingSent = true;
      _service.setTyping(listingId: widget.listingId, isTyping: true);
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 800), () {
      if (_isTypingSent) {
        _isTypingSent = false;
        _service.setTyping(listingId: widget.listingId, isTyping: false);
      }
    });
  }

  void _reconnectLater() {
    if (!mounted) return;
    setState(() => _connecting = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _connectRealtime();
      }
    });
  }

  Future<void> _fetchPresence() async {
    final toUid = widget.toUid;
    if (toUid == null) return;
    try {
      final presence = await _service.getPresence(toUid);
      if (!mounted) return;
      setState(() {
        _sellerIsOnline = presence['isOnline'] == true;
        final lastSeenRaw = presence['lastSeen'];
        if (lastSeenRaw != null) {
          if (lastSeenRaw is DateTime) {
            _sellerLastSeen = lastSeenRaw;
          } else if (lastSeenRaw is String) {
            _sellerLastSeen = DateTime.tryParse(lastSeenRaw);
          }
        }
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadPeerProfile() async {
    final toUid = widget.toUid;
    if (toUid == null) return;
    setState(() => _loadingPeer = true);
    try {
      final prof = await _service.fetchUserProfileByUid(toUid);
      if (!mounted) return;
      setState(() => _peerProfile = prof);
    } catch (_) {
      // ignore - keep fallback
    } finally {
      if (mounted) setState(() => _loadingPeer = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(
        message: text,
        listingId: widget.listingId,
        toUid: widget.toUid,
      );
      _controller.clear();
      if (_isTypingSent) {
        _isTypingSent = false;
        _service.setTyping(listingId: widget.listingId, isTyping: false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _deleteMessage(ChatMessageDto msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This will remove the message from your side only.'),
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
        await _service.deleteMessage(msg.id);
        if (!mounted) return;
        setState(() {
          _messages.removeWhere((m) => m.id == msg.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}')),
        );
      }
    }
  }

  String _formatPresence() {
    if (_sellerIsOnline) {
      return 'Online';
    }
    if (_sellerLastSeen == null) {
      return '';
    }
    final now = DateTime.now();
    final diff = now.difference(_sellerLastSeen!);
    if (diff.inMinutes < 1) {
      return 'Last seen just now';
    } else if (diff.inHours < 1) {
      return 'Last seen ${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return 'Last seen ${diff.inHours}h ago';
    } else {
      return 'Last seen ${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _peerPhotoUrl.trim();
    final productImageUrl = (widget.productImageUrl ?? '').trim();
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green.shade100,
              backgroundImage:
                  productImageUrl.isNotEmpty
                      ? NetworkImage(productImageUrl)
                      : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null),
              child:
                  productImageUrl.isEmpty && photoUrl.isEmpty
                      ? Text(
                          _chatTitle.trim().isNotEmpty
                              ? _chatTitle.trim()[0].toUpperCase()
                              : 'P',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        )
                      : null,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_chatTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            if (widget.toUid == null)
              const Text(
                'Conversation attached to this listing',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sellerIsOnline ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color:
                        _sellerIsOnline
                            ? Colors.lightGreenAccent.shade100
                            : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _presenceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_threadError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              color: Colors.red.shade50,
              child: Text(
                _threadError!.contains('must start')
                    ? 'This product chat has not been started by a buyer yet.'
                    : 'Unable to open this product chat right now.',
                style: TextStyle(color: Colors.red.shade800, fontSize: 12),
              ),
            ),
          if (_typingUids.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: Colors.white,
              child: Text(
                'Seller is typing...',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_connecting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: Colors.green.shade100,
              child: Text(
                'Connecting chat...',
                style: TextStyle(color: Colors.green.shade900, fontSize: 12),
              ),
            ),
          Expanded(
            child:
                _messagesLoadFailed && _messages.isEmpty
                    ? AsyncErrorWidget(
                      error: 'Unable to load chat messages right now.',
                      onRetry: () {
                        setState(() {
                          _messagesLoadFailed = false;
                          _connecting = true;
                        });
                        _loadInitialMessages();
                        _connectRealtime();
                      },
                    )
                    : _messages.isEmpty && !_connecting
                    ? const AsyncEmptyWidget(
                      message: 'No messages yet. Start the conversation below.',
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length + (_hasMoreMessages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_hasMoreMessages && index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Center(
                              child: TextButton.icon(
                                onPressed:
                                    _loadingMoreMessages
                                        ? null
                                        : _loadMoreMessages,
                                icon:
                                    _loadingMoreMessages
                                        ? const CompactLoadingIndicator(
                                          size: 14,
                                        )
                                        : const Icon(Icons.unfold_more),
                                label: Text(
                                  _loadingMoreMessages
                                      ? 'Loading earlier messages...'
                                      : 'Load earlier messages',
                                ),
                              ),
                            ),
                          );
                        }

                        final msgIndex = _hasMoreMessages ? index - 1 : index;
                        final msg = _messages[msgIndex];
                        final fromMe = msg.fromUid == (_myUid ?? '');
                        final isRead =
                            msg.toUid != null && msg.readBy.contains(msg.toUid);
                        final isIncomingUnread =
                            !fromMe &&
                            msg.toUid == (_myUid ?? '') &&
                            !msg.readBy.contains(_myUid ?? '');
                        return GestureDetector(
                          onLongPress: () => _deleteMessage(msg),
                          child: Align(
                            alignment:
                                fromMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: AnimatedOpacity(
                              opacity: 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.1, 0),
                                  end: Offset.zero,
                                ).animate(
                                  AlwaysStoppedAnimation(0.0),
                                ),
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 300),
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        fromMe ? Colors.green.shade700 : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.previewText,
                                        style: TextStyle(
                                          color:
                                              fromMe ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatTs(msg.timestamp),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  fromMe
                                                      ? Colors.white70
                                                      : Colors.grey.shade600,
                                            ),
                                          ),
                                          if (fromMe) ...[
                                            const SizedBox(width: 8),
                                            Icon(
                                              isRead ? Icons.done_all : Icons.check,
                                              size: 13,
                                              color:
                                                  isRead
                                                      ? Colors
                                                          .lightGreenAccent
                                                          .shade100
                                                      : Colors.white70,
                                            ),
                                          ],
                                          if (isIncomingUnread) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(
                                                  10,
                                                ),
                                              ),
                                              child: Text(
                                                'Unread',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.green.shade900,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _onInputChanged,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            widget.toUid == null
                                ? 'Message...'
                                : 'Message $_peerName...',
                        filled: true,
                        fillColor: Colors.white,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        labelStyle: const TextStyle(color: Colors.black87),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: AppColors.primaryMid,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sending ? Colors.green.shade600 : Colors.green.shade700,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                      elevation: _sending ? 2 : 4,
                    ),
                    onPressed: _sending ? null : _send,
                    child:
                        _sending
                            ? const CompactLoadingIndicator(
                              size: 16,
                              color: Colors.white,
                            )
                            : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
