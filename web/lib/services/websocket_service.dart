import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/utils/formatters.dart';

class StockWebSocketService {
  StockWebSocketService({String? baseWs}) : baseWs = baseWs ?? wsBaseFromApi(const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000/api'));

  final String baseWs;

  WebSocketChannel connect({required int stationId, required String accessToken}) {
    final uri = Uri.parse('$baseWs/ws/stations/$stationId/?token=$accessToken');
    return WebSocketChannel.connect(uri);
  }

  void listen(WebSocketChannel channel, void Function(Map<String, dynamic>) onUpdate) {
    channel.stream.listen(
      (event) {
        try {
          onUpdate(jsonDecode(event as String) as Map<String, dynamic>);
        } catch (_) {}
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }
}
