import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/caption/presentation/controllers/subtitle_model.dart';
import '../features/assistant/presentation/controllers/question_model.dart' show ConnectionStatus;


class SseService {
  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  SupabaseClient? _client;
  dynamic _channel;

  StreamController<SubtitleSegment>? _subtitleController;
  StreamController<ConnectionStatus>? _statusController;

  String? _lectureId;

  Stream<SubtitleSegment> get subtitleStream =>
      _subtitleController?.stream ?? const Stream.empty();

  Stream<ConnectionStatus> get statusStream =>
      _statusController?.stream ?? const Stream.empty();

  Future<void> connect({String? lectureId}) async {
    _subtitleController ??= StreamController<SubtitleSegment>.broadcast();
    _statusController ??= StreamController<ConnectionStatus>.broadcast();

    _lectureId = lectureId ?? 'demo-lecture';

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      _statusController?.add(ConnectionStatus.error);
      return;
    }

    _statusController?.add(ConnectionStatus.connecting);

    try {
      _client ??= SupabaseClient(_supabaseUrl, _supabaseAnonKey);

      _channel = _client!.channel('lecture_$_lectureId');

      _channel
          .onBroadcast(
            event: 'new_caption',
            callback: (payload) {
              final json = Map<String, dynamic>.from(payload);
              final segment = SubtitleSegment.fromJson(json);
              _subtitleController?.add(segment);
            },
          )
          .subscribe();

      _statusController?.add(ConnectionStatus.connected);
    } catch (_) {
      _statusController?.add(ConnectionStatus.error);
    }
  }

  void disconnect() {
    try {
      _channel?.unsubscribe();
    } catch (_) {}

    _channel = null;
    _statusController?.add(ConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _subtitleController?.close();
    _statusController?.close();
    _subtitleController = null;
    _statusController = null;
  }

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
    _mockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final text = mockData[index % mockData.length];

      _subtitleController?.add(
        SubtitleSegment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          originalText: text,
          translatedText: text.contains(RegExp(r'[a-zA-Z]{4,}'))
              ? '$text (번역됨)'
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
