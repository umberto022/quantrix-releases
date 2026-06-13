import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;

  const ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiChatService {
  static final AiChatService _i = AiChatService._();
  factory AiChatService() => _i;
  AiChatService._();

  // Configurá tu API key aquí o en las variables de entorno
  static const _apiKey = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
    defaultValue: '', // Agregá tu key aquí: 'sk-ant-...'
  );

  static const _systemPrompt = '''Sos el asistente de análisis de mercado de Quantrix.
Tu rol es ayudar a los usuarios a entender mercados financieros: crypto, forex, acciones.
Respondés en español, de manera clara y concisa.
Cuando alguien pregunta sobre un activo, dás contexto de precio, tendencias y riesgo.
No dás consejos financieros directos, pero sí explicás conceptos y datos.
Sos experto en análisis técnico: RSI, MACD, Bandas de Bollinger, soportes/resistencias.
Máximo 3 párrafos por respuesta.''';

  Future<String> chat(List<ChatMessage> history, String userMessage) async {
    if (_apiKey.isEmpty) {
      return 'Para usar el chat IA, configurá tu API key de Anthropic en las variables de entorno de la app.';
    }

    final messages = [
      ...history.map((m) => m.toJson()),
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final resp = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 1024,
          'system': _systemPrompt,
          'messages': messages,
        }),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final content = data['content'] as List<dynamic>;
        return (content.first as Map<String, dynamic>)['text'] as String? ??
            'Sin respuesta';
      }
      return 'Error ${resp.statusCode}. Revisá tu API key.';
    } catch (e) {
      return 'Error de conexión. Intentá de nuevo.';
    }
  }
}
