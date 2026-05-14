// lib/services/api_service.dart
// FastAPI 백엔드 REST / WebSocket 통신 서비스

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';

class ApiService {
  static const String _baseUrl = 'http://localhost:8000';
  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // ─── 교수에게 질문 (RAG Q&A) ─────────────────────────────────
  Future<QuestionResponse> askQuestion(QuestionRequest request) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/qa/ask'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return QuestionResponse.fromJson(json);
      } else {
        return QuestionResponse.error('서버 오류: ${response.statusCode}');
      }
    } on Exception catch (e) {
      return QuestionResponse.error('연결 실패: $e');
    }
  }

  // ─── 용어집 조회 ─────────────────────────────────────────────
  Future<List<GlossaryEntry>> searchGlossary(String term) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '$_baseUrl/api/v1/glossary/search?term=${Uri.encodeComponent(term)}',
            ),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((e) => GlossaryEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } on Exception {
      return [];
    }
  }

  // ─── Mock 응답 (백엔드 없을 때) ──────────────────────────────
  Future<QuestionResponse> mockAskQuestion(QuestionRequest request) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final answers = {
      'glossary': QuestionResponse(
        answer: '**${request.question}** 은(는) 머신러닝의 핵심 개념으로, '
            '신경망이 오차를 최소화하기 위해 가중치를 업데이트하는 과정입니다. '
            'Gradient Descent를 통해 반복적으로 최적값에 수렴합니다.',
        keyPoints: ['오차 역전파', '경사 하강법', '가중치 업데이트'],
        source: '강의 23:15 구간 참고',
      ),
      'professor': QuestionResponse(
        answer: '교수님 답변: 방금 설명드린 내용에서 **기울기 소실 문제**는 '
            'Sigmoid 활성화 함수를 사용할 때 미분값이 0에 가까워지면서 발생합니다. '
            'ReLU를 사용하면 이 문제를 완화할 수 있습니다.',
        keyPoints: ['기울기 소실', 'Sigmoid', 'ReLU'],
        source: '강의 15분 내용 기반 답변',
        relatedSlide: '슬라이드 7 - 활성화 함수 비교',
      ),
    };

    return answers[request.mode] ??
        QuestionResponse(
          answer: '질문을 이해했습니다. 강의 맥락을 검색 중...',
          keyPoints: [],
        );
  }

  Future<List<GlossaryEntry>> mockSearchGlossary(String term) async {
    await Future.delayed(const Duration(milliseconds: 800));

    return [
      GlossaryEntry(
        term: term,
        definition: '$term: 딥러닝에서 사용되는 핵심 개념으로, 입력 데이터로부터 특징을 자동으로 학습하는 방법입니다.',
        example: '예시: CNN에서 필터가 이미지의 엣지를 감지하는 것이 $term의 대표적 사례입니다.',
        source: '강의 교재 3장 / 강의 내용',
      ),
      GlossaryEntry(
        term: '${term}_관련',
        definition: '${term}과 관련된 심화 개념입니다.',
        source: '추가 참고자료',
      ),
    ];
  }

  void dispose() {
    _client.close();
  }
}
