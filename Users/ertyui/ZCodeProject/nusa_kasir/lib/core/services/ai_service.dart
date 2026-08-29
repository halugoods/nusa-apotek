import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
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

  /// Serialize to OpenAI-compatible format for sending to the AI provider.
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
      toolCallId: json['tool_call_id'] as String?,
      toolName: json['tool_name'] as String?,
      toolArgs: json['tool_args'] != null
          ? (json['tool_args'] is Map<String, dynamic>
              ? json['tool_args'] as Map<String, dynamic>
              : _safeJsonDecode(json['tool_args'] as String? ?? ''))
          : null,
    );
  }

  static Map<String, dynamic> _safeJsonDecode(String s) {
    try {
      return const JsonDecoder().convert(s) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
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

/// Konfigurasi provider AI (dari `ai_settings` — dashboard nusa-online / app).
class AiSettings {
  final String baseUrl;
  final String model;
  final bool isCustom;
  final String defaultModel;

  const AiSettings({
    required this.baseUrl,
    required this.model,
    required this.isCustom,
    required this.defaultModel,
  });

  factory AiSettings.fromJson(Map<String, dynamic> json) => AiSettings(
        baseUrl: json['base_url'] as String? ?? 'https://openrouter.ai/api/v1',
        model: json['model'] as String? ?? 'google/gemini-2.0-flash-lite-001',
        isCustom: json['is_custom'] as bool? ?? false,
        defaultModel: json['default_model'] as String? ?? '',
      );
}

/// Stream event dari edge function (SSE).
class AiStreamEvent {
  final String? delta;
  final List<dynamic>? toolCallsDelta;
  final bool done;

  const AiStreamEvent({this.delta, this.toolCallsDelta, this.done = false});

  bool get isDone => done;
}

/// Calls the Supabase Edge Function `ai-assistant` (cloud, Area H) untuk AI chat.
///
/// - Streaming SSE: [chatStream] menerima [AiStreamEvent] per token.
/// - Tool-calling: kirim `tools` (JSON Schema) — provider bisa minta tool.
/// - Provider configurable: `ai_settings` per owner (dashboard nusa-online).
/// - Riwayat chat cloud: `ai_chat_history` (via owner + session_id).
class AiService {
  final SupabaseClient supabase;

  AiService(this.supabase);

  /// Canonical UID (nusa_account_uid → nusa_google_user_id) sebagai owner.
  static Future<String?> ownerId() => SecureStore.resolveCanonicalUid();

  /// URL edge function langsung (untuk SSE manual via http).
  static String functionUrl() =>
      '${NusaConfig.supabaseUrl}/functions/v1/ai-assistant';

  /// Ambil konfigurasi AI untuk [owner] (dipakai app + dashboard).
  static Future<AiSettings?> getSettings(String? owner) async {
    try {
      final url = Uri.parse(
        '${functionUrl()}/settings?owner=${owner ?? ''}',
      );
      final res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${NusaConfig.supabaseAnon}',
          'apikey': NusaConfig.supabaseAnon,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return AiSettings.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Simpan konfigurasi AI untuk [owner] (upsert ai_settings).
  static Future<bool> saveSettings({
    required String owner,
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(functionUrl()),
        headers: {
          'Authorization': 'Bearer ${NusaConfig.supabaseAnon}',
          'apikey': NusaConfig.supabaseAnon,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'save_settings',
          'owner': owner,
          'base_url': baseUrl,
          'api_key': apiKey,
          'model': model,
        }),
      ).timeout(const Duration(seconds: 15));
      return res.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  /// Cloud chat history — daftar sesi chat (title = pesan user pertama).
  /// Area H: riwayat chat tersimpan di `ai_chat_history` (Supabase), jadi
  /// user bisa buka chat lama dari perangkat mana pun.
  static Future<List<Map<String, dynamic>>> getHistory({
    required String owner,
    int limit = 30,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(functionUrl()),
        headers: {
          'Authorization': 'Bearer ${NusaConfig.supabaseAnon}',
          'apikey': NusaConfig.supabaseAnon,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'history',
          'owner': owner,
          'limit': limit,
        }),
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode >= 400) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['sessions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cloud chat history — pesan lengkap 1 sesi.
  static Future<List<Map<String, dynamic>>> getHistoryMessages({
    required String owner,
    required String sessionId,
    int limit = 100,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(functionUrl()),
        headers: {
          'Authorization': 'Bearer ${NusaConfig.supabaseAnon}',
          'apikey': NusaConfig.supabaseAnon,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'history_messages',
          'owner': owner,
          'session_id': sessionId,
          'limit': limit,
        }),
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode >= 400) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['messages'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cloud chat history — hapus 1 sesi.
  static Future<bool> deleteHistory({
    required String owner,
    required String sessionId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(functionUrl()),
        headers: {
          'Authorization': 'Bearer ${NusaConfig.supabaseAnon}',
          'apikey': NusaConfig.supabaseAnon,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': 'history_delete',
          'owner': owner,
          'session_id': sessionId,
        }),
      ).timeout(const Duration(seconds: 20));
      return res.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  /// Non-streaming chat — pakai fungsi invoke SDK (simple, untuk test/admin).
  Future<AiResponse> chat({
    required List<ChatMessage> messages,
    String? storeName,
    String? dbContext,
    List<Map<String, dynamic>>? tools,
    String? owner,
    String? sessionId,
  }) async {
    final body = <String, dynamic>{
      'messages': messages.map((m) => m.toJson()).toList(),
      if (storeName != null) 'store_name': storeName,
      if (dbContext != null) 'db_context': dbContext,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (owner != null && owner.isNotEmpty) 'owner': owner,
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
    };

    try {
      final res = await supabase.functions.invoke('ai-assistant', body: body);
      if (res.status >= 400) {
        return const AiResponse(reply: 'Maaf, AI Assistant sedang tidak tersedia.');
      }
      final data = res.data as Map<String, dynamic>;
      final rawToolCalls = data['tool_calls'] as List?;
      if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
        final toolCalls = rawToolCalls
            .map((t) => ToolCall.fromJson(t as Map<String, dynamic>))
            .toList();
        return AiResponse(toolCalls: toolCalls);
      }
      final reply = data['reply'] as String? ?? 'Maaf, tidak ada jawaban.';
      return AiResponse(reply: reply);
    } catch (e) {
      return AiResponse(reply: 'Gagal menghubungi AI Assistant: $e');
    }
  }

  /// Streaming chat via SSE (token bertahap) + tool-calling.
  ///
  /// Menghubungi edge function `ai-assistant` dengan `stream: true` dan
  /// `Content-Type: text/event-stream`; mem-parse event `data:` berisi
  /// `{delta}` (teks) atau `{tool_calls_delta}`. Callback [onEvent] dipanggil
  /// per event; [onDone] saat selesai. Mengembalikan tool_calls terkumpul
  /// (kalau ada).
  static Future<List<ToolCall>?> chatStream({
    required List<ChatMessage> messages,
    List<Map<String, dynamic>>? tools,
    String? storeName,
    String? owner,
    String? sessionId,
    required void Function(AiStreamEvent) onEvent,
    void Function()? onDone,
  }) async {
    final body = <String, dynamic>{
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': true,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (storeName != null) 'store_name': storeName,
      if (owner != null && owner.isNotEmpty) 'owner': owner,
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
    };

    final client = http.Client();
    try {
      final req = http.Request('POST', Uri.parse(functionUrl()))
        ..headers.addAll({
          'Authorization': 'Bearer ${NusaConfig.supabaseAnon}',
          'apikey': NusaConfig.supabaseAnon,
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode(body);

      final streamed = await client.send(req).timeout(
            const Duration(seconds: 120),
          );

      if (streamed.statusCode >= 400) {
        onEvent(const AiStreamEvent(
          delta: 'Maaf, AI Assistant sedang tidak tersedia.',
        ));
        onDone?.call();
        return null;
      }

      final collectedToolCalls = <Map<String, dynamic>>[];
      final toolCallIndex = <int, Map<String, dynamic>>{};

      await streamed.stream.transform(utf8.decoder).transform(
        const LineSplitter(),
      ).forEach((line) async {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) return;
        final payload = trimmed.substring(5).trim();
        if (payload.isEmpty) return;
        if (payload == '[DONE]') return;
        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          if (json['done'] == true) return;
          if (json['delta'] != null) {
            onEvent(AiStreamEvent(delta: json['delta'] as String));
            return;
          }
          if (json['tool_calls_delta'] != null) {
            final deltas = json['tool_calls_delta'] as List;
            for (final d in deltas) {
              final dMap = d as Map<String, dynamic>;
              final idx = dMap['index'] as int? ?? 0;
              final entry = toolCallIndex.putIfAbsent(idx, () => {
                    'id': dMap['id'] as String? ?? '',
                    'type': 'function',
                    'function': {'name': '', 'arguments': ''},
                  });
              final fn = dMap['function'] as Map<String, dynamic>?;
              if (fn != null) {
                if (entry['id'] == '') entry['id'] = dMap['id'] ?? '';
                final name = fn['name'] as String?;
                final args = fn['arguments'] as String?;
                if (name != null && name.isNotEmpty) {
                  (entry['function'] as Map<String, dynamic>)['name'] =
                      (entry['function'] as Map<String, dynamic>)['name'] + name;
                }
                if (args != null && args.isNotEmpty) {
                  (entry['function'] as Map<String, dynamic>)['arguments'] =
                      (entry['function'] as Map<String, dynamic>)['arguments'] + args;
                }
              }
            }
            onEvent(AiStreamEvent(toolCallsDelta: deltas));
            return;
          }
          // non-stream fallback: {reply, tool_calls}
          if (json['reply'] != null) {
            onEvent(AiStreamEvent(delta: json['reply'] as String));
          }
          if (json['tool_calls'] != null) {
            collectedToolCalls.addAll(
              (json['tool_calls'] as List).cast<Map<String, dynamic>>(),
            );
          }
        } catch (_) {
          // bukan JSON — lewati
        }
      });

      // gabungkan tool call index (streaming) → daftar final
      final finalToolCalls = toolCallIndex.values
          .map((e) => ToolCall.fromJson(e))
          .toList();

      onDone?.call();
      if (finalToolCalls.isNotEmpty) return finalToolCalls;
      if (collectedToolCalls.isNotEmpty) {
        return collectedToolCalls.map((e) => ToolCall.fromJson(e)).toList();
      }
      return null;
    } catch (e) {
      onEvent(AiStreamEvent(
        delta: 'Gagal terhubung ke AI Assistant ($e)',
      ));
      onDone?.call();
      return null;
    } finally {
      client.close();
    }
  }
}
