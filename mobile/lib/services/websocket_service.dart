import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class StockWebSocketService {
  StockWebSocketService({this.baseWs = 'ws://127.0.0.1:8000'});

  final String baseWs;

  WebSocketChannel connect({required int stationId, required String accessToken}) {
    final uri = Uri.parse('$baseWs/ws/stations/$stationId/?token=$accessToken');
    return WebSocketChannel.connect(uri);
  }

  void listen(WebSocketChannel channel, void Function(Map<String, dynamic>) onUpdate) {
    channel.stream.listen((event) {
      onUpdate(jsonDecode(event as String) as Map<String, dynamic>);
    });
  }
}
