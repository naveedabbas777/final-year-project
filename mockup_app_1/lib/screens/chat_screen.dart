import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/market_api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.listingId, required this.toUid});

  final String listingId;
  final String toUid;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = MarketApiService();
  final _controller = TextEditingController();
  final _messages = <Map<String, dynamic>>[];
  StreamSubscription<String>? _sseSub;
  HttpClient? _httpClient;
  String? _myUid;
  bool _connecting = true;
  bool _sending = false;
  final Set<String> _typingUids = <String>{};
  Timer? _typingDebounce;
  bool _isTypingSent = false;
  bool _sellerIsOnline = false;
  DateTime? _sellerLastSeen;

  String _formatTs(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is Map && raw['seconds'] is num) {
      final dt = DateTime.fromMillisecondsSinceEpoch(((raw['seconds'] as num).toInt()) * 1000, isUtc: true).toLocal();
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
    _connectRealtime();
    _fetchPresence();
    _service.setPresence(isOnline: true);
  }

  @override
  void dispose() {
    if (_isTypingSent) {
      _service.setTyping(listingId: widget.listingId, isTyping: false);
    }
    _service.setPresence(isOnline: false);
    _typingDebounce?.cancel();
    _sseSub?.cancel();
    _httpClient?.close(force: true);
    _controller.dispose();
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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _connecting = false);
        return;
      }

      final token = await user.getIdToken(true);
      final uri = Uri.parse('${_base()}/api/messages/stream/listing/${widget.listingId}?limit=200');

      _httpClient?.close(force: true);
      _httpClient = HttpClient();
      final req = await _httpClient!.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      final res = await req.close();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (!mounted) return;
        setState(() => _connecting = false);
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
    } catch (_) {
      _reconnectLater();
    }
  }

  String _pendingEvent = 'message';

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
      final rows = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(rows);
      });
      _markReadIfNeeded(rows);
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

  Future<void> _markReadIfNeeded(List<Map<String, dynamic>> rows) async {
    final hasUnread = rows.any((m) {
      final toUid = (m['toUid'] ?? '').toString();
      final readBy = _toStringList(m['readBy']);
      return toUid == (_myUid ?? '') && !readBy.contains(_myUid ?? '');
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
    _typingDebounce = Timer(const Duration(milliseconds: 1200), () {
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
    try {
      final presence = await _service.getPresence(widget.toUid);
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(message: text, listingId: widget.listingId, toUid: widget.toUid);
      _controller.clear();
      if (_isTypingSent) {
        _isTypingSent = false;
        _service.setTyping(listingId: widget.listingId, isTyping: false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
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
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat'),
            Text(
              _formatPresence(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_typingUids.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: Colors.white,
              child: Text(
                'Seller is typing...',
                style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          if (_connecting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: Colors.green.shade100,
              child: Text('Connecting chat...', style: TextStyle(color: Colors.green.shade900, fontSize: 12)),
            ),
          Expanded(
            child: ListView.builder(
              reverse: false,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final fromMe = (msg['fromUid'] ?? '').toString() == (_myUid ?? '');
                final readBy = _toStringList(msg['readBy']);
                final messageToUid = (msg['toUid'] ?? '').toString();
                final isRead = messageToUid.isNotEmpty && readBy.contains(messageToUid);
                final isIncomingUnread = !fromMe && messageToUid == (_myUid ?? '') && !readBy.contains(_myUid ?? '');
                return Align(
                  alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: fromMe ? Colors.green.shade700 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (msg['message'] ?? '').toString(),
                          style: TextStyle(color: fromMe ? Colors.white : Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTs(msg['timestamp']),
                              style: TextStyle(fontSize: 10, color: fromMe ? Colors.white70 : Colors.grey.shade600),
                            ),
                            if (fromMe) ...[
                              const SizedBox(width: 8),
                              Icon(
                                isRead ? Icons.done_all : Icons.check,
                                size: 13,
                                color: isRead ? Colors.lightGreenAccent.shade100 : Colors.white70,
                              ),
                            ],
                            if (isIncomingUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Unread',
                                  style: TextStyle(fontSize: 9, color: Colors.green.shade900, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
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
                        hintText: 'Message seller...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: const CircleBorder(), padding: const EdgeInsets.all(12)),
                    onPressed: _sending ? null : _send,
                    child: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.white),
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
