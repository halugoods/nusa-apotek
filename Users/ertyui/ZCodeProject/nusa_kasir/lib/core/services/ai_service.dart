import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI chat message.
class ChatMessage {
  final String role; // 'user', 'assistant', or 'tool'
  final String content;
  final DateTime timestamp;
  final String? toolCallId;   // for 'tool' role messages
  final String? toolName;     // metadata from assistant tool_calls
  final Map<String, dynamic>? toolArgs; // arguments for assistant tool_calls

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.toolCallId,
    this.toolName,
    this.toolArgs,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Whether this message should be hidden from chat UI (internal tool messages).
  bool get isInternal => role == 'tool' || (role == 'assistant' && toolCallId != null);

  /// Serialize to OpenAI-compatible format for sending to Groq.
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'role': role};
    if (role == 'tool') {
      // Tool result message: {role: "tool", tool_call_id: "...", content: "..."}
      m['tool_call_id'] = toolCallId;
      m['content'] = content;
    } else if (role == 'assistant' && toolCallId != null && toolName != null) {
      // Assistant message with tool_calls: {role: "assistant", content: null, tool_calls: [...]}
      m['content'] = null;
      m['tool_calls'] = [
        {
          'id': toolCallId,
          'type': 'function',
          'function': {
            'name': toolName,
            'arguments': toolArgs != null && toolArgs!.isNotEmpty
                ? const JsonEncoder().convert(toolArgs)
                : '{}',
          },
        },
      ];
    } else {
      // Regular message (user or assistant text): {role: "...", content: "..."}
      m['content'] = content;
    }
    return m;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String? ?? '',
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Represents a tool call requested by the AI model.
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({required this.id, required this.name, required this.arguments});

  factory ToolCall.fromJson(Map<String, dynamic> json) => ToolCall(
        id: json['id'] as String? ?? '',
        name: json['function']?['name'] as String? ?? '',
        arguments: (json['function']?['arguments'] as String?)?.isNotEmpty == true
            ? _safeJsonDecode(json['function']['arguments'] as String)
            : {},
      );

  static Map<String, dynamic> _safeJsonDecode(String s) {
    try {
      return const JsonDecoder().convert(s) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

/// Response from the AI service — either a text reply or tool calls.
class AiResponse {
  final String? reply;
  final List<ToolCall>? toolCalls;

  const AiResponse({this.reply, this.toolCalls});

  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;
}

/// Calls the Supabase Edge Function `ai-assistant` for AI chat.
/// Uses Groq API (free, fast) — powered by Llama 3.1 8B Instant.
class AiService {
  final SupabaseClient supabase;

  AiService(this.supabase);

  /// Send a conversation with optional tools and get the assistant's response.
  /// When [tools] is provided, the AI may request tool calls instead of text.
  Future<AiResponse> chat({
    required List<ChatMessage> messages,
    String? storeName,
    String? dbContext,
    List<Map<String, dynamic>>? tools, // OpenAI-compatible tool definitions
  }) async {
    final body = <String, dynamic>{
      'messages': messages.map((m) => m.toJson()).toList(),
      if (storeName != null) 'store_name': storeName,
      if (dbContext != null) 'db_context': dbContext,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
    };

    try {
      final res = await supabase.functions.invoke(
        'ai-assistant',
        body: body,
      );

      if (res.status >= 400) {
        return const AiResponse(reply: 'Maaf, AI Assistant sedang tidak tersedia.');
      }

      final data = res.data as Map<String, dynamic>;

      // Check for tool calls
      final rawToolCalls = data['tool_calls'] as List?;
      if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
        final toolCalls = rawToolCalls
            .map((t) => ToolCall.fromJson(t as Map<String, dynamic>))
            .toList();
        return AiResponse(toolCalls: toolCalls);
      }

      // Text reply
      final reply = data['reply'] as String? ?? 'Maaf, tidak ada jawaban.';
      return AiResponse(reply: reply);
    } catch (e) {
      return AiResponse(reply: 'Gagal menghubungi AI Assistant: $e');
    }
  }
}
