import 'package:supabase_flutter/supabase_flutter.dart';

/// AI chat message.
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };

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

/// Calls the Supabase Edge Function `ai-assistant` for AI chat.
/// Uses Groq API (free, fast) — powered by Llama 3.1 8B Instant.
class AiService {
  final SupabaseClient supabase;

  AiService(this.supabase);

  /// Send a conversation and get the assistant's reply.
  /// [messages] includes the full history (user + assistant turns).
  /// [storeName] is optional — adds store context to the prompt.
  /// [dbContext] is optional — real-time database snapshot for analysis.
  Future<String> chat({
    required List<ChatMessage> messages,
    String? storeName,
    String? dbContext,
  }) async {
    final body = <String, dynamic>{
      'messages': messages.map((m) => m.toJson()).toList(),
      if (storeName != null) 'store_name': storeName,
      if (dbContext != null) 'db_context': dbContext,
    };

    try {
      final res = await supabase.functions.invoke(
        'ai-assistant',
        body: body,
      );

      if (res.status >= 400) {
        return 'Maaf, AI Assistant sedang tidak tersedia.';
      }

      final data = res.data as Map<String, dynamic>;
      return data['reply'] as String? ?? 'Maaf, tidak ada jawaban.';
    } catch (e) {
      return 'Gagal menghubungi AI Assistant: $e';
    }
  }
}
