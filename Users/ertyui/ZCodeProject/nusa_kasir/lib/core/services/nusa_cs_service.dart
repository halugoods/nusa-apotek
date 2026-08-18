import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/ai_service.dart';

/// NUSA CS — bot customer service internal.
///
/// Menghubungi server lokal [NusaCsServer] (Node, 9Router/DeepSeek) yang
/// menjawab grounded ke source code (knowledge.json). Digunakan dari layar
/// AI Chat (ai_chat_screen.dart) — response kompatibel [AiResponse].
class NusaCsServer {
  /// Alamat server Nusa CS (Node, port 8790; 8787 dipakai headroom-proxy).
  /// Emulator Android pakai 10.0.2.2; real device pakai IP LAN PC.
  static Future<String> baseUrl() async {
    if (NusaConfig.isEmulator) return 'http://10.0.2.2:8790';
    return 'http://${await NusaConfig.lanIp()}:8790';
  }

  static Future<AiResponse> chat({
    required List<ChatMessage> messages,
    String? variant,
  }) async {
    final body = {
      'variant': variant ?? NusaConfig.productId,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
    try {
      final res = await http
          .post(
            Uri.parse('${await baseUrl()}/v1/nusa/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
      if (res.statusCode >= 400) {
        return const AiResponse(reply: 'Maaf, Nusa sedang tidak tersedia.');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return AiResponse(reply: data['reply'] as String? ?? 'Maaf, tidak ada jawaban.');
    } catch (e) {
      return AiResponse(
        reply: 'Maaf, server Nusa sedang offline — nanti saya cek ke tim dulu ya 🙏',
      );
    }
  }
}
