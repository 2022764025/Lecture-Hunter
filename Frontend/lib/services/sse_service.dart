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
  Timer? _pollingTimer; 
  int _lastRowId = 0;   

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

    // [치명적 버그 수정] 다른 파일에서 이미 'lecture-'를 붙여서 넘겨줬으므로,
    // 내부에서 중복으로 접두사를 더하거나 조립하지 않고 들어온 순정 문자열 그대로 쓴다
    _lectureId = lectureId ?? AppConfig.defaultLectureId;

    print('==========================================================');
    print('[SseService] 순정 ID 다이렉트 매핑 가동! 강의 ID: $_lectureId');
    print('==========================================================');

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      print('[SseService] 에러: Supabase 설정값이 비어있습니다.');
      _statusController?.add(ConnectionStatus.error);
      return;
    }

    _statusController?.add(ConnectionStatus.connecting);

    try {
      try {
        _client = Supabase.instance.client;
      } catch (_) {
        _client ??= SupabaseClient(_supabaseUrl, _supabaseAnonKey);
      }
      
      _pollingTimer?.cancel();
      _lastRowId = 0; 

      _statusController?.add(ConnectionStatus.connected);

      _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        try {
          // 순정 _lectureId 그대로 변조 없이 완벽하게 타겟팅 쿼리 설정
          final response = await _client!
              .from('lecture_contents')
              .select('id, original_text, translated_text, created_at')
              .eq('lecture_id', _lectureId!)
              .gt('id', _lastRowId) 
              .order('id', ascending: true);

          if (response != null && response.isNotEmpty) {
            print('[SseService Polling] [연동 매칭 성공] 새 자막 로드 완료! 개수: ${response.length}');
            
            for (var row in response) {
              final int currentId = int.parse(row['id'].toString());
              
              if (currentId > _lastRowId) {
                _lastRowId = currentId; 
              }

              final segment = SubtitleSegment(
                id: currentId.toString(),
                originalText: row['original_text']?.toString() ?? '',
                translatedText: row['translated_text']?.toString(),
                language: 'ko',
                timestamp: row['created_at'] != null
                    ? DateTime.parse(row['created_at'].toString())
                    : DateTime.now(),
              );
              
              _subtitleController?.add(segment);
            }
          }
        } catch (pollingError) {
          print('[SseService Polling] 쿼리 전송 실패 에러: $pollingError');
        }
      });

      print('[SseService] 문자열 필터링 싱크 동기화 완료!');
    } catch (e) {
      print('[SseService] connect 초기화 실패: $e');
      _statusController?.add(ConnectionStatus.error);
    }
  }

  void disconnect() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
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
    ];

    int index = 0;
    _mockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final text = mockData[index % mockData.length];

      _subtitleController?.add(
        SubtitleSegment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          originalText: text,
          translatedText: null,
          language: 'ko',
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