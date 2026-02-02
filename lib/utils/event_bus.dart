import 'dart:async';

class EventBus {
  final StreamController<Map<String, dynamic>> _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<T> on<T>() {
    return _controller.stream
        .where((event) => event.containsKey('type') && event['type'] == T.toString())
        .map((event) => event['data'] as T);
  }

  Stream<dynamic> onEvent(String eventName) {
    return _controller.stream
        .where((event) => event['type'] == eventName)
        .map((event) => event['data']);
  }

  void emit(String eventName, dynamic data) {
    _controller.add({
      'type': eventName,
      'data': data,
    });
  }

  void dispose() {
    _controller.close();
  }
}
