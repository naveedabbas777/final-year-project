import 'package:flutter/foundation.dart';

import 'api_client.dart';

enum AssistantReplyMode { auto, english, urdu, both }

class AssistantMessage {
  AssistantMessage({
    required this.role,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String role;
  final String content;
  final DateTime createdAt;

  bool get isUser => role == 'user';

  Map<String, dynamic> toHistoryPayload() {
    return {'role': role, 'content': content};
  }
}

class AssistantResponse {
  AssistantResponse({required this.reply, required this.language});

  final String reply;
  final String language;

  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    return AssistantResponse(
      reply: (json['reply'] ?? '').toString(),
      language: (json['language'] ?? 'auto').toString(),
    );
  }
}

class AssistantService {
  AssistantService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<AssistantResponse> sendMessage({
    required String message,
    required List<AssistantMessage> history,
    AssistantReplyMode mode = AssistantReplyMode.auto,
  }) async {
    final data = await _client.post(
      '/api/assistant/chat',
      auth: true,
      body: {
        'message': message,
        'language': _modeValue(mode),
        'history': history.map((item) => item.toHistoryPayload()).toList(),
      },
    );

    if (data is Map<String, dynamic>) {
      return AssistantResponse.fromJson(data);
    }

    if (kDebugMode) {
      debugPrint(
        '[AssistantService] Unexpected response type: ${data.runtimeType}',
      );
    }

    throw Exception('Assistant returned an invalid response');
  }

  String _modeValue(AssistantReplyMode mode) {
    switch (mode) {
      case AssistantReplyMode.english:
        return 'en';
      case AssistantReplyMode.urdu:
        return 'ur';
      case AssistantReplyMode.both:
        return 'both';
      case AssistantReplyMode.auto:
        return 'auto';
    }
  }
}
