import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../models/caption_language.dart';
import '../models/lecture_models.dart';

/// 백엔드 오류. message는 백엔드의 detail(한국어 안내)을 그대로 쓴다.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});

  bool get isTableMissing => statusCode == 503 && message.contains('테이블');

  @override
  String toString() => message;
}

/// FastAPI 백엔드(App/main.py) REST 클라이언트
class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _base = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _base;

  static const _defaultTimeout = Duration(seconds: 60);
  static const _llmTimeout = Duration(seconds: 120);    // 질문 답변·요약 (M1에서 10~25초)
  static const _vlmTimeout = Duration(seconds: 180);    // 화면 질문 (M1에서 약 60초)

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
    });
    return Uri.parse('$_base$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Duration timeout = _defaultTimeout,
  }) async {
    final uri = _uri(path, query);
    final headers = {'Accept': 'application/json', if (body != null) 'Content-Type': 'application/json'};
    late http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _client.send(req).timeout(timeout));
    } on TimeoutException {
      throw const ApiException('서버 응답이 너무 오래 걸립니다. 잠시 후 다시 시도해 주세요.');
    } catch (_) {
      throw const ApiException('백엔드 서버에 연결할 수 없습니다. 서버가 켜져 있는지 확인해 주세요.');
    }

    final text = utf8.decode(res.bodyBytes);
    Object? json;
    try {
      json = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      json = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json is Map<String, dynamic> ? json : <String, dynamic>{};
    }
    throw ApiException(_detail(json) ?? '서버 오류 (${res.statusCode})', statusCode: res.statusCode);
  }

  String? _detail(Object? json) {
    if (json is! Map) return null;
    final detail = json['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty && detail.first is Map) {
      final msg = (detail.first as Map)['msg']?.toString() ?? '';
      return msg.replaceFirst('Value error, ', '');
    }
    return null;
  }

  // ─── 강의 상태·설정 ─────────────────────────────────────────

  Future<LectureStatus> lectureStatus(String lectureId) async =>
      LectureStatus.fromJson(await _request('GET', '/lecture/status', query: {'lecture_id': lectureId}));

  Future<void> setTargetLanguage(String lectureId, CaptionLanguage lang) =>
      _request('PUT', '/lecture/settings', body: {'lecture_id': lectureId, 'target_lang': lang.code});

  Future<void> endLecture(String lectureId) =>
      _request('POST', '/lecture/end', query: {'lecture_id': lectureId}, timeout: _llmTimeout);

  // ─── AI 질문 (RAG) / 화면 질문 (VLM) ─────────────────────────

  Future<AiAnswer> askAi({
    required String lectureId,
    required String question,
    required CaptionLanguage lang,
    required String clientId,
  }) async =>
      AiAnswer.fromJson(await _request('POST', '/lecture/ask',
          body: {
            'lecture_id': lectureId,
            'question': question,
            'target_lang': lang.backendName,
            'client_id': clientId,
          },
          timeout: _llmTimeout));

  Future<void> resetAi({required String lectureId, required String clientId}) =>
      _request('POST', '/lecture/ask/reset', query: {'lecture_id': lectureId, 'client_id': clientId});

  Future<AiAnswer> askAboutScreen({
    required String lectureId,
    required String imageDataUrl,
    required CaptionLanguage lang,
    String? question,
  }) async =>
      AiAnswer.fromJson(await _request('POST', '/api/vlm/analyze',
          body: {
            'lecture_id': lectureId,
            'image': imageDataUrl,
            if (question != null && question.trim().isNotEmpty) 'question': question.trim(),
            'target_lang': lang.backendName,
          },
          timeout: _vlmTimeout));

  // ─── 용어집 ─────────────────────────────────────────────────

  Future<List<GlossaryEntry>> glossary(String lectureId, {String? keyword}) async {
    final json = await _request('GET', '/lecture/glossary',
        query: {'lecture_id': lectureId, 'keyword': keyword?.trim()}, timeout: _llmTimeout);
    return (json['glossary'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(GlossaryEntry.fromJson)
        .toList();
  }

  // ─── 요약 ───────────────────────────────────────────────────

  Future<SummaryResult> summaryRecent(String lectureId, int minutes, CaptionLanguage lang) async =>
      SummaryResult.fromJson(await _request('GET', '/lecture/summary/adaptive',
          query: {'lecture_id': lectureId, 'minutes': minutes, 'target_lang': lang.backendName},
          timeout: _llmTimeout));

  Future<SummaryResult> summaryRange(String lectureId, int startMin, int endMin, CaptionLanguage lang) async =>
      SummaryResult.fromJson(await _request('GET', '/lecture/summary/range',
          query: {
            'lecture_id': lectureId,
            'start_min': startMin,
            'end_min': endMin,
            'target_lang': lang.backendName,
          },
          timeout: _llmTimeout));

  Future<SummaryResult> summaryFull(String lectureId, CaptionLanguage lang) async =>
      SummaryResult.fromJson(await _request('GET', '/lecture/summary/full',
          query: {'lecture_id': lectureId, 'regenerate': 'true', 'target_lang': lang.backendName},
          timeout: const Duration(seconds: 240)));

  // ─── 익명 질문 · 공지 ───────────────────────────────────────

  Future<LectureQuestion> createQuestion({
    required String lectureId,
    required String content,
    required String clientId,
    bool isAiRefined = false,
  }) async {
    final json = await _request('POST', '/lecture/questions', body: {
      'lecture_id': lectureId,
      'content': content,
      'client_id': clientId,
      'is_ai_refined': isAiRefined,
    });
    return LectureQuestion.fromRow(json['question'] as Map<String, dynamic>);
  }

  Future<List<LectureQuestion>> questions(String lectureId) async {
    final json = await _request('GET', '/lecture/questions', query: {'lecture_id': lectureId});
    return (json['questions'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(LectureQuestion.fromRow)
        .toList();
  }

  Future<RefineResult> refineQuestion(String lectureId, String content) async {
    final json = await _request('POST', '/lecture/questions/refine',
        body: {'lecture_id': lectureId, 'content': content}, timeout: _llmTimeout);
    return RefineResult(
      refined: (json['refined'] ?? content).toString(),
      changed: json['changed'] == true,
    );
  }

  Future<List<LectureNotice>> notices(String lectureId) async {
    final json = await _request('GET', '/lecture/notices', query: {'lecture_id': lectureId});
    return (json['notices'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(LectureNotice.fromRow)
        .toList();
  }

  void dispose() => _client.close();
}
