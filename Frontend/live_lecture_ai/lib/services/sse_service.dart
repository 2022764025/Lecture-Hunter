// lib/services/sse_service.dart
// SSE(Server-Sent Events) 실시간 자막 스트리밍 서비스

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subtitle_model.dart';
import '../models/question_model.dart';

class SseService {
  static const String _baseUrl = 'http://localhost:8000'; // FastAPI 서버

  StreamController<SubtitleSegment>? _subtitleController;
  StreamController<ConnectionStatus>? _statusController;
  http.Client? _client;
  Timer? _reconnectTimer;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // 자막 스트림 (외부 구독용)
  Stream<SubtitleSegment> get subtitleStream =>
      _subtitleController?.stream ?? const Stream.empty();

  // 연결 상태 스트림
  Stream<ConnectionStatus> get statusStream =>
      _statusController?.stream ?? const Stream.empty();

  /// SSE 연결 시작
  Future<void> connect({String? lectureId}) async {
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _subtitleController ??= StreamController<SubtitleSegment>.broadcast();
    _statusController ??= StreamController<ConnectionStatus>.broadcast();

    await _startConnection(lectureId: lectureId);
  }

  Future<void> _startConnection({String? lectureId}) async {
    _statusController?.add(ConnectionStatus.connecting);

    try {
      _client = http.Client();
      final uri = Uri.parse(
        '$_baseUrl/api/v1/subtitle/stream${lectureId != null ? '?lecture_id=$lectureId' : ''}',
      );

      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache'
        ..headers['Connection'] = 'keep-alive';

      final response = await _client!.send(request);

      if (response.statusCode == 200) {
        _statusController?.add(ConnectionStatus.connected);
        _reconnectAttempts = 0;

        // SSE 스트림 파싱
        response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              _onSseData,
              onError: _onSseError,
              onDone: _onSseDone,
            );
      } else {
        _onSseError('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _onSseError(e.toString());
    }
  }

  void _onSseData(String line) {
    if (line.startsWith('data: ')) {
      final jsonStr = line.substring(6).trim();
      if (jsonStr.isEmpty || jsonStr == '[DONE]') return;

      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final segment = SubtitleSegment.fromJson(json);
        _subtitleController?.add(segment);
      } catch (e) {
        // 파싱 오류 무시 (부분 데이터)
      }
    }
  }

  void _onSseError(dynamic error) {
    _statusController?.add(ConnectionStatus.error);
    _scheduleReconnect();
  }

  void _onSseDone() {
    if (_shouldReconnect) {
      _statusController?.add(ConnectionStatus.reconnecting);
      _scheduleReconnect();
    } else {
      _statusController?.add(ConnectionStatus.disconnected);
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectAttempts >= _maxReconnectAttempts) {
      _statusController?.add(ConnectionStatus.disconnected);
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2); // 지수 백오프

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect) {
        _statusController?.add(ConnectionStatus.reconnecting);
        _startConnection();
      }
    });
  }

  /// 연결 해제
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _client?.close();
    _client = null;
    _statusController?.add(ConnectionStatus.disconnected);
  }

  /// 리소스 해제
  void dispose() {
    disconnect();
    _subtitleController?.close();
    _statusController?.close();
    _subtitleController = null;
    _statusController = null;
  }

  // ─── Mock 모드 (백엔드 없을 때 테스트용) ───────────────────────
  Timer? _mockTimer;

  void startMock() {
    _subtitleController ??= StreamController<SubtitleSegment>.broadcast();
    _statusController ??= StreamController<ConnectionStatus>.broadcast();
    _statusController?.add(ConnectionStatus.connected);

    final mockData = [
      '안녕하세요, 오늘은 역전파 알고리즘에 대해 배워보겠습니다.',
      '역전파는 신경망의 가중치를 업데이트하는 핵심 알고리즘입니다.',
      'The backpropagation algorithm calculates gradients efficiently.',
      '기울기 소실 문제는 Sigmoid 함수의 미분값이 작아질 때 발생합니다.',
      '오늘 실습에서는 PyTorch를 사용해 직접 구현해 보겠습니다.',
    ];

    int index = 0;
    _mockTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final text = mockData[index % mockData.length];
      _subtitleController?.add(
        SubtitleSegment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          originalText: text,
          translatedText: text.contains(RegExp(r'[a-zA-Z]{4,}'))
              ? '${text} (번역됨)'
              : null,
          language: text.contains(RegExp(r'[a-zA-Z]{4,}')) ? 'en' : 'ko',
          timestamp: DateTime.now(),
        ),
      );
      index++;
    });
  }

  void stopMock() {
    _mockTimer?.cancel();
    _statusController?.add(ConnectionStatus.disconnected);
  }
}
