import 'dart:async';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

import '../features/caption/presentation/controllers/subtitle_model.dart';
import '../features/assistant/presentation/controllers/question_model.dart' show ConnectionStatus;


class SseService {
  static const String _supabaseUrl = AppConfig.supabaseUrl;
  static const String _supabaseAnonKey = AppConfig.supabaseAnonKey;

  SupabaseClient? _client;
  dynamic _channel;

  StreamController<SubtitleSegment>? _subtitleController;
  StreamController<ConnectionStatus>? _statusController;

  SseService() {
    _subtitleController = StreamController<SubtitleSegment>.broadcast();
    _statusController = StreamController<ConnectionStatus>.broadcast();
  }

  String? _lectureId;

  Stream<SubtitleSegment> get subtitleStream =>
      _subtitleController?.stream ?? const Stream.empty();

  Stream<ConnectionStatus> get statusStream =>
      _statusController?.stream ?? const Stream.empty();

  Future<void> connect({String? lectureId}) async {
    _subtitleController ??= StreamController<SubtitleSegment>.broadcast();
    _statusController ??= StreamController<ConnectionStatus>.broadcast();

    _lectureId = lectureId ?? AppConfig.defaultLectureId;

    debugPrint('[SSE] connect start lectureId=$_lectureId');
    debugPrint(
      '[SSE] supabaseUrl empty=${_supabaseUrl.isEmpty}, anonKey empty=${_supabaseAnonKey.isEmpty}',
    );

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      debugPrint('[SSE] missing Supabase config');
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
              debugPrint('[SSE] new_caption payload: $payload');

              final payloadMap = Map<String, dynamic>.from(payload);
              final json = payloadMap['payload'] is Map
                  ? Map<String, dynamic>.from(payloadMap['payload'] as Map)
                  : payloadMap;

              final segment = SubtitleSegment.fromJson(json);
              _subtitleController?.add(segment);
            },
          )
          .subscribe((status, error) {
            debugPrint('[SSE] subscribe status: $status');
            if (error != null) {
              debugPrint('[SSE] subscribe error: $error');
            }

            final statusText = status.toString();

            if (statusText.contains('subscribed') ||
                statusText.contains('SUBSCRIBED')) {
              _statusController?.add(ConnectionStatus.connected);
            } else if (statusText.contains('channelError') ||
                statusText.contains('CHANNEL_ERROR') ||
                statusText.contains('timedOut') ||
                statusText.contains('TIMED_OUT')) {
              _statusController?.add(ConnectionStatus.error);
            }
          });

      debugPrint('[SSE] subscribe requested: lecture_$_lectureId');
    } catch (e) {
      debugPrint('[SSE] connect error: $e');
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
    _mockTimer?.cancel();
    _mockTimer = null;

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
    _mockTimer = null;
    _statusController?.add(ConnectionStatus.disconnected);
  }
}
